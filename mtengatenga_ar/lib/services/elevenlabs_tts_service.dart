import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ElevenLabsSpeechClip {
  final Uint8List wavBytes;
  final Duration duration;

  const ElevenLabsSpeechClip({
    required this.wavBytes,
    required this.duration,
  });
}

class ElevenLabsTtsService {
  // Rachel — warm, calm female narrator voice.
  static const String _defaultVoiceId = '21m00Tcm4TlvDq8ikWAM';
  static const String _defaultModel = 'eleven_multilingual_v2';
  static const int _maxRetries = 2;
  static const int _sampleRate = 24000;

  Future<ElevenLabsSpeechClip> synthesizeSpeech(String text) async {
    final apiKey = dotenv.env['ELEVENLABS_API_KEY']?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw StateError('Missing ELEVENLABS_API_KEY for ElevenLabs TTS.');
    }

    final voiceId = _resolveVoiceId();
    final model = _resolveModel();
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final client = HttpClient();
      try {
        final url = Uri.parse(
          'https://api.elevenlabs.io/v1/text-to-speech/$voiceId'
          '?output_format=pcm_24000',
        );
        final request = await client.postUrl(url);
        request.headers.contentType = ContentType.json;
        request.headers.set('xi-api-key', apiKey);
        request.add(
          utf8.encode(
            jsonEncode({
              'text': text,
              'model_id': model,
              'voice_settings': {
                'stability': 0.50,
                'similarity_boost': 0.75,
                'style': 0.0,
                'use_speaker_boost': true,
              },
            }),
          ),
        );

        final response = await request.close();

        if (response.statusCode == 429 ||
            (response.statusCode >= 500 && response.statusCode < 600)) {
          final body = await utf8.decoder.bind(response).join();
          lastError = HttpException(
            'ElevenLabs TTS (${response.statusCode}): '
            '${_extractErrorMessage(body)}',
          );
          lastStackTrace = StackTrace.current;
          if (attempt < _maxRetries) {
            final delay = _retryDelay(attempt);
            debugPrint(
              'ElevenLabsTtsService: rate limited, retrying in '
              '${delay.inSeconds}s (attempt ${attempt + 1}/$_maxRetries)',
            );
            await Future.delayed(delay);
            continue;
          }
          Error.throwWithStackTrace(lastError, lastStackTrace);
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final body = await utf8.decoder.bind(response).join();
          throw HttpException(
            'ElevenLabs TTS failed (${response.statusCode}): '
            '${_extractErrorMessage(body)}',
          );
        }

        // Response is raw PCM bytes (signed 16-bit LE mono @ 24 kHz).
        final pcmBytes = await _collectBytes(response);
        final wavBytes = _wrapPcmAsWav(pcmBytes);
        final durationMicros = pcmBytes.isEmpty
            ? 0
            : (pcmBytes.length * Duration.microsecondsPerSecond) ~/
                (_sampleRate * 2); // 16-bit mono = 2 bytes/sample
        return ElevenLabsSpeechClip(
          wavBytes: wavBytes,
          duration: Duration(microseconds: durationMicros),
        );
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        if (attempt < _maxRetries && _isRetryable(e)) {
          final delay = _retryDelay(attempt);
          debugPrint(
            'ElevenLabsTtsService: retryable error, retrying in '
            '${delay.inSeconds}s (attempt ${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(delay);
          continue;
        }

        debugPrint('ElevenLabsTtsService.synthesizeSpeech ERROR: $e');
        debugPrintStack(stackTrace: st);
        break;
      } finally {
        client.close(force: true);
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    throw StateError(
      'ElevenLabs TTS failed before any attempt completed.',
    );
  }

  // ── Config ───────────────────────────────────────────────────────────────

  String _resolveVoiceId() {
    final configured = dotenv.env['ELEVENLABS_VOICE_ID']?.trim();
    if (configured == null || configured.isEmpty) return _defaultVoiceId;
    return configured;
  }

  String _resolveModel() {
    final configured = dotenv.env['ELEVENLABS_MODEL']?.trim();
    if (configured == null || configured.isEmpty) return _defaultModel;
    return configured;
  }

  // ── Retry helpers ────────────────────────────────────────────────────────

  static bool _isRetryable(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('429') ||
        msg.contains('rate limit') ||
        msg.contains('quota') ||
        msg.contains('502') ||
        msg.contains('503');
  }

  static Duration _retryDelay(int attempt) {
    final baseMs = 2000 * pow(2, attempt).toInt();
    final jitterMs = Random().nextInt(800);
    return Duration(milliseconds: baseMs + jitterMs);
  }

  // ── Response helpers ─────────────────────────────────────────────────────

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is Map<String, dynamic> && detail['message'] is String) {
          return detail['message'] as String;
        }
        if (detail is String) return detail;
      }
    } catch (_) {
      // Fall through.
    }
    return body.length > 200 ? body.substring(0, 200) : body;
  }

  Future<Uint8List> _collectBytes(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  // ── WAV wrapper ──────────────────────────────────────────────────────────

  Uint8List _wrapPcmAsWav(Uint8List pcmData) {
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = _sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcmData.length;
    final header = BytesBuilder(copy: false);

    void writeAscii(String value) {
      header.add(ascii.encode(value));
    }

    void writeUint16(int value) {
      final d = ByteData(2)..setUint16(0, value, Endian.little);
      header.add(d.buffer.asUint8List());
    }

    void writeUint32(int value) {
      final d = ByteData(4)..setUint32(0, value, Endian.little);
      header.add(d.buffer.asUint8List());
    }

    writeAscii('RIFF');
    writeUint32(36 + dataLength);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeUint32(16);
    writeUint16(1); // PCM
    writeUint16(channels);
    writeUint32(_sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeAscii('data');
    writeUint32(dataLength);
    header.add(pcmData);

    return header.toBytes();
  }
}
