// lib/ui/widgets/flow_gauge.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class FlowGauge extends StatelessWidget {
  final double actualFlow;
  final double desiredFlow;
  final List<double> flowHistory;

  const FlowGauge({
    super.key,
    required this.actualFlow,
    required this.desiredFlow,
    required this.flowHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviation = desiredFlow > 0
        ? ((actualFlow - desiredFlow) / desiredFlow * 100)
        : 0.0;
    final isOk = deviation.abs() < 20;

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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.compare_arrows, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'FLOW COMPARISON',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOk ? AppColors.safe : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isOk ? AppColors.safe : AppColors.warning)
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  isOk
                      ? '✓ ON TARGET'
                      : '${deviation > 0 ? '+' : ''}${deviation.toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isOk ? AppColors.safe : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Desired vs Actual
          Row(
            children: [
              Expanded(
                child: _FlowValueCard(
                  label: 'DESIRED',
                  value: desiredFlow.toStringAsFixed(1),
                  unit: 'mL/hr',
                  color: AppColors.primary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward,
                size: 18,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FlowValueCard(
                  label: 'ACTUAL',
                  value: actualFlow.toStringAsFixed(1),
                  unit: 'mL/hr',
                  color: isOk ? AppColors.safe : AppColors.warning,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mini flow chart
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: Size.infinite,
              painter: _FlowChartPainter(
                flowHistory: flowHistory,
                desiredFlow: desiredFlow,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowValueCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isDark;

  const _FlowValueCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowChartPainter extends CustomPainter {
  final List<double> flowHistory;
  final double desiredFlow;
  final bool isDark;

  _FlowChartPainter({
    required this.flowHistory,
    required this.desiredFlow,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (flowHistory.isEmpty) return;

    final maxVal = [
      ...flowHistory,
      desiredFlow,
    ].reduce(max) * 1.3;
    final minVal = 0.0;
    final range = maxVal - minVal;
    if (range <= 0) return;

    // Draw desired flow line
    if (desiredFlow > 0) {
      final desiredY =
          size.height - ((desiredFlow - minVal) / range) * size.height;
      final desiredPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Dashed line
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, desiredY),
          Offset(min(startX + dashWidth, size.width), desiredY),
          desiredPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    // Draw actual flow line
    final paint = Paint()
      ..color = AppColors.flowColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.2),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final step = size.width / (flowHistory.length - 1).clamp(1, 999);

    for (int i = 0; i < flowHistory.length; i++) {
      final x = i * step;
      final y =
          size.height - ((flowHistory[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo((flowHistory.length - 1) * step, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, gradientPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FlowChartPainter old) => true;
}
