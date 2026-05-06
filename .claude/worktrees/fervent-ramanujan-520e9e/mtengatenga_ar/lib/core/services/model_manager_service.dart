import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

typedef ModelProgressCallback = void Function(ModelLoadProgress progress);

class ModelLoadProgress {
  const ModelLoadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get ratio {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return receivedBytes / total;
  }
}

class ModelLoadResult {
  const ModelLoadResult({
    required this.localFileUri,
    required this.localFilePath,
    required this.usedCache,
    required this.source,
  });

  final String localFileUri;
  final String localFilePath;
  final bool usedCache;
  final String source;
}

class ModelManagerException implements Exception {
  const ModelManagerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ModelManagerService {
  static const int _maxCacheBytes = 100 * 1024 * 1024;
  static const String _cacheFolderName = 'ar_models';
  static const List<String> _supportedExtensions = <String>['.glb', '.gltf'];

  Future<ModelLoadResult> resolveModel({
    required String artifactId,
    required String source,
    ModelProgressCallback? onProgress,
  }) async {
    final normalizedSource = source.trim();
    if (normalizedSource.isEmpty) {
      throw const ModelManagerException('Model source is empty.');
    }

    final extension = _extractSupportedExtension(normalizedSource);
    if (extension == null) {
      throw const ModelManagerException(
        'Unsupported model format. Use .glb or .gltf.',
      );
    }

    final cacheDirectory = await _ensureCacheDirectory();
    final cacheFile = File(
      '${cacheDirectory.path}${Platform.pathSeparator}${_cacheFileName(artifactId, normalizedSource, extension)}',
    );

    if (await _isUsableCacheFile(cacheFile)) {
      await _touch(cacheFile);
      return ModelLoadResult(
        localFileUri: cacheFile.uri.toString(),
        localFilePath: cacheFile.path,
        usedCache: true,
        source: normalizedSource,
      );
    }

    if (_isAssetPath(normalizedSource)) {
      await _copyAssetToFile(
        assetPath: normalizedSource,
        destination: cacheFile,
        onProgress: onProgress,
      );
    } else {
      await _downloadToFile(
        sourceUrl: normalizedSource,
        destination: cacheFile,
        onProgress: onProgress,
      );
    }

    await _enforceCacheLimit(cacheDirectory);

    return ModelLoadResult(
      localFileUri: cacheFile.uri.toString(),
      localFilePath: cacheFile.path,
      usedCache: false,
      source: normalizedSource,
    );
  }

  Future<void> clearAllCachedModels() async {
    final cacheDirectory = await _ensureCacheDirectory();
    if (!await cacheDirectory.exists()) return;

    final entities = cacheDirectory.listSync();
    for (final entity in entities) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {
          // Keep cleanup best-effort.
        }
      }
    }
  }

  bool isSupportedSource(String source) {
    return _extractSupportedExtension(source.trim()) != null;
  }

  bool _isAssetPath(String source) {
    return source.startsWith('assets/');
  }

  String? _extractSupportedExtension(String source) {
    final lower = source.toLowerCase();
    for (final extension in _supportedExtensions) {
      if (lower.contains('?')) {
        final pathWithoutQuery = lower.split('?').first;
        if (pathWithoutQuery.endsWith(extension)) return extension;
      }
      if (lower.endsWith(extension)) return extension;
    }
    return null;
  }

  Future<Directory> _ensureCacheDirectory() async {
    final rootDirectory = await getTemporaryDirectory();
    final cacheDirectory = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}$_cacheFolderName',
    );
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }
    return cacheDirectory;
  }

  Future<bool> _isUsableCacheFile(File file) async {
    if (!await file.exists()) return false;
    final stat = await file.stat();
    return stat.size > 0;
  }

  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } catch (_) {
      // Ignore timestamp failures; cache still valid.
    }
  }

  Future<void> _copyAssetToFile({
    required String assetPath,
    required File destination,
    ModelProgressCallback? onProgress,
  }) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(bytes, flush: true);
      onProgress?.call(
        ModelLoadProgress(
          receivedBytes: bytes.length,
          totalBytes: bytes.length,
        ),
      );
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('unable to load asset')) {
        throw ModelManagerException('Asset model not found: $assetPath');
      }
      throw ModelManagerException('Failed to copy asset model: $error');
    }
  }

  Future<void> _downloadToFile({
    required String sourceUrl,
    required File destination,
    ModelProgressCallback? onProgress,
  }) async {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const ModelManagerException(
        'Model URL is invalid. Use an http/https URL or assets path.',
      );
    }

    final tempFile = File('${destination.path}.part');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);

    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ModelManagerException(
          'Model download failed with status ${response.statusCode}.',
        );
      }

      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : null;
      sink = tempFile.openWrite();
      var receivedBytes = 0;

      await for (final List<int> chunk in response) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        onProgress?.call(
          ModelLoadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      await destination.parent.create(recursive: true);
      await tempFile.rename(destination.path);
    } on SocketException {
      throw const ModelManagerException(
        'Network error while downloading the 3D model.',
      );
    } on TimeoutException {
      throw const ModelManagerException(
        'Timed out while downloading the 3D model.',
      );
    } catch (error) {
      if (error is ModelManagerException) rethrow;
      throw ModelManagerException('Failed to download model: $error');
    } finally {
      client.close(force: true);
      if (sink != null) {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {
          // Ignore best-effort cleanup errors.
        }
      }
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // Ignore temp cleanup failures.
        }
      }
    }
  }

  Future<void> _enforceCacheLimit(Directory cacheDirectory) async {
    final files = await cacheDirectory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();

    if (files.isEmpty) return;

    files.sort((a, b) {
      final aTime = a.statSync().modified;
      final bTime = b.statSync().modified;
      return aTime.compareTo(bTime);
    });

    var totalBytes = 0;
    for (final file in files) {
      try {
        totalBytes += file.statSync().size;
      } catch (_) {
        // Ignore non-readable files.
      }
    }

    for (final file in files) {
      if (totalBytes <= _maxCacheBytes) break;
      try {
        final size = file.statSync().size;
        await file.delete();
        totalBytes -= size;
      } catch (_) {
        // Keep cleanup best-effort.
      }
    }
  }

  String _cacheFileName(String artifactId, String source, String extension) {
    final key = '${artifactId.trim().toLowerCase()}|${source.trim()}';
    final hash = _fnv1a64Hex(key);
    return '${artifactId.trim().toLowerCase()}_$hash$extension';
  }

  String _fnv1a64Hex(String input) {
    var hash = 0xcbf29ce484222325;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
