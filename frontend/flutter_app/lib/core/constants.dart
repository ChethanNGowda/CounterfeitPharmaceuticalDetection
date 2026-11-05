class AppConstants {
  static const String appName = 'PharmaAssist';
  static const String appTitle = 'Pharmaceutical Screening Instrument';
  static const String appSubtitle = 'Field-Screening & Quality Triage System';
  static const String appVersion = '1.2.0';

  // Override for a build or configure at runtime in Settings. The default is
  // loopback so a developer's private LAN address is never shipped.
  static const String defaultDevUrl = String.fromEnvironment(
    'PHARMA_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const String defaultEmulatorUrl = 'http://10.0.2.2:8000';
  static const String defaultLocalhostUrl = 'http://127.0.0.1:8000';

  // Storage keys
  static const String keyBackendUrl = 'pharma_backend_url';
  static const String keyThreshold = 'pharma_threshold';
  static const String keyModelName = 'pharma_model_name';
  static const String keyVisionMode = 'pharma_vision_mode';
  static const String keyEnableQwen = 'pharma_enable_qwen';
  static const String keyOperatingMode = 'pharma_operating_mode';
  static const String keyScanHistory = 'pharma_scan_history_v1';
  static const String keySyncQueue = 'pharma_sync_queue_v1';
  static const String keySyncConsent = 'pharma_sync_consent_v1';
  static const String keyThemeMode = 'pharma_theme_mode';
  static const String keyFavoriteIds = 'pharma_favorite_ids';

  // Defaults
  static const double defaultThreshold = 0.70;
  static const String defaultModel = 'efficientnet_b0';
  static const String defaultVisionMode = 'auto'; // 'auto', 'always', 'never'
  static const bool defaultEnableQwen = true;
  static const String defaultOperatingMode = 'hybrid';
  static const String defaultThemeMode = 'dark'; // 'dark' or 'light'

  static const String operatingModeOffline = 'offline';
  static const String operatingModeAutomatic = 'automatic';
  static const String operatingModeBackend = 'backend';

  static const String visionModeAutoLabel =
      'Automatic - review borderline results';
  static const String visionModeAlwaysLabel =
      'Every scan - request an AI review';
  static const String visionModeNeverLabel = 'Off - use the main model only';

  // Max upload size in bytes (15 MB)
  static const int maxFileSizeBytes = 15 * 1024 * 1024;
  static const int maxHistoryRecords = 50;
  static const int maxSyncAttempts = 5;
  static const int maxSyncRetrySeconds = 3600;

  static const String providerBackend = 'backend';
  static const String providerLocal = 'local';
  static const String providerUnavailable = 'unavailable';

  static const String syncStatusLocal = 'local';
  static const String syncStatusPending = 'pending';
  static const String syncStatusSynced = 'synced';
  static const String syncStatusFailed = 'failed';
  static const String syncStatusBlocked = 'blocked';
  static const String syncStatusSyncing = 'syncing';
  static const String syncStatusConflict = 'conflict';

  // Global Disclaimers
  static const String persistentDisclaimer =
      'AI-assisted preliminary screening only. Visual inspection cannot prove chemical '
      'purity, active pharmaceutical ingredients (API), or bioequivalence. '
      'Do not take or discard medicine based solely on this app. Always consult a qualified '
      'pharmacist or official regulatory authority.';

  static const String legalNotice =
      'This application provides non-diagnostic visual and convolutional pattern screening. '
      'Definitive authentication requires certified chemical and spectrometry laboratory testing.';
}
