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
    return PackagingChecklistItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      criteria: json['criteria'] as String,
      status: json['status'] as String? ?? 'UNCHECKED',
      notes: json['notes'] as String? ?? '',
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
  bool get isComplete => checkedCount == items.length;

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
    return PackagingChecklistSummary(
      id:
          json['id'] as String? ??
          'CHK-${DateTime.now().millisecondsSinceEpoch}',
      sampleId: json['sample_id'] as String? ?? 'SMP-CHK',
      medicineName: json['medicine_name'] as String? ?? 'Unknown Packaging',
      imagePath: json['image_path'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                PackagingChecklistItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
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
        criteria: 'Check for unbroken foil, consistent heat sealing, absence of re-gluing marks or double seals.',
      ),
      PackagingChecklistItem(
        id: 'print',
        title: 'Printing Quality & Typography',
        description:
            'Text clarity, spelling, font consistency, and ink bleeding',
        criteria: 'Legitimate pharmaceutical packaging has crisp, sharp printing without typos or fuzzy registration.',
      ),
      PackagingChecklistItem(
        id: 'batch',
        title: 'Batch Number Legibility',
        description: 'Embossed or laser-printed batch / lot identification',
        criteria: 'Batch number should be clearly stamped, embossed, or dot-matrix printed, not photocopied.',
      ),
      PackagingChecklistItem(
        id: 'dates',
        title: 'Manufacturing & Expiry Dates',
        description:
            'Printed dates on both outer carton and inner primary blister',
        criteria: 'Expiry dates on blister packs and outer carton must match exactly without signs of overwriting.',
      ),
      PackagingChecklistItem(
        id: 'manufacturer',
        title: 'Manufacturer Details & License',
        description:
            'Registered manufacturer name, production address, license numbers',
        criteria: 'Must include complete manufacturer address and pharmaceutical manufacturing license.',
      ),
      PackagingChecklistItem(
        id: 'security',
        title: 'Holograms & Security Features',
        description:
            'Optically variable devices, iridescent labels, QR/2D barcodes',
        criteria: 'Genuine security holograms show color shifts and depth when tilted; counterfeits are often flat metallic foil.',
      ),
      PackagingChecklistItem(
        id: 'integrity',
        title: 'Physical Container Integrity',
        description:
            'Crushed corners, punctures, watermarks, or chemical odors',
        criteria: 'Packaging must be structurally sound without dampness, discoloration, or foreign particulate contamination.',
      ),
    ];
  }
}
