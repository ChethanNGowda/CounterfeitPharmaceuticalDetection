import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/widgets/medicine_photo_guide.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';

/// Packaging & Medicine Capture Guide Screen
class PackagingGuideScreen extends StatelessWidget {
  const PackagingGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.pharmaTokens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Packaging & Capture Guide'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          PharmaCard(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            child: Row(
              children: [
                Icon(
                  Icons.camera_enhance_outlined,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Optimal photographic conditions ensure reliable visual preflight checks and accurate AI screening.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const MedicinePhotoGuide(),
          const SizedBox(height: 16),
          const PharmaSectionHeader(
            title: 'Supported Formats',
            subtitle: 'Recommended capture methods for tablets and packaging',
          ),
          PharmaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBullet(
                  context,
                  title: 'Loose Tablets & Capsules',
                  description: 'Place a single tablet centered on a matte, non-reflective background. Ensure debossed imprints or markings face directly upward toward the camera.',
                ),
                Divider(height: 20, color: tokens.borderSubtle),
                _buildBullet(
                  context,
                  title: 'Blister Packs & Foil Strips',
                  description: 'Flatten the blister foil. Avoid extreme ceiling light reflections. Align the printed lot numbers and expiry text clearly in view.',
                ),
                Divider(height: 20, color: tokens.borderSubtle),
                _buildBullet(
                  context,
                  title: 'Cartons & Outer Packaging',
                  description: 'Capture the principal display panel showing the commercial drug name, batch number, and manufacturing details squarely.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBullet(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final tokens = context.pharmaTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted),
          ),
        ),
      ],
    );
  }
}
