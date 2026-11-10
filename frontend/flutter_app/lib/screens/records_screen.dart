import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/services/history_csv_exporter.dart';
import 'package:pharma_assist/services/report_service.dart';
import 'package:pharma_assist/services/simple_pdf_report_generator.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/status_badge.dart';

/// Unified Pharmaceutical Inspection Records & Reports Screen
/// Combines historical screenings, date/verdict filtering, search,
/// and comprehensive exports (PDF, CSV, TXT) into a single cohesive interface.
class RecordsScreen extends StatefulWidget {
  final StorageService storage;

  const RecordsScreen({super.key, required this.storage});

  @override
  State<RecordsScreen> createState() => RecordsScreenState();
}

class RecordsScreenState extends State<RecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ScanHistoryItem> _allRecords = [];
  List<ScanHistoryItem> _filteredRecords = [];

  String _selectedFilter =
      'ALL'; // ALL, AUTHENTIC, COUNTERFEIT, REVIEW, FAVORITES
  bool _sortNewestFirst = true;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    loadRecords();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void loadRecords() {
    final history = widget.storage.getScanHistory();
    if (mounted) {
      setState(() {
        _allRecords = history;
        _applyFilters();
      });
    }
  }

  // Alias for backward compatibility
  void loadHistory() => loadRecords();
  void loadReports() => loadRecords();

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    List<ScanHistoryItem> list = List.from(_allRecords);

    // 1. Status Filter Tab
    if (_selectedFilter == 'AUTHENTIC') {
      list = list.where((r) => r.isLikelyAuthentic).toList();
    } else if (_selectedFilter == 'COUNTERFEIT') {
      list = list.where((r) => r.isLikelyCounterfeit).toList();
    } else if (_selectedFilter == 'REVIEW') {
      list = list
          .where((r) => r.isSuspicious || r.needsHumanVerification)
          .toList();
    } else if (_selectedFilter == 'FAVORITES') {
      final favs = widget.storage.getFavoriteIds();
      list = list.where((r) => favs.contains(r.id)).toList();
    }

    // 2. Date Range Filter
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
      list = list
          .where(
            (r) =>
                r.timestamp.isAfter(
                  start.subtract(const Duration(seconds: 1)),
                ) &&
                r.timestamp.isBefore(end.add(const Duration(seconds: 1))),
          )
          .toList();
    }

    // 3. Search Query Filter
    if (query.isNotEmpty) {
      list = list.where((r) {
        final sampleMatch = r.sampleId.toLowerCase().contains(query);
        final medMatch = (r.medicineName ?? '').toLowerCase().contains(query);
        final predMatch = r.prediction.toLowerCase().contains(query);
        final notesMatch = (r.notes ?? '').toLowerCase().contains(query);
        return sampleMatch || medMatch || predMatch || notesMatch;
      }).toList();
    }

    // 4. Sorting
    list.sort((a, b) {
      final comp = b.timestamp.compareTo(a.timestamp);
      return _sortNewestFirst ? comp : -comp;
    });

    setState(() {
      _filteredRecords = list;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      helpText: 'Select Inspection Date Range',
      confirmText: 'Apply Filter',
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

  // ── Single Record Exports ───────────────────────────────────────────────────

  Future<void> _exportPdfReport(ScanHistoryItem item) async {
    try {
      final bytes = SimplePdfReportGenerator.generateReportPdf(item);
      final tempDir = Directory.systemTemp;
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}pharma_report_${item.sampleId}.pdf',
      );
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generated: ${file.path}'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Copy Path',
            textColor: Colors.white,
            onPressed: () => Clipboard.setData(ClipboardData(text: file.path)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export PDF: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _exportTxtReport(ScanHistoryItem item) async {
    try {
      final reportText = ReportService.generateReportFromHistory(item);
      await Clipboard.setData(ClipboardData(text: reportText));

      final tempDir = Directory.systemTemp;
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}report_${item.sampleId}.txt',
      );
      await file.writeAsString(reportText);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report saved to ${file.path} and copied to clipboard'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export TXT: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _exportAllCsv() async {
    if (_filteredRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records matching the filter to export.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    try {
      final csv = HistoryCsvExporter.encode(_filteredRecords);
      await Clipboard.setData(ClipboardData(text: csv));

      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}pharma_assist_screenings_$timestamp.csv',
      );
      await file.writeAsString(csv);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${_filteredRecords.length} records to ${file.path} & clipboard',
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Copy Path',
            textColor: Colors.white,
            onPressed: () => Clipboard.setData(ClipboardData(text: file.path)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export CSV: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _toggleFavorite(ScanHistoryItem item) async {
    await widget.storage.toggleFavorite(item.id);
    loadRecords();
  }

  Future<void> _deleteRecord(ScanHistoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inspection Record'),
        content: Text(
          'Are you sure you want to delete ${item.sampleId}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.storage.deleteScanHistoryItem(item.id);
      loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Record ${item.sampleId} deleted'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pharmaTokens;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Inspection Records'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range_outlined,
              color: _selectedDateRange != null
                  ? tokens.tealAccent
                  : tokens.textMuted,
            ),
            tooltip: _selectedDateRange == null
                ? 'Filter by Date'
                : 'Clear Date Filter',
            onPressed: _selectedDateRange == null
                ? _pickDateRange
                : _clearDateRange,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Export & Actions',
            onSelected: (val) {
              if (val == 'csv') _exportAllCsv();
              if (val == 'sort') {
                setState(() {
                  _sortNewestFirst = !_sortNewestFirst;
                  _applyFilters();
                });
              }
              if (val == 'clear_date') _clearDateRange();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(
                      Icons.table_view_outlined,
                      size: 18,
                      color: tokens.tealAccent,
                    ),
                    const SizedBox(width: 10),
                    Text('Export ${_filteredRecords.length} to CSV'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(
                      _sortNewestFirst
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 18,
                      color: tokens.tealAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _sortNewestFirst
                          ? 'Sort: Oldest First'
                          : 'Sort: Newest First',
                    ),
                  ],
                ),
              ),
              if (_selectedDateRange != null)
                const PopupMenuItem(
                  value: 'clear_date',
                  child: Row(
                    children: [
                      Icon(Icons.event_busy, size: 18, color: AppTheme.warning),
                      SizedBox(width: 10),
                      Text('Clear Date Filter'),
                    ],
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: tokens.borderSubtle),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Category Filters Bar
            Container(
              color: AppTheme.secondaryBackground,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  // Search TextField
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search sample ID, medicine name, or notes...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Filter Chips Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('ALL', 'All (${_allRecords.length})'),
                        const SizedBox(width: 6),
                        _filterChip(
                          'AUTHENTIC',
                          'Authentic (${_allRecords.where((r) => r.isLikelyAuthentic).length})',
                        ),
                        const SizedBox(width: 6),
                        _filterChip(
                          'COUNTERFEIT',
                          'Counterfeit (${_allRecords.where((r) => r.isLikelyCounterfeit).length})',
                        ),
                        const SizedBox(width: 6),
                        _filterChip(
                          'REVIEW',
                          'Review (${_allRecords.where((r) => r.isSuspicious || r.needsHumanVerification).length})',
                        ),
                        const SizedBox(width: 6),
                        _filterChip(
                          'FAVORITES',
                          'Starred (${_allRecords.where((r) => widget.storage.getFavoriteIds().contains(r.id)).length})',
                        ),
                      ],
                    ),
                  ),

                  // Active Date Range Badge
                  if (_selectedDateRange != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.tealAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: tokens.tealAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: tokens.tealAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}',
                                style: TextStyle(
                                  color: tokens.tealAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: _clearDateRange,
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: tokens.tealAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Records List
            Expanded(
              child: _filteredRecords.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async => loadRecords(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRecords.length,
                        separatorBuilder: (ctx, idx) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final item = _filteredRecords[idx];
                          return _buildRecordCard(item, tokens);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    final tokens = context.pharmaTokens;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filterKey;
            _applyFilters();
          });
        }
      },
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : tokens.textMuted,
      ),
      backgroundColor: AppTheme.elevatedCard,
      selectedColor: tokens.tealAccent,
      side: BorderSide(
        color: isSelected ? tokens.tealAccent : tokens.borderSubtle,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRecordCard(ScanHistoryItem item, PharmaThemeTokens tokens) {
    final double confPct = item.confidence <= 1.0
        ? (item.confidence * 100)
        : item.confidence;
    final isFav = widget.storage.getFavoriteIds().contains(item.id);

    Color indicatorColor = tokens.suspiciousAmber;
    if (item.isLikelyAuthentic) {
      indicatorColor = tokens.authenticGreen;
    } else if (item.isLikelyCounterfeit) {
      indicatorColor = tokens.counterfeitRed;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              if (item.fullResponse != null) {
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
              } else {
                _showRecordDetailDialog(item);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.sampleId,
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            if (item.medicineName != null &&
                                item.medicineName!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.medicineName!,
                                style: TextStyle(
                                  color: tokens.tealAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d, yyyy · HH:mm')
                                  .format(item.timestamp),
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(statusText: item.finalResult),
                          const SizedBox(height: 4),
                          Text(
                            '${confPct.toStringAsFixed(1)}% match',
                            style: AppTheme.monoNumeric(
                              color: tokens.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(height: 1, color: tokens.borderSubtle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _exportPdfReport(item),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                  label: const Text('PDF', style: TextStyle(fontSize: 11.5)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: tokens.tealAccent,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _exportTxtReport(item),
                  icon: const Icon(Icons.copy_outlined, size: 15),
                  label: const Text(
                    'Copy TXT',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: tokens.tealAccent,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? AppTheme.warning : tokens.textMuted,
                    size: 18,
                  ),
                  tooltip: isFav ? 'Unstar' : 'Star',
                  onPressed: () => _toggleFavorite(item),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.error,
                    size: 18,
                  ),
                  tooltip: 'Delete',
                  onPressed: () => _deleteRecord(item),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordDetailDialog(ScanHistoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.sampleId, style: const TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.medicineName != null) ...[
                Text(
                  'Medicine: ${item.medicineName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
              ],
              Text('Verdict: ${item.finalResult}'),
              Text(
                'Confidence: ${(item.confidence * 100).toStringAsFixed(1)}%',
              ),
              Text(
                'Timestamp: ${DateFormat('yyyy-MM-dd HH:mm').format(item.timestamp)}',
              ),
              if (item.notes != null) ...[
                const SizedBox(height: 4),
                Text('Notes: ${item.notes}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportPdfReport(item);
            },
            child: const Text('Export PDF'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportTxtReport(item);
            },
            child: const Text('Save TXT'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final tokens = context.pharmaTokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.secondaryBackground,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: tokens.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text('No Inspection Records', style: AppTheme.headingSmall()),
            const SizedBox(height: 6),
            Text(
              _allRecords.isEmpty
                  ? 'Perform a sample scan to record your first pharmaceutical inspection.'
                  : 'No records match your active search, date, or category filters.',
              style: AppTheme.bodyText(color: tokens.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (_selectedDateRange != null ||
                _searchController.text.isNotEmpty ||
                _selectedFilter != 'ALL') ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _selectedFilter = 'ALL';
                  _clearDateRange();
                },
                child: const Text('Clear All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
