import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/screens/home_screen.dart';
import 'package:pharma_assist/screens/onboarding_screen.dart';
import 'package:pharma_assist/screens/medicine_screen.dart';
import 'package:pharma_assist/screens/more_hub_screen.dart';
import 'package:pharma_assist/screens/records_screen.dart';
import 'package:pharma_assist/screens/reports_screen.dart';
import 'package:pharma_assist/screens/scan_screen.dart';
import 'package:pharma_assist/screens/settings_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/app_update_service.dart';
import 'package:pharma_assist/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.getInstance();
  final apiService = ApiService(storage);

  runApp(PharmaAssistApp(storage: storage, apiService: apiService));
}

class PharmaAssistApp extends StatefulWidget {
  final StorageService storage;
  final ApiService apiService;

  const PharmaAssistApp({
    super.key,
    required this.storage,
    required this.apiService,
  });

  @override
  State<PharmaAssistApp> createState() => _PharmaAssistAppState();
}

class _PharmaAssistAppState extends State<PharmaAssistApp>
    with WidgetsBindingObserver {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = _parseThemeMode(widget.storage.getThemeMode());
    _updatePalette();
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      setState(_updatePalette);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updatePalette() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppTheme.setPalette(
      _themeMode == ThemeMode.light ||
          (_themeMode == ThemeMode.system && brightness == Brightness.light),
    );
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  void _onThemeChanged(String mode) {
    final nextMode = _parseThemeMode(mode);
    setState(() {
      _themeMode = nextMode;
      _updatePalette();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: widget.storage.isOnboardingComplete()
          ? MainNavigationScaffold(
              storage: widget.storage,
              apiService: widget.apiService,
              onThemeChanged: _onThemeChanged,
            )
          : OnboardingScreen(
              onComplete: () async {
                await widget.storage.setOnboardingComplete();
                if (!mounted) return;
                setState(() {});
              },
            ),
    );
  }
}

class MainNavigationScaffold extends StatefulWidget {
  final StorageService storage;
  final ApiService apiService;
  final Function(String mode)? onThemeChanged;

  const MainNavigationScaffold({
    super.key,
    required this.storage,
    required this.apiService,
    this.onThemeChanged,
  });

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<ScanScreenState> _scanKey = GlobalKey<ScanScreenState>();
  final GlobalKey<MedicineScreenState> _medicineKey =
      GlobalKey<MedicineScreenState>();
  final GlobalKey<RecordsScreenState> _recordsKey =
      GlobalKey<RecordsScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    if (kReleaseMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForStartupUpdate();
      });
    }
    _screens = [
      HomeScreen(
        key: _homeKey,
        storage: widget.storage,
        apiService: widget.apiService,
        onNavigateToScan: () => _onTabTapped(1),
        onChooseGallery: _chooseGalleryFromHome,
        onNavigateToSettings: () => _onTabTapped(4),
        onNavigateToReports: _openReports,
      ),
      ScanScreen(
        key: _scanKey,
        storage: widget.storage,
        apiService: widget.apiService,
        onScanComplete: () {
          _homeKey.currentState?.refreshData();
          _medicineKey.currentState?.loadProfiles();
          _recordsKey.currentState?.loadRecords();
        },
      ),
      MedicineScreen(key: _medicineKey, storage: widget.storage),
      RecordsScreen(key: _recordsKey, storage: widget.storage),
      MoreHubScreen(
        storage: widget.storage,
        apiService: widget.apiService,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];
  }

  Future<void> _checkForStartupUpdate() async {
    try {
      final update = await AppUpdateService().checkForUpdate();
      if (!mounted || !update.updateAvailable) return;
      final release = update.release!;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('PharmaAssist update available'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${release.title} · v${release.version}'),
                const SizedBox(height: 10),
                Text(
                  release.notes,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      storage: widget.storage,
                      apiService: widget.apiService,
                      onThemeChanged: widget.onThemeChanged,
                    ),
                  ),
                );
              },
              child: const Text('View update'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Offline or unpublished releases must never block app startup.
    }
  }

  void _onTabTapped(int index) {
    if (index == 0) {
      _homeKey.currentState?.refreshData();
    } else if (index == 2) {
      _medicineKey.currentState?.loadProfiles();
    } else if (index == 3) {
      _recordsKey.currentState?.loadRecords();
    }
    setState(() => _currentIndex = index);
  }

  void _chooseGalleryFromHome() {
    _onTabTapped(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanKey.currentState?.chooseFromGallery();
    });
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportsScreen(storage: widget.storage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) _onTabTapped(0);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wideLayout = constraints.maxWidth >= 840;
          return Scaffold(
            body: Row(
              children: [
                if (wideLayout) _buildNavigationRail(),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: _screens),
                ),
              ],
            ),
            bottomNavigationBar: wideLayout ? null : _buildBottomNav(),
          );
        },
      ),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onTabTapped,
      labelType: NavigationRailLabelType.all,
      minWidth: 80,
      groupAlignment: -0.85,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Tooltip(
          message: AppConstants.appName,
          child: Icon(
            Icons.biotech_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.document_scanner_outlined),
          selectedIcon: Icon(Icons.document_scanner),
          label: Text('Scan'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.medication_outlined),
          selectedIcon: Icon(Icons.medication),
          label: Text('Medicine'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: Text('Records'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: Text('More'),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onTabTapped,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      indicatorColor: Theme.of(context).colorScheme.primary
          .withValues(alpha: 0.14),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.document_scanner_outlined),
          selectedIcon: Icon(Icons.document_scanner),
          label: 'Scan',
        ),
        NavigationDestination(
          icon: Icon(Icons.medication_outlined),
          selectedIcon: Icon(Icons.medication),
          label: 'Medicine',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: 'Records',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'More',
        ),
      ],
    );
  }
}
