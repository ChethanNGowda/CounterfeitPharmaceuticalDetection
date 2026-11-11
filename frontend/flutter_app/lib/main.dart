import 'package:flutter/material.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/screens/home_screen.dart';
import 'package:pharma_assist/screens/medicine_screen.dart';
import 'package:pharma_assist/screens/more_hub_screen.dart';
import 'package:pharma_assist/screens/records_screen.dart';
import 'package:pharma_assist/screens/scan_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
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

class _PharmaAssistAppState extends State<PharmaAssistApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = _parseThemeMode(widget.storage.getThemeMode());
    AppTheme.setPalette(_themeMode == ThemeMode.light);
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  void _onThemeChanged(String mode) {
    final nextMode = _parseThemeMode(mode);
    AppTheme.setPalette(nextMode == ThemeMode.light);
    setState(() {
      _themeMode = nextMode;
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
      home: MainNavigationScaffold(
        storage: widget.storage,
        apiService: widget.apiService,
        onThemeChanged: _onThemeChanged,
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
    _screens = [
      HomeScreen(
        key: _homeKey,
        storage: widget.storage,
        apiService: widget.apiService,
        onNavigateToScan: () => _onTabTapped(1),
        onChooseGallery: _chooseGalleryFromHome,
        onNavigateToSettings: () => _onTabTapped(4),
        onNavigateToReports: () => _onTabTapped(3),
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

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) _onTabTapped(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onTabTapped,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
