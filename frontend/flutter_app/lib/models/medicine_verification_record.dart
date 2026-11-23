class MedicineVerificationSource {
  final String title;
  final String url;
  final String? publishedAt;
  final DateTime? retrievedAt;
  final String excerpt;

  const MedicineVerificationSource({
    required this.title,
    required this.url,
    this.publishedAt,
    this.retrievedAt,
    this.excerpt = '',
  });

  factory MedicineVerificationSource.fromJson(Map<String, dynamic> json) =>
      MedicineVerificationSource(
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        publishedAt: json['published_at'] as String?,
        retrievedAt: DateTime.tryParse(json['retrieved_at'] as String? ?? ''),
        excerpt: json['excerpt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'published_at': publishedAt,
    'retrieved_at': retrievedAt?.toIso8601String(),
    'excerpt': excerpt,
  };
}

/// Saved result from a public source check. Its status never means that the
/// physical medicine was authenticated.
class MedicineVerificationRecord {
  final String status;
  final String statusLabel;
  final DateTime checkedAt;
  final String? explanation;
  final List<String> evidenceMatches;
  final List<MedicineVerificationSource> sources;
  final bool ollamaAvailable;
  final String warning;
  final String disclaimer;

  const MedicineVerificationRecord({
    required this.status,
    required this.statusLabel,
    required this.checkedAt,
    required this.sources,
    required this.warning,
    required this.disclaimer,
    this.explanation,
    this.evidenceMatches = const [],
    this.ollamaAvailable = false,
  });

  factory MedicineVerificationRecord.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    final rawMatches = json['evidence_matches'];
    return MedicineVerificationRecord(
      status: json['status'] as String? ?? 'unable_to_verify',
      statusLabel: json['status_label'] as String? ?? 'Unable to verify',
      checkedAt:
          DateTime.tryParse(json['checked_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      explanation: json['explanation'] as String?,
      evidenceMatches: rawMatches is List
          ? rawMatches.map((value) => value.toString()).toList()
          : const [],
      sources: rawSources is List
          ? rawSources
                .whereType<Map>()
                .map(
                  (source) => MedicineVerificationSource.fromJson(
                    source.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList()
          : const [],
      ollamaAvailable: json['ollama_available'] == true,
      warning: json['warning'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'status_label': statusLabel,
    'checked_at': checkedAt.toIso8601String(),
    'explanation': explanation,
    'evidence_matches': evidenceMatches,
    'sources': sources.map((source) => source.toJson()).toList(),
    'ollama_available': ollamaAvailable,
    'warning': warning,
    'disclaimer': disclaimer,
  };
}
