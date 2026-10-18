import 'package:flutter/material.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/widgets/disclaimer_banner.dart';

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
            const Text('Instrument Specifications & Safety'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                  body:
                      'Fine-tuned EfficientNet-B0 trained on 10,551 deduplicated pharmaceutical tablet images. '
                      'Test accuracy 99.88%, macro F1 99.82%, ROC-AUC 0.9988. Evaluated on a clean, leakage-controlled test split.',
                ),
                _InfoItem(
                  label: 'Secondary AI Vision Verifier',
                  body:
                      'Qwen Vision (4B parameters) vision-language model running via local Ollama. '
                      'Inspects physical tablet shape, color consistency, surface texture, and packaging integrity.',
                ),
                _InfoItem(
                  label: 'OpenCV Quality & Feature Engine',
                  body:
                      'Deterministic pre-screening: 17 color centroids in RGB/HSV, Laplacian variance blur detection (threshold ≥ 50.0), '
                      'exposure validation (mean 15–245), and minimum 64×64 pixel resolution gate.',
                ),
                _InfoItem(
                  label: 'Conservative Decision Engine',
                  body:
                      'Deterministic multi-tier synthesis. Automatically enforces mandatory physical laboratory verification '
                      'if primary confidence < 0.70, models disagree, or secondary verifier is uncertain.',
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

            const SizedBox(height: 24),
            Center(
              child: Text(
                'PharmaAssist v${AppConstants.appVersion} · Build 2026.10',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          ],
        ),
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
                Row(
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        'v1.2.0',
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
