import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppReleaseInfo {
  final String version;
  final String tagName;
  final String title;
  final String notes;
  final String releaseUrl;
  final String apkUrl;
  final String sha256Digest;

  const AppReleaseInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.notes,
    required this.releaseUrl,
    required this.apkUrl,
    required this.sha256Digest,
  });
}

class AppUpdateCheck {
  final String currentVersion;
  final AppReleaseInfo? release;

  const AppUpdateCheck({required this.currentVersion, required this.release});

  bool get updateAvailable =>
      release != null &&
      AppUpdateService.isNewerVersion(release!.version, currentVersion);
}

/// GitHub Releases update channel using a static latest-release manifest.
///
/// A static manifest avoids unauthenticated GitHub API rate limits. The APK
/// is downloaded over HTTPS, SHA-256 verified, then handed to Android's
/// package installer. Android always asks the user to confirm installation.
class AppUpdateService {
  static const String owner = 'ChethanNGowda';
  static const String repository = 'CounterfeitPharmaceuticalDetection';
  static const String apkAssetName = 'pharmaassist-android-universal.apk';
  static const MethodChannel _channel = MethodChannel(
    'com.chethan.pharmaassist.pharma_assist/updates',
  );

  Future<String> getInstalledVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  static Uri get _latestManifestUri => Uri.parse(
    'https://github.com/$owner/$repository/releases/latest/download/pharmaassist-update.json',
  );

  Future<AppUpdateCheck> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final response = await http
        .get(
          _latestManifestUri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'PharmaAssist-Android-Updater',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 404) {
      throw StateError('No public Android release has been published yet.');
    }
    if (response.statusCode != 200) {
      throw HttpException(
        'GitHub update manifest failed (HTTP ${response.statusCode}).',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('GitHub returned an invalid update manifest.');
    }
    final version = payload['version']?.toString() ?? '';
    final tag = payload['tag_name']?.toString() ?? '';
    final apkUrl = payload['apk_url']?.toString() ?? '';
    final releaseUrl = payload['release_url']?.toString() ?? '';
    final digest = payload['sha256']?.toString().toLowerCase() ?? '';

    final apkUri = Uri.tryParse(apkUrl);
    final releaseUri = Uri.tryParse(releaseUrl);
    if (version.isEmpty ||
        tag.isEmpty ||
        apkUri == null ||
        apkUri.scheme != 'https' ||
        apkUri.host != 'github.com' ||
        releaseUri == null ||
        releaseUri.scheme != 'https' ||
        releaseUri.host != 'github.com') {
      throw const FormatException('The update manifest contains invalid release links or version information.');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('The update manifest does not contain a valid SHA-256 digest.');
    }

    return AppUpdateCheck(
      currentVersion: packageInfo.version,
      release: AppReleaseInfo(
        version: version,
        tagName: tag,
        title: payload['title']?.toString() ?? 'PharmaAssist $tag',
        notes: payload['notes']?.toString() ?? 'Open the release page for changes.',
        releaseUrl: releaseUrl,
        apkUrl: apkUrl,
        sha256Digest: digest,
      ),
    );
  }

  static bool isNewerVersion(String latest, String current) {
    List<int> parts(String value) {
      final clean = value.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
      return clean
          .split('-')
          .first
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
    }

    final a = parts(latest);
    final b = parts(current);
    final count = a.length > b.length ? a.length : b.length;
    for (var index = 0; index < count; index++) {
      final left = index < a.length ? a[index] : 0;
      final right = index < b.length ? b[index] : 0;
      if (left != right) return left > right;
    }
    return false;
  }

  Future<String> downloadApk(
    AppReleaseInfo release, {
    required void Function(double progress) onProgress,
  }) async {
    final uri = Uri.parse(release.apkUrl);
    if (uri.scheme != 'https' || uri.host != 'github.com') {
      throw const FormatException('Refusing to download an APK from an untrusted host.');
    }

    final request = http.Request('GET', uri)
      ..headers['User-Agent'] = 'PharmaAssist-Android-Updater';
    final client = http.Client();
    final response = await client.send(request).timeout(
      const Duration(seconds: 30),
    );
    if (response.statusCode != 200) {
      client.close();
      throw HttpException('APK download failed (HTTP ${response.statusCode}).');
    }
    const maxBytes = 250 * 1024 * 1024;
    if (response.contentLength != null && response.contentLength! > maxBytes) {
      client.close();
      throw StateError('The release APK exceeds the 250 MB safety limit.');
    }

    final temporary = await getTemporaryDirectory();
    final directory = Directory('${temporary.path}/pharmaassist-updates');
    await directory.create(recursive: true);
    final file = File('${directory.path}/pharmaassist-${release.version}.apk');
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > maxBytes) {
          throw StateError('The release APK exceeds the 250 MB safety limit.');
        }
        sink.add(chunk);
        final total = response.contentLength ?? 0;
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0).toDouble());
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      client.close();
    }

    if (await file.length() < 1024 * 1024) {
      await file.delete();
      throw StateError('The downloaded APK is unexpectedly small.');
    }
    final actual = await sha256.bind(file.openRead()).first;
    if (actual.toString().toLowerCase() != release.sha256Digest) {
      await file.delete();
      throw StateError('APK SHA-256 verification failed. The file was discarded.');
    }
    onProgress(1);
    return file.path;
  }

  Future<bool> canInstallUnknownApps() async =>
      await _channel.invokeMethod<bool>('canInstallUnknownApps') ?? false;

  Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  Future<void> installApk(String path) async {
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }

  Future<void> openReleasePage(String url) async {
    await _channel.invokeMethod<void>('openReleasePage', {'url': url});
  }
}
