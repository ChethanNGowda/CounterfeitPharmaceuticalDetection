/// Represents an interactive packaging checklist inspection session
class PackagingChecklistItem {
  final String id;
  final String title;
  final String description;
  final String criteria;
  String status; // 'PASS', 'CONCERN', 'TAMPERED', 'UNCHECKED'
  String notes;

  PackagingChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.criteria,
    this.status = 'UNCHECKED',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'criteria': criteria,
    'status': status,
    'notes': notes,
  };

  factory PackagingChecklistItem.fromJson(Map<String, dynamic> json) {
    const allowedStatuses = {'PASS', 'CONCERN', 'TAMPERED', 'UNCHECKED'};
    final savedStatus = json['status']?.toString().toUpperCase();
    return PackagingChecklistItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      criteria: json['criteria']?.toString() ?? '',
      status: allowedStatuses.contains(savedStatus)
          ? savedStatus!
          : 'UNCHECKED',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class PackagingChecklistSummary {
  final String id;
  final String sampleId;
  final String medicineName;
  final String? imagePath;
  final List<PackagingChecklistItem> items;
  final String overallNotes;
  final DateTime inspectedAt;

  PackagingChecklistSummary({
    required this.id,
    required this.sampleId,
    required this.medicineName,
    this.imagePath,
    required this.items,
    this.overallNotes = '',
    required this.inspectedAt,
  });

  int get passCount => items.where((i) => i.status == 'PASS').length;
  int get concernCount => items.where((i) => i.status == 'CONCERN').length;
  int get tamperedCount => items.where((i) => i.status == 'TAMPERED').length;
  int get checkedCount => items.where((i) => i.status != 'UNCHECKED').length;
  bool get isComplete => items.isNotEmpty && checkedCount == items.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sample_id': sampleId,
    'medicine_name': medicineName,
    'image_path': imagePath,
    'items': items.map((i) => i.toJson()).toList(),
    'overall_notes': overallNotes,
    'inspected_at': inspectedAt.toIso8601String(),
  };

  factory PackagingChecklistSummary.fromJson(Map<String, dynamic> json) {
    final parsedItems = <PackagingChecklistItem>[];
    final savedItems = json['items'];
    if (savedItems is List) {
      for (final item in savedItems) {
        if (item is! Map || item.keys.any((key) => key is! String)) continue;
        try {
          parsedItems.add(
            PackagingChecklistItem.fromJson(Map<String, dynamic>.from(item)),
          );
        } on Exception {
          // Keep readable inspection items if one saved item is malformed.
        }
      }
    }
    return PackagingChecklistSummary(
      id:
          json['id'] as String? ??
          'CHK-${DateTime.now().millisecondsSinceEpoch}',
      sampleId: json['sample_id']?.toString() ?? '',
      medicineName: json['medicine_name']?.toString() ?? '',
      imagePath: json['image_path'] as String?,
      items: parsedItems,
      overallNotes: json['overall_notes'] as String? ?? '',
      inspectedAt: json['inspected_at'] != null
          ? DateTime.tryParse(json['inspected_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static List<PackagingChecklistItem> createDefaultItems() {
    return [
      PackagingChecklistItem(
        id: 'seal',
        title: 'Packaging Seal & Tamper Evidence',
        description: 'Blister foil seal, box adhesive, cap band or shrink wrap',
        criteria: 'Record visible seal breaks, resealing marks, punctures, or differences from an available official reference. Packaging appearance alone cannot establish product status.',
      ),
      PackagingChecklistItem(
        id: 'print',
        title: 'Printing Quality & Typography',
        description:
            'Text clarity, spelling, font consistency, and ink bleeding',
        criteria: 'Note blurred or misaligned printing, spelling differences, label placement, and variation from a reliable manufacturer reference when available.',
      ),
      PackagingChecklistItem(
        id: 'batch',
        title: 'Batch Number Legibility',
        description: 'Embossed or laser-printed batch / lot identification',
        criteria: 'Record whether the batch marking is present and legible, and note alterations or differences across package views. Do not infer a missing value.',
      ),
      PackagingChecklistItem(
        id: 'dates',
        title: 'Manufacturing & Expiry Dates',
        description:
            'Printed dates on both outer carton and inner primary blister',
        criteria: 'Compare printed batch and dates across carton, label, and inner packaging; record each observed value and any discrepancy for review.',
      ),
      PackagingChecklistItem(
        id: 'manufacturer',
        title: 'Manufacturer Details & License',
        description:
            'Registered manufacturer name, production address, license numbers',
        criteria: 'Record the manufacturer and address text visible on the package. Verify details only against an authoritative source where available.',
      ),
      PackagingChecklistItem(
        id: 'security',
        title: 'Holograms & Security Features',
        description:
            'Optically variable devices, iridescent labels, QR/2D barcodes',
        criteria: 'Record the security feature and any visible damage. Compare it only with manufacturer or regulatory guidance for this product; a QR code or hologram alone is not proof.',
      ),
      PackagingChecklistItem(
        id: 'integrity',
        title: 'Physical Container Integrity',
        description:
            'Crushed corners, punctures, watermarks, or chemical odors',
        criteria: 'Record visible crushing, punctures, moisture marks, discoloration, or blister damage. Do not infer contents, safety, or authenticity from appearance.',
      ),
    ];
  }
}
