// lib/ui/widgets/heart_rate_wave.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class HeartRateWave extends StatelessWidget {
  final List<double> buffer;
  final double currentHR;

  const HeartRateWave({
    super.key,
    required this.buffer,
    required this.currentHR,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.heartColor.withValues(alpha: 0.2),
                      AppColors.heartColor.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.favorite, color: AppColors.heartColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'HEART RATE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heartColor,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.heartColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.heartColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${currentHR.toStringAsFixed(0)} BPM',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.heartColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: CustomPaint(
              size: Size.infinite,
              painter: _HRWavePainter(
                buffer: buffer,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HRWavePainter extends CustomPainter {
  final List<double> buffer;
  final bool isDark;

  _HRWavePainter({required this.buffer, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (buffer.isEmpty) return;

    final validValues = buffer.where((v) => v > 0).toList();
    if (validValues.isEmpty) return;

    final maxVal = validValues.reduce((a, b) => a > b ? a : b) * 1.1;
    final minVal = validValues.reduce((a, b) => a < b ? a : b) * 0.9;
    final range = maxVal - minVal;
    if (range <= 0) return;

    final paint = Paint()
      ..color = AppColors.heartColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final step = size.width / (buffer.length - 1).clamp(1, 999);

    bool started = false;
    for (int i = 0; i < buffer.length; i++) {
      if (buffer[i] <= 0) continue;
      final x = i * step;
      final y = size.height - ((buffer[i] - minVal) / range) * size.height;
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Glow effect
    final glowPaint = Paint()
      ..color = AppColors.heartColor.withValues(alpha: 0.15)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _HRWavePainter old) => true;
}
