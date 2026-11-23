/// Decoded QR/barcode data and any conservative GS1 interpretation.
///
/// Raw payload is retained unchanged. Parsed values remain unverified package
/// data and are never followed as URLs or treated as authentication evidence.
class ProductIdentifier {
  final String value;
  final String format;
  final DateTime capturedAt;
  final Map<String, String> parsedFields;
  final Set<String> correctedFields;
  final String unparsedData;

  const ProductIdentifier({
    required this.value,
    required this.format,
    required this.capturedAt,
    this.parsedFields = const {},
    this.correctedFields = const {},
    this.unparsedData = '',
  });

  ProductIdentifier copyWith({
    Map<String, String>? parsedFields,
    Set<String>? correctedFields,
  }) => ProductIdentifier(
    value: value,
    format: format,
    capturedAt: capturedAt,
    parsedFields: parsedFields ?? this.parsedFields,
    correctedFields: correctedFields ?? this.correctedFields,
    unparsedData: unparsedData,
  );

  static ProductIdentifier? tryCreate(
    String value, {
    String format = 'manual',
    DateTime? capturedAt,
    Map<String, String>? parsedFields,
    Set<String>? correctedFields,
    String? unparsedData,
  }) {
    final normalized = format == 'manual' ? value.trim() : value;
    if (normalized.trim().isEmpty ||
        normalized.length > 2048 ||
        normalized.runes.any(
          (rune) => rune < 0x20 && rune != 0x1d || rune == 0x7f,
        )) {
      return null;
    }
    final parsed = parsedFields == null
        ? parseGs1(normalized)
        : (
            fields: Map<String, String>.unmodifiable(parsedFields),
            unparsed: unparsedData ?? '',
          );
    return ProductIdentifier(
      value: normalized,
      format: format.trim().isEmpty ? 'unknown' : format.trim(),
      capturedAt: capturedAt ?? DateTime.now(),
      parsedFields: parsed.fields,
      correctedFields: correctedFields ?? const {},
      unparsedData: unparsedData ?? parsed.unparsed,
    );
  }

  /// Parses GS1 parenthesized element strings and separator-delimited data.
  /// Variable-length AIs are read only to FNC1/GS or end-of-input; raw input
  /// is always retained when a code is partial or contains unknown elements.
  static ({Map<String, String> fields, String unparsed}) parseGs1(String raw) {
    var input = raw.trim();
    if (input.startsWith(']') && input.length >= 3) input = input.substring(3);
    final fields = <String, String>{};
    final unknown = <String>[];
    if (input.contains('(')) {
      final matches = RegExp(r'\((\d{2,4})\)([^()]*)').allMatches(input);
      for (final match in matches) {
        final ai = match.group(1)!;
        final value = (match.group(2) ?? '').replaceAll('\u001d', '').trim();
        _storeAi(fields, unknown, ai, value);
      }
      final residue = input.replaceAll(RegExp(r'\(\d{2,4}\)[^()]*'), '');
      if (residue.trim().isNotEmpty) unknown.add(residue.trim());
      return (fields: Map.unmodifiable(fields), unparsed: unknown.join(' '));
    }

    var index = 0;
    var sawGs1 = false;
    while (index < input.length) {
      if (input.codeUnitAt(index) == 0x1d) {
        index++;
        continue;
      }
      final ai = _matchAi(input, index);
      if (ai == null) {
        unknown.add(input.substring(index));
        break;
      }
      sawGs1 = true;
      final valueStart = index + ai.length;
      final fixedLength = _fixedLengths[ai];
      int valueEnd;
      if (fixedLength != null) {
        valueEnd = valueStart + fixedLength;
        if (valueEnd > input.length ||
            input.substring(valueStart, valueEnd).contains('\u001d')) {
          unknown.add(input.substring(index));
          break;
        }
      } else {
        valueEnd = input.indexOf('\u001d', valueStart);
        if (valueEnd < 0) valueEnd = input.length;
      }
      final value = input.substring(valueStart, valueEnd);
      if (!_storeAi(fields, unknown, ai, value)) {
        unknown.add(input.substring(index));
        break;
      }
      index = valueEnd;
    }
    if (!sawGs1 && unknown.isEmpty) unknown.add(raw);
    return (fields: Map.unmodifiable(fields), unparsed: unknown.join(' '));
  }

  static const _fixedLengths = <String, int>{
    '00': 18,
    '01': 14,
    '02': 14,
    '11': 6,
    '13': 6,
    '15': 6,
    '17': 6,
    '20': 2,
    '410': 13,
    '414': 13,
    '422': 3,
    '30': -1,
    '37': -1,
  };

  static String? _matchAi(String value, int index) {
    for (final ai in [
      '00',
      '01',
      '02',
      '10',
      '11',
      '13',
      '15',
      '17',
      '20',
      '21',
      '30',
      '37',
      '240',
      '241',
      '242',
      '250',
      '251',
      '400',
      '410',
      '414',
      '422',
    ]) {
      if (value.startsWith(ai, index)) return ai;
    }
    return null;
  }

  static bool _storeAi(
    Map<String, String> fields,
    List<String> unknown,
    String ai,
    String value,
  ) {
    final key = switch (ai) {
      '00' => 'sscc',
      '01' => 'gtin',
      '02' => 'contained_gtin',
      '10' => 'batch_number',
      '11' => 'manufacturing_date',
      '13' => 'packaging_date',
      '15' => 'best_before_date',
      '17' => 'expiry_date',
      '20' => 'product_variant',
      '21' => 'serial_number',
      '30' || '37' => 'count',
      '240' => 'additional_product_id',
      '241' => 'customer_part_number',
      '242' => 'made_to_order_number',
      '250' => 'secondary_serial',
      '251' => 'reference_to_source',
      '400' => 'customer_purchase_order',
      '410' => 'ship_to_location',
      '414' => 'physical_location',
      '422' => 'country_of_origin',
      _ => null,
    };
    if (key == null || value.isEmpty) {
      unknown.add('($ai)$value');
      return key != null;
    }
    final expectedLength = _fixedLengths[ai];
    if (expectedLength != null &&
        expectedLength > 0 &&
        value.length != expectedLength) {
      unknown.add('($ai)$value');
      return false;
    }
    if (ai == '01' || ai == '02') {
      fields['${key}_check_digit_valid'] = _hasValidGs1CheckDigit(value)
          .toString();
    }
    if (ai == '11' || ai == '13' || ai == '15' || ai == '17') {
      final parsedDate = _parseGs1Date(
        value,
        allowLastDay: ai == '15' || ai == '17',
      );
      if (parsedDate == null) {
        unknown.add('($ai)$value');
        return false;
      }
      fields[key] = _formatDate(parsedDate);
    } else {
      fields[key] = value;
    }
    return true;
  }

  static DateTime? _parseGs1Date(String value, {required bool allowLastDay}) {
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return null;
    final year = 2000 + int.parse(value.substring(0, 2));
    final month = int.parse(value.substring(2, 4));
    final day = int.parse(value.substring(4, 6));
    if (month < 1 || month > 12) return null;
    final actualDay = day == 0 && allowLastDay
        ? DateTime(year, month + 1, 0).day
        : day;
    final date = DateTime(year, month, actualDay);
    if (day == 0 && !allowLastDay ||
        date.year != year ||
        date.month != month ||
        date.day != actualDay) {
      return null;
    }
    return date;
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static bool _hasValidGs1CheckDigit(String value) {
    if (!RegExp(r'^\d{14}$').hasMatch(value)) return false;
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      sum += int.parse(value[i]) * (i.isEven ? 3 : 1);
    }
    return (10 - (sum % 10)) % 10 == int.parse(value[13]);
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'format': format,
    'captured_at': capturedAt.toIso8601String(),
    'parsed_fields': parsedFields,
    'corrected_fields': correctedFields.toList(),
    'unparsed_data': unparsedData,
  };

  factory ProductIdentifier.fromJson(Map<String, dynamic> json) {
    final rawFields = json['parsed_fields'];
    return ProductIdentifier(
      value: json['value']?.toString() ?? '',
      format: json['format']?.toString() ?? 'unknown',
      capturedAt:
          DateTime.tryParse(json['captured_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      parsedFields: rawFields is Map
          ? rawFields.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : parseGs1(json['value']?.toString() ?? '').fields,
      correctedFields: json['corrected_fields'] is List
          ? (json['corrected_fields'] as List)
                .map((value) => value.toString())
                .toSet()
          : const {},
      unparsedData:
          json['unparsed_data']?.toString() ??
          parseGs1(json['value']?.toString() ?? '').unparsed,
    );
  }
}
