import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/services/history_csv_exporter.dart';
import 'package:pharma_assist/widgets/status_badge.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storage;

  const HistoryScreen({super.key, required this.storage});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<ScanHistoryItem> _allHistory = [];
  List<ScanHistoryItem> _filteredHistory = [];
  String _searchQuery = '';
  String _selectedFilter =
      'ALL'; // ALL, AUTHENTIC, COUNTERFEIT, REVIEW, FAVORITES
  bool _sortNewestFirst = true;
  DateTimeRange? _dateRange;

  final TextEditingController _searchController = TextEditingController();

  // Multi-select for side-by-side comparison (Phase 8 Feature #1)
  final Set<String> _selectedForComparison = {};

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void loadHistory() {
    if (!mounted) return;
    setState(() {
      _allHistory = widget.storage.getScanHistory();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<ScanHistoryItem> list = List.from(_allHistory);

    // Apply category filter
    if (_selectedFilter == 'AUTHENTIC') {
      list = list.where((item) => item.isLikelyAuthentic).toList();
    } else if (_selectedFilter == 'COUNTERFEIT') {
      list = list.where((item) => item.isLikelyCounterfeit).toList();
    } else if (_selectedFilter == 'REVIEW') {
      list = list
          .where((item) => item.isSuspicious || item.needsHumanVerification)
          .toList();
    } else if (_selectedFilter == 'FAVORITES') {
      final favs = widget.storage.getFavoriteIds();
      list = list.where((item) => favs.contains(item.id)).toList();
    }

    // Apply search query
    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      list = list
          .where(
            (item) =>
                !item.timestamp.isBefore(start) && !item.timestamp.isAfter(end),
          )
          .toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((item) {
        final sampleMatch = item.sampleId.toLowerCase().contains(q);
        final medMatch = item.medicineName?.toLowerCase().contains(q) ?? false;
        final notesMatch = item.notes?.toLowerCase().contains(q) ?? false;
        final verdictMatch = item.finalResult.toLowerCase().contains(q);
        return sampleMatch || medMatch || notesMatch || verdictMatch;
      }).toList();
    }

    // Sort order
    list.sort(
      (a, b) => _sortNewestFirst
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp),
    );

    _filteredHistory = list;
  }

  Future<void> _toggleFavorite(ScanHistoryItem item) async {
    await widget.storage.toggleFavorite(item.id);
    setState(() {
      _applyFilters();
    });
  }

  void _toggleComparisonSelection(String id) {
    setState(() {
      if (_selectedForComparison.contains(id)) {
        _selectedForComparison.remove(id);
      } else {
        if (_selectedForComparison.length >= 2) {
          _selectedForComparison.remove(_selectedForComparison.first);
        }
        _selectedForComparison.add(id);
      }
    });
  }

  void _openComparisonDialog() {
    if (_selectedForComparison.length != 2) return;
    final idList = _selectedForComparison.toList();
    final itemA = _allHistory.firstWhere((e) => e.id == idList[0]);
    final itemB = _allHistory.firstWhere((e) => e.id == idList[1]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.elevatedCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            Icon(Icons.compare_arrows, color: AppTheme.primaryCyan, size: 20),
            const SizedBox(width: 8),
            Text('Side-by-Side Comparison', style: AppTheme.headingSmall()),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Comparative analysis between two archived screening records. '
                  'Note: Visual screening comparison cannot establish identical chemical formulation.',
                  style: AppTheme.bodyText(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(color: AppTheme.border, width: 0.8),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBackground,
                      ),
                      children: [
                        _tableCell('Metric', isHeader: true),
                        _tableCell(itemA.sampleId, isHeader: true),
                        _tableCell(itemB.sampleId, isHeader: true),
                      ],
                    ),
                    TableRow(
                      children: [
                        _tableCell('Product Name'),
                        _tableCell(itemA.medicineName ?? '—'),
                        _tableCell(itemB.medicineName ?? '—'),
                      ],
                    ),
                    TableRow(
                      children: [
                        _tableCell('Final Verdict'),
                        _tableCell(itemA.finalResult),
                        _tableCell(itemB.finalResult),
                      ],
                    ),
                    TableRow(
                      children: [
                        _tableCell('Primary Confidence'),
                        _tableCell(
                          '${(itemA.confidence * 100).toStringAsFixed(1)}%',
                        ),
                        _tableCell(
                          '${(itemB.confidence * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        _tableCell('Primary Architecture'),
                        _tableCell(itemA.primaryModel),
                        _tableCell(itemB.primaryModel),
                      ],
                    ),
                    TableRow(
                      children: [
                        _tableCell('Human Review Required'),
                        _tableCell(itemA.needsHumanVerification ? 'YES' : 'NO'),
                        _tableCell(itemB.needsHumanVerification ? 'YES' : 'NO'),
                      ],
                    ),
                    TableRow(
                      children: [
                        _tableCell('Inspection Date'),
                        _tableCell(
                          DateFormat('yyyy-MM-dd').format(itemA.timestamp),
                        ),
                        _tableCell(
                          DateFormat('yyyy-MM-dd').format(itemB.timestamp),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11.5 : 11,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
          color: isHeader ? AppTheme.primaryCyan : AppTheme.textPrimary,
        ),
      ),
    );
  }

  void _exportHistoryCsv() {
    final csv = HistoryCsvExporter.encode(_filteredHistory);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.elevatedCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            Icon(
              Icons.file_download_outlined,
              color: AppTheme.primaryCyan,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text('Exported History CSV', style: AppTheme.headingSmall()),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Metadata export of ${_filteredHistory.length} inspection records. No images embedded for privacy protection.',
                style: AppTheme.bodyText(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 180,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: AppTheme.monoNumeric(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(ctx);
              await Clipboard.setData(ClipboardData(text: csv));
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(ScanHistoryItem item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.elevatedCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.border),
        ),
        title: Text('Delete Record?', style: AppTheme.headingSmall()),
        content: Text(
          'Permanently remove inspection record "${item.sampleId}" from device memory?',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.storage.deleteScanHistoryItem(item.id);
      loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Record ${item.sampleId} removed from storage'),
            backgroundColor: AppTheme.elevatedCard,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchAndFilters(),
            if (_selectedForComparison.isNotEmpty) _buildComparisonBar(),
            Divider(height: 1, color: AppTheme.border),
            Expanded(
              child: _filteredHistory.isEmpty
                  ? _buildEmptyState()
                  : _buildHistoryList(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            child: Icon(Icons.history, color: AppTheme.primaryCyan, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Inspection Records',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headingSmall(),
                ),
                Text(
                  '${_allHistory.length} local records preserved',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyText(
                    color: AppTheme.textMuted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined, size: 19),
          tooltip: 'Export CSV',
          onPressed: _filteredHistory.isNotEmpty ? _exportHistoryCsv : null,
        ),
        IconButton(
          icon: Icon(_sortNewestFirst ? Icons.south : Icons.north, size: 18),
          tooltip: _sortNewestFirst
              ? 'Sort: Newest First'
              : 'Sort: Oldest First',
          onPressed: () {
            setState(() {
              _sortNewestFirst = !_sortNewestFirst;
              _applyFilters();
            });
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  Widget _buildComparisonBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppTheme.secondaryBackground,
      child: Row(
        children: [
          Icon(Icons.compare_arrows, size: 16, color: AppTheme.primaryCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_selectedForComparison.length}/2 records selected for comparison',
              style: AppTheme.bodyText(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          if (_selectedForComparison.length == 2)
            ElevatedButton(
              onPressed: _openComparisonDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                foregroundColor: const Color(0xFF0B1020),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(60, 32),
              ),
              child: const Text(
                'Compare',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: AppTheme.textMuted),
            onPressed: () => setState(() => _selectedForComparison.clear()),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      color: AppTheme.secondaryBackground,
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilters();
                });
              },
              style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText:
                    'Search by sample ID, brand name, notes, or verdict...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(
                    _dateRange == null
                        ? 'Dates'
                        : '${DateFormat('MMM d').format(_dateRange!.start)}–${DateFormat('MMM d').format(_dateRange!.end)}',
                  ),
                  onPressed: _chooseDateRange,
                ),
                if (_dateRange != null)
                  IconButton(
                    tooltip: 'Clear date filter',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _dateRange = null;
                      _applyFilters();
                    }),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                const SizedBox(width: 4),
                _filterChip('ALL', 'All (${_allHistory.length})'),
                const SizedBox(width: 6),
                _filterChip(
                  'AUTHENTIC',
                  'Authentic (${_allHistory.where((e) => e.isLikelyAuthentic).length})',
                  color: AppTheme.success,
                ),
                const SizedBox(width: 6),
                _filterChip(
                  'COUNTERFEIT',
                  'Counterfeit (${_allHistory.where((e) => e.isLikelyCounterfeit).length})',
                  color: AppTheme.error,
                ),
                const SizedBox(width: 6),
                _filterChip(
                  'REVIEW',
                  'Needs Review (${_allHistory.where((e) => e.isSuspicious || e.needsHumanVerification).length})',
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 6),
                _filterChip(
                  'FAVORITES',
                  'Bookmarked (${_allHistory.where((e) => widget.storage.isFavorite(e.id)).length})',
                  color: AppTheme.softViolet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
      helpText: 'Filter screening dates',
    );
    if (range != null && mounted) {
      setState(() {
        _dateRange = range;
        _applyFilters();
      });
    }
  }

  Widget _filterChip(String id, String label, {Color? color}) {
    final bool isSelected = _selectedFilter == id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = id;
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (color?.withValues(alpha: 0.2) ?? AppTheme.surfaceHighlight)
              : AppTheme.elevatedCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? (color ?? AppTheme.primaryCyan)
                : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (color ?? AppTheme.primaryCyan)
                : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.secondaryBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 28,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No Matching Records Found'
                  : 'No Inspection Records',
              style: AppTheme.headingSmall(),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search query, filter chips, or date sorting.'
                  : 'Completed field screenings will be preserved in this local archive.',
              style: AppTheme.bodyText(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    final DateFormat formatter = DateFormat('yyyy-MM-dd · HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _filteredHistory.length,
      itemBuilder: (context, index) {
        final item = _filteredHistory[index];
        final double normConf = item.confidence <= 1.0
            ? item.confidence * 100
            : item.confidence;
        final bool isFav = widget.storage.isFavorite(item.id);
        final bool isSelected = _selectedForComparison.contains(item.id);
        final String historyLabel =
            item.isSuspicious || item.needsHumanVerification
            ? 'NEEDS REVIEW'
            : item.prediction;

        final Color stripColor = item.isLikelyAuthentic
            ? AppTheme.success
            : (item.isLikelyCounterfeit ? AppTheme.error : AppTheme.warning);

        return Dismissible(
          key: Key('history_${item.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppTheme.counterfeitBg,
            child: const Icon(Icons.delete, color: AppTheme.error),
          ),
          confirmDismiss: (dir) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.elevatedCard,
                title: Text('Delete Record?', style: AppTheme.headingSmall()),
                content: Text(
                  'Remove ${item.sampleId} from device archive?',
                  style: AppTheme.bodyText(fontSize: 12.5),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (dir) {
            widget.storage.deleteScanHistoryItem(item.id);
            loadHistory();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.surfaceHighlight
                  : AppTheme.elevatedCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.primaryCyan : AppTheme.border,
                width: isSelected ? 1.5 : 1.0,
              ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 3.5,
                            height: 44,
                            decoration: BoxDecoration(
                              color: stripColor,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.monoNumeric(fontSize: 12.5),
                                ),
                                if (item.medicineName != null &&
                                    item.medicineName!.isNotEmpty)
                                  Text(
                                    item.medicineName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.bodyText(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  formatter.format(item.timestamp),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.bodyText(
                                    color: AppTheme.textMuted,
                                    fontSize: 10.5,
                                  ),
                                ),
                                Text(
                                  item.finalResult,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.bodyText(
                                    color: AppTheme.textMuted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${normConf.toStringAsFixed(1)}%',
                            style: AppTheme.monoNumeric(
                              color: stripColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusBadge(statusText: historyLabel),
                          const Spacer(),
                        ],
                      ),
                      if (item.fullResponse != null) ...[
                        const SizedBox(height: 6),
                        _buildAiReviewSummary(item),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isFav ? Icons.bookmark : Icons.bookmark_border,
                                size: 18,
                                color: isFav
                                    ? AppTheme.softViolet
                                    : AppTheme.textMuted,
                              ),
                              tooltip: isFav
                                  ? 'Remove Bookmark'
                                  : 'Bookmark Record',
                              onPressed: () => _toggleFavorite(item),
                            ),
                            IconButton(
                              icon: Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 18,
                                color: isSelected
                                    ? AppTheme.primaryCyan
                                    : AppTheme.textMuted,
                              ),
                              tooltip: 'Select for Comparison',
                              onPressed: () =>
                                  _toggleComparisonSelection(item.id),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppTheme.textMuted,
                              ),
                              tooltip: 'Delete Record',
                              onPressed: () => _deleteItem(item),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiReviewSummary(ScanHistoryItem item) {
    final response = item.fullResponse!;
    final qwen = response.qwen;
    final String title = !response.secondaryExecuted
        ? 'AI review not run'
        : qwen.available
        ? 'AI review: ${qwen.assessment}'
        : 'AI review unavailable';
    final String? detail = !response.secondaryExecuted
        ? response.secondaryReason
        : qwen.available
        ? (qwen.finalExplanation ??
              qwen.recommendation ??
              qwen.reasoning.firstOrNull)
        : (qwen.error ?? qwen.warning ?? response.secondaryReason);
    final Color color = !response.secondaryExecuted
        ? AppTheme.textMuted
        : qwen.available
        ? AppTheme.primaryCyan
        : AppTheme.warning;
    return Semantics(
      label: detail == null || detail.isEmpty ? title : '$title. $detail',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.secondaryBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.psychology_outlined, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyText(color: color, fontSize: 10.5),
                  ),
                  if (detail != null && detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyText(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
