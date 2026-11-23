/// Decoded QR/barcode text kept as user-reviewed package data.
///
/// Payloads are never followed as URLs or treated as authentication evidence.
class ProductIdentifier {
  final String value;
  final String format;
  final DateTime capturedAt;

  const ProductIdentifier({
    required this.value,
    required this.format,
    required this.capturedAt,
  });

  static ProductIdentifier? tryCreate(
    String value, {
    String format = 'manual',
    DateTime? capturedAt,
  }) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.length > 2048 ||
        normalized.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
      return null;
    }
    return ProductIdentifier(
      value: normalized,
      format: format.trim().isEmpty ? 'unknown' : format.trim(),
      capturedAt: capturedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'format': format,
    'captured_at': capturedAt.toIso8601String(),
  };
}
