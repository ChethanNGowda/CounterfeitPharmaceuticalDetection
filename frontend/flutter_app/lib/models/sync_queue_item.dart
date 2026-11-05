class SyncQueueItem {
  final String recordId;
  final DateTime queuedAt;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime? nextRetryAt;
  final String? lastFailureReason;
  final String status;

  const SyncQueueItem({
    required this.recordId,
    required this.queuedAt,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.nextRetryAt,
    this.lastFailureReason,
    this.status = 'pending',
  });

  factory SyncQueueItem.pending(String recordId, {DateTime? queuedAt}) {
    return SyncQueueItem(
      recordId: recordId,
      queuedAt: queuedAt ?? DateTime.now(),
      status: 'pending',
    );
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    final recordId = json['record_id']?.toString().trim() ?? '';
    if (recordId.isEmpty) {
      throw const FormatException('Sync queue item has no record ID');
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return SyncQueueItem(
      recordId: recordId,
      queuedAt: parseDate(json['queued_at']) ?? DateTime.now(),
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      lastAttemptAt: parseDate(json['last_attempt_at']),
      nextRetryAt: parseDate(json['next_retry_at']),
      lastFailureReason: json['last_failure_reason']?.toString(),
      status: json['status']?.toString() ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'record_id': recordId,
    'queued_at': queuedAt.toIso8601String(),
    'attempt_count': attemptCount,
    'last_attempt_at': lastAttemptAt?.toIso8601String(),
    'next_retry_at': nextRetryAt?.toIso8601String(),
    'last_failure_reason': lastFailureReason,
    'status': status,
  };

  SyncQueueItem copyWith({
    DateTime? queuedAt,
    int? attemptCount,
    DateTime? lastAttemptAt,
    DateTime? nextRetryAt,
    String? lastFailureReason,
    String? status,
  }) {
    return SyncQueueItem(
      recordId: recordId,
      queuedAt: queuedAt ?? this.queuedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastFailureReason: lastFailureReason ?? this.lastFailureReason,
      status: status ?? this.status,
    );
  }
}
