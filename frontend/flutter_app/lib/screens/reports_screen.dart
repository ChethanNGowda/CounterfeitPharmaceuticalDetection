import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/services/history_csv_exporter.dart';
import 'package:pharma_assist/services/report_service.dart';
import 'package:pharma_assist/services/simple_pdf_report_generator.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';
import 'package:pharma_assist/widgets/status_badge.dart';

/// Dedicated Healthcare Inspection Reports Screen with PDF, CSV, TXT exports and date filtering
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
  DateTimeRange? _selectedDateRange;

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

    // Apply Date Range Filter
    if (_selectedDateRange != null) {
      final start = DateTime(
        _selectedDateRange!.start.year,
        _selectedDateRange!.start.month,
        _selectedDateRange!.start.day,
      );
      final end = DateTime(
        _selectedDateRange!.end.year,
        _selectedDateRange!.end.month,
        _selectedDateRange!.end.day,
        23,
        59,
        59,
      );
      list = list.where((item) {
        return item.timestamp.isAfter(
              start.subtract(const Duration(seconds: 1)),
            ) &&
            item.timestamp.isBefore(end.add(const Duration(seconds: 1)));
      }).toList();
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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _applyFilters();
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _selectedDateRange = null;
      _applyFilters();
    });
  }

  Future<void> _exportPdfReport(ScanHistoryItem item) async {
    try {
      final pdfBytes = SimplePdfReportGenerator.generateReportPdf(item);
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/report_${item.sampleId}.pdf');
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF report saved: ${file.path}'),
            action: SnackBarAction(
              label: 'Copy Path',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: file.path)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    }
  }

  Future<void> _exportTxtReport(ScanHistoryItem item) async {
    try {
      final reportText = ReportService.generateReportFromHistory(item);
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/report_${item.sampleId}.txt');
      await file.writeAsString(reportText);
      await Clipboard.setData(ClipboardData(text: reportText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report saved to ${file.path} and copied to clipboard.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export report: $e')));
      }
    }
  }

  Future<void> _exportAllCsv() async {
    if (_allReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No inspection reports available to export.'),
        ),
      );
      return;
    }

    try {
      final csvContent = HistoryCsvExporter.encode(_allReports);
      final tempDir = Directory.systemTemp;
      final file = File(
        '${tempDir.path}/pharma_assist_screenings_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csvContent);
      await Clipboard.setData(ClipboardData(text: csvContent));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${_allReports.length} records to ${file.path} (copied to clipboard).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
      }
    }
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
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('Export PDF'),
              onPressed: () {
                Navigator.pop(ctx);
                _exportPdfReport(item);
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Save TXT'),
              onPressed: () {
                Navigator.pop(ctx);
                _exportTxtReport(item);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.pharmaTokens;
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Reports'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: _selectedDateRange == null
                ? 'Filter by Date Range'
                : 'Clear Date Filter',
            icon: Icon(
              Icons.date_range,
              color: _selectedDateRange != null
                  ? theme.colorScheme.primary
                  : null,
            ),
            onPressed: () {
              if (_selectedDateRange != null) {
                _clearDateRange();
              } else {
                _pickDateRange();
              }
            },
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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

          // Date Filter Badge (if active)
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${dateFmt.format(_selectedDateRange!.start)} to ${dateFmt.format(_selectedDateRange!.end)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _clearDateRange,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                            _selectedFilter != 'ALL' ||
                            _selectedDateRange != null
                        ? 'No Matching Reports'
                        : 'No Inspection Reports',
                    description:
                        _searchController.text.isNotEmpty ||
                            _selectedDateRange != null
                        ? 'Try modifying your search query, filter tab, or date range.'
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
