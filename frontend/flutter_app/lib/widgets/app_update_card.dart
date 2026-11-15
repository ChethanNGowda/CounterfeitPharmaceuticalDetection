import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pharma_assist/services/app_update_service.dart';

class AppUpdateCard extends StatefulWidget {
  const AppUpdateCard({super.key});

  @override
  State<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends State<AppUpdateCard> {
  final AppUpdateService _service = AppUpdateService();
  AppUpdateCheck? _check;
  String _currentVersion = 'Loading…';
  String? _downloadedPath;
  String? _message;
  bool _checking = false;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final version = await _service.getInstalledVersion();
      if (mounted) setState(() => _currentVersion = version);
    } catch (_) {
      // Keep the loading placeholder if package metadata is unavailable.
    }
    try {
      final result = await _service.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _currentVersion = result.currentVersion;
        _check = result;
        _message = result.updateAvailable
            ? 'Version ${result.release!.version} is available.'
            : 'You are using the latest published version.';
      });
    } catch (_) {
      // Manual check shows any network or release-channel errors.
    }
  }

  Future<void> _checkUpdates() async {
    setState(() {
      _checking = true;
      _message = null;
      _downloadedPath = null;
    });
    try {
      final result = await _service.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _check = result;
        _currentVersion = result.currentVersion;
        _message = result.updateAvailable
            ? 'A new version is ready to download.'
            : 'You are using the latest published version.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadOrInstall() async {
    final release = _check?.release;
    if (release == null || !_check!.updateAvailable) return;

    try {
      if (_downloadedPath == null) {
        setState(() {
          _downloading = true;
          _progress = 0;
          _message = 'Downloading the release APK…';
        });
        _downloadedPath = await _service.downloadApk(
          release,
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
        );
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _message = 'Download complete. Ready to install.';
        });
      }

      final allowed = await _service.canInstallUnknownApps();
      if (!allowed) {
        await _service.openInstallPermissionSettings();
        if (!mounted) return;
        setState(() {
          _message = 'Allow PharmaAssist to install updates in Android settings, return here, then tap Install update again.';
        });
        return;
      }

      await _service.installApk(_downloadedPath!);
      if (mounted) {
        setState(() => _message = 'Android opened the package installer. Confirm the update there.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _message = error.toString().replaceFirst('PlatformException(', '');
        });
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final release = _check?.release;
    final updateAvailable = _check?.updateAvailable ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_alt, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'App updates',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('v$_currentVersion', style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Check the official GitHub release channel for new PharmaAssist versions.',
            style: theme.textTheme.bodySmall,
          ),
          if (release != null && updateAvailable) ...[
            const SizedBox(height: 14),
            Text(
              release.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('Version ${release.version} is available'),
            if (release.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(release.notes, style: theme.textTheme.bodySmall),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _service.openReleasePage(release.releaseUrl),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View release notes'),
                ),
              ),
            ],
          ],
          if (_downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 4),
            Text(
              _progress > 0 ? '${(_progress * 100).round()}%' : 'Preparing download…',
              style: theme.textTheme.labelSmall,
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: updateAvailable
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _checking || _downloading ? null : _checkUpdates,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_checking ? 'Checking…' : 'Check for updates'),
              ),
              if (updateAvailable)
                FilledButton.icon(
                  onPressed: _downloading ? null : _downloadOrInstall,
                  icon: Icon(
                    _downloadedPath == null ? Icons.download : Icons.install_mobile,
                  ),
                  label: Text(
                    _downloadedPath == null ? 'Download update' : 'Install update',
                  ),
                ),
            ],
          ),
          if (!Platform.isAndroid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Direct APK installation is available on Android only.',
                style: theme.textTheme.labelSmall,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Updates are downloaded from GitHub over HTTPS. Android always asks you to confirm installation.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
