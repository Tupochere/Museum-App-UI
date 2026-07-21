import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Details of a release published on GitHub that is newer than the
/// currently installed build.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.apkUrl,
    required this.releasePageUrl,
  });

  /// Version string of the remote release, e.g. `1.2.0`.
  final String version;

  /// Body of the GitHub release (markdown), used as a changelog.
  final String releaseNotes;

  /// Direct download URL of the `.apk` asset, or `null` if the release
  /// has no APK attached (fall back to [releasePageUrl] in that case).
  final String? apkUrl;

  /// Human-facing release page on GitHub.
  final String releasePageUrl;

  /// Best URL to send the user to for the download.
  String get downloadUrl => apkUrl ?? releasePageUrl;
}

/// Checks GitHub Releases for a newer version of the app.
///
/// This is intentionally read-only and unauthenticated: it hits the public
/// `releases/latest` endpoint, so it works for public repositories without a
/// token. The service owns all version-comparison logic; widgets only consume
/// the [AppUpdateInfo] it returns.
class UpdateService {
  UpdateService({
    http.Client? client,
    this.repoOwner = 'Tupochere',
    this.repoName = 'Museum-App-UI',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String repoOwner;
  final String repoName;

  Uri get _latestReleaseUri => Uri.https(
        'api.github.com',
        '/repos/$repoOwner/$repoName/releases/latest',
      );

  /// Returns update details when the latest GitHub release is newer than the
  /// installed build, or `null` when the app is already up to date, when there
  /// is no published release, or when the check fails (offline, rate-limited).
  ///
  /// Never throws: an update check must not break app startup.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _client.get(
        _latestReleaseUri,
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      final remoteVersion = _normalizeVersion(tag);
      if (remoteVersion.isEmpty) return null;

      if (!_isNewer(remoteVersion, currentVersion)) return null;

      final assets = (data['assets'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final apkAsset = assets.firstWhere(
        (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
        orElse: () => const <String, dynamic>{},
      );

      return AppUpdateInfo(
        version: remoteVersion,
        releaseNotes: (data['body'] as String?)?.trim() ?? '',
        apkUrl: apkAsset['browser_download_url'] as String?,
        releasePageUrl: (data['html_url'] as String?) ??
            'https://github.com/$repoOwner/$repoName/releases/latest',
      );
    } catch (_) {
      // Offline, rate-limited, malformed payload — treat as "no update".
      return null;
    }
  }

  /// Strips a leading `v` and any build/pre-release suffix so `v1.2.0` and
  /// `1.2.0+5` both compare as `1.2.0`.
  String _normalizeVersion(String raw) {
    var v = raw.trim();
    if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
    final plus = v.indexOf('+');
    if (plus != -1) v = v.substring(0, plus);
    final dash = v.indexOf('-');
    if (dash != -1) v = v.substring(0, dash);
    return v.trim();
  }

  /// True when [remote] is a strictly higher semantic version than [current].
  bool _isNewer(String remote, String current) {
    final r = _parseParts(remote);
    final c = _parseParts(_normalizeVersion(current));
    for (var i = 0; i < 3; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }

  List<int> _parseParts(String version) {
    final parts = version.split('.');
    return List<int>.generate(3, (i) {
      if (i >= parts.length) return 0;
      return int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    });
  }
}
