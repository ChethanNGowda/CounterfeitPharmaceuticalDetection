import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/models/sync_queue_item.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  /// Resets the singleton. For use in tests only.
  static void resetForTesting() {
    _instance = null;
    _prefs = null;
  }

  // ── Backend URL management ────────────────────────────────────────────────
  String getBackendUrl() {
    final String? stored = _prefs?.getString(AppConstants.keyBackendUrl);
    if (stored != null && stored.trim().isNotEmpty) {
      return normalizeUrl(stored);
    }
    // Default to the physical device development endpoint
    return AppConstants.defaultDevUrl;
  }

  Future<bool> setBackendUrl(String url) async {
    final String clean = normalizeUrl(url);
    return await _prefs?.setString(AppConstants.keyBackendUrl, clean) ?? false;
  }

  static String normalizeUrl(String url) {
    String trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  // ── Detection Parameters ──────────────────────────────────────────────────
  double getThreshold() {
    return _prefs?.getDouble(AppConstants.keyThreshold) ??
        AppConstants.defaultThreshold;
  }

  Future<bool> setThreshold(double value) async {
    return await _prefs?.setDouble(AppConstants.keyThreshold, value) ?? false;
  }

  String getModelName() {
    return _prefs?.getString(AppConstants.keyModelName) ??
        AppConstants.defaultModel;
  }

  Future<bool> setModelName(String model) async {
    return await _prefs?.setString(AppConstants.keyModelName, model) ?? false;
  }

  String getVisionMode() {
    return _prefs?.getString(AppConstants.keyVisionMode) ??
        AppConstants.defaultVisionMode;
  }

  Future<bool> setVisionMode(String mode) async {
    return await _prefs?.setString(AppConstants.keyVisionMode, mode) ?? false;
  }

  bool getEnableQwen() {
    return _prefs?.getBool(AppConstants.keyEnableQwen) ??
        AppConstants.defaultEnableQwen;
  }

  bool getSyncConsent() =>
      _prefs?.getBool(AppConstants.keySyncConsent) ?? false;

  Future<bool> setSyncConsent(bool enabled) async {
    return await _prefs?.setBool(AppConstants.keySyncConsent, enabled) ?? false;
  }

  Future<bool> setEnableQwen(bool enable) async {
    return await _prefs?.setBool(AppConstants.keyEnableQwen, enable) ?? false;
  }

  String getOperatingMode() {
    final mode = _prefs?.getString(AppConstants.keyOperatingMode);
    const validModes = {
      AppConstants.operatingModeOffline,
      AppConstants.operatingModeAutomatic,
      AppConstants.operatingModeBackend,
      'hybrid',
    };
    return mode != null && validModes.contains(mode)
        ? mode
        : AppConstants.defaultOperatingMode;
  }

  Future<bool> setOperatingMode(String mode) async {
    const validModes = {
      AppConstants.operatingModeOffline,
      AppConstants.operatingModeAutomatic,
      AppConstants.operatingModeBackend,
      'hybrid',
    };
    if (!validModes.contains(mode)) return false;
    return await _prefs?.setString(AppConstants.keyOperatingMode, mode) ??
        false;
  }

  // ── Scan History ──────────────────────────────────────────────────────────
  List<ScanHistoryItem> getScanHistory() {
    final String? raw = _prefs?.getString(AppConstants.keyScanHistory);
    if (raw == null || raw.isEmpty) return [];

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final List<ScanHistoryItem> items = [];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            items.add(ScanHistoryItem.fromJson(item));
          } catch (_) {
            // Silently recover from individual malformed records
          }
        }
      }
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> addScanHistoryItem(ScanHistoryItem item) async {
    final List<ScanHistoryItem> current = getScanHistory();
    // Prevent duplicate entries by id
    current.removeWhere((e) => e.id == item.id);
    current.insert(0, item);

    // Keep top maxHistoryRecords (50)
    final trimmed = current
        .take(AppConstants.maxHistoryRecords)
        .map((e) => e.toJson())
        .toList();
    await _prefs?.setString(AppConstants.keyScanHistory, jsonEncode(trimmed));
  }

  List<SyncQueueItem> getSyncQueue() {
    final raw = _prefs?.getString(AppConstants.keySyncQueue);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = <SyncQueueItem>[];
      final ids = <String>{};
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          final item = SyncQueueItem.fromJson(entry);
          if (ids.add(item.recordId)) items.add(item);
        } on FormatException {
          continue;
        }
      }
      items.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveSyncQueue(Iterable<SyncQueueItem> items) async {
    await _prefs?.setString(
      AppConstants.keySyncQueue,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<bool> enqueueSync(String recordId, {DateTime? queuedAt}) async {
    final history = getScanHistory();
    final recordIndex = history.indexWhere((item) => item.id == recordId);
    if (recordIndex < 0) return false;
    final record = history[recordIndex];
    if (record.operatingMode == AppConstants.operatingModeOffline ||
        record.provider == AppConstants.providerUnavailable) {
      return false;
    }
    final queue = getSyncQueue();
    if (queue.any((item) => item.recordId == recordId)) return false;
    queue.add(SyncQueueItem.pending(recordId, queuedAt: queuedAt));
    await _saveSyncQueue(queue);
    await updateScanSyncStatus(recordId, AppConstants.syncStatusPending);
    return true;
  }

  Future<bool> updateSyncQueueItem(SyncQueueItem updated) async {
    final queue = getSyncQueue();
    final index = queue.indexWhere((item) => item.recordId == updated.recordId);
    if (index < 0) return false;
    queue[index] = updated;
    await _saveSyncQueue(queue);
    return true;
  }

  Future<bool> recordSyncAttempt(
    String recordId, {
    required String failureReason,
    DateTime? attemptedAt,
  }) async {
    final queue = getSyncQueue();
    final index = queue.indexWhere((item) => item.recordId == recordId);
    if (index < 0) return false;
    final item = queue[index];
    final now = attemptedAt ?? DateTime.now();
    final attempts = item.attemptCount + 1;
    final delaySeconds = (1 << (attempts - 1)).clamp(
      1,
      AppConstants.maxSyncRetrySeconds,
    );
    final exhausted = attempts >= AppConstants.maxSyncAttempts;
    queue[index] = SyncQueueItem(
      recordId: item.recordId,
      queuedAt: item.queuedAt,
      attemptCount: attempts,
      lastAttemptAt: now,
      nextRetryAt: exhausted ? null : now.add(Duration(seconds: delaySeconds)),
      lastFailureReason: failureReason,
      status: exhausted
          ? AppConstants.syncStatusFailed
          : AppConstants.syncStatusPending,
    );
    await _saveSyncQueue(queue);
    await updateScanSyncStatus(
      recordId,
      exhausted
          ? AppConstants.syncStatusFailed
          : AppConstants.syncStatusPending,
    );
    return true;
  }

  Future<bool> removeSyncQueueItem(String recordId) async {
    final queue = getSyncQueue();
    final filtered = queue.where((item) => item.recordId != recordId).toList();
    if (filtered.length == queue.length) return false;
    await _saveSyncQueue(filtered);
    return true;
  }

  Future<bool> updateScanSyncStatus(String recordId, String status) async {
    final history = getScanHistory();
    final index = history.indexWhere((item) => item.id == recordId);
    if (index < 0) return false;
    history[index] = history[index].copyWith(syncStatus: status);
    final serialized = history
        .take(AppConstants.maxHistoryRecords)
        .map((item) => item.toJson())
        .toList();
    await _prefs?.setString(
      AppConstants.keyScanHistory,
      jsonEncode(serialized),
    );
    return true;
  }

  Future<bool> markSynced(
    String recordId, {
    required String serverRecordId,
    required DateTime synchronizedAt,
  }) async {
    final history = getScanHistory();
    final index = history.indexWhere((item) => item.id == recordId);
    if (index < 0) return false;
    history[index] = history[index].copyWith(
      syncStatus: AppConstants.syncStatusSynced,
      serverRecordId: serverRecordId,
      synchronizedAt: synchronizedAt,
    );
    await _prefs?.setString(
      AppConstants.keyScanHistory,
      jsonEncode(history.map((item) => item.toJson()).toList()),
    );
    await removeSyncQueueItem(recordId);
    return true;
  }

  Future<bool> deleteScanHistoryItem(String id) async {
    final List<ScanHistoryItem> current = getScanHistory();
    final int initialLength = current.length;
    current.removeWhere((e) => e.id == id);

    if (current.length != initialLength) {
      final serialized = current.map((e) => e.toJson()).toList();
      return await _prefs?.setString(
            AppConstants.keyScanHistory,
            jsonEncode(serialized),
          ) ??
          false;
    }
    return false;
  }

  Future<void> clearScanHistory() async {
    await _prefs?.remove(AppConstants.keyScanHistory);
  }

  // ── Appearance / Theme Preferences ────────────────────────────────────────
  String getThemeMode() {
    return _prefs?.getString(AppConstants.keyThemeMode) ??
        AppConstants.defaultThemeMode;
  }

  Future<bool> setThemeMode(String mode) async {
    return await _prefs?.setString(AppConstants.keyThemeMode, mode) ?? false;
  }

  // ── Bookmarked / Pinned Favorites ─────────────────────────────────────────
  Set<String> getFavoriteIds() {
    final List<String>? list = _prefs?.getStringList(
      AppConstants.keyFavoriteIds,
    );
    return list != null ? list.toSet() : <String>{};
  }

  Future<bool> toggleFavorite(String scanId) async {
    final Set<String> current = getFavoriteIds();
    if (current.contains(scanId)) {
      current.remove(scanId);
    } else {
      current.add(scanId);
    }
    return await _prefs?.setStringList(
          AppConstants.keyFavoriteIds,
          current.toList(),
        ) ??
        false;
  }

  bool isFavorite(String scanId) {
    return getFavoriteIds().contains(scanId);
  }
}
