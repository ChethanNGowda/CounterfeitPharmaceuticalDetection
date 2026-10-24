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
  List<String> _availableModels = const [];
  bool _modelRegistryLoaded = false;

  final List<String> _visionModes = ['auto', 'always', 'never'];
  final List<String> _themeModes = ['dark', 'light'];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.storage.getBackendUrl(),
    );
    _threshold = widget.storage.getThreshold();
    // Older app builds may have stored a retired experimental architecture.
    _modelName = AppConstants.defaultModel;
    _visionMode = widget.storage.getVisionMode();
    _enableQwen = widget.storage.getEnableQwen();
    _themeMode = widget.storage.getThemeMode() == 'light' ? 'light' : 'dark';
    if (widget.storage.getThemeMode() != _themeMode) {
      widget.storage.setThemeMode(_themeMode);
    }
    _loadModelRegistry();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final cleanUrl = StorageService.normalizeUrl(_urlController.text);
    if (!_isValidBaseUrl(cleanUrl)) {
      _showInvalidUrlMessage();
      return;
    }
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
    if (!_isValidBaseUrl(targetUrl)) {
      _showInvalidUrlMessage();
      return;
    }
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final HealthResponse health = await widget.apiService.checkHealth(
        customBaseUrl: targetUrl,
      );
      List<String> available = [];
      try {
        final registry = await widget.apiService.fetchModels(
          customBaseUrl: targetUrl,
        );
        final models = registry['models'];
        if (models is List) {
          available = models
              .whereType<Map>()
              .where((m) => m['finetuned_available'] == true)
              .map((m) => m['model_name']?.toString())
              .whereType<String>()
              .toList();
        }
        _modelRegistryLoaded = true;
        _availableModels = available;
        if (available.isNotEmpty && !available.contains(_modelName)) {
          _modelName = available.contains(AppConstants.defaultModel)
              ? AppConstants.defaultModel
              : available.first;
        }
      } catch (_) {
        _modelRegistryLoaded = false;
        _availableModels = [];
      }
      Map<String, dynamic>? qwenStatus;
      try {
        qwenStatus = await widget.apiService.fetchQwenStatus(
          customBaseUrl: targetUrl,
        );
      } catch (_) {
        // A missing optional AI service does not mean the main API is offline.
      }
      setState(() {
        _testSuccess = true;
        _testResult =
            'CONNECTION SUCCESSFUL\n'
            '- API version: ${health.version}\n'
            '- Compute device: ${health.device ?? "Not reported"}\n'
            '- Main model: ${health.defaultModel ?? "Not reported"} ${available.contains(health.defaultModel) ? "(ready)" : "(not confirmed ready)"}\n'
            '- Optional AI visual review: ${qwenStatus == null
                ? "status could not be checked"
                : qwenStatus['available'] == true
                ? "ready (${qwenStatus['model_name'] ?? 'vision model'})"
                : "not ready - ${qwenStatus['message'] ?? 'check the backend AI service'}"}';
      });
      await widget.storage.setBackendUrl(targetUrl);
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult =
            'CONNECTION FAILED\n$e\n\n'
            'Troubleshooting Checklist:\n'
            '1. Ensure backend is running: python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000\n'
            '2. Check Wi-Fi pairing: Both computer and phone must share the same local network subnet.\n'
            '3. Emulator note: Use 10.0.2.2 instead of localhost.';
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  bool _isValidBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }

  void _showInvalidUrlMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Enter a valid http:// or https:// backend base URL without credentials.',
        ),
      ),
    );
  }

  Future<void> _loadModelRegistry() async {
    try {
      final registry = await widget.apiService.fetchModels();
      final models = registry['models'];
      if (models is List) {
        final available = models
            .whereType<Map>()
            .where((m) => m['finetuned_available'] == true)
            .map((m) => m['model_name']?.toString())
            .whereType<String>()
            .toList();
        if (mounted) {
          setState(() {
            _availableModels = available;
            _modelRegistryLoaded = true;
            if (available.isNotEmpty && !available.contains(_modelName)) {
              _modelName = available.contains(AppConstants.defaultModel)
                  ? AppConstants.defaultModel
                  : available.first;
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _modelRegistryLoaded = false);
    }
  }

  void _applyPreset(String url) => setState(() => _urlController.text = url);

  Future<void> _clearAllHistory() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.elevatedCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          'Clear All Local Archives?',
          style: AppTheme.headingSmall(),
        ),
        content: Text(
          'Permanently wipe all inspection records and cached result metadata from this device? This will not affect training data or server checkpoints.',
          style: AppTheme.bodyText(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
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
              child: Icon(
                Icons.settings_outlined,
                color: AppTheme.primaryCyan,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Settings & Diagnostics', style: AppTheme.headingSmall()),
                Text(
                  'Instrument configuration & safety',
                  style: AppTheme.bodyText(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
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
          Text('Appearance', style: AppTheme.headingSmall()),
          const SizedBox(height: 4),
          Text(
            'Choose the app appearance. Your selection is saved on this device.',
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
                      widget.storage.setThemeMode(mode);
                      widget.onThemeChanged?.call(mode);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppTheme.primaryCyan.withValues(alpha: 0.15)
                            : AppTheme.secondaryBackground,
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
                                : Icons.light_mode_outlined,
                            size: 18,
                            color: isSel
                                ? AppTheme.primaryCyan
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mode.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSel
                                  ? AppTheme.primaryCyan
                                  : AppTheme.textSecondary,
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
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
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
              _presetChip(
                'Physical Dev (${AppConstants.defaultDevUrl})',
                AppConstants.defaultDevUrl,
              ),
              _presetChip(
                'Emulator (10.0.2.2)',
                AppConstants.defaultEmulatorUrl,
              ),
              _presetChip(
                'Localhost (127.0.0.1)',
                AppConstants.defaultLocalhostUrl,
              ),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi, color: AppTheme.textMuted, size: 15),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local Wi-Fi Pairing: Phone and computer must share the same local network. '
                    'Launch backend with: python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
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
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    )
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
                color: _testSuccess
                    ? AppTheme.authenticBg
                    : AppTheme.counterfeitBg,
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
                  color: _testSuccess
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFCA5A5),
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
          Text(
            'Main screening model',
            style: AppTheme.bodyText(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            !_modelRegistryLoaded
                ? 'Model availability has not been confirmed by the backend.'
                : _availableModels.isEmpty
                ? 'The backend reports no fine-tuned models available.'
                : 'Available: ${_availableModels.join(', ')}',
            style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondaryBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              _modelRegistryLoaded && _availableModels.contains(_modelName)
                  ? 'Active screening model: $_modelName. Other model names are not available as fine-tuned medicine classifiers on this backend.'
                  : 'Active screening model: $_modelName. Connect to the backend to confirm its checkpoint is ready.',
              style: AppTheme.bodyText(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Authentic-Probability Cutoff',
                style: AppTheme.bodyText(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              Text(
                '${(_threshold * 100).toInt()}%',
                style: AppTheme.monoNumeric(
                  color: AppTheme.primaryCyan,
                  fontSize: 13,
                ),
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
            'Below 50% authentic indicates counterfeit. From 50% through this cutoff requires review; above it indicates authentic. Default cutoff: 70%.',
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
                    Text(
                      'Additional AI photo review',
                      style: AppTheme.headingSmall(),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'A second visual opinion from the AI service running with your backend.',
                      style: AppTheme.bodyText(
                        color: AppTheme.textMuted,
                        fontSize: 10.5,
                      ),
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

          Text(
            'When should the additional review run?',
            style: AppTheme.bodyText(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _visionModes.contains(_visionMode)
                ? _visionMode
                : _visionModes.first,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            dropdownColor: AppTheme.elevatedCard,
            items: const [
              DropdownMenuItem(
                value: 'auto',
                child: Text(
                  AppConstants.visionModeAutoLabel,
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              DropdownMenuItem(
                value: 'always',
                child: Text(
                  AppConstants.visionModeAlwaysLabel,
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              DropdownMenuItem(
                value: 'never',
                child: Text(
                  AppConstants.visionModeNeverLabel,
                  style: TextStyle(fontSize: 11.5),
                ),
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
                  Text(
                    'Archive Capacity ($count / ${AppConstants.maxHistoryRecords})',
                    style: AppTheme.headingSmall(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Saved on this device · Privacy preserved',
                    style: AppTheme.bodyText(
                      color: AppTheme.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: count > 0 ? _clearAllHistory : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  side: const BorderSide(color: AppTheme.error),
                ),
                child: const Text(
                  'Clear Storage',
                  style: TextStyle(color: AppTheme.error, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Screening history stays on this device. When you submit a scan, its image is sent to the backend URL configured above.',
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
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AboutScreen()));
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
                border: Border.all(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                Icons.info_outline,
                color: AppTheme.primaryCyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About PharmaAssist Instrument',
                    style: AppTheme.headingSmall(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Model architecture, clinical limitations, and legal disclaimers.',
                    style: AppTheme.bodyText(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textMuted),
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
                border: Border.all(
                  color: AppTheme.softViolet.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                Icons.science_outlined,
                color: AppTheme.softViolet,
                size: 20,
              ),
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
                    style: AppTheme.bodyText(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
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
          style: AppTheme.bodyText(
            color: AppTheme.textSecondary,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }
}
