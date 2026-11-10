import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/services/history_csv_exporter.dart';
import 'package:pharma_assist/services/report_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';
import 'package:pharma_assist/widgets/status_badge.dart';

/// Dedicated Healthcare Inspection Reports Screen
class ReportsScreen extends StatefulWidget {
  final StorageService storage;

  const ReportsScreen({super.key, required this.storage});

  @override
  State<ReportsScreen> createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ScanHistoryItem> _allReports = [];
  List<ScanHistoryItem> _filteredReports = [];
  String _selectedFilter = 'ALL'; // ALL, AUTHENTIC, COUNTERFEIT, REVIEW
  bool _sortNewestFirst = true;

  @override
  void initState() {
    super.initState();
    loadReports();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void loadReports() {
    final history = widget.storage.getScanHistory();
    if (mounted) {
      setState(() {
        _allReports = history;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    List<ScanHistoryItem> list = List.from(_allReports);

    // Apply Filter Tab
    if (_selectedFilter == 'AUTHENTIC') {
      list = list.where((item) => item.isLikelyAuthentic).toList();
    } else if (_selectedFilter == 'COUNTERFEIT') {
      list = list.where((item) => item.isLikelyCounterfeit).toList();
    } else if (_selectedFilter == 'REVIEW') {
      list = list
          .where((item) => item.isSuspicious || item.needsHumanVerification)
          .toList();
    }

    // Apply Search Query
    if (query.isNotEmpty) {
      list = list.where((item) {
        final sampleId = item.sampleId.toLowerCase();
        final medicine = (item.medicineName ?? '').toLowerCase();
        final verdict = item.finalResult.toLowerCase();
        final model = item.primaryModel.toLowerCase();
        return sampleId.contains(query) ||
            medicine.contains(query) ||
            verdict.contains(query) ||
            model.contains(query);
      }).toList();
    }

    // Apply Sort Order
    list.sort(
      (a, b) => _sortNewestFirst
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp),
    );

    setState(() {
      _filteredReports = list;
    });
  }

  void _showReportDetails(ScanHistoryItem item) {
    final reportText = ReportService.generateReportFromHistory(item);

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final tokens = ctx.pharmaTokens;

        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: tokens.borderSubtle),
          ),
          title: Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Inspection Report',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                reportText,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: ['monospace'],
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Copy Text'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: reportText));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report copied to clipboard.')),
                );
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _exportAllCsv() {
    if (_allReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No inspection reports available to export.'),
        ),
      );
      return;
    }

    final csvContent = HistoryCsvExporter.encode(_allReports);
    Clipboard.setData(ClipboardData(text: csvContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exported ${_allReports.length} reports to CSV (copied to clipboard).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.pharmaTokens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Reports'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: _sortNewestFirst
                ? 'Showing Newest First'
                : 'Showing Oldest First',
            icon: Icon(
              _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            onPressed: () {
              setState(() {
                _sortNewestFirst = !_sortNewestFirst;
                _applyFilters();
              });
            },
          ),
          IconButton(
            tooltip: 'Export Reports CSV',
            icon: const Icon(Icons.download_outlined),
            onPressed: _exportAllCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by sample ID, medicine, verdict...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All (${_allReports.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'AUTHENTIC',
                  'Authentic (${_allReports.where((e) => e.isLikelyAuthentic).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'COUNTERFEIT',
                  'Counterfeit (${_allReports.where((e) => e.isLikelyCounterfeit).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'REVIEW',
                  'Attention (${_allReports.where((e) => e.isSuspicious || e.needsHumanVerification).length})',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Reports List or Empty State
          Expanded(
            child: _filteredReports.isEmpty
                ? PharmaEmptyState(
                    icon: Icons.assignment_outlined,
                    title:
                        _searchController.text.isNotEmpty ||
                            _selectedFilter != 'ALL'
                        ? 'No Matching Reports'
                        : 'No Inspection Reports',
                    description: _searchController.text.isNotEmpty
                        ? 'Try modifying your search query or filter criteria.'
                        : 'Completed medicine screenings will generate structured compliance reports here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _filteredReports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _filteredReports[index];
                      return _buildReportCard(item, theme, tokens);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    final theme = Theme.of(context);
    final tokens = context.pharmaTokens;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _selectedFilter = filterKey;
          _applyFilters();
        });
      },
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected ? theme.colorScheme.primary : tokens.textMuted,
      ),
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : tokens.borderSubtle,
        width: 1,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildReportCard(
    ScanHistoryItem item,
    ThemeData theme,
    PharmaThemeTokens tokens,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy · HH:mm');
    final String timeStr = dateFormat.format(item.timestamp);
    final String confidence = (item.confidence * 100).toStringAsFixed(1);

    Color indicatorColor = tokens.suspiciousAmber;
    if (item.isLikelyAuthentic) {
      indicatorColor = tokens.authenticGreen;
    } else if (item.isLikelyCounterfeit) {
      indicatorColor = tokens.counterfeitRed;
    }

    return PharmaCard(
      onTap: () => _showReportDetails(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.medicineName ?? item.sampleId,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(statusText: item.finalResult),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.fingerprint, size: 14, color: tokens.textMuted),
              const SizedBox(width: 4),
              Text(
                item.sampleId,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: const ['monospace'],
                  fontSize: 11,
                  color: tokens.textMuted,
                ),
              ),
              const Spacer(),
              Icon(Icons.analytics_outlined, size: 14, color: tokens.textMuted),
              const SizedBox(width: 4),
              Text(
                'Conf: $confidence%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule, size: 13, color: tokens.textMuted),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.primaryModel,
                  style: TextStyle(fontSize: 10, color: tokens.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
