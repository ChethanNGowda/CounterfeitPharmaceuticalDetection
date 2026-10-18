import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme.dart';

/// A small, dependency-free illustration showing the framing expected by scan.
class MedicinePhotoGuide extends StatelessWidget {
  const MedicinePhotoGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to take a clear photo', style: AppTheme.headingSmall()),
          const SizedBox(height: 4),
          Text(
            'Use one tablet or package on a plain, matte background. Keep the whole item in frame.',
            style: AppTheme.bodyText(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            width: double.infinity,
            child: CustomPaint(
              painter: _PhotoGuidePainter(),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          const _GuideStep(
            number: '1',
            text: 'Place medicine flat; avoid a busy or shiny surface.',
          ),
          const _GuideStep(
            number: '2',
            text: 'Hold the camera above it. Tap the medicine to focus.',
          ),
          const _GuideStep(
            number: '3',
            text: 'Use bright, even light. Keep hands steady and avoid glare.',
          ),
          const _GuideStep(
            number: '4',
            text: 'Include markings and edges. Do not crop, cover, or edit the image.',
          ),
          const SizedBox(height: 6),
          Text(
            'A photo can only support a visual screening. It cannot prove what ingredients are in a medicine.',
            style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String text;

  const _GuideStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.secondaryBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            number,
            style: TextStyle(
              color: AppTheme.primaryCyan,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodyText(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PhotoGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE7E8E3);
    final border = Paint()
      ..color = const Color(0xFF718096)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final pillPaint = Paint()..color = const Color(0xFFF8FAFC);
    final accent = Paint()..color = AppTheme.secondaryTeal;
    final viewfinder = Paint()
      ..color = AppTheme.primaryTeal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final scene = Rect.fromLTWH(
      size.width * .08,
      8,
      size.width * .84,
      size.height - 16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scene, const Radius.circular(12)),
      bg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scene, const Radius.circular(12)),
      border,
    );

    final medicine = Rect.fromCenter(
      center: Offset(size.width * .5, size.height * .54),
      width: size.width * .39,
      height: 31,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(medicine, const Radius.circular(16)),
      pillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(medicine, const Radius.circular(16)),
      border,
    );
    canvas.drawLine(
      Offset(medicine.center.dx, medicine.top + 2),
      Offset(medicine.center.dx, medicine.bottom - 2),
      accent..strokeWidth = 2,
    );

    const frame = 20.0;
    final left = scene.left + 18;
    final right = scene.right - 18;
    final top = scene.top + 14;
    final bottom = scene.bottom - 14;
    for (final x in [left, right]) {
      for (final y in [top, bottom]) {
        final dx = x == left ? frame : -frame;
        final dy = y == top ? frame : -frame;
        canvas.drawLine(Offset(x, y), Offset(x + dx, y), viewfinder);
        canvas.drawLine(Offset(x, y), Offset(x, y + dy), viewfinder);
      }
    }
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'CENTER THE MEDICINE',
        style: TextStyle(
          color: Color(0xFF263746),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height - 23),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
