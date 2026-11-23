import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/models/medicine_profile.dart';
import 'package:pharma_assist/models/medicine_package_image.dart';
import 'package:pharma_assist/models/medicine_record_metadata.dart';
import 'package:pharma_assist/models/medicine_verification_record.dart';
import 'package:pharma_assist/models/product_identifier.dart';
import 'package:pharma_assist/services/medicine_ocr_service.dart';
import 'package:pharma_assist/services/medicine_image_storage_service.dart';
import 'package:pharma_assist/services/medicine_verification_service.dart';
import 'package:pharma_assist/services/export_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/screens/product_identifier_scanner_screen.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';

const _packageImageLabels = <String>[
  'Front of package',
  'Back of package',
  'Left side',
  'Right side',
  'Top',
  'Bottom',
  'Blister strip front',
  'Blister strip back',
  'Bottle label',
  'Bottle cap',
  'Close-up',
  'Package photo',
];

List<ProductIdentifier> _mergeProductIdentifiers(
  List<ProductIdentifier> existing,
  ProductIdentifier? current,
) {
  final result = [...existing];
  if (current != null && !result.any((item) => item.value == current.value)) {
    result.add(current);
  }
  return List.unmodifiable(result);
}

String _identifierFieldLabel(String key) => switch (key) {
  'gtin' => 'GTIN / product identifier',
  'contained_gtin' => 'Contained product GTIN',
  'batch_number' => 'Batch / lot number',
  'manufacturing_date' => 'Manufacturing date',
  'packaging_date' => 'Packaging date',
  'expiry_date' => 'Expiry date',
  'best_before_date' => 'Best-before date',
  'serial_number' => 'Serial number',
  'sscc' => 'SSCC',
  'product_variant' => 'Product variant',
  'count' => 'Count',
  'additional_product_id' => 'Additional product ID',
  'customer_part_number' => 'Customer part number',
  'made_to_order_number' => 'Made-to-order number',
  'secondary_serial' => 'Secondary serial',
  'reference_to_source' => 'Reference to source',
  'customer_purchase_order' => 'Customer purchase order',
  'ship_to_location' => 'Ship-to location',
  'physical_location' => 'Physical location',
  'country_of_origin' => 'Country of origin',
  _ => key.replaceAll('_', ' '),
};

List<MedicineBatchRecord> _saveCurrentBatch(
  List<MedicineBatchRecord> current, {
  required String batchNumber,
  required String manufacturingDate,
  required String expiryDate,
  required String mrp,
  String sourceType = 'manual',
}) {
  if (batchNumber.trim().isEmpty &&
      manufacturingDate.trim().isEmpty &&
      expiryDate.trim().isEmpty &&
      mrp.trim().isEmpty) {
    return List.unmodifiable(current);
  }
  final index = current.indexWhere(
    (batch) =>
        batch.batchNumber.trim().isNotEmpty &&
        batch.batchNumber.trim().toLowerCase() ==
            batchNumber.trim().toLowerCase(),
  );
  final now = DateTime.now();
  final record = MedicineBatchRecord(
    id: index >= 0 ? current[index].id : 'BATCH-${now.microsecondsSinceEpoch}',
    batchNumber: batchNumber.trim(),
    manufacturingDate: manufacturingDate.trim(),
    expiryDate: expiryDate.trim(),
    mrp: mrp.trim(),
    recordedAt: index >= 0 ? current[index].recordedAt : now,
    sourceType: sourceType,
  );
  final updated = [...current];
  if (index >= 0) {
    updated[index] = record;
  } else {
    updated.add(record);
  }
  return List.unmodifiable(updated);
}

List<MedicineFieldAuditEntry> _recordFieldAudit(
  MedicineProfile previous,
  Map<String, String> currentValues,
  List<MedicinePackageImage> images,
  ProductIdentifier? identifier,
) {
  final oldValues = <String, String>{
    MedicineOcrField.medicineName: previous.medicineName,
    MedicineOcrField.manufacturer: previous.manufacturer,
    MedicineOcrField.strength: previous.strength,
    MedicineOcrField.dosageForm: previous.dosageForm,
    MedicineOcrField.genericName: previous.genericName,
    MedicineOcrField.composition: previous.composition,
    MedicineOcrField.batchNumber: previous.batchNumber,
    MedicineOcrField.manufacturingDate: previous.manufacturingDate,
    MedicineOcrField.expiryDate: previous.expiryDate,
    MedicineOcrField.mrp: previous.mrp,
    MedicineOcrField.marketer: previous.marketer,
    MedicineOcrField.manufacturingLicenceNumber:
        previous.manufacturingLicenceNumber,
    MedicineOcrField.packSize: previous.packSize,
  };
  final entries = [...previous.auditHistory];
  final knownIds = entries.map((entry) => entry.id).toSet();
  final now = DateTime.now();
  for (final image in images) {
    for (final observation in image.extractedFields.entries) {
      final saved = currentValues[observation.key] ?? '';
      final id = 'ocr:${image.id}:${observation.key}:$saved';
      if (!knownIds.add(id)) continue;
      entries.add(
        MedicineFieldAuditEntry(
          id: id,
          fieldKey: observation.key,
          originalValue: observation.value,
          savedValue: saved,
          previousValue: oldValues[observation.key],
          sourceType: 'ocr',
          sourceId: image.id,
          confidence: null,
          userCorrected: observation.value.trim() != saved.trim(),
          userReviewed: true,
          changedAt: now,
        ),
      );
    }
  }
  for (final entry in currentValues.entries) {
    final before = oldValues[entry.key] ?? '';
    if (before.trim() == entry.value.trim()) continue;
    final id = 'manual:${entry.key}:${entry.value.trim()}:$before';
    if (!knownIds.add(id)) continue;
    entries.add(
      MedicineFieldAuditEntry(
        id: id,
        fieldKey: entry.key,
        originalValue: before,
        savedValue: entry.value.trim(),
        previousValue: before,
        sourceType: 'manual',
        userCorrected: true,
        userReviewed: true,
        changedAt: now,
      ),
    );
  }
  if (identifier != null) {
    final sourceId =
        '${identifier.format}:${identifier.capturedAt.toIso8601String()}';
    for (final entry in identifier.parsedFields.entries) {
      if (entry.key.endsWith('_check_digit_valid')) continue;
      final id = 'code:$sourceId:${entry.key}:${entry.value}';
      if (!knownIds.add(id)) continue;
      entries.add(
        MedicineFieldAuditEntry(
          id: id,
          fieldKey: entry.key,
          originalValue: entry.value,
          savedValue: entry.value,
          sourceType: 'qr_barcode',
          sourceId: sourceId,
          confidence: null,
          userCorrected: identifier.correctedFields.contains(entry.key),
          userReviewed: true,
          changedAt: now,
        ),
      );
    }
  }
  return List.unmodifiable(entries);
}

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
  final Set<String> _verifyingProfileIds = {};

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
    } else if (_selectedFilter == 'VERIFICATION_HISTORY') {
      list = list.where((p) => p.verificationHistory.isNotEmpty).toList();
    }

    if (query.isNotEmpty) {
      list = list.where((p) {
        return p.medicineName.toLowerCase().contains(query) ||
            p.manufacturer.toLowerCase().contains(query) ||
            p.batchNumber.toLowerCase().contains(query) ||
            p.productIdentifier.toLowerCase().contains(query) ||
            p.strength.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredProfiles = list;
    });
  }

  Future<({MedicinePackageImage image, OcrExtractionResult extraction})?>
  _pickPackageImage(ImageSource source, String label) async {
    final selected = await _picker.pickImage(source: source);
    if (selected == null) return null;

    String? preservedPath;
    try {
      preservedPath = await MedicineImageStorageService.preserveOriginal(
        selected.path,
      );
      final extraction = await MedicineOcrService.recognizeImage(preservedPath);
      final image = extraction.toPackageImage(
        path: preservedPath,
        label: label,
      );
      if (image == null) throw StateError('The selected image is invalid.');
      return (image: image, extraction: extraction);
    } catch (_) {
      if (preservedPath != null) {
        await MedicineImageStorageService.deleteIfAppOwned(preservedPath);
      }
      rethrow;
    }
  }

  Future<void> _captureOrPickPackaging(ImageSource source) async {
    if (_isProcessingOcr) return;
    setState(() => _isProcessingOcr = true);
    try {
      final label = source == ImageSource.camera
          ? 'Front of package'
          : 'Package photo';
      final picked = await _pickPackageImage(source, label);
      if (picked == null) return;

      final ocrResult = picked.extraction;
      final profile = ocrResult
          .toProfile(
            imagePath: picked.image.path,
            notes:
                'Captured via ${source == ImageSource.camera ? 'Camera' : 'Gallery'} for packaging inspection.',
          )
          .copyWith(packagingImages: [picked.image]);

      if (mounted) {
        setState(() => _isProcessingOcr = false);
        if (ocrResult.rawText.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No text was readable in this photo. The original image is kept so you can enter details manually or add another package view.',
              ),
            ),
          );
        }
        await _showEditProfileModal(context, profile, isNew: true);
      }
    } catch (e) {
      if (mounted) {
        final message = e is StateError
            ? e.message.toString()
            : 'The packaging image could not be read. Check camera or photo access, then try another clear image.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted && _isProcessingOcr) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  Future<void> _showEditProfileModal(
    BuildContext context,
    MedicineProfile profile, {
    bool isNew = false,
  }) async {
    final nameCtrl = TextEditingController(text: profile.medicineName);
    final mfgCtrl = TextEditingController(text: profile.manufacturer);
    final strengthCtrl = TextEditingController(text: profile.strength);
    final dosageCtrl = TextEditingController(text: profile.dosageForm);
    final genericNameCtrl = TextEditingController(text: profile.genericName);
    final compositionCtrl = TextEditingController(text: profile.composition);
    final marketerCtrl = TextEditingController(text: profile.marketer);
    final licenceCtrl = TextEditingController(
      text: profile.manufacturingLicenceNumber,
    );
    final packSizeCtrl = TextEditingController(text: profile.packSize);
    final mrpCtrl = TextEditingController(text: profile.mrp);
    final batchCtrl = TextEditingController(text: profile.batchNumber);
    final mfgDateCtrl = TextEditingController(text: profile.manufacturingDate);
    final expDateCtrl = TextEditingController(text: profile.expiryDate);
    final notesCtrl = TextEditingController(text: profile.notes ?? '');
    final existingIdentifiers = profile.allProductIdentifiers.toList();
    final identifierCtrl = TextEditingController(
      text: profile.productIdentifier.isNotEmpty
          ? profile.productIdentifier
          : (existingIdentifiers.isEmpty ? '' : existingIdentifiers.last.value),
    );
    String identifierFormat = profile.productIdentifierFormat.isNotEmpty
        ? profile.productIdentifierFormat
        : (existingIdentifiers.isEmpty ? '' : existingIdentifiers.last.format);
    DateTime? identifierScannedAt =
        profile.productIdentifierScannedAt ??
        (existingIdentifiers.isEmpty
            ? null
            : existingIdentifiers.last.capturedAt);
    Map<String, String> identifierFields = existingIdentifiers.isEmpty
        ? {}
        : Map<String, String>.from(existingIdentifiers.last.parsedFields);
    String? scannedIdentifierValue = existingIdentifiers.isEmpty
        ? null
        : existingIdentifiers.last.value;
    final batchRecords = profile.allBatches.toList();
    bool isVerified = profile.isVerifiedByUser;
    final packageImages = profile.packageImageRecords.toList();
    final managedPhotoPaths = packageImages.map((image) => image.path).toSet();
    bool isAddingPackageImage = false;

    Future<void> chooseMonth(TextEditingController controller) async {
      final now = DateTime.now();
      final current = MedicineProfile.parseDateValue(controller.text);
      final picked = await showDatePicker(
        context: context,
        initialDate: current ?? now,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
        helpText: 'Choose a month and year',
      );
      if (picked != null) {
        controller.text = DateFormat('MM/yyyy').format(picked);
      }
    }

    await showModalBottomSheet<void>(
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
            void showImageMessage(String message) {
              ScaffoldMessenger.of(modalContext)
                  .showSnackBar(SnackBar(content: Text(message)));
            }

            Future<ImageSource?> chooseImageSource() =>
                showModalBottomSheet<ImageSource>(
                  context: modalContext,
                  builder: (sourceContext) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt_outlined),
                          title: const Text('Take a photo'),
                          onTap: () =>
                              Navigator.pop(sourceContext, ImageSource.camera),
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: const Text('Choose from gallery'),
                          onTap: () =>
                              Navigator.pop(sourceContext, ImageSource.gallery),
                        ),
                      ],
                    ),
                  ),
                );

            Map<String, TextEditingController> editableFields() => {
              MedicineOcrField.medicineName: nameCtrl,
              MedicineOcrField.manufacturer: mfgCtrl,
              MedicineOcrField.strength: strengthCtrl,
              MedicineOcrField.dosageForm: dosageCtrl,
              MedicineOcrField.genericName: genericNameCtrl,
              MedicineOcrField.composition: compositionCtrl,
              MedicineOcrField.batchNumber: batchCtrl,
              MedicineOcrField.manufacturingDate: mfgDateCtrl,
              MedicineOcrField.expiryDate: expDateCtrl,
              MedicineOcrField.mrp: mrpCtrl,
              MedicineOcrField.marketer: marketerCtrl,
              MedicineOcrField.manufacturingLicenceNumber: licenceCtrl,
              MedicineOcrField.packSize: packSizeCtrl,
            };

            void applyOnlyMissingOcrFields(MedicinePackageImage image) {
              final controllers = editableFields();
              for (final entry in image.extractedFields.entries) {
                final controller = controllers[entry.key];
                if (controller != null && controller.text.trim().isEmpty) {
                  controller.text = entry.value;
                }
              }
            }

            Future<void> addPackageImage(ImageSource source) async {
              if (packageImages.length >= 12) {
                showImageMessage(
                  'A medicine record can include up to 12 package photos.',
                );
                return;
              }
              setModalState(() => isAddingPackageImage = true);
              try {
                final result = await _pickPackageImage(
                  source,
                  'Package view ${packageImages.length + 1}',
                );
                if (result == null || !modalContext.mounted) return;
                managedPhotoPaths.add(result.image.path);
                setModalState(() => packageImages.add(result.image));
                applyOnlyMissingOcrFields(result.image);
                if (result.image.rawOcrText.trim().isEmpty) {
                  showImageMessage(
                    'No text was readable in this photo. The original image is retained for manual review.',
                  );
                }
              } catch (_) {
                if (modalContext.mounted) {
                  showImageMessage(
                    'The photo could not be saved or read. Choose a clear image smaller than 15 MB and try again.',
                  );
                }
              } finally {
                if (modalContext.mounted) {
                  setModalState(() => isAddingPackageImage = false);
                }
              }
            }

            Future<void> replacePackageImage(
              int index,
              ImageSource source,
            ) async {
              final oldImage = packageImages[index];
              setModalState(() => isAddingPackageImage = true);
              try {
                final result = await _pickPackageImage(source, oldImage.label);
                if (result == null || !modalContext.mounted) return;
                managedPhotoPaths.add(result.image.path);
                final replacement = result.image.copyWith(id: oldImage.id);
                setModalState(() => packageImages[index] = replacement);
                applyOnlyMissingOcrFields(replacement);
              } catch (_) {
                if (modalContext.mounted) {
                  showImageMessage('Could not replace this package photo.');
                }
              } finally {
                if (modalContext.mounted) {
                  setModalState(() => isAddingPackageImage = false);
                }
              }
            }

            Future<void> removePackageImage(int index) async {
              final remove = await showDialog<bool>(
                context: modalContext,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Remove package photo?'),
                  content: const Text(
                    'This removes the selected photo from this medicine record after you save your changes.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (remove == true && modalContext.mounted) {
                setModalState(() => packageImages.removeAt(index));
              }
            }

            final conflictingFields = MedicineOcrService.findConflictingFields(
              packageImages,
            ).entries.toList();

            Future<void> scanProductIdentifier() async {
              final result = await Navigator.of(modalContext)
                  .push<ProductIdentifier>(
                    MaterialPageRoute(
                      builder: (_) => const ProductIdentifierScannerScreen(),
                    ),
                  );
              if (result == null || !modalContext.mounted) return;
              if (existingIdentifiers.any(
                (item) => item.value == result.value,
              )) {
                showImageMessage(
                  'This code is already saved in the medicine record.',
                );
                return;
              }
              setModalState(() {
                identifierCtrl.text = result.value;
                identifierFormat = result.format;
                identifierScannedAt = result.capturedAt;
                identifierFields = result.parsedFields;
                scannedIdentifierValue = result.value;
              });
            }

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
                        Expanded(
                          child: Text(
                            isNew
                                ? 'New Medicine Profile'
                                : 'Edit Medicine Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Package photos (${packageImages.length}/12)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Add package photo',
                          onPressed: isAddingPackageImage
                              ? null
                              : () async {
                                  final source = await chooseImageSource();
                                  if (source != null && modalContext.mounted) {
                                    await addPackageImage(source);
                                  }
                                },
                          icon: const Icon(Icons.add_a_photo_outlined),
                        ),
                      ],
                    ),
                    if (packageImages.isEmpty)
                      Text(
                        'No package photos attached. Add front, back, label, or close-up views as needed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      )
                    else
                      SizedBox(
                        height: 192,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: packageImages.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final image = packageImages[index];
                            final file = File(image.path);
                            final label =
                                _packageImageLabels.contains(image.label)
                                ? image.label
                                : 'Package photo';
                            return SizedBox(
                              width: 174,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      height: 86,
                                      child: file.existsSync()
                                          ? Image.file(
                                              file,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.broken_image_outlined,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              key: ValueKey(
                                                'package-image-label-${image.id}',
                                              ),
                                              initialValue: label,
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      vertical: 6,
                                                    ),
                                              ),
                                              items: _packageImageLabels
                                                  .map(
                                                    (value) => DropdownMenuItem(
                                                      value: value,
                                                      child: Text(
                                                        value,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (value) {
                                                if (value != null) {
                                                  setModalState(() {
                                                    packageImages[index] = image
                                                        .copyWith(label: value);
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            tooltip: 'Manage ${image.label}',
                                            onSelected: (action) async {
                                              if (action == 'remove') {
                                                await removePackageImage(index);
                                              } else if (action == 'replace') {
                                                final source =
                                                    await chooseImageSource();
                                                if (source != null &&
                                                    modalContext.mounted) {
                                                  await replacePackageImage(
                                                    index,
                                                    source,
                                                  );
                                                }
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'replace',
                                                child: Text('Replace photo'),
                                              ),
                                              PopupMenuItem(
                                                value: 'remove',
                                                child: Text('Remove photo'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        0,
                                        8,
                                        6,
                                      ),
                                      child: Text(
                                        'Added ${DateFormat.yMMMd().add_jm().format(image.capturedAt.toLocal())}',
                                        style: theme.textTheme.labelSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (isAddingPackageImage) const LinearProgressIndicator(),
                    if (conflictingFields.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.suspiciousAmberBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tokens.suspiciousAmber),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Values differ across package photos',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'OCR observations are not verified. Compare these values with the physical package and review the editable fields before saving.',
                              style: theme.textTheme.bodySmall,
                            ),
                            for (final conflict in conflictingFields) ...[
                              const SizedBox(height: 8),
                              Text(
                                MedicineOcrField.labels[conflict.key] ??
                                    conflict.key,
                                style: theme.textTheme.labelLarge,
                              ),
                              for (final observation in conflict.value)
                                Text(
                                  '• ${observation.imageLabel}: ${observation.value}',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    if (profile.auditHistory.isNotEmpty)
                      ExpansionTile(
                        key: const ValueKey('medicine-field-audit-history'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'Field review history (${profile.auditHistory.length})',
                        ),
                        children: [
                          for (final entry in profile.auditHistory.reversed)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${MedicineOcrField.labels[entry.fieldKey] ?? entry.fieldKey}: ${entry.savedValue.isEmpty ? 'Cleared' : entry.savedValue}',
                              ),
                              subtitle: Text(
                                '${entry.sourceType.toUpperCase()} · ${DateFormat.yMMMd().add_jm().format(entry.changedAt.toLocal())}${entry.sourceId == null ? '' : ' · image ${entry.sourceId}'}${entry.confidence == null ? '' : ' · source confidence ${entry.confidence}'}',
                              ),
                            ),
                        ],
                      ),

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
                              'Extracted field coverage: ${profile.confidence}. This is not an authenticity score. Confirm every value against the physical packaging.',
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

                    for (final image in packageImages)
                      if (image.rawOcrText.trim().isNotEmpty)
                        ExpansionTile(
                          key: ValueKey('ocr-evidence-${image.id}'),
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 12),
                          title: Text('OCR text · ${image.label}'),
                          subtitle: const Text(
                            'Unverified text recognized from this photo.',
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tokens.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                image.rawOcrText,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),

                    // Form fields
                    TextField(
                      key: const ValueKey('medicine-name-field'),
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Medicine Name',
                        hintText: 'e.g. Amoxicillin Trihydrate',
                        prefixIcon: Icon(Icons.medication_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('medicine-strength-field'),
                            controller: strengthCtrl,
                            decoration: InputDecoration(
                              labelText: 'Strength',
                              hintText: 'e.g. 500 mg',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('medicine-dosage-form-field'),
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
                      key: const ValueKey('medicine-manufacturer-field'),
                      controller: mfgCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer / Brand',
                        hintText: 'e.g. Standard Pharma Labs Ltd.',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      key: const ValueKey('medicine-batch-field'),
                      controller: batchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Batch / Lot Number',
                        hintText: 'e.g. B-90421',
                        prefixIcon: Icon(Icons.qr_code_outlined),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          final manufacturing = mfgDateCtrl.text.trim();
                          final expiry = expDateCtrl.text.trim();
                          if ((manufacturing.isNotEmpty &&
                                  MedicineProfile.parseDateValue(
                                        manufacturing,
                                      ) ==
                                      null) ||
                              (expiry.isNotEmpty &&
                                  MedicineProfile.parseDateValue(
                                        expiry,
                                        expiryDate: true,
                                      ) ==
                                      null)) {
                            showImageMessage(
                              'Review the current batch dates before adding another batch.',
                            );
                            return;
                          }
                          final savedBatches = _saveCurrentBatch(
                            batchRecords,
                            batchNumber: batchCtrl.text,
                            manufacturingDate: mfgDateCtrl.text,
                            expiryDate: expDateCtrl.text,
                            mrp: mrpCtrl.text,
                          );
                          setModalState(() {
                            batchRecords
                              ..clear()
                              ..addAll(savedBatches);
                            batchCtrl.clear();
                            mfgDateCtrl.clear();
                            expDateCtrl.clear();
                            mrpCtrl.clear();
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add another batch'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('medicine-identifier-field'),
                      controller: identifierCtrl,
                      maxLength: 2048,
                      decoration: InputDecoration(
                        labelText: 'QR / barcode value',
                        helperText: 'Product identification only. No official product verification source is configured.',
                        prefixIcon: const Icon(Icons.qr_code_2_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Scan QR or barcode',
                          onPressed: scanProductIdentifier,
                          icon: const Icon(Icons.document_scanner_outlined),
                        ),
                      ),
                    ),
                    if (identifierFormat.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Captured as $identifierFormat${identifierScannedAt == null ? '' : ' on ${DateFormat.yMMMd().format(identifierScannedAt!)}'}. Review the value before saving.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                    if (existingIdentifiers.isNotEmpty)
                      ExpansionTile(
                        key: const ValueKey('medicine-identifier-history'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'Saved QR / barcode scans (${existingIdentifiers.length})',
                        ),
                        children: [
                          for (final code in existingIdentifiers)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(code.format),
                              subtitle: SelectableText(code.value),
                            ),
                        ],
                      ),
                    if (profile.verificationHistory.isNotEmpty)
                      ExpansionTile(
                        key: const ValueKey('medicine-verification-history'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'Public-source check history (${profile.verificationHistory.length})',
                        ),
                        subtitle: const Text(
                          'Historical alert-list checks; not proof of authenticity.',
                        ),
                        children: [
                          for (final report in profile.verificationHistory) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(report.statusLabel),
                              subtitle: Text(
                                '${DateFormat.yMMMd().add_jm().format(report.checkedAt.toLocal())}\n${report.warning}',
                              ),
                            ),
                            for (final source in report.sources)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(source.title),
                                subtitle: SelectableText(source.url),
                              ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey(
                              'medicine-manufacturing-date-field',
                            ),
                            controller: mfgDateCtrl,
                            decoration: InputDecoration(
                              labelText: 'Manufacturing Date',
                              hintText: 'MM/yyyy',
                              suffixIcon: IconButton(
                                tooltip: 'Choose manufacturing month',
                                icon: const Icon(
                                  Icons.calendar_month,
                                  size: 18,
                                ),
                                onPressed: () => chooseMonth(mfgDateCtrl),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('medicine-expiry-date-field'),
                            controller: expDateCtrl,
                            decoration: InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'MM/yyyy',
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.calendar_month,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  await chooseMonth(expDateCtrl);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A month/year expiry is treated as valid through the final day of that month. Unclear dates remain unknown.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    if (batchRecords.isNotEmpty)
                      ExpansionTile(
                        key: const ValueKey('medicine-batch-history'),
                        tilePadding: EdgeInsets.zero,
                        title: Text('Saved batches (${batchRecords.length})'),
                        subtitle: const Text(
                          'Batch and expiry details remain separate for this medicine.',
                        ),
                        children: [
                          for (final batch in batchRecords)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                batch.batchNumber.isEmpty
                                    ? 'Batch number not recorded'
                                    : 'Batch ${batch.batchNumber}',
                              ),
                              subtitle: Text(
                                'Mfg: ${batch.manufacturingDate.isEmpty ? 'Unknown' : batch.manufacturingDate} · Exp: ${batch.expiryDate.isEmpty ? 'Unknown' : batch.expiryDate} · MRP: ${batch.mrp.isEmpty ? 'Unknown' : batch.mrp}',
                              ),
                            ),
                        ],
                      ),
                    if (identifierFields.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recognized code details',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              for (final entry in identifierFields.entries)
                                if (!entry.key.endsWith('_check_digit_valid'))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      '${_identifierFieldLabel(entry.key)}: ${entry.value}',
                                    ),
                                  ),
                              if (identifierFields['gtin_check_digit_valid'] ==
                                  'false')
                                Text(
                                  'GTIN check digit mismatch; review the decoded value.',
                                  style: TextStyle(
                                    color: tokens.suspiciousAmber,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Extracted data is not verified product information.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),

                    TextField(
                      key: const ValueKey('medicine-mrp-field'),
                      controller: mrpCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Printed MRP (optional)',
                        hintText: 'Enter the value printed on the package',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    ExpansionTile(
                      key: const ValueKey('medicine-additional-fields'),
                      tilePadding: EdgeInsets.zero,
                      title: const Text('More printed package details'),
                      subtitle: const Text(
                        'Optional fields; review each value against the label.',
                      ),
                      children: [
                        TextField(
                          key: const ValueKey('medicine-generic-name-field'),
                          controller: genericNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Generic name',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('medicine-composition-field'),
                          controller: compositionCtrl,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Composition as printed',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('medicine-marketer-field'),
                          controller: marketerCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Marketed by',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('medicine-licence-field'),
                          controller: licenceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Manufacturing licence number',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('medicine-pack-size-field'),
                          controller: packSizeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Pack size',
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
                        final manufacturingDate = mfgDateCtrl.text.trim();
                        final expiryDate = expDateCtrl.text.trim();
                        final manufacturing = manufacturingDate.isEmpty
                            ? null
                            : MedicineProfile.parseDateValue(manufacturingDate);
                        final expiry = expiryDate.isEmpty
                            ? null
                            : MedicineProfile.parseDateValue(
                                expiryDate,
                                expiryDate: true,
                              );
                        if ((manufacturingDate.isNotEmpty &&
                                manufacturing == null) ||
                            (expiryDate.isNotEmpty && expiry == null)) {
                          ScaffoldMessenger.of(modalContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enter a valid date such as MM/YYYY or DD/MM/YYYY. Ambiguous or incomplete dates are not saved as confirmed dates.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (manufacturing != null &&
                            expiry != null &&
                            manufacturing.isAfter(expiry)) {
                          ScaffoldMessenger.of(modalContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Manufacturing date must not be later than expiry date.',
                              ),
                            ),
                          );
                          return;
                        }
                        final identifierText = identifierCtrl.text.trim();
                        final isSameScannedPayload =
                            scannedIdentifierValue == identifierText;
                        final productIdentifier = identifierText.isEmpty
                            ? null
                            : ProductIdentifier.tryCreate(
                                identifierText,
                                format:
                                    !isSameScannedPayload ||
                                        identifierFormat.isEmpty
                                    ? 'manual'
                                    : identifierFormat,
                                capturedAt: identifierScannedAt,
                                parsedFields: isSameScannedPayload
                                    ? identifierFields
                                    : null,
                              );
                        if (identifierText.isNotEmpty &&
                            productIdentifier == null) {
                          ScaffoldMessenger.of(modalContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enter a valid product code of 2,048 characters or fewer.',
                              ),
                            ),
                          );
                          return;
                        }
                        final activeBatchNumber = batchCtrl.text.trim();
                        final savedBatches = _saveCurrentBatch(
                          batchRecords,
                          batchNumber: activeBatchNumber,
                          manufacturingDate: manufacturingDate,
                          expiryDate: expiryDate,
                          mrp: mrpCtrl.text,
                          sourceType:
                              isSameScannedPayload &&
                                  identifierFields['batch_number'] ==
                                      activeBatchNumber
                              ? 'qr_barcode'
                              : 'manual',
                        );
                        final activeBatch = savedBatches.isEmpty
                            ? null
                            : activeBatchNumber.isEmpty
                            ? savedBatches.last
                            : savedBatches.firstWhere(
                                (batch) =>
                                    batch.batchNumber.toLowerCase() ==
                                    activeBatchNumber.toLowerCase(),
                                orElse: () => savedBatches.last,
                              );
                        final savedBatchNumber = activeBatchNumber.isEmpty
                            ? (activeBatch?.batchNumber ?? '')
                            : activeBatchNumber;
                        final savedManufacturingDate = manufacturingDate.isEmpty
                            ? (activeBatch?.manufacturingDate ?? '')
                            : manufacturingDate;
                        final savedExpiryDate = expiryDate.isEmpty
                            ? (activeBatch?.expiryDate ?? '')
                            : expiryDate;
                        final savedMrp = mrpCtrl.text.trim().isEmpty
                            ? (activeBatch?.mrp ?? '')
                            : mrpCtrl.text.trim();
                        final fieldValues = <String, String>{
                          MedicineOcrField.medicineName: nameCtrl.text.trim(),
                          MedicineOcrField.manufacturer: mfgCtrl.text.trim(),
                          MedicineOcrField.strength: strengthCtrl.text.trim(),
                          MedicineOcrField.dosageForm: dosageCtrl.text.trim(),
                          MedicineOcrField.genericName: genericNameCtrl.text
                              .trim(),
                          MedicineOcrField.composition: compositionCtrl.text
                              .trim(),
                          MedicineOcrField.batchNumber: savedBatchNumber,
                          MedicineOcrField.manufacturingDate:
                              savedManufacturingDate,
                          MedicineOcrField.expiryDate: savedExpiryDate,
                          MedicineOcrField.mrp: savedMrp,
                          MedicineOcrField.marketer: marketerCtrl.text.trim(),
                          MedicineOcrField.manufacturingLicenceNumber:
                              licenceCtrl.text.trim(),
                          MedicineOcrField.packSize: packSizeCtrl.text.trim(),
                        };
                        final updated = profile.copyWith(
                          medicineName: nameCtrl.text.trim(),
                          manufacturer: mfgCtrl.text.trim(),
                          strength: strengthCtrl.text.trim(),
                          dosageForm: dosageCtrl.text.trim(),
                          genericName: genericNameCtrl.text.trim(),
                          composition: compositionCtrl.text.trim(),
                          marketer: marketerCtrl.text.trim(),
                          manufacturingLicenceNumber: licenceCtrl.text.trim(),
                          packSize: packSizeCtrl.text.trim(),
                          batchNumber: savedBatchNumber,
                          manufacturingDate: savedManufacturingDate,
                          expiryDate: savedExpiryDate,
                          mrp: savedMrp,
                          rawOcrText: packageImages
                              .where((image) => image.rawOcrText.isNotEmpty)
                              .map(
                                (image) =>
                                    '--- ${image.label} ---\n${image.rawOcrText}',
                              )
                              .join('\n\n'),
                          packagingImagePath: packageImages.isEmpty
                              ? null
                              : packageImages.first.path,
                          clearPackagingImagePath: packageImages.isEmpty,
                          packagingImages: List.unmodifiable(packageImages),
                          notes: notesCtrl.text.trim(),
                          isVerifiedByUser: isVerified,
                          productIdentifier: productIdentifier?.value ?? '',
                          productIdentifierFormat:
                              productIdentifier?.format ?? '',
                          productIdentifierScannedAt:
                              productIdentifier?.capturedAt,
                          clearProductIdentifierScannedAt:
                              productIdentifier == null,
                          productIdentifiers: _mergeProductIdentifiers(
                            existingIdentifiers,
                            productIdentifier,
                          ),
                          batches: savedBatches,
                          auditHistory: _recordFieldAudit(
                            profile,
                            fieldValues,
                            packageImages,
                            productIdentifier,
                          ),
                        );

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        final saved = await widget.storage.saveMedicineProfile(
                          updated,
                        );
                        if (!mounted || !modalContext.mounted) return;
                        if (!saved) {
                          ScaffoldMessenger.of(modalContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not save this medicine profile. Please try again.',
                              ),
                            ),
                          );
                          return;
                        }
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

    final matchingProfiles = widget.storage.getMedicineProfiles().where(
      (stored) => stored.id == profile.id,
    );
    final savedProfile = matchingProfiles.isEmpty
        ? null
        : matchingProfiles.first;
    final savedPaths =
        savedProfile?.packageImageRecords.map((image) => image.path).toSet() ??
        const <String>{};
    for (final path in managedPhotoPaths.difference(savedPaths)) {
      await MedicineImageStorageService.deleteIfAppOwned(path);
    }
  }

  Future<void> _verifySavedProfile(MedicineProfile profile) async {
    if (profile.batchNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add and review the package batch number before checking alerts.',
          ),
        ),
      );
      return;
    }
    if (_verifyingProfileIds.contains(profile.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check public medicine alerts?'),
        content: Text(
          'Send the saved medicine name, manufacturer, batch, dates, strength, and product code to your configured backend. It will check the public CDSCO spurious-drug alert list. Package photos are not sent. A missing match cannot verify the medicine.\n\n${profile.medicineName.isEmpty ? 'Medicine name not recorded' : profile.medicineName} · Batch ${profile.batchNumber}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _verifyingProfileIds.add(profile.id));
    MedicineVerificationRecord report;
    try {
      report = await MedicineVerificationService(widget.storage)
          .checkOfficialAlerts(profile);
    } catch (_) {
      report = MedicineVerificationRecord(
        status: 'unable_to_verify',
        statusLabel: 'Unable to verify',
        checkedAt: DateTime.now(),
        sources: const [
          MedicineVerificationSource(
            title: 'CDSCO Alerts (not queried)',
            url: 'https://www.cdsco.gov.in/opencms/opencms/en/Alerts/',
          ),
        ],
        warning: 'The configured backend or official source was unavailable. No product conclusion was produced.',
        disclaimer: 'This preliminary source check cannot establish the identity, composition, dosage, safety, or authenticity of the physical medicine.',
      );
    }

    final storedProfiles = widget.storage.getMedicineProfiles().where(
      (item) => item.id == profile.id,
    );
    var historySaved = false;
    if (storedProfiles.isNotEmpty) {
      final current = storedProfiles.first;
      historySaved = await widget.storage.saveMedicineProfile(
        current.copyWith(
          verificationHistory: [report, ...current.verificationHistory],
        ),
      );
    }
    if (mounted) {
      loadProfiles();
      if (!historySaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The result could not be saved to medicine history.'),
          ),
        );
      }
      await _showVerificationReport(report, historySaved: historySaved);
      if (mounted) setState(() => _verifyingProfileIds.remove(profile.id));
    }
  }

  Future<void> _exportProfile(MedicineProfile profile) async {
    final result = await ExportService.exportMedicineProfilePdf(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success ? 'Medicine PDF saved: ${result.filePath}' : 'Medicine PDF could not be created. Check available storage and try again.',
        ),
      ),
    );
  }

  Future<void> _showVerificationReport(
    MedicineVerificationRecord report, {
    required bool historySaved,
  }) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(report.statusLabel),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(report.warning),
              if (report.explanation?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                const Text('AI explanation of the cited evidence'),
                const SizedBox(height: 4),
                Text(report.explanation!),
                const SizedBox(height: 4),
                const Text(
                  'Ollama only explains source evidence; it does not decide or change this status.',
                ),
              ],
              if (report.evidenceMatches.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Matched fields: ${report.evidenceMatches.join(', ')}'),
              ],
              const SizedBox(height: 12),
              Text(
                'Checked ${DateFormat.yMMMd().add_jm().format(report.checkedAt.toLocal())}',
              ),
              if (report.sources.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Sources'),
                for (final source in report.sources) ...[
                  const SizedBox(height: 8),
                  Text(
                    source.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SelectableText(source.url),
                  if (source.publishedAt != null)
                    Text('Published: ${source.publishedAt}'),
                  if (source.retrievedAt != null)
                    Text(
                      'Retrieved: ${DateFormat.yMMMd().add_jm().format(source.retrievedAt!.toLocal())}',
                    ),
                  if (source.excerpt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SelectableText(source.excerpt),
                  ],
                ],
              ],
              const SizedBox(height: 12),
              Text(report.disclaimer),
              if (historySaved)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('This check is saved in medicine history.'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );

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
              final deleted = await widget.storage.deleteMedicineProfile(
                profile.id,
              );
              if (deleted) {
                for (final image in profile.packageImageRecords) {
                  await MedicineImageStorageService.deleteIfAppOwned(
                    image.path,
                  );
                }
              }
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
        child: PharmaContentFrame(
          maxWidth: 1100,
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
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('Scan Packaging'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: theme.colorScheme.primary,
                            ),
                            onPressed: _isProcessingOcr
                                ? null
                                : () => _captureOrPickPackaging(
                                    ImageSource.camera,
                                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
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
                    const SizedBox(width: 6),
                    _filterChip(
                      'VERIFICATION_HISTORY',
                      'Checked (${_allProfiles.where((p) => p.verificationHistory.isNotEmpty).length})',
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
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final profile = _filteredProfiles[i];
                          return _buildProfileCard(profile, tokens, theme);
                        },
                      ),
              ),
            ],
          ),
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
    final expiryStatus = profile.expiryStatus();
    final badgeColor = switch (expiryStatus) {
      MedicineExpiryStatus.expired => tokens.counterfeitRed,
      MedicineExpiryStatus.expiringSoon => tokens.suspiciousAmber,
      MedicineExpiryStatus.valid ||
      MedicineExpiryStatus.unknown => tokens.textMuted,
    };
    final badgeBg = switch (expiryStatus) {
      MedicineExpiryStatus.expired => tokens.counterfeitRedBg,
      MedicineExpiryStatus.expiringSoon => tokens.suspiciousAmberBg,
      MedicineExpiryStatus.valid ||
      MedicineExpiryStatus.unknown => tokens.surfaceSubtle,
    };
    final badgeText = switch (expiryStatus) {
      MedicineExpiryStatus.expired => 'Expired · ${profile.expiryDate}',
      MedicineExpiryStatus.expiringSoon =>
        'Expires in ${days ?? 0} days · ${profile.expiryDate}',
      MedicineExpiryStatus.valid => 'Not expired · ${profile.expiryDate}',
      MedicineExpiryStatus.unknown =>
        profile.expiryDate.trim().isEmpty
            ? 'Expiry date not recorded'
            : 'Expiry date unclear · ${profile.expiryDate}',
    };

    return Material(
      color: AppTheme.elevatedCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
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
          child: _verifyingProfileIds.contains(profile.id)
              ? Padding(
                  padding: const EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Icon(
                  Icons.medication_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                profile.medicineName.trim().isEmpty
                    ? 'Medicine name not recorded'
                    : profile.medicineName,
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
              '${profile.manufacturer.isNotEmpty ? profile.manufacturer : "Unknown Manufacturer"} ΓÇó Batch: ${profile.batchNumber.isNotEmpty ? profile.batchNumber : "N/A"}',
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
            } else if (val == 'official_alerts') {
              _verifySavedProfile(profile);
            } else if (val == 'export_pdf') {
              _exportProfile(profile);
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
              value: 'official_alerts',
              child: Row(
                children: [
                  Icon(Icons.policy_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Check official alerts'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export_pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Export medicine PDF'),
                ],
              ),
            ),
            PopupMenuItem(
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
