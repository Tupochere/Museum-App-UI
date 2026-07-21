import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'kokoro_model_manager.dart';
import 'kokoro_phonemizer.dart';

/// A speech clip produced by on-device Kokoro TTS.
class KokoroSpeechClip {
  final Uint8List wavBytes;
  final Duration duration;

  const KokoroSpeechClip({required this.wavBytes, required this.duration});
}

/// On-device TTS using the Kokoro-82M ONNX model.
///
/// Pipeline: text → phoneme IDs → ONNX inference → float32 PCM → 16-bit WAV.
///
/// The model is downloaded on first use via [KokoroModelManager]. If the model
/// is not yet available, throws [KokoroModelNotReadyException] so the caller
/// can fall back to a cloud TTS provider.
class KokoroTtsService {
  KokoroTtsService({KokoroModelManager? modelManager})
      : _modelManager = modelManager ?? KokoroModelManager();

  static const int _sampleRate = 24000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  static const int _bytesPerSecond =
      _sampleRate * _channels * _bitsPerSample ~/ 8;

  final KokoroModelManager _modelManager;
  final KokoroPhonemizer _phonemizer = KokoroPhonemizer();

  OnnxRuntime? _runtime;
  OrtSession? _session;
  Float32List? _voiceEmbedding;
  bool _initialized = false;

  /// Exposes download progress from the model manager.
  ValueNotifier<double?> get downloadProgress => _modelManager.downloadProgress;

  /// Whether the model is downloaded and ready for inference.
  bool get isModelReady {
    _ensureStoragePath();
    return _modelManager.isModelReady;
  }

  /// Synthesize speech from [text].
  ///
  /// Returns a [KokoroSpeechClip] with 24 kHz, 16-bit mono WAV audio.
  ///
  /// If the model is not downloaded, this triggers a background download and
  /// throws [KokoroModelNotReadyException] for the current call. Subsequent
  /// calls after the download completes will succeed.
  Future<KokoroSpeechClip> synthesizeSpeech(String text) async {
    await _ensureInitialized();

    // Tokenize text into phoneme-ID chunks.
    final chunks = _phonemizer.tokenize(text);
    if (chunks.isEmpty) {
      return KokoroSpeechClip(
        wavBytes: _wrapPcmAsWav(Uint8List(0)),
        duration: Duration.zero,
      );
    }

    // Run inference on each chunk and concatenate PCM.
    final allPcmBytes = BytesBuilder(copy: false);
    for (final chunk in chunks) {
      final pcm = await _runInference(chunk);
      allPcmBytes.add(pcm);
    }

    final pcmData = allPcmBytes.toBytes();
    final durationMicros =
        (pcmData.length * Duration.microsecondsPerSecond) ~/ _bytesPerSecond;

    return KokoroSpeechClip(
      wavBytes: _wrapPcmAsWav(pcmData),
      duration: Duration(microseconds: durationMicros),
    );
  }

  /// Pre-load the ONNX session and voice embedding so they're ready
  /// before the user enters voice mode. Safe to call multiple times.
  Future<void> warmUp() async {
    try {
      await _ensureInitialized();
      debugPrint('KokoroTtsService: warm-up complete.');
    } catch (e) {
      debugPrint('KokoroTtsService: warm-up skipped ($e)');
    }
  }

  /// Release ONNX resources. Call when the service is no longer needed.
  Future<void> dispose() async {
    await _session?.close();
    _session = null;
    _runtime = null;
    _voiceEmbedding = null;
    _initialized = false;
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  void _ensureStoragePath() {
    // Fire-and-forget initialization of storage path.
    if (_modelManager.isModelReady) return;
    _modelManager.initialize();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized && _session != null) return;

    await _modelManager.initialize();

    if (!_modelManager.isModelReady) {
      // Trigger background download — don't await it.
      _modelManager.ensureModel().catchError((e) {
        debugPrint('KokoroTtsService: background download failed: $e');
      });
      throw const KokoroModelNotReadyException();
    }

    // Load ONNX session.
    _runtime ??= OnnxRuntime();
    if (_session == null) {
      final modelPath = _modelManager.modelPath!;
      debugPrint('KokoroTtsService: loading ONNX session from $modelPath');
      _session = await _runtime!.createSession(modelPath);
      debugPrint('KokoroTtsService: session loaded.');
    }

    // Load voice embedding.
    if (_voiceEmbedding == null) {
      final voicePath = _modelManager.voicePath!;
      final voiceFile = File(voicePath);
      final bytes = await voiceFile.readAsBytes();
      // The .bin file contains raw float32 values for the voice style matrix.
      // Shape is [N, 1, 256] where N = max phoneme length. We select one row
      // at inference time based on token count.
      _voiceEmbedding = bytes.buffer.asFloat32List();
      debugPrint(
        'KokoroTtsService: loaded voice embedding '
        '(${_voiceEmbedding!.length} floats)',
      );
    }

    _initialized = true;
  }

  // ── Inference ──────────────────────────────────────────────────────────────

  Future<Uint8List> _runInference(List<int> tokenIds) async {
    final session = _session!;
    final voiceData = _voiceEmbedding!;

    // Prepare input_ids tensor: shape [1, N].
    final tokenCount = tokenIds.length;
    final inputIds = Int64List.fromList(tokenIds);

    // Select voice style: row = min(tokenCount, maxRows - 1) from the
    // [N, 1, 256] embedding. Each row is 256 floats.
    const styleSize = 256;
    final maxRows = voiceData.length ~/ styleSize;
    final rowIndex = tokenCount < maxRows ? tokenCount : maxRows - 1;
    final styleVector = Float32List.sublistView(
      voiceData,
      rowIndex * styleSize,
      rowIndex * styleSize + styleSize,
    );

    // Speed scalar.
    final speed = Float32List.fromList([1.0]);

    OrtValue? inputIdsTensor;
    OrtValue? styleTensor;
    OrtValue? speedTensor;
    Map<String, OrtValue>? outputs;

    try {
      // Create OrtValue tensors (async factory).
      inputIdsTensor = await OrtValue.fromList(inputIds, [1, tokenCount]);
      styleTensor = await OrtValue.fromList(styleVector, [1, styleSize]);
      speedTensor = await OrtValue.fromList(speed, [1]);

      // Run the model.
      outputs = await session.run({
        'input_ids': inputIdsTensor,
        'style': styleTensor,
        'speed': speedTensor,
      });

      // Extract float32 audio samples from the first output.
      final audioOutput = outputs.values.first;
      final audioData = await audioOutput.asFlattenedList();

      // Convert to Float32List.
      final floatSamples = Float32List.fromList(
        audioData.map((e) => (e as num).toDouble()).toList(),
      );

      // Convert float32 [-1, 1] to int16 PCM bytes.
      return _float32ToInt16Pcm(floatSamples);
    } catch (e, st) {
      debugPrint('KokoroTtsService: inference error: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    } finally {
      // Dispose all OrtValue tensors.
      await inputIdsTensor?.dispose();
      await styleTensor?.dispose();
      await speedTensor?.dispose();
      if (outputs != null) {
        for (final v in outputs.values) {
          await v.dispose();
        }
      }
    }
  }

  // ── Audio conversion ───────────────────────────────────────────────────────

  /// Convert float32 samples in [-1.0, 1.0] to 16-bit signed PCM bytes
  /// (little-endian).
  Uint8List _float32ToInt16Pcm(Float32List samples) {
    final pcm = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final int16 = (clamped * 32767).round().clamp(-32768, 32767);
      pcm.setInt16(i * 2, int16, Endian.little);
    }
    return pcm.buffer.asUint8List();
  }

  /// Wrap raw PCM data with a RIFF/WAVE header (24 kHz, mono, 16-bit).
  Uint8List _wrapPcmAsWav(Uint8List pcmData) {
    const byteRate = _sampleRate * _channels * _bitsPerSample ~/ 8;
    const blockAlign = _channels * _bitsPerSample ~/ 8;
    final dataLength = pcmData.length;
    final header = BytesBuilder(copy: false);

    void writeAscii(String value) {
      header.add(ascii.encode(value));
    }

    void writeUint16(int value) {
      final data = ByteData(2)..setUint16(0, value, Endian.little);
      header.add(data.buffer.asUint8List());
    }

    void writeUint32(int value) {
      final data = ByteData(4)..setUint32(0, value, Endian.little);
      header.add(data.buffer.asUint8List());
    }

    writeAscii('RIFF');
    writeUint32(36 + dataLength);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(_channels);
    writeUint32(_sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(_bitsPerSample);
    writeAscii('data');
    writeUint32(dataLength);
    header.add(pcmData);

    return header.toBytes();
  }
}
