import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'update_service.dart';

/// Byte counts for an in-flight update download.
class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;

  /// `null` when the server sends no `Content-Length`.
  final int? totalBytes;

  /// Completion in `0.0..1.0`, or `null` when the total size is unknown.
  double? get ratio {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}

typedef UpdateProgressCallback = void Function(UpdateDownloadProgress progress);

/// A user-presentable failure during download or install.
class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads a release APK and hands it to Android's package installer, so the
/// user never has to leave the app to find the file themselves.
///
/// Only Android is supported. The platform *always* shows its own install
/// confirmation — a non-privileged app cannot install silently — so the best
/// achievable flow is "tap Update, confirm once". Callers should keep a browser
/// fallback for every failure path; see [UpdatePrompt].
class AppUpdateInstaller {
  AppUpdateInstaller({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'mtengatenga_ar/app_installer';
  static const String _cacheFolderName = 'app_updates';

  final MethodChannel _channel;

  HttpClient? _client;
  bool _cancelled = false;

  /// Whether this platform can install an update in place at all.
  bool get isSupported => Platform.isAndroid;

  /// True when the user has granted "Install unknown apps" for this app.
  /// Failures are reported as `false` so the caller can route to settings.
  Future<bool> canInstall() async {
    if (!isSupported) return false;
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstall');
      return allowed ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens this app's "Install unknown apps" settings screen.
  Future<bool> openInstallSettings() async {
    if (!isSupported) return false;
    try {
      final opened = await _channel.invokeMethod<bool>('openInstallSettings');
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Downloads the APK for [info], reporting progress via [onProgress], and
  /// returns the local file path.
  ///
  /// Throws [AppUpdateException] on any failure, including cancellation.
  Future<String> download(
    AppUpdateInfo info, {
    UpdateProgressCallback? onProgress,
  }) async {
    if (!isSupported) {
      throw const AppUpdateException(
        'In-app updates are only available on Android.',
      );
    }

    final apkUrl = info.apkUrl;
    if (apkUrl == null || apkUrl.isEmpty) {
      throw const AppUpdateException(
        'This release has no APK attached.',
      );
    }

    final uri = Uri.tryParse(apkUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const AppUpdateException('The download URL is invalid.');
    }

    _cancelled = false;
    final cacheDirectory = await _ensureCacheDirectory();
    await _clearCache(cacheDirectory);

    final destination = File(
      '${cacheDirectory.path}${Platform.pathSeparator}mtengatenga-ar-${info.version}.apk',
    );
    final tempFile = File('${destination.path}.part');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    _client = client;

    IOSink? sink;
    try {
      // GitHub's browser_download_url redirects to objects.githubusercontent.com;
      // HttpClient follows redirects by default.
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppUpdateException(
          'Download failed with status ${response.statusCode}.',
        );
      }

      final totalBytes =
          response.contentLength > 0 ? response.contentLength : null;
      sink = tempFile.openWrite();
      var receivedBytes = 0;

      await for (final List<int> chunk in response) {
        if (_cancelled) {
          throw const AppUpdateException('Download cancelled.');
        }
        receivedBytes += chunk.length;
        sink.add(chunk);
        onProgress?.call(
          UpdateDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (await tempFile.length() <= 0) {
        throw const AppUpdateException('The downloaded file was empty.');
      }

      await tempFile.rename(destination.path);
      return destination.path;
    } on SocketException {
      throw const AppUpdateException(
        'Network error while downloading the update.',
      );
    } on TimeoutException {
      throw const AppUpdateException(
        'Timed out while downloading the update.',
      );
    } on HttpException {
      throw const AppUpdateException(
        'The download was interrupted. Please try again.',
      );
    } catch (error) {
      if (error is AppUpdateException) rethrow;
      throw AppUpdateException('Could not download the update: $error');
    } finally {
      _client = null;
      client.close(force: true);
      if (sink != null) {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {
          // Best-effort cleanup.
        }
      }
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }

  /// Aborts an in-flight [download]. The partial file is cleaned up by the
  /// download's own `finally` block.
  void cancelDownload() {
    _cancelled = true;
    _client?.close(force: true);
  }

  /// Launches the system package installer for the APK at [path].
  ///
  /// Returning `true` means the installer was *opened*, not that the install
  /// succeeded — the user still has to confirm, and the app is typically
  /// replaced before any result comes back.
  Future<bool> install(String path) async {
    if (!isSupported) return false;
    try {
      final started = await _channel.invokeMethod<bool>(
        'installApk',
        <String, dynamic>{'path': path},
      );
      return started ?? false;
    } on PlatformException catch (error) {
      throw AppUpdateException(
        error.message ?? 'Could not open the installer.',
      );
    } on MissingPluginException {
      throw const AppUpdateException(
        'The installer is unavailable on this build.',
      );
    }
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

  /// Drops previously downloaded APKs so old releases don't accumulate; each
  /// one is tens of megabytes.
  Future<void> _clearCache(Directory cacheDirectory) async {
    try {
      await for (final entity in cacheDirectory.list()) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {
            // Keep cleanup best-effort.
          }
        }
      }
    } catch (_) {
      // Directory may have vanished; the download will recreate it.
    }
  }
}
