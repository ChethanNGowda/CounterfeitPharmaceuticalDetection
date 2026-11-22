import 'package:flutter/material.dart';
import 'package:pharma_assist/screens/pharma_license_screen.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/widgets/disclaimer_banner.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(
                Icons.info_outline,
                color: AppTheme.primaryTeal,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Instrument Specifications & Safety',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SafeArea(
        child: PharmaContentFrame(
          maxWidth: 960,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              // Instrument identity block
              _buildIdentityBlock(),
              const SizedBox(height: 16),

              // Prominent Medical Advisory Banner
              const DisclaimerBanner(
                customText: AppConstants.persistentDisclaimer,
              ),
              const SizedBox(height: 16),

              _buildSectionLabel('SYSTEM ARCHITECTURE'),
              const SizedBox(height: 8),
              _buildInfoBlock(
                items: const [
                  _InfoItem(
                    label: 'Primary Convolutional Classifier',
                    body: 'EfficientNet-B0 is the default registered primary classifier. Model availability and screening output depend on the deployed checkpoint. Current dataset audits have not certified leakage-free generalization or reproduced historical benchmark metrics.',
                  ),
                  _InfoItem(
                    label: 'Secondary AI Vision Verifier',
                    body: 'Optional Qwen vision-language advisory review through a locally configured Ollama service. It is secondary evidence only and cannot override the primary decision policy or replace professional review.',
                  ),
                  _InfoItem(
                    label: 'OpenCV Quality & Feature Engine',
                    body:
                        'Deterministic pre-screening: 17 color centroids in RGB/HSV, Laplacian variance blur detection (threshold ≥ 50.0), '
                        'exposure validation (mean 15–245), and minimum 64×64 pixel resolution gate.',
                  ),
                  _InfoItem(
                    label: 'Authentic-Probability Decision Bands',
                    body: 'Below 50% authentic probability indicates counterfeit; 50% through the configured cutoff (70% by default) requires manual review; above the cutoff indicates authentic. Poor image quality or conflicting secondary review still requires manual review.',
                  ),
                ],
              ),

              const SizedBox(height: 20),
              _buildSectionLabel('CLINICAL & SCIENTIFIC LIMITATIONS'),
              const SizedBox(height: 8),
              _buildInfoBlock(
                accentColor: AppTheme.suspiciousAmber,
                items: const [
                  _InfoItem(
                    label: 'No Chemical Certification',
                    body:
                        'A smartphone camera cannot directly determine chemical composition, Active Pharmaceutical Ingredient (API) potency, '
                        'excipient distribution, or microbiological purity.',
                  ),
                  _InfoItem(
                    label: 'Laboratory Chromatography Standard',
                    body:
                        'Definitive authentication requires certified chemical assays such as High-Performance Liquid Chromatography (HPLC), '
                        'Mass Spectrometry (LC-MS), or Raman/FTIR spectroscopy.',
                  ),
                  _InfoItem(
                    label: 'Optical Variation & False Positives',
                    body:
                        'Smartphone lighting, shadows, focus artifacts, packaging reflections, and distribution variations can impact visual predictions. '
                        'All suspicious or inconclusive outcomes must be escalated for physical testing.',
                  ),
                  _InfoItem(
                    label: 'Non-Diagnostic Field Tool',
                    body:
                        'Never take, discard, dispense, or alter medical treatment solely based on this screening result. '
                        'Always consult a certified pharmacist or national health authority.',
                  ),
                ],
              ),

              const SizedBox(height: 20),
              _buildSectionLabel('REGULATORY & LEGAL NOTICE'),
              const SizedBox(height: 8),
              _buildInfoBlock(
                items: const [
                  _InfoItem(
                    label: 'Intended Scope of Use',
                    body: 'Intended for preliminary field supply-chain triage and rapid visual inspection support by authorized personnel.',
                  ),
                  _InfoItem(
                    label: 'No Regulatory Clearance Claimed',
                    body:
                        'This software does not constitute medical advice or FDA/EMA regulatory product clearance. '
                        'No certification of compliance with medical device standards is made.',
                  ),
                ],
              ),

              const SizedBox(height: 20),
              _buildSectionLabel('LICENCES & ATTRIBUTIONS'),
              const SizedBox(height: 8),
              _buildLicenseActions(context),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'PharmaAssist v${AppConstants.appVersion} · Developed by Chethan N. · Apache-2.0',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseActions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.article_outlined, color: AppTheme.primaryTeal),
            title: Text(
              'PharmaAssist Licence',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Apache License 2.0 · Copyright © 2026 Chethan N.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5),
            ),
            trailing: Icon(Icons.chevron_right, color: AppTheme.textMuted),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PharmaLicenseScreen()),
            ),
          ),
          Container(height: 1, color: AppTheme.borderSubtle),
          ListTile(
            leading: Icon(Icons.code_outlined, color: AppTheme.primaryTeal),
            title: Text(
              'Open-source licences',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Licences and acknowledgements for Flutter and bundled dependencies.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5),
            ),
            trailing: Icon(Icons.chevron_right, color: AppTheme.textMuted),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
              applicationLegalese: 'Copyright © 2026 Chethan N.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppTheme.primaryTeal.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              Icons.biotech_outlined,
              color: AppTheme.primaryTeal,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        'v${AppConstants.appVersion}',
                        style: TextStyle(
                          color: AppTheme.primaryTeal,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppConstants.appSubtitle,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock({required List<_InfoItem> items, Color? accentColor}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (i > 0) Container(height: 1, color: AppTheme.borderSubtle),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 34,
                      margin: const EdgeInsets.only(top: 2, right: 10),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.body,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppTheme.textMuted,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String body;

  const _InfoItem({required this.label, required this.body});
}
