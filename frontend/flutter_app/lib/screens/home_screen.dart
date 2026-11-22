import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/screens/scan_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/disclaimer_banner.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';
import 'package:pharma_assist/widgets/status_badge.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService apiService;
  final VoidCallback? onNavigateToScan;
  final VoidCallback? onChooseGallery;
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onNavigateToReports;

  const HomeScreen({
    super.key,
    required this.storage,
    required this.apiService,
    this.onNavigateToScan,
    this.onChooseGallery,
    this.onNavigateToSettings,
    this.onNavigateToReports,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  bool _isCheckingConnection = false;
  bool? _isBackendConnected;
  String? _connectedDevice;
  String? _serverModel;
  bool? _modelAvailable;
  bool? _qwenAvailable;
  String? _apiVersion;

  List<ScanHistoryItem> _recentInspections = [];

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    _loadRecentInspections();
    await _checkBackendHealth();
  }

  void _loadRecentInspections() {
    final history = widget.storage.getScanHistory();
    if (mounted) {
      setState(() {
        _recentInspections = history.take(3).toList();
      });
    }
  }

  Future<void> _checkBackendHealth() async {
    if (_isCheckingConnection) return;
    setState(() => _isCheckingConnection = true);

    try {
      final health = await widget.apiService.checkHealth();
      if (mounted) {
        setState(() {
          _isBackendConnected = true;
          _connectedDevice = health.device;
          _serverModel = health.defaultModel;
          _apiVersion = health.version;
        });
      }
      try {
        final registry = await widget.apiService.fetchModels();
        final models = registry['models'];
        final matches = models is List
            ? models
                  .whereType<Map>()
                  .where(
                    (entry) =>
                        entry['model_name']?.toString() == health.defaultModel,
                  )
                  .toList()
            : <Map>[];
        final model = matches.isEmpty ? null : matches.first;
        if (mounted) {
          setState(
            () => _modelAvailable = model?['finetuned_available'] == true,
          );
        }
      } catch (_) {
        if (mounted) setState(() => _modelAvailable = null);
      }
      try {
        final qwen = await widget.apiService.fetchQwenStatus();
        if (mounted) setState(() => _qwenAvailable = qwen['available'] == true);
      } catch (_) {
        if (mounted) setState(() => _qwenAvailable = null);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isBackendConnected = false;
          _connectedDevice = null;
          _serverModel = null;
          _modelAvailable = null;
          _qwenAvailable = null;
          _apiVersion = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isCheckingConnection = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildHeader(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshData,
          color: AppTheme.primaryCyan,
          backgroundColor: AppTheme.elevatedCard,
          child: PharmaContentFrame(
            maxWidth: 960,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGreeting(),
                  const SizedBox(height: 16),
                  // Primary Scan Card (High Visual Priority)
                  _buildPrimaryScanCard(),
                  const SizedBox(height: 16),

                  // Compact Summary Statistics
                  _buildSummaryStats(),
                  const SizedBox(height: 16),

                  // Compact System Status
                  _buildSystemStatusCard(),
                  const SizedBox(height: 18),

                  // Recent Scans Section
                  _buildRecentScansSection(),
                  const SizedBox(height: 18),

                  // Safety Reminder
                  const DisclaimerBanner(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryCyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryCyan.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            'PRELIMINARY MEDICINE SCREENING',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              color: AppTheme.primaryCyan,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pharmaceutical screening, made clearer.',
          style: AppTheme.headingLarge(),
        ),
        const SizedBox(height: 4),
        Text(
          'Review preliminary model indications, service availability, and recent reports.',
          style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSummaryStats() {
    final history = widget.storage.getScanHistory();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final authentic = history.where((item) => item.isLikelyAuthentic).length;
    final counterfeit = history
        .where((item) => item.isLikelyCounterfeit)
        .length;
    final attention = history
        .where((item) => item.isSuspicious || item.needsHumanVerification)
        .length;

    final stats = [
      (
        'Saved screenings',
        history.length,
        Icons.fact_check_outlined,
        AppTheme.primaryCyan,
      ),
      (
        'Authentic indicated',
        authentic,
        Icons.verified_outlined,
        AppTheme.success,
      ),
      (
        'Potential counterfeit',
        counterfeit,
        Icons.gpp_bad_outlined,
        AppTheme.error,
      ),
      (
        'Inconclusive / review',
        attention,
        Icons.priority_high_rounded,
        AppTheme.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stats.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 680 ? 4 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: textScale >= 1.4 ? 152 : 104,
        ),
        itemBuilder: (context, index) {
          final item = stats[index];
          return _statCard(item.$1, item.$2.toString(), item.$3, item.$4);
        },
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return PharmaCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: AppTheme.secondaryBackground,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTheme.headingMedium()),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyText(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.secondaryTeal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.biotech, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headingSmall(),
                ),
                Text(
                  'Smart Medicine, Safer Choices',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyText(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            size: 19,
            color: _isCheckingConnection
                ? AppTheme.primaryCyan
                : AppTheme.textSecondary,
          ),
          tooltip: 'Refresh Status',
          onPressed: _isCheckingConnection ? null : _checkBackendHealth,
        ),
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            size: 20,
            color: AppTheme.textSecondary,
          ),
          tooltip: 'Settings',
          onPressed: widget.onNavigateToSettings,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    final bool isOnline = _isBackendConnected == true;
    final bool isOffline = _isBackendConnected == false;

    Color badgeColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    if (_isCheckingConnection) {
      badgeColor = AppTheme.warning;
      statusTitle = 'Checking Connectivity...';
      statusSubtitle = 'Testing link to ${widget.storage.getBackendUrl()}';
      statusIcon = Icons.sync;
    } else if (isOnline) {
      badgeColor = AppTheme.success;
      statusTitle = 'Backend Connected';
      statusSubtitle =
          'API ${_apiVersion ?? 'version unavailable'} · ${_connectedDevice ?? 'Compute device not reported'}';
      statusIcon = Icons.check_circle_outline;
    } else if (isOffline) {
      badgeColor = AppTheme.error;
      statusTitle = 'Backend Unavailable';
      statusSubtitle =
          'Offline: Verify server is running at ${widget.storage.getBackendUrl()}';
      statusIcon = Icons.error_outline;
    } else {
      badgeColor = AppTheme.textMuted;
      statusTitle = 'Status Unknown';
      statusSubtitle = 'Tap to check backend connection';
      statusIcon = Icons.help_outline;
    }

    return PharmaCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Icon(statusIcon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        statusTitle,
                        style: AppTheme.headingSmall(color: badgeColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  statusSubtitle,
                  style: AppTheme.bodyText(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isOnline) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _statusPill(
                        'Model ${_serverModel ?? 'unknown'}',
                        _modelAvailable,
                      ),
                      _statusPill('Qwen review', _qwenAvailable),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, bool? available) {
    final color = available == true
        ? AppTheme.success
        : (available == false ? AppTheme.warning : AppTheme.textMuted);
    final status = available == true
        ? 'available'
        : (available == false ? 'unavailable' : 'unknown');
    return Semantics(
      label: '$label $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$label · $status',
          style: AppTheme.bodyText(color: color, fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildPrimaryScanCard() {
    return PharmaCard(
      padding: const EdgeInsets.all(22),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'PRELIMINARY VISUAL SCREENING',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: AppTheme.primaryCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Icon(
                Icons.shield_outlined,
                color: AppTheme.secondaryTeal,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Screen a medicine sample', style: AppTheme.headingLarge()),
          const SizedBox(height: 6),
          Text(
            'Capture a clear image of a tablet or package in even light. Review the result as an initial visual indication only.',
            style: AppTheme.bodyText(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 480 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18;
              final scan = PharmaPrimaryButton(
                label: 'Scan medicine',
                icon: Icons.document_scanner_outlined,
                onPressed: _openScanner,
                height: 52,
              );
              final gallery = PharmaSecondaryButton(
                label: 'Choose image',
                icon: Icons.photo_library_outlined,
                onPressed: _openGallery,
                height: 52,
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [scan, const SizedBox(height: 10), gallery],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 3, child: scan),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: gallery),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  void _openScanner() {
    if (widget.onNavigateToScan != null) {
      widget.onNavigateToScan!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          storage: widget.storage,
          apiService: widget.apiService,
          onScanComplete: refreshData,
        ),
      ),
    );
  }

  void _openGallery() {
    if (widget.onChooseGallery != null) {
      widget.onChooseGallery!();
      return;
    }
    if (widget.onNavigateToScan != null) {
      widget.onNavigateToScan!();
      return;
    }
    _openScanner();
  }

  Widget _buildRecentScansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PharmaSectionHeader(
          title: 'Recent screenings',
          subtitle:
              '${widget.storage.getScanHistory().length} saved on this device',
          icon: Icons.history_outlined,
          trailing: widget.onNavigateToReports == null
              ? null
              : TextButton(
                  onPressed: widget.onNavigateToReports,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('View reports'),
                ),
        ),
        const SizedBox(height: 8),
        if (_recentInspections.isEmpty)
          _buildEmptyRecentScans()
        else
          ..._recentInspections.map(_buildRecentScanTile),
      ],
    );
  }

  Widget _buildEmptyRecentScans() {
    return PharmaCard(
      child: PharmaEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No screenings yet',
        description: 'Start a screening to see saved results and reports here.',
        action: PharmaSecondaryButton(
          label: 'Start a scan',
          icon: Icons.document_scanner_outlined,
          onPressed: _openScanner,
        ),
      ),
    );
  }

  Widget _buildRecentScanTile(ScanHistoryItem item) {
    final double normConf = item.confidence <= 1.0
        ? item.confidence * 100
        : item.confidence;
    final bool isAuthentic = item.isLikelyAuthentic;
    final bool isCounterfeit = item.isLikelyCounterfeit;

    final Color statusColor = isAuthentic
        ? AppTheme.success
        : (isCounterfeit ? AppTheme.error : AppTheme.warning);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            File? img;
            if (item.imagePath != null && item.imagePath!.isNotEmpty) {
              final f = File(item.imagePath!);
              if (f.existsSync()) img = f;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ResultsScreen(
                  result: item.effectiveResponse,
                  imageFile: img,
                  sampleId: item.sampleId,
                  medicineName: item.medicineName,
                  notes: item.notes,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.sampleId,
                            style: AppTheme.monoNumeric(fontSize: 12),
                          ),
                          if (item.medicineName != null &&
                              item.medicineName!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· ${item.medicineName}',
                              style: AppTheme.bodyText(
                                color: AppTheme.textSecondary,
                                fontSize: 11.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.timestamp.year}-${item.timestamp.month.toString().padLeft(2, '0')}-${item.timestamp.day.toString().padLeft(2, '0')} · ${item.finalResult}',
                        style: AppTheme.bodyText(
                          color: AppTheme.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${normConf.toStringAsFixed(1)}%',
                      style: AppTheme.monoNumeric(
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    StatusBadge(statusText: item.prediction),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
