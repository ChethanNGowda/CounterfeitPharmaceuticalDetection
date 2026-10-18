import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/models/scan_history_item.dart';

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
    return _prefs?.getDouble(AppConstants.keyThreshold) ?? AppConstants.defaultThreshold;
  }

  Future<bool> setThreshold(double value) async {
    return await _prefs?.setDouble(AppConstants.keyThreshold, value) ?? false;
  }

  String getModelName() {
    return _prefs?.getString(AppConstants.keyModelName) ?? AppConstants.defaultModel;
  }

  Future<bool> setModelName(String model) async {
    return await _prefs?.setString(AppConstants.keyModelName, model) ?? false;
  }

  String getVisionMode() {
    return _prefs?.getString(AppConstants.keyVisionMode) ?? AppConstants.defaultVisionMode;
  }

  Future<bool> setVisionMode(String mode) async {
    return await _prefs?.setString(AppConstants.keyVisionMode, mode) ?? false;
  }

  bool getEnableQwen() {
    return _prefs?.getBool(AppConstants.keyEnableQwen) ?? AppConstants.defaultEnableQwen;
  }

  Future<bool> setEnableQwen(bool enable) async {
    return await _prefs?.setBool(AppConstants.keyEnableQwen, enable) ?? false;
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
    final trimmed = current.take(AppConstants.maxHistoryRecords).map((e) => e.toJson()).toList();
    await _prefs?.setString(AppConstants.keyScanHistory, jsonEncode(trimmed));
  }

  Future<bool> deleteScanHistoryItem(String id) async {
    final List<ScanHistoryItem> current = getScanHistory();
    final int initialLength = current.length;
    current.removeWhere((e) => e.id == id);

    if (current.length != initialLength) {
      final serialized = current.map((e) => e.toJson()).toList();
      return await _prefs?.setString(AppConstants.keyScanHistory, jsonEncode(serialized)) ?? false;
    }
    return false;
  }

  Future<void> clearScanHistory() async {
    await _prefs?.remove(AppConstants.keyScanHistory);
  }

  // ── Appearance / Theme Preferences ────────────────────────────────────────
  String getThemeMode() {
    return _prefs?.getString(AppConstants.keyThemeMode) ?? AppConstants.defaultThemeMode;
  }

  Future<bool> setThemeMode(String mode) async {
    return await _prefs?.setString(AppConstants.keyThemeMode, mode) ?? false;
  }

  // ── Bookmarked / Pinned Favorites ─────────────────────────────────────────
  Set<String> getFavoriteIds() {
    final List<String>? list = _prefs?.getStringList(AppConstants.keyFavoriteIds);
    return list != null ? list.toSet() : <String>{};
  }

  Future<bool> toggleFavorite(String scanId) async {
    final Set<String> current = getFavoriteIds();
    if (current.contains(scanId)) {
      current.remove(scanId);
    } else {
      current.add(scanId);
    }
    return await _prefs?.setStringList(AppConstants.keyFavoriteIds, current.toList()) ?? false;
  }

  bool isFavorite(String scanId) {
    return getFavoriteIds().contains(scanId);
  }
}
