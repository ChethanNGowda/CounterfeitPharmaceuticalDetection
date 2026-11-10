import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/screens/about_screen.dart';
import 'package:pharma_assist/screens/model_lab_screen.dart';
import 'package:pharma_assist/screens/settings_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';

/// "More" Section Screen providing organized hub for secondary healthcare utilities
class MoreHubScreen extends StatelessWidget {
  final StorageService storage;
  final ApiService apiService;
  final Function(String mode)? onThemeChanged;

  const MoreHubScreen({
    super.key,
    required this.storage,
    required this.apiService,
    this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.pharmaTokens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilities & Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          PharmaCard(
            padding: const EdgeInsets.all(16),
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.health_and_safety_outlined,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PharmaAssist Core',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AI-Assisted Visual Drug Screening Platform',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const PharmaSectionHeader(
            title: 'System & Diagnostics',
            subtitle:
                'AI verification status, model lab, and system configuration',
          ),
          PharmaCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.science_outlined,
                  title: 'AI Diagnostics & Model Lab',
                  subtitle: 'Inspect local Qwen Vision & ML classifier configurations',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModelLabScreen(
                          storage: storage,
                          apiService: apiService,
                        ),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: tokens.borderSubtle),
                _buildTile(
                  context,
                  icon: Icons.tune_outlined,
                  title: 'Settings & Cloud Sync',
                  subtitle:
                      'Operating mode, backend URLs, themes & sync tokens',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          storage: storage,
                          apiService: apiService,
                          onThemeChanged: onThemeChanged,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const PharmaSectionHeader(
            title: 'Compliance & Safety',
            subtitle: 'Medical safety notices and regulatory disclaimers',
          ),
          PharmaCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'About PharmaAssist',
                  subtitle:
                      'Architecture, safety boundaries & versioning details',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'PharmaAssist v1.2.0 • Hybrid Sync Edition',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final tokens = context.pharmaTokens;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted),
      ),
      trailing: Icon(Icons.chevron_right, color: tokens.textMuted, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }
}
