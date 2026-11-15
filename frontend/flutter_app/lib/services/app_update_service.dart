import 'dart:convert';
import 'dart:io';

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
  final String? sha256Digest;

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

/// Public GitHub Releases update channel. Downloads are HTTPS-only, optionally
/// SHA-256 verified, and installed only after Android's system confirmation.
class AppUpdateService {
  static const String owner = 'ChethanNGowda';
  static const String repository = 'CounterfeitPharmaceuticalDetection';
  static const String apkAssetName = 'pharmaassist-android-universal.apk';
  static const MethodChannel _channel = MethodChannel(
    'com.chethan.pharmaassist.pharma_assist/updates',
  );

  Future<String> getInstalledVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  static Uri get _latestReleaseUri => Uri.parse(
    'https://api.github.com/repos/$owner/$repository/releases/latest',
  );

  Future<AppUpdateCheck> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final response = await http
        .get(
          _latestReleaseUri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'PharmaAssist-Android-Updater',
            'X-GitHub-Api-Version': '2026-03-10',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 404) {
      throw StateError('No public Android release has been published yet.');
    }
    if (response.statusCode != 200) {
      throw HttpException(
        'GitHub update check failed (HTTP ${response.statusCode}).',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('GitHub returned an invalid release record.');
    }
    final assets = payload['assets'];
    if (assets is! List) {
      throw const FormatException('The GitHub release has no APK assets.');
    }
    final apkAssets = assets.whereType<Map<String, dynamic>>().where((asset) {
      final name = asset['name']?.toString().toLowerCase() ?? '';
      return name == apkAssetName || name.endsWith('.apk');
    }).toList();
    if (apkAssets.isEmpty) {
      throw StateError('The latest GitHub release does not contain an Android APK.');
    }

    final asset = apkAssets.firstWhere(
      (item) => item['name'] == apkAssetName,
      orElse: () => apkAssets.first,
    );
    final tag = payload['tag_name']?.toString() ?? '';
    final version = tag.replaceFirst(RegExp(r'^[vV]'), '');
    final apkUrl = asset['browser_download_url']?.toString() ?? '';
    final uri = Uri.tryParse(apkUrl);
    if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') {
      throw const FormatException('The release APK URL is not a trusted GitHub HTTPS URL.');
    }

    final digest = asset['digest']?.toString();
    return AppUpdateCheck(
      currentVersion: packageInfo.version,
      release: AppReleaseInfo(
        version: version,
        tagName: tag,
        title: payload['name']?.toString() ?? 'PharmaAssist $tag',
        notes: payload['body']?.toString() ?? 'No release notes provided.',
        releaseUrl: payload['html_url']?.toString() ?? '',
        apkUrl: apkUrl,
        sha256Digest: digest != null && digest.startsWith('sha256:')
            ? digest.substring(7).toLowerCase()
            : null,
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
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
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
    if (release.sha256Digest != null) {
      final actual = await sha256.bind(file.openRead()).first;
      if (actual.toString().toLowerCase() != release.sha256Digest) {
        await file.delete();
        throw StateError('APK SHA-256 verification failed. The file was discarded.');
      }
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
}
