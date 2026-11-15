import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/services/export_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/status_badge.dart';

/// Clean, professional Screening Records Screen consolidating inspection history,
/// multi-criteria search, filters, and Android-native PDF/TXT/CSV exports.
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
      'ALL'; // 'ALL', 'AUTHENTIC', 'COUNTERFEIT', 'REVIEW', 'FAVORITES'
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

  // Aliases for backward compatibility
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

  // ── Single Record Exports via ExportService ────────────────────────────────

  Future<void> _exportPdfReport(ScanHistoryItem item) async {
    final result = await ExportService.exportPdfReport(item);
    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.publicDownloadsPath != null
                ? 'PDF report saved to Downloads: ${result.filePath.split(Platform.pathSeparator).last}'
                : 'PDF report exported: ${result.filePath}',
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export PDF: ${result.errorMessage}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _exportTxtReport(ScanHistoryItem item) async {
    final result = await ExportService.exportTxtReport(item);
    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.publicDownloadsPath != null
                ? 'Report saved to Downloads and copied to clipboard'
                : 'Report exported to ${result.filePath} and copied',
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export TXT: ${result.errorMessage}'),
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

    final result = await ExportService.exportHistoryCsv(_filteredRecords);
    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_filteredRecords.length} records to CSV'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export CSV: ${result.errorMessage}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _toggleFavorite(String id) async {
    await widget.storage.toggleFavorite(id);
    setState(() {
      _applyFilters();
    });
  }

  Future<void> _confirmDelete(ScanHistoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inspection Record'),
        content: Text(
          'Are you sure you want to delete screening record "${item.sampleId}"? This action cannot be undone.',
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

  void _openFullReport(ScanHistoryItem item) {
    File? originalImage;
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      final f = File(item.imagePath!);
      if (f.existsSync()) {
        originalImage = f;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          result: item.effectiveResponse,
          imageFile: originalImage,
          sampleId: item.sampleId,
          medicineName: item.medicineName,
          notes: item.notes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pharmaTokens;
    final theme = Theme.of(context);

    final authenticCount = _allRecords.where((r) => r.isLikelyAuthentic).length;
    final counterfeitCount = _allRecords
        .where((r) => r.isLikelyCounterfeit)
        .length;
    final reviewCount = _allRecords
        .where((r) => r.isSuspicious || r.needsHumanVerification)
        .length;

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
          IconButton(
            icon: Icon(
              _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              size: 20,
              color: tokens.tealAccent,
            ),
            tooltip: _sortNewestFirst
                ? 'Sort: Oldest First'
                : 'Sort: Newest First',
            onPressed: () {
              setState(() {
                _sortNewestFirst = !_sortNewestFirst;
                _applyFilters();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export all to CSV',
            onPressed: _allRecords.isNotEmpty ? _exportAllCsv : null,
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
            // Top Description & Summary Strip
            Container(
              color: AppTheme.secondaryBackground,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audit trail of pharmaceutical inspections, classifications, and exports.',
                    style: TextStyle(fontSize: 12, color: tokens.textMuted),
                  ),
                  const SizedBox(height: 10),

                  // Metrics Summary Row
                  Row(
                    children: [
                      _summaryChip(
                        'Total: ${_allRecords.length}',
                        tokens.navyBrand,
                        tokens.surfaceSubtle,
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        'Authentic: $authenticCount',
                        tokens.authenticGreen,
                        tokens.authenticGreenBg,
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        'Counterfeit: $counterfeitCount',
                        tokens.counterfeitRed,
                        tokens.counterfeitRedBg,
                      ),
                      const SizedBox(width: 8),
                      _summaryChip(
                        'Review: $reviewCount',
                        tokens.suspiciousAmber,
                        tokens.suspiciousAmberBg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

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
                        _filterChip('AUTHENTIC', 'Authentic ($authenticCount)'),
                        const SizedBox(width: 6),
                        _filterChip(
                          'COUNTERFEIT',
                          'Counterfeit ($counterfeitCount)',
                        ),
                        const SizedBox(width: 6),
                        _filterChip('REVIEW', 'Review ($reviewCount)'),
                        const SizedBox(width: 6),
                        _filterChip(
                          'FAVORITES',
                          'Starred (${widget.storage.getFavoriteIds().length})',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Active Date Filter Notification
            if (_selectedDateRange != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                color: tokens.tealAccent.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_alt_outlined,
                      size: 14,
                      color: tokens.tealAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Filtered: ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} → ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}',
                        style: TextStyle(
                          color: tokens.tealAccent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _clearDateRange,
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: tokens.counterfeitRed,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Records List View
            Expanded(
              child: _filteredRecords.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _filteredRecords.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        return _buildRecordCard(
                          _filteredRecords[index],
                          tokens,
                          theme,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final tokens = context.pharmaTokens;
    final isSelected = _selectedFilter == filterKey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? tokens.tealAccent : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tokens.tealAccent : tokens.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : tokens.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(
    ScanHistoryItem item,
    PharmaThemeTokens tokens,
    ThemeData theme,
  ) {
    final isFav = widget.storage.getFavoriteIds().contains(item.id);

    File? imageFile;
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      final f = File(item.imagePath!);
      if (f.existsSync()) {
        imageFile = f;
      }
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
          // Top Row: Sample ID and Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: tokens.surfaceSubtle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.sampleId,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: tokens.primaryBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(statusText: item.finalResult),
              ],
            ),
          ),

          // Middle Section: Thumbnail, Medicine Name, Date, Model
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 54,
                    height: 54,
                    color: tokens.surfaceSubtle,
                    child: imageFile != null
                        ? Image.file(
                            imageFile,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.medication_outlined,
                            color: tokens.textMuted,
                            size: 26,
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.medicineName != null &&
                                item.medicineName!.isNotEmpty
                            ? item.medicineName!
                            : 'Unlabeled Medicine Sample',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('MMM d, yyyy · HH:mm')
                            .format(item.timestamp),
                        style: TextStyle(color: tokens.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Text(
                              item.primaryModel,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: tokens.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(item.confidence * 100).toStringAsFixed(1)}% match',
                            style: AppTheme.monoNumeric(
                              color: tokens.tealAccent,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, thickness: 1, color: tokens.borderSubtle),

          // Bottom Action Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                // Primary View Report action
                TextButton.icon(
                  onPressed: () => _openFullReport(item),
                  icon: const Icon(Icons.analytics_outlined, size: 15),
                  label: const Text(
                    'Full Report',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: tokens.tealAccent,
                  ),
                ),
                const Spacer(),

                // PDF Export
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  tooltip: 'Export PDF to Phone',
                  onPressed: () => _exportPdfReport(item),
                  visualDensity: VisualDensity.compact,
                ),

                // TXT Export
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  tooltip: 'Save / Share TXT',
                  onPressed: () => _exportTxtReport(item),
                  visualDensity: VisualDensity.compact,
                ),

                // Favorite Star
                IconButton(
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    size: 19,
                    color: isFav ? AppTheme.warning : tokens.textMuted,
                  ),
                  tooltip: isFav ? 'Remove Star' : 'Star Record',
                  onPressed: () => _toggleFavorite(item.id),
                  visualDensity: VisualDensity.compact,
                ),

                // Delete
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: tokens.counterfeitRed,
                  ),
                  tooltip: 'Delete Record',
                  onPressed: () => _confirmDelete(item),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
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
                  : 'No inspection records match the current filter criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
