import 'package:flutter/material.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/health_response.dart';
import 'package:pharma_assist/screens/about_screen.dart';
import 'package:pharma_assist/screens/model_lab_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService apiService;
  final Function(String mode)? onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.apiService,
    this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  late double _threshold;
  late String _modelName;
  late String _visionMode;
  late bool _enableQwen;
  late String _themeMode;

  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  final List<String> _models = ['efficientnet_b0', 'mobilenet_v3_large', 'baseline_cnn', 'goldformer'];
  final List<String> _visionModes = ['auto', 'always', 'never'];
  final List<String> _themeModes = ['dark', 'light', 'system'];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.storage.getBackendUrl());
    _threshold = widget.storage.getThreshold();
    _modelName = widget.storage.getModelName();
    _visionMode = widget.storage.getVisionMode();
    _enableQwen = widget.storage.getEnableQwen();
    _themeMode = widget.storage.getThemeMode();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final cleanUrl = StorageService.normalizeUrl(_urlController.text);
    await widget.storage.setBackendUrl(cleanUrl);
    await widget.storage.setThreshold(_threshold);
    await widget.storage.setModelName(_modelName);
    await widget.storage.setVisionMode(_visionMode);
    await widget.storage.setEnableQwen(_enableQwen);
    await widget.storage.setThemeMode(_themeMode);

    widget.onThemeChanged?.call(_themeMode);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuration saved successfully'),
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _testConnection() async {
    final String targetUrl = StorageService.normalizeUrl(_urlController.text);
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final HealthResponse health =
          await widget.apiService.checkHealth(customBaseUrl: targetUrl);
      setState(() {
        _testSuccess = true;
        _testResult = 'CONNECTION SUCCESSFUL\n'
            '• API Version: ${health.version}\n'
            '• Compute Device: ${health.device ?? "CPU"}\n'
            '• Production Model: ${health.defaultModel ?? "efficientnet_b0"}\n'
            '• Secondary AI: ${health.secondaryAiModel ?? "qwen3-vl:4b"}\n'
            '• Secondary Endpoint: ${health.secondaryAiEndpoint ?? "http://localhost:11434"}';
      });
      await widget.storage.setBackendUrl(targetUrl);
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'CONNECTION FAILED\n$e\n\n'
            'Troubleshooting Checklist:\n'
            '1. Ensure backend is running: python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000\n'
            '2. Check Wi-Fi pairing: Both computer and phone must share the same local network subnet.\n'
            '3. Emulator note: Use 10.0.2.2 instead of localhost.';
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _applyPreset(String url) => setState(() => _urlController.text = url);

  Future<void> _clearAllHistory() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.elevatedCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Clear All Local Archives?', style: AppTheme.headingSmall()),
        content: Text(
          'Permanently wipe all inspection records and cached result metadata from this device? This will not affect training data or server checkpoints.',
          style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 12.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Clear All Records'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.storage.clearScanHistory();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All inspection records cleared'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int historyCount = widget.storage.getScanHistory().length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.secondaryBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.settings_outlined, color: AppTheme.primaryCyan, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Settings & Diagnostics', style: AppTheme.headingSmall()),
                Text(
                  'Instrument configuration & safety',
                  style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                color: AppTheme.primaryCyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // 1. Appearance Section
            _buildSectionLabel('APPEARANCE & THEME'),
            const SizedBox(height: 8),
            _buildAppearanceSection(),

            const SizedBox(height: 20),

            // 2. Connectivity and Diagnostics
            _buildSectionLabel('BACKEND COMMUNICATION ENDPOINT'),
            const SizedBox(height: 8),
            _buildBackendSection(),

            const SizedBox(height: 20),

            // 3. Scanning Preferences
            _buildSectionLabel('DETECTION MODEL PARAMETERS'),
            const SizedBox(height: 8),
            _buildClassifierSection(),

            const SizedBox(height: 20),

            // 4. Secondary AI Vision-Language
            _buildSectionLabel('SECONDARY VISION-LANGUAGE VERIFIER'),
            const SizedBox(height: 8),
            _buildQwenSection(),

            const SizedBox(height: 20),

            // 5. Local Storage & Privacy
            _buildSectionLabel('LOCAL STORAGE & PRIVACY'),
            const SizedBox(height: 8),
            _buildStorageSection(historyCount),

            const SizedBox(height: 20),

            // 6. About Link & Model Lab (nested under settings)
            _buildSectionLabel('INSTRUMENT SPECIFICATIONS'),
            const SizedBox(height: 8),
            _buildAboutCard(),
            const SizedBox(height: 10),
            _buildModelLabCard(),

            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: const Text(
                  'APPLY & SAVE SETTINGS',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme Architecture', style: AppTheme.headingSmall()),
          const SizedBox(height: 4),
          Text(
            'Select UI appearance. Default is scientific Dark Mode with high-contrast laboratory accents.',
            style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: _themeModes.map((mode) {
              final isSel = _themeMode == mode;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() => _themeMode = mode);
                      widget.onThemeChanged?.call(mode);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.primaryCyan.withValues(alpha: 0.15) : AppTheme.secondaryBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSel ? AppTheme.primaryCyan : AppTheme.border,
                          width: isSel ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            mode == 'dark'
                                ? Icons.dark_mode_outlined
                                : (mode == 'light' ? Icons.light_mode_outlined : Icons.settings_brightness_outlined),
                            size: 18,
                            color: isSel ? AppTheme.primaryCyan : AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mode.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? AppTheme.primaryCyan : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Backend Base URL',
              hintText: 'http://10.152.189.167:8000',
              prefixIcon: Icon(Icons.link, size: 18),
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _presetChip('Physical Dev (${AppConstants.defaultDevUrl})', AppConstants.defaultDevUrl),
              _presetChip('Emulator (10.0.2.2)', AppConstants.defaultEmulatorUrl),
              _presetChip('Localhost (127.0.0.1)', AppConstants.defaultLocalhostUrl),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi, color: AppTheme.textMuted, size: 15),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local Wi-Fi Pairing: Phone and computer must share the same local network. '
                    'Launch backend with: python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 10.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8))
                  : const Icon(Icons.network_check, size: 16),
              label: Text(
                _isTesting ? 'Testing Link...' : 'Test Backend Connection',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _testSuccess ? AppTheme.authenticBg : AppTheme.counterfeitBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _testSuccess
                      ? AppTheme.success.withValues(alpha: 0.5)
                      : AppTheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testSuccess ? const Color(0xFFD1FAE5) : const Color(0xFFFCA5A5),
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono',
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClassifierSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Primary Model Architecture', style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11.5)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _models.contains(_modelName) ? _modelName : _models.first,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            dropdownColor: AppTheme.elevatedCard,
            items: _models.map((m) {
              return DropdownMenuItem(
                value: m,
                child: Text(
                  m == 'efficientnet_b0' ? '$m (Production · 99.76% Verified)' : m,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _modelName = val);
            },
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Screening Confidence Threshold', style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11.5)),
              Text(
                '${(_threshold * 100).toInt()}%',
                style: AppTheme.monoNumeric(color: AppTheme.primaryCyan, fontSize: 13),
              ),
            ],
          ),
          Slider(
            value: _threshold,
            min: 0.50,
            max: 0.95,
            divisions: 9,
            onChanged: (val) => setState(() => _threshold = val),
          ),
          Text(
            'Samples scoring below this threshold escalate to mandatory physical inspection. Standard: 70%.',
            style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildQwenSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enable Secondary AI Inspection', style: AppTheme.headingSmall()),
                    const SizedBox(height: 3),
                    Text(
                      'Invokes local Ollama qwen3-vl:4b vision model for packaging and imprint inspection.',
                      style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enableQwen,
                activeThumbColor: AppTheme.primaryCyan,
                onChanged: (val) => setState(() => _enableQwen = val),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text('Vision Mode Execution', style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11.5)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _visionModes.contains(_visionMode) ? _visionMode : _visionModes.first,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            dropdownColor: AppTheme.elevatedCard,
            items: const [
              DropdownMenuItem(
                value: 'auto',
                child: Text('auto — conditional gating [70%, 90%) borderline zone', style: TextStyle(fontSize: 11.5)),
              ),
              DropdownMenuItem(
                value: 'always',
                child: Text('always — force secondary review on all samples', style: TextStyle(fontSize: 11.5)),
              ),
              DropdownMenuItem(
                value: 'never',
                child: Text('never — fast path, skip secondary AI', style: TextStyle(fontSize: 11.5)),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _visionMode = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStorageSection(int count) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Archive Capacity ($count / ${AppConstants.maxHistoryRecords})', style: AppTheme.headingSmall()),
                  const SizedBox(height: 2),
                  Text('Local device storage · Privacy preserved', style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5)),
                ],
              ),
              OutlinedButton(
                onPressed: count > 0 ? _clearAllHistory : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: AppTheme.error),
                ),
                child: const Text('Clear Storage', style: TextStyle(color: AppTheme.error, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Privacy notice: Sample photographs and metadata remain exclusively stored on your local device. No images are sent to any third-party clouds or external telemetry services.',
            style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return _card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.info_outline, color: AppTheme.primaryCyan, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About PharmaAssist Instrument', style: AppTheme.headingSmall()),
                  const SizedBox(height: 2),
                  Text(
                    'Model architecture, clinical limitations, and legal disclaimers.',
                    style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildModelLabCard() {
    return _card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ModelLabScreen(
                storage: widget.storage,
                apiService: widget.apiService,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.softViolet.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.softViolet.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.science_outlined, color: AppTheme.softViolet, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Model Laboratory', style: AppTheme.headingSmall()),
                  const SizedBox(height: 2),
                  Text(
                    'Model registry status, historical benchmarks, and Qwen AI verification.',
                    style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Space Grotesk',
        color: AppTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }

  Widget _presetChip(String label, String url) {
    return InkWell(
      onTap: () => _applyPreset(url),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.secondaryBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 10.5),
        ),
      ),
    );
  }
}
