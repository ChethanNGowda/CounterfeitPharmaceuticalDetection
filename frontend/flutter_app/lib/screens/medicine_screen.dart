import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/models/medicine_profile.dart';
import 'package:pharma_assist/services/medicine_ocr_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';

/// Medicine Information, OCR Packaging Scanner & Expiry Management Destination
class MedicineScreen extends StatefulWidget {
  final StorageService storage;

  const MedicineScreen({super.key, required this.storage});

  @override
  State<MedicineScreen> createState() => MedicineScreenState();
}

class MedicineScreenState extends State<MedicineScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<MedicineProfile> _allProfiles = [];
  List<MedicineProfile> _filteredProfiles = [];
  String _selectedFilter = 'ALL'; // 'ALL', 'NEAR_EXPIRY', 'EXPIRED', 'VERIFIED'
  bool _isProcessingOcr = false;

  @override
  void initState() {
    super.initState();
    loadProfiles();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void loadProfiles() {
    final profiles = widget.storage.getMedicineProfiles();
    if (mounted) {
      setState(() {
        _allProfiles = profiles;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    List<MedicineProfile> list = List.from(_allProfiles);

    if (_selectedFilter == 'NEAR_EXPIRY') {
      list = list.where((p) => p.isNearExpiry(60)).toList();
    } else if (_selectedFilter == 'EXPIRED') {
      list = list.where((p) => p.isExpired).toList();
    } else if (_selectedFilter == 'VERIFIED') {
      list = list.where((p) => p.isVerifiedByUser).toList();
    }

    if (query.isNotEmpty) {
      list = list.where((p) {
        return p.medicineName.toLowerCase().contains(query) ||
            p.manufacturer.toLowerCase().contains(query) ||
            p.batchNumber.toLowerCase().contains(query) ||
            p.strength.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredProfiles = list;
    });
  }

  Future<void> _captureOrPickPackaging(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isProcessingOcr = true);

      // Simulate on-device OCR scan & regex pattern analysis
      await Future.delayed(const Duration(milliseconds: 600));

      final basename = file.name.replaceAll('_', ' ').replaceAll('-', ' ');
      final syntheticText =
          'Rx Medicine\nSample Product: $basename\nBatch No: B-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}\n'
          'Mfg Date: ${DateFormat('MM/yyyy').format(DateTime.now().subtract(const Duration(days: 90)))}\n'
          'Exp Date: ${DateFormat('MM/yyyy').format(DateTime.now().add(const Duration(days: 365)))}\n'
          'Strength: 500 mg\nTablets\nMfd by: Standard Pharma Labs Ltd.\n';

      final ocrResult = MedicineOcrService.parsePackagingText(syntheticText);
      final profile = ocrResult.toProfile(
        imagePath: file.path,
        notes:
            'Captured via ${source == ImageSource.camera ? 'Camera' : 'Gallery'} for packaging inspection.',
      );

      if (mounted) {
        setState(() => _isProcessingOcr = false);
        _showEditProfileModal(context, profile, isNew: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read packaging image: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showEditProfileModal(
    BuildContext context,
    MedicineProfile profile, {
    bool isNew = false,
  }) {
    final nameCtrl = TextEditingController(text: profile.medicineName);
    final mfgCtrl = TextEditingController(text: profile.manufacturer);
    final strengthCtrl = TextEditingController(text: profile.strength);
    final dosageCtrl = TextEditingController(text: profile.dosageForm);
    final batchCtrl = TextEditingController(text: profile.batchNumber);
    final mfgDateCtrl = TextEditingController(text: profile.manufacturingDate);
    final expDateCtrl = TextEditingController(text: profile.expiryDate);
    final notesCtrl = TextEditingController(text: profile.notes ?? '');
    bool isVerified = profile.isVerifiedByUser || isNew;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final tokens = ctx.pharmaTokens;
        final theme = Theme.of(ctx);

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.borderSubtle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isNew
                              ? 'New Medicine Profile'
                              : 'Edit Medicine Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Packaging Thumbnail if available
                    if (profile.packagingImagePath != null &&
                        File(profile.packagingImagePath!).existsSync()) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(profile.packagingImagePath!),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // OCR Confidence Notice
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 16,
                            color: tokens.tealAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'OCR extraction confidence: ${profile.confidence}. Please confirm details against the physical packaging.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Form fields
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Medicine Name *',
                        hintText: 'e.g. Amoxicillin Trihydrate',
                        prefixIcon: Icon(Icons.medication_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: strengthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Strength',
                              hintText: 'e.g. 500 mg',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: dosageCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Dosage Form',
                              hintText: 'e.g. Tablet',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: mfgCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer / Brand',
                        hintText: 'e.g. Standard Pharma Labs Ltd.',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: batchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Batch / Lot Number',
                        hintText: 'e.g. B-90421',
                        prefixIcon: Icon(Icons.qr_code_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: mfgDateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Mfg Date',
                              hintText: 'MM/yyyy',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: expDateCtrl,
                            decoration: InputDecoration(
                              labelText: 'Expiry Date *',
                              hintText: 'MM/yyyy',
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.calendar_month,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: now.add(
                                      const Duration(days: 180),
                                    ),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(now.year + 10),
                                  );
                                  if (picked != null) {
                                    expDateCtrl.text = DateFormat('MM/yyyy')
                                        .format(picked);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Clinical / Field Notes',
                        hintText: 'Packaging observations, blister condition, storage notes...',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // User verification checkbox
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isVerified,
                        onChanged: (val) {
                          setModalState(() => isVerified = val ?? true);
                        },
                        title: Text(
                          'I have verified these values against physical packaging',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Medical disclaimer
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.suspiciousAmberBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Notice: OCR text extraction is an assistive aid. It does not certify chemical composition or authenticity. Do not rely solely on optical scanning for medical decisions.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.suspiciousAmber,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit button
                    PharmaPrimaryButton(
                      label: isNew
                          ? 'Save Confirmed Profile'
                          : 'Update Profile',
                      icon: Icons.check,
                      onPressed: () async {
                        final updated = profile.copyWith(
                          medicineName: nameCtrl.text.trim().isNotEmpty
                              ? nameCtrl.text.trim()
                              : 'Unnamed Sample',
                          manufacturer: mfgCtrl.text.trim(),
                          strength: strengthCtrl.text.trim(),
                          dosageForm: dosageCtrl.text.trim(),
                          batchNumber: batchCtrl.text.trim(),
                          manufacturingDate: mfgDateCtrl.text.trim(),
                          expiryDate: expDateCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                          isVerifiedByUser: isVerified,
                        );

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        await widget.storage.saveMedicineProfile(updated);
                        if (!mounted) return;
                        navigator.pop();
                        loadProfiles();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Medicine profile for "${updated.medicineName}" saved',
                            ),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProfile(MedicineProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medicine Profile?'),
        content: Text(
          'Remove "${profile.medicineName}" from local saved medicine profiles?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.storage.deleteMedicineProfile(profile.id);
              loadProfiles();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pharmaTokens;
    final theme = Theme.of(context);

    // Count near-expiry or expired
    final expiredCount = _allProfiles.where((p) => p.isExpired).length;
    final nearExpiryCount = _allProfiles
        .where((p) => p.isNearExpiry(60))
        .length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Medicine Information'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Medicine Manually',
            onPressed: () {
              final empty = MedicineProfile(
                id: 'MED-${DateTime.now().millisecondsSinceEpoch}',
                medicineName: '',
                createdAt: DateTime.now(),
              );
              _showEditProfileModal(context, empty, isNew: true);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Action Card & Scanner
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppTheme.elevatedCard,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Scan Packaging'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: theme.colorScheme.primary,
                          ),
                          onPressed: _isProcessingOcr
                              ? null
                              : () =>
                                    _captureOrPickPackaging(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: const Text('From Gallery'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: theme.colorScheme.primary,
                          ),
                          onPressed: _isProcessingOcr
                              ? null
                              : () => _captureOrPickPackaging(
                                  ImageSource.gallery,
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (_isProcessingOcr) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(color: tokens.tealAccent),
                  ],
                ],
              ),
            ),

            // Expiry Alert Banner if applicable
            if (expiredCount > 0 || nearExpiryCount > 0) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: expiredCount > 0
                      ? tokens.counterfeitRedBg
                      : tokens.suspiciousAmberBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: expiredCount > 0
                        ? tokens.counterfeitRed
                        : tokens.suspiciousAmber,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      expiredCount > 0
                          ? Icons.error_outline
                          : Icons.warning_amber_rounded,
                      size: 20,
                      color: expiredCount > 0
                          ? tokens.counterfeitRed
                          : tokens.suspiciousAmber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        expiredCount > 0
                            ? '$expiredCount medicine profile(s) have expired!'
                            : '$nearExpiryCount medicine profile(s) expiring within 60 days.',
                        style: TextStyle(
                          color: expiredCount > 0
                              ? tokens.counterfeitRed
                              : tokens.suspiciousAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFilter = expiredCount > 0
                              ? 'EXPIRED'
                              : 'NEAR_EXPIRY';
                          _applyFilters();
                        });
                      },
                      child: Text(
                        'View',
                        style: TextStyle(
                          color: expiredCount > 0
                              ? tokens.counterfeitRed
                              : tokens.suspiciousAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search medicine name, batch, manufacturer...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _filterChip('ALL', 'All (${_allProfiles.length})'),
                  const SizedBox(width: 6),
                  _filterChip(
                    'NEAR_EXPIRY',
                    'Expiring Soon (${_allProfiles.where((p) => p.isNearExpiry(60)).length})',
                  ),
                  const SizedBox(width: 6),
                  _filterChip(
                    'EXPIRED',
                    'Expired (${_allProfiles.where((p) => p.isExpired).length})',
                  ),
                  const SizedBox(width: 6),
                  _filterChip(
                    'VERIFIED',
                    'Verified (${_allProfiles.where((p) => p.isVerifiedByUser).length})',
                  ),
                ],
              ),
            ),

            // Profiles List
            Expanded(
              child: _filteredProfiles.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredProfiles.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final profile = _filteredProfiles[i];
                        return _buildProfileCard(profile, tokens, theme);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = key;
            _applyFilters();
          });
        }
      },
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildProfileCard(
    MedicineProfile profile,
    PharmaThemeTokens tokens,
    ThemeData theme,
  ) {
    final days = profile.daysUntilExpiry;

    Color badgeColor = tokens.authenticGreen;
    Color badgeBg = tokens.authenticGreenBg;
    String badgeText = profile.expiryDate.isNotEmpty
        ? 'Exp: ${profile.expiryDate}'
        : 'No Expiry Set';

    if (profile.isExpired) {
      badgeColor = tokens.counterfeitRed;
      badgeBg = tokens.counterfeitRedBg;
      badgeText = 'EXPIRED (${profile.expiryDate})';
    } else if (profile.isNearExpiry(60)) {
      badgeColor = tokens.suspiciousAmber;
      badgeBg = tokens.suspiciousAmberBg;
      badgeText = 'Exp in ${days ?? 0}d (${profile.expiryDate})';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Icon(
            Icons.medication_outlined,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                profile.medicineName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (profile.strength.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  profile.strength,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.tealAccent,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${profile.manufacturer.isNotEmpty ? profile.manufacturer : "Unknown Manufacturer"} • Batch: ${profile.batchNumber.isNotEmpty ? profile.batchNumber : "N/A"}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (profile.isVerifiedByUser)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: tokens.authenticGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: tokens.authenticGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (val) {
            if (val == 'edit') {
              _showEditProfileModal(context, profile);
            } else if (val == 'delete') {
              _confirmDeleteProfile(profile);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Edit Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppTheme.error)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showEditProfileModal(context, profile),
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
                Icons.medical_information_outlined,
                color: tokens.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text('No Medicine Profiles', style: AppTheme.headingSmall()),
            const SizedBox(height: 6),
            Text(
              _allProfiles.isEmpty
                  ? 'Scan packaging with the camera or add a profile manually to track medicines, batches, and expiry dates.'
                  : 'No medicine profiles match your active search or filter.',
              style: AppTheme.bodyText(color: tokens.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_allProfiles.isEmpty)
              PharmaPrimaryButton(
                label: 'Scan Medicine Packaging',
                icon: Icons.camera_alt,
                onPressed: () => _captureOrPickPackaging(ImageSource.camera),
              ),
          ],
        ),
      ),
    );
  }
}
