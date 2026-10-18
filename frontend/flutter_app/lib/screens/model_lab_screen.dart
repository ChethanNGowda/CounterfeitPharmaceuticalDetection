import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/status_badge.dart';

/// Model Laboratory — Screen 3
///
/// Shows the model registry status, historical benchmark metrics,
/// Qwen secondary AI diagnostics, and the scan history with
/// model/confidence/Qwen columns. All data is sourced from the backend
/// or local storage — no invented values are shown.
class ModelLabScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService apiService;

  const ModelLabScreen({
    super.key,
    required this.storage,
    required this.apiService,
  });

  @override
  State<ModelLabScreen> createState() => _ModelLabScreenState();
}

class _ModelLabScreenState extends State<ModelLabScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Models registry state
  bool _loadingModels = false;
  String? _modelsError;
  Map<String, dynamic>? _modelsData;

  // Qwen status state
  bool _loadingQwen = false;
  String? _qwenError;
  Map<String, dynamic>? _qwenData;

  // History state
  List<ScanHistoryItem> _history = [];
  String _historySearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAll() {
    _fetchModels();
    _fetchQwen();
    _loadHistory();
  }

  Future<void> _fetchModels() async {
    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });
    try {
      final data = await widget.apiService.fetchModels();
      if (mounted) setState(() { _modelsData = data; _loadingModels = false; });
    } catch (e) {
      if (mounted) setState(() { _modelsError = e.toString(); _loadingModels = false; });
    }
  }

  Future<void> _fetchQwen() async {
    setState(() {
      _loadingQwen = true;
      _qwenError = null;
    });
    try {
      final data = await widget.apiService.fetchQwenStatus();
      if (mounted) setState(() { _qwenData = data; _loadingQwen = false; });
    } catch (e) {
      if (mounted) setState(() { _qwenError = e.toString(); _loadingQwen = false; });
    }
  }

  void _loadHistory() {
    setState(() {
      _history = widget.storage.getScanHistory();
    });
  }

  // ─────────────────────────── BUILD ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
                color: AppTheme.violetAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.violetAccent.withValues(alpha: 0.45)),
              ),
              child: Icon(Icons.science_outlined, color: AppTheme.violetAccent, size: 17),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Model Laboratory', style: AppTheme.headingSmall()),
                Text('Registry · Benchmarks · History',
                    style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 9.5)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 19),
            tooltip: 'Refresh',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.violetAccent,
          labelColor: AppTheme.violetAccent,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'REGISTRY'),
            Tab(text: 'QWEN AI'),
            Tab(text: 'HISTORY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildModelRegistryTab(),
          _buildQwenTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // ─────────────────────── TAB 1: MODEL REGISTRY ─────────────────────────────

  Widget _buildModelRegistryTab() {
    if (_loadingModels) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.violetAccent),
            const SizedBox(height: 16),
            const Text('Fetching model registry…',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    if (_modelsError != null) {
      return _buildErrorState(
        'Cannot reach model registry',
        _modelsError!,
        onRetry: _fetchModels,
        accentColor: AppTheme.violetAccent,
      );
    }
    if (_modelsData == null) {
      return _buildEmptyState('No model data', 'Tap refresh to load the registry.', Icons.inventory_2_outlined);
    }

    final models = (_modelsData!['models'] as List?) ?? [];
    final availableList = (_modelsData!['available_models'] as List?)?.cast<String>() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.elevatedCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              _summaryBadge('${_modelsData!['total_models']}', 'Registered', AppTheme.primaryCyan),
              const SizedBox(width: 20),
              _summaryBadge('${availableList.length}', 'Runnable', AppTheme.success),
              const SizedBox(width: 20),
              _summaryBadge('${models.length - availableList.length}', 'Checkpoint\nMissing', AppTheme.warning),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Safety note
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.violetAccent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.violetAccent.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Historical benchmark metrics are from the original training run (2026-09-23, test.csv, 827 images). '
            'Only EfficientNet-B0 has been reproduced from the current checkpoint. '
            'No fine-tuned checkpoints exist for MobileNetV3, GoldFormer, or Baseline CNN.',
            style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5),
          ),
        ),
        const SizedBox(height: 14),
        for (final model in models) ...[
          _buildModelCard(model),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildModelCard(Map<String, dynamic> model) {
    final bool available = model['finetuned_available'] == true;
    final bool evaluated = model['evaluated'] == true;
    final String name = model['model_name'] ?? '';
    final String status = model['status'] ?? '';
    final String desc = model['description'] ?? '';
    final String? sha = model['checkpoint_sha256'] as String?;
    final Map<String, dynamic>? metrics = model['metrics'] as Map<String, dynamic>?;

    final Color statusColor = available ? AppTheme.success : AppTheme.warning;
    final IconData statusIcon = available ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: available
              ? AppTheme.success.withValues(alpha: 0.4)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(desc, style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: available
                        ? AppTheme.success.withValues(alpha: 0.12)
                        : AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    available ? 'RUNNABLE' : 'UNAVAILABLE',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Checkpoint info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryBackground,
              border: Border(
                top: BorderSide(color: AppTheme.border),
                bottom: BorderSide(color: AppTheme.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Status: ', style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5)),
                    Expanded(
                      child: Text(
                        status,
                        style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 10.5),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                if (sha != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('SHA-256: ', style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5)),
                      Text(
                        '${sha.substring(0, 16)}…',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          color: AppTheme.primaryCyan,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Metrics
          if (evaluated && metrics != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    available ? 'REPRODUCED METRICS' : 'HISTORICAL BENCHMARK',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: available ? AppTheme.success : AppTheme.textMuted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _metricsRow([
                    ('Accuracy', _pct(metrics['accuracy'])),
                    ('Recall', _pct(metrics['recall'])),
                    ('Precision', _pct(metrics['precision'])),
                  ]),
                  const SizedBox(height: 4),
                  _metricsRow([
                    ('Macro F1', _pct(metrics['macro_f1'])),
                    ('Specificity', _pct(metrics['specificity'])),
                    ('ROC-AUC', _fmt(metrics['roc_auc'])),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    metrics['note'] as String? ?? '',
                    style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 9.5),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'NOT EVALUATED — fine-tuned checkpoint missing from disk.',
                style: AppTheme.bodyText(color: AppTheme.error, fontSize: 10.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricsRow(List<(String, String)> pairs) {
    return Row(
      children: pairs.map((p) {
        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.$1, style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 9.5)),
              Text(
                p.$2,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  color: AppTheme.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _pct(dynamic v) {
    if (v == null) return '—';
    final double d = (v as num).toDouble();
    return '${(d * 100).toStringAsFixed(2)}%';
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    return (v as num).toStringAsFixed(5);
  }

  Widget _summaryBadge(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            )),
        Text(label, style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  // ─────────────────────── TAB 2: QWEN STATUS ────────────────────────────────

  Widget _buildQwenTab() {
    if (_loadingQwen) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryCyan),
            SizedBox(height: 16),
            Text('Checking Qwen AI status…',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    if (_qwenError != null) {
      return _buildErrorState(
        'Qwen status check failed',
        _qwenError!,
        onRetry: _fetchQwen,
        accentColor: AppTheme.error,
      );
    }
    if (_qwenData == null) {
      return _buildEmptyState('No Qwen data', 'Tap refresh to check secondary AI status.', Icons.psychology_outlined);
    }

    final String status = _qwenData!['status'] ?? 'UNKNOWN';
    final bool available = _qwenData!['available'] == true;
    final String modelName = _qwenData!['model_name'] ?? '—';
    final String baseUrl = _qwenData!['base_url'] ?? '—';
    final String message = _qwenData!['message'] ?? '';
    final List<String> installedModels = (_qwenData!['installed_models'] as List?)?.cast<String>() ?? [];

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'READY':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'MODEL_NOT_INSTALLED':
        statusColor = AppTheme.warning;
        statusIcon = Icons.download_outlined;
        break;
      case 'OLLAMA_UNREACHABLE':
        statusColor = AppTheme.error;
        statusIcon = Icons.cloud_off_outlined;
        break;
      default:
        statusColor = AppTheme.textMuted;
        statusIcon = Icons.help_outline;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.elevatedCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 3),
                    Text(message, style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Configuration details
        _infoCard('CONFIGURATION', [
          ('Configured Model', modelName),
          ('Ollama Endpoint', baseUrl),
          ('Integration Type', 'Vision-language model receiving actual image via Ollama API'),
          ('Image Encoding', 'Base64 JPEG (resized to max 384px, quality 88)'),
          ('Prompt Style', 'Structured output: Assessment / Confidence / Tablet Analysis / Concerns'),
        ]),
        const SizedBox(height: 12),

        // Test coverage
        _infoCard('AUTOMATED TEST COVERAGE', [
          ('Ollama unavailable (connection refused)', '✅ Returns UNAVAILABLE fallback'),
          ('Request timeout', '✅ Returns UNAVAILABLE with timeout message'),
          ('Model not installed (404)', '✅ Returns UNAVAILABLE with install instructions'),
          ('Multimodal not supported', '✅ Returns UNAVAILABLE with model suggestion'),
          ('Malformed / empty response', '✅ Defaults to UNCERTAIN + MANUAL REVIEW'),
          ('Qwen contradicts primary classifier', '✅ SUSPICIOUS / NEEDS VERIFICATION result'),
          ('Low primary confidence (<0.70)', '✅ SUSPICIOUS without secondary invocation'),
          ('High primary confidence (≥0.90, auto mode)', '✅ Qwen skipped, fast path used'),
        ]),
        const SizedBox(height: 12),

        // Installed models (if any)
        if (installedModels.isNotEmpty) ...[
          _infoCard('INSTALLED OLLAMA MODELS', [
            for (final m in installedModels) (m, ''),
          ]),
          const SizedBox(height: 12),
        ],

        // Integration notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.elevatedCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INTEGRATION NOTICE',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: AppTheme.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Qwen3-VL is a true multimodal vision model. It receives the actual tablet image '
                '(base64-encoded JPEG) — not JSON metadata or classifier statistics. '
                'It operates as a secondary verifier: Qwen agreement does not prove authenticity, '
                'and Qwen disagreement always escalates the result to SUSPICIOUS / NEEDS VERIFICATION. '
                'End-to-end integration requires a running local Ollama instance with qwen3-vl:4b installed.',
                style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5),
              ),
              if (!available) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    'To enable secondary AI review:\n'
                    '  1. Install Ollama (https://ollama.com)\n'
                    '  2. Run: ollama pull qwen3-vl:4b\n'
                    '  3. Ensure Ollama is running on port 11434',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      color: AppTheme.warning,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String title, List<(String, String)> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                color: AppTheme.textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Divider(color: AppTheme.border, height: 1),
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: rows[i].$2.isEmpty
                  ? Text(rows[i].$1, style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11.5))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(rows[i].$1,
                              style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 11)),
                        ),
                        Expanded(
                          child: Text(rows[i].$2,
                              style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11)),
                        ),
                      ],
                    ),
            ),
            if (i < rows.length - 1)
              const Divider(color: AppTheme.border, height: 1, indent: 12),
          ],
        ],
      ),
    );
  }

  // ─────────────────────── TAB 3: HISTORY ────────────────────────────────────

  Widget _buildHistoryTab() {
    final filtered = _history.where((item) {
      if (_historySearch.isEmpty) return true;
      final q = _historySearch.toLowerCase();
      return item.sampleId.toLowerCase().contains(q) ||
          (item.medicineName?.toLowerCase().contains(q) ?? false) ||
          item.finalResult.toLowerCase().contains(q) ||
          item.modelName.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by sample, product, verdict, or model…',
              hintStyle: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
              suffixIcon: _historySearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                      onPressed: () => setState(() => _historySearch = ''),
                    )
                  : null,
            ),
            style: AppTheme.bodyText(fontSize: 12),
            onChanged: (v) => setState(() => _historySearch = v),
          ),
        ),
        // Column headers
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Sample / Product', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Verdict', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Model', style: _headerStyle())),
              Expanded(flex: 2, child: Text('Qwen', style: _headerStyle())),
            ],
          ),
        ),
        // List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  _historySearch.isNotEmpty ? 'No matching records' : 'No inspection records',
                  _historySearch.isNotEmpty
                      ? 'Try a different search term.'
                      : 'Complete a scan to see history here.',
                  Icons.history,
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _buildHistoryRow(filtered[i]),
                ),
        ),
      ],
    );
  }

  TextStyle _headerStyle() => const TextStyle(
        fontFamily: 'Space Grotesk',
        color: AppTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  Widget _buildHistoryRow(ScanHistoryItem item) {
    final String qwenStatus = item.qwenAssessment ?? '—';
    final Color qwenColor;
    if (qwenStatus == 'AUTHENTIC') {
      qwenColor = AppTheme.success;
    } else if (qwenStatus == 'COUNTERFEIT') {
      qwenColor = AppTheme.error;
    } else if (qwenStatus == 'UNAVAILABLE' || qwenStatus == '—') {
      qwenColor = AppTheme.textMuted;
    } else {
      qwenColor = AppTheme.warning;
    }

    return InkWell(
      onTap: () => _openDetail(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.6))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sampleId,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      color: AppTheme.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.medicineName != null)
                    Text(
                      item.medicineName!,
                      style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    DateFormat('MMM d, HH:mm').format(item.timestamp),
                    style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 9.5),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: StatusBadge(statusText: item.finalResult),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.modelName,
                style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 9.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                qwenStatus.length > 10 ? '${qwenStatus.substring(0, 9)}…' : qwenStatus,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  color: qwenColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(ScanHistoryItem item) {
    final result = item.toPredictionResponse();
    if (result != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            result: result,
            sampleId: item.sampleId,
            medicineName: item.medicineName,
            notes: item.notes,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reconstruct full result for this record.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ──────────────────────── UTILITY WIDGETS ──────────────────────────────────

  Widget _buildErrorState(
    String title,
    String detail, {
    required VoidCallback onRetry,
    required Color accentColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: accentColor, size: 48),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.headingSmall()),
            const SizedBox(height: 8),
            Text(
              detail,
              style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 11.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(foregroundColor: accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(title, style: AppTheme.headingSmall()),
          const SizedBox(height: 4),
          Text(subtitle,
              style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 11.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
