import 'package:flutter/material.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/screens/history_screen.dart';
import 'package:pharma_assist/screens/home_screen.dart';
import 'package:pharma_assist/screens/scan_screen.dart';
import 'package:pharma_assist/screens/settings_screen.dart';
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
    setState(() {
      _themeMode = _parseThemeMode(mode);
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
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();

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
        onNavigateToSettings: () => _onTabTapped(3),
      ),
      ScanScreen(
        storage: widget.storage,
        apiService: widget.apiService,
        onScanComplete: () {
          _homeKey.currentState?.refreshData();
          _historyKey.currentState?.loadHistory();
        },
      ),
      HistoryScreen(key: _historyKey, storage: widget.storage),
      SettingsScreen(
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
      _historyKey.currentState?.loadHistory();
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner_outlined),
            activeIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_outlined),
            activeIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
