import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/models/packaging_checklist.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';

/// Interactive Packaging Inspection Checklist Workflow
class PackagingChecklistScreen extends StatefulWidget {
  final StorageService storage;

  const PackagingChecklistScreen({super.key, required this.storage});

  @override
  State<PackagingChecklistScreen> createState() =>
      _PackagingChecklistScreenState();
}

class _PackagingChecklistScreenState extends State<PackagingChecklistScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _sampleIdCtrl = TextEditingController(
    text:
        'SMP-CHK-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
  );
  final TextEditingController _medicineCtrl = TextEditingController();
  final TextEditingController _overallNotesCtrl = TextEditingController();

  late List<PackagingChecklistItem> _items;
  String? _attachedImagePath;
  List<PackagingChecklistSummary> _savedSummaries = [];
  bool _showingSavedHistory = false;

  @override
  void initState() {
    super.initState();
    _resetChecklist();
    _loadSavedSummaries();
  }

  @override
  void dispose() {
    _sampleIdCtrl.dispose();
    _medicineCtrl.dispose();
    _overallNotesCtrl.dispose();
    super.dispose();
  }

  void _resetChecklist() {
    setState(() {
      _items = PackagingChecklistSummary.createDefaultItems();
      _sampleIdCtrl.text =
          'SMP-CHK-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      _medicineCtrl.clear();
      _overallNotesCtrl.clear();
      _attachedImagePath = null;
    });
  }

  void _loadSavedSummaries() {
    setState(() {
      _savedSummaries = widget.storage.getChecklistSummaries();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() {
        _attachedImagePath = file.path;
      });
    }
  }

  Future<void> _saveSummary() async {
    final incomplete = _items.where((i) => i.status == 'UNCHECKED').length;
    if (incomplete > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Incomplete Inspection Items'),
          content: Text(
            '$incomplete item(s) are still unchecked. Do you want to save this preliminary checklist summary anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review Items'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final summary = PackagingChecklistSummary(
      id: 'CHK-${DateTime.now().millisecondsSinceEpoch}',
      sampleId: _sampleIdCtrl.text.trim().isNotEmpty
          ? _sampleIdCtrl.text.trim()
          : 'SMP-CHK',
      medicineName: _medicineCtrl.text.trim().isNotEmpty
          ? _medicineCtrl.text.trim()
          : 'Unlabeled Sample',
      imagePath: _attachedImagePath,
      items: _items,
      overallNotes: _overallNotesCtrl.text.trim(),
      inspectedAt: DateTime.now(),
    );

    await widget.storage.saveChecklistSummary(summary);
    _loadSavedSummaries();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Packaging inspection summary saved successfully.'),
          backgroundColor: AppTheme.success,
        ),
      );
      setState(() => _showingSavedHistory = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pharmaTokens;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Packaging Inspection Checklist'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_showingSavedHistory ? Icons.checklist : Icons.history),
            tooltip: _showingSavedHistory
                ? 'Active Inspection'
                : 'Saved Checklists',
            onPressed: () {
              setState(() => _showingSavedHistory = !_showingSavedHistory);
            },
          ),
        ],
      ),
      body: _showingSavedHistory
          ? _buildSavedHistoryView(tokens, theme)
          : _buildActiveInspectionView(tokens, theme),
    );
  }

  Widget _buildActiveInspectionView(PharmaThemeTokens tokens, ThemeData theme) {
    final completedCount = _items.where((i) => i.status != 'UNCHECKED').length;
    final progress = _items.isEmpty ? 0.0 : completedCount / _items.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Educational Banner Notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: tokens.tealAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Educational Aid Notice: This checklist provides structured physical inspection criteria for blister packs, cartons, and labels. It does not replace analytical laboratory testing or verify medicine ingredients.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Sample Information Form
        PharmaCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inspection Metadata',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sampleIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sample ID',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _medicineCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Medicine Name',
                        hintText: 'e.g. Paracetamol 500mg',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Attached Image Thumbnail / Selector
              Row(
                children: [
                  if (_attachedImagePath != null &&
                      File(_attachedImagePath!).existsSync()) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(_attachedImagePath!),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: Text(
                        _attachedImagePath == null
                            ? 'Attach Packaging Photo'
                            : 'Change Photo',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Progress Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Inspection Progress ($completedCount/${_items.length} items checked)',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.tealAccent,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: tokens.borderSubtle,
          color: tokens.tealAccent,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 16),

        // Checklist Items
        ...List.generate(_items.length, (index) {
          final item = _items[index];
          return _buildChecklistItemCard(item, tokens, theme);
        }),

        const SizedBox(height: 14),
        // Overall observations
        TextField(
          controller: _overallNotesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Overall Packaging Inspection Notes',
            hintText: 'Record general observations, suspicious variations, or notes for pharmacist...',
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetChecklist,
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PharmaPrimaryButton(
                label: 'Save Inspection Summary',
                icon: Icons.check,
                onPressed: _saveSummary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildChecklistItemCard(
    PackagingChecklistItem item,
    PharmaThemeTokens tokens,
    ThemeData theme,
  ) {
    Color statusColor = tokens.textMuted;
    if (item.status == 'PASS') statusColor = tokens.authenticGreen;
    if (item.status == 'CONCERN') statusColor = tokens.suspiciousAmber;
    if (item.status == 'TAMPERED') statusColor = tokens.counterfeitRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.status == 'UNCHECKED'
              ? tokens.borderSubtle
              : statusColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textMuted,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Criteria: ${item.criteria}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.primaryBlue,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),

          // Status selector buttons
          Row(
            children: [
              _statusButton(item, 'PASS', 'Normal', tokens.authenticGreen),
              const SizedBox(width: 6),
              _statusButton(
                item,
                'CONCERN',
                'Minor Defect',
                tokens.suspiciousAmber,
              ),
              const SizedBox(width: 6),
              _statusButton(
                item,
                'TAMPERED',
                'Tampering Sign',
                tokens.counterfeitRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusButton(
    PackagingChecklistItem item,
    String value,
    String label,
    Color color,
  ) {
    final isSelected = item.status == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            item.status = isSelected ? 'UNCHECKED' : value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : AppTheme.secondaryBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? color : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedHistoryView(PharmaThemeTokens tokens, ThemeData theme) {
    if (_savedSummaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text(
              'No Saved Inspection Checklists',
              style: AppTheme.headingSmall(),
            ),
            const SizedBox(height: 6),
            Text(
              'Complete a checklist inspection to save records here.',
              style: AppTheme.bodyText(color: tokens.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _savedSummaries.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final summary = _savedSummaries[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.elevatedCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    summary.medicineName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy HH:mm').format(summary.inspectedAt),
                    style: TextStyle(color: tokens.textMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Sample: ${summary.sampleId}',
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statBadge(
                    '${summary.passCount} Normal',
                    tokens.authenticGreen,
                    tokens.authenticGreenBg,
                  ),
                  const SizedBox(width: 6),
                  _statBadge(
                    '${summary.concernCount} Concerns',
                    tokens.suspiciousAmber,
                    tokens.suspiciousAmberBg,
                  ),
                  const SizedBox(width: 6),
                  _statBadge(
                    '${summary.tamperedCount} Tampered',
                    tokens.counterfeitRed,
                    tokens.counterfeitRedBg,
                  ),
                ],
              ),
              if (summary.overallNotes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Notes: ${summary.overallNotes}',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statBadge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
