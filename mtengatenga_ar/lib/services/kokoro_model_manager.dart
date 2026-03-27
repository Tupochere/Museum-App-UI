import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

/// Progress callback for Kokoro model downloads.
typedef KokoroDownloadProgress = void Function(
  int receivedBytes,
  int? totalBytes,
);

/// Exception thrown by [KokoroModelManager].
class KokoroModelException implements Exception {
  const KokoroModelException(this.message);
  final String message;

  @override
  String toString() => 'KokoroModelException: $message';
}

/// Thrown when synthesis is attempted but the model is still downloading.
class KokoroModelNotReadyException implements Exception {
  const KokoroModelNotReadyException();

  @override
  String toString() => 'Kokoro model is not yet downloaded.';
}

/// Manages downloading and caching the Kokoro ONNX model and voice files.
///
/// Files are stored in persistent app-support storage (survives cache clears)
/// under a `kokoro_tts/` subdirectory.
class KokoroModelManager {
  static const String _storageFolderName = 'kokoro_tts';
  static const String _modelFileName = 'model_q8f16.onnx';
  static const String _defaultVoice = 'af_heart';

  static const String _baseUrl =
      'https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main';
  static const String _modelUrl = '$_baseUrl/onnx/$_modelFileName';

  /// Expected model file size in bytes (~86 MB). Used for integrity checks.
  static const int _expectedModelSizeMin = 80 * 1024 * 1024;

  String? _cachedStoragePath;
  bool _downloading = false;

  /// A notifier that emits download progress as a 0.0–1.0 ratio, or null when
  /// no download is active.
  final ValueNotifier<double?> downloadProgress = ValueNotifier<double?>(null);

  // ── Public API ───────────────────────────────────────────────────────────

  /// Whether both the ONNX model and voice file are present on disk.
  bool get isModelReady {
    final path = _cachedStoragePath;
    if (path == null) return false;
    return File('$path/$_modelFileName').existsSync() &&
        File('$path/${_voiceName}.bin').existsSync();
  }

  /// Path to the ONNX model file, or null if not downloaded.
  String? get modelPath {
    final path = _cachedStoragePath;
    if (path == null) return null;
    final file = File('$path/$_modelFileName');
    return file.existsSync() ? file.path : null;
  }

  /// Path to the voice embedding file, or null if not downloaded.
  String? get voicePath {
    final path = _cachedStoragePath;
    if (path == null) return null;
    final file = File('$path/${_voiceName}.bin');
    return file.existsSync() ? file.path : null;
  }

  /// The configured voice name (from `KOKORO_VOICE` env var or default).
  String get _voiceName {
    final configured = dotenv.env['KOKORO_VOICE']?.trim();
    return (configured != null && configured.isNotEmpty)
        ? configured
        : _defaultVoice;
  }

  /// Initialize the storage path. Call once at service creation.
  Future<void> initialize() async {
    final appDir = await getApplicationSupportDirectory();
    final storageDir = Directory('${appDir.path}/$_storageFolderName');
    if (!storageDir.existsSync()) {
      await storageDir.create(recursive: true);
    }
    _cachedStoragePath = storageDir.path;
  }

  /// Ensure both model and voice files are downloaded.
  ///
  /// Returns immediately if files are already present. Otherwise downloads
  /// them from HuggingFace. Throws [KokoroModelException] on failure.
  Future<void> ensureModel({KokoroDownloadProgress? onProgress}) async {
    if (_cachedStoragePath == null) await initialize();

    if (isModelReady) return;

    if (_downloading) {
      throw const KokoroModelNotReadyException();
    }

    _downloading = true;
    downloadProgress.value = 0.0;

    try {
      final storagePath = _cachedStoragePath!;

      // Download model file.
      final modelFile = File('$storagePath/$_modelFileName');
      if (!modelFile.existsSync() || modelFile.lengthSync() < _expectedModelSizeMin) {
        debugPrint('KokoroModelManager: downloading ONNX model...');
        await _downloadFile(
          url: _modelUrl,
          destination: modelFile,
          onProgress: (received, total) {
            final ratio = (total != null && total > 0) ? received / total : null;
            downloadProgress.value = ratio;
            onProgress?.call(received, total);
          },
        );
        // Integrity check.
        if (modelFile.lengthSync() < _expectedModelSizeMin) {
          await modelFile.delete();
          throw const KokoroModelException(
            'Downloaded model file is too small — likely corrupted.',
          );
        }
        debugPrint('KokoroModelManager: model download complete.');
      }

      // Download voice file.
      final voiceFile = File('$storagePath/${_voiceName}.bin');
      if (!voiceFile.existsSync() || voiceFile.lengthSync() == 0) {
        final voiceUrl = '$_baseUrl/voices/${_voiceName}.bin';
        debugPrint('KokoroModelManager: downloading voice "$_voiceName"...');
        await _downloadFile(
          url: voiceUrl,
          destination: voiceFile,
          onProgress: (received, total) {
            // Voice file is small; keep progress at ~0.99 during this phase.
            downloadProgress.value = 0.99;
            onProgress?.call(received, total);
          },
        );
        debugPrint('KokoroModelManager: voice download complete.');
      }

      downloadProgress.value = 1.0;
    } finally {
      _downloading = false;
      // Clear progress after a short delay so listeners can see 1.0.
      Future.delayed(const Duration(seconds: 2), () {
        downloadProgress.value = null;
      });
    }
  }

  /// Delete all downloaded Kokoro files.
  Future<void> deleteModel() async {
    if (_cachedStoragePath == null) return;
    final dir = Directory(_cachedStoragePath!);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  // ── Download helper ────────────────────────────────────────────────────────

  Future<void> _downloadFile({
    required String url,
    required File destination,
    KokoroDownloadProgress? onProgress,
  }) async {
    final uri = Uri.parse(url);
    final tempFile = File('${destination.path}.part');
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 60);

    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw KokoroModelException(
          'Download failed with status ${response.statusCode} for $url',
        );
      }

      final totalBytes =
          response.contentLength > 0 ? response.contentLength : null;
      sink = tempFile.openWrite();
      var receivedBytes = 0;

      await for (final List<int> chunk in response) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        onProgress?.call(receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Atomic rename.
      await destination.parent.create(recursive: true);
      await tempFile.rename(destination.path);
    } on SocketException {
      throw const KokoroModelException(
        'Network error while downloading Kokoro model.',
      );
    } on TimeoutException {
      throw const KokoroModelException(
        'Timed out while downloading Kokoro model.',
      );
    } catch (error) {
      if (error is KokoroModelException) rethrow;
      throw KokoroModelException('Failed to download Kokoro file: $error');
    } finally {
      client.close(force: true);
      if (sink != null) {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {}
      }
      if (tempFile.existsSync()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }
}
