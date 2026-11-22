import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _content = [
    (
      Icons.health_and_safety_outlined,
      'A careful first look at medicine packaging',
      'PharmaAssist provides a preliminary visual screening to help flag cases that may need a closer review.',
    ),
    (
      Icons.center_focus_strong_outlined,
      'Capture a clear image',
      'Use the camera or choose a photo. Good lighting, a steady hand, and a fully visible medicine help the image quality checks.',
    ),
    (
      Icons.fact_check_outlined,
      'Keep your screening records',
      'Review past screenings and create reports from saved records. A report summarizes the screening; it is not a laboratory certificate.',
    ),
    (
      Icons.wifi_off_outlined,
      'Works offline for record keeping',
      'You can manage local records and reports without a connection. AI screening requires a configured backend; this app does not run a validated model on-device.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _content.length - 1) {
      widget.onComplete();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.biotech_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text('PharmaAssist', style: AppTheme.headingMedium()),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onComplete,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _content.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final item = _content[index];
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 172,
                              height: 172,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.10,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.$1,
                                size: 82,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              item.$2,
                              textAlign: TextAlign.center,
                              style: AppTheme.headingLarge().copyWith(
                                fontSize: 25,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item.$3,
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyText(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                            if (index == _content.length - 1) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.suspiciousBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.warning),
                                ),
                                child: Text(
                                  'Screening is not proof of authenticity, composition, or safety. Do not make treatment or product-disposal decisions from an AI result alone. Ask a pharmacist or health authority to review concerns.',
                                  style: AppTheme.bodyText(fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _content.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? colorScheme.primary
                          : AppTheme.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _index == _content.length - 1
                          ? 'Get started'
                          : 'Continue',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
