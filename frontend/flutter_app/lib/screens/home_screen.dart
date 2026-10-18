import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/screens/scan_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/disclaimer_banner.dart';
import 'package:pharma_assist/widgets/status_badge.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService apiService;
  final VoidCallback? onNavigateToScan;
  final VoidCallback? onChooseGallery;
  final VoidCallback? onNavigateToSettings;

  const HomeScreen({
    super.key,
    required this.storage,
    required this.apiService,
    this.onNavigateToScan,
    this.onChooseGallery,
    this.onNavigateToSettings,
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGreeting(),
                const SizedBox(height: 16),
                // System Status Widget
                _buildSystemStatusCard(),
                const SizedBox(height: 16),

                _buildSummaryStats(),
                const SizedBox(height: 16),

                // Primary Scan Card
                _buildPrimaryScanCard(),
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
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 3),
        Text(
          'Pharmaceutical screening, made clearer.',
          style: AppTheme.headingLarge(),
        ),
        const SizedBox(height: 3),
        Text(
          'Review a medicine sample using your connected screening service.',
          style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSummaryStats() {
    final history = widget.storage.getScanHistory();
    final authentic = history.where((item) => item.isLikelyAuthentic).length;
    final review = history
        .where((item) => item.isSuspicious || item.needsHumanVerification)
        .length;
    return Row(
      children: [
        _statCard(
          'Screenings',
          history.length.toString(),
          Icons.fact_check_outlined,
          AppTheme.primaryCyan,
        ),
        const SizedBox(width: 8),
        _statCard(
          'Likely authentic',
          authentic.toString(),
          Icons.verified_outlined,
          AppTheme.success,
        ),
        const SizedBox(width: 8),
        _statCard(
          'Flagged',
          review.toString(),
          Icons.priority_high_rounded,
          AppTheme.warning,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 6),
            Text(value, style: AppTheme.headingMedium()),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: AppTheme.background,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryCyan, AppTheme.secondaryTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.biotech,
              color: Color(0xFF0B1020),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PharmaAssist', style: AppTheme.headingSmall()),
              Text(
                'AI-assisted pharmaceutical screening',
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
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
                    Text(
                      statusTitle,
                      style: AppTheme.headingSmall(color: badgeColor),
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  'PRIMARY ACTION',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: AppTheme.primaryCyan,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
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
            'Capture a clear image of a tablet or package in even light. The model provides a preliminary visual screening only.',
            style: AppTheme.bodyText(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (widget.onNavigateToScan != null) {
                      widget.onNavigateToScan!();
                    } else {
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
                  },
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('Scan medicine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCyan,
                    foregroundColor: const Color(0xFF0B1020),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (widget.onChooseGallery != null) {
                      widget.onChooseGallery!();
                    } else if (widget.onNavigateToScan != null) {
                      widget.onNavigateToScan!();
                    } else {
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
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Choose image'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT SCREENINGS',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                color: AppTheme.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${widget.storage.getScanHistory().length} total',
              style: AppTheme.monoNumeric(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.textMuted,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'No Prior Screenings Recorded',
              style: AppTheme.headingSmall(),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the Scan Medicine button above to perform your first sample triage.',
              style: AppTheme.bodyText(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
          onTap: item.fullResponse != null
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ResultsScreen(
                        result: item.fullResponse!,
                        sampleId: item.sampleId,
                        medicineName: item.medicineName,
                        notes: item.notes,
                      ),
                    ),
                  );
                }
              : null,
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
