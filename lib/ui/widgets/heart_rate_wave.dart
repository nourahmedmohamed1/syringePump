// lib/ui/widgets/heart_rate_wave.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/constants/app_colors.dart';
import '../../core/constants/thresholds.dart';
import '../../core/models/hr_reading.dart';

/// Intermittent Heart Rate Trend Graph.
/// Displays discrete data points over time (NOT a continuous ECG line).
class HeartRateWave extends StatelessWidget {
  final List<double> buffer;
  final double currentHR;
  final List<HrReading> hrReadings;
  final bool kidsMode;

  const HeartRateWave({
    super.key,
    required this.buffer,
    required this.currentHR,
    this.hrReadings = const [],
    this.kidsMode = false,
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
                kidsMode ? '💖 HEART HEALTH' : 'HR TREND',
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
          const SizedBox(height: 6),
          // Reading count & source info
          if (hrReadings.isNotEmpty)
            Text(
              '${hrReadings.length} reading${hrReadings.length == 1 ? '' : 's'} • Camera PPG',
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: kidsMode ? 80 : 100,
            child: hrReadings.isNotEmpty
                ? CustomPaint(
                    size: Size.infinite,
                    painter: _IntermittentTrendPainter(
                      readings: hrReadings,
                      isDark: isDark,
                      kidsMode: kidsMode,
                    ),
                  )
                : Center(
                    child: Text(
                      kidsMode
                          ? '💖 No heart scans yet!'
                          : 'No HR readings yet — tap Scan to begin',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
          ),
          // Time labels for intermittent graph
          if (hrReadings.length >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('HH:mm').format(hrReadings.first.timestamp),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm').format(hrReadings.last.timestamp),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Intermittent Trend Painter (Discrete Points) ────────────────────────────

class _IntermittentTrendPainter extends CustomPainter {
  final List<HrReading> readings;
  final bool isDark;
  final bool kidsMode;

  _IntermittentTrendPainter({
    required this.readings,
    required this.isDark,
    this.kidsMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty) return;

    final padding = 12.0;
    final graphWidth = size.width - padding * 2;
    final graphHeight = size.height - padding * 2;

    // Calculate Y range
    final bpmValues = readings.map((r) => r.bpm).toList();
    final minBpm = (bpmValues.reduce(min) - 10).clamp(30.0, 200.0);
    final maxBpm = (bpmValues.reduce(max) + 10).clamp(50.0, 250.0);
    final bpmRange = maxBpm - minBpm;
    if (bpmRange <= 0) return;

    // Calculate X range (time)
    final minTime = readings.first.timestamp.millisecondsSinceEpoch.toDouble();
    final maxTime = readings.last.timestamp.millisecondsSinceEpoch.toDouble();
    final timeRange = maxTime - minTime;

    // Draw threshold bands
    _drawThresholdBands(canvas, size, padding, graphHeight, minBpm, bpmRange);

    // Calculate point positions
    final points = <Offset>[];
    for (final reading in readings) {
      final x = timeRange > 0
          ? padding +
              ((reading.timestamp.millisecondsSinceEpoch - minTime) /
                      timeRange) *
                  graphWidth
          : size.width / 2;
      final y = padding + (1 - (reading.bpm - minBpm) / bpmRange) * graphHeight;
      points.add(Offset(x, y));
    }

    if (!kidsMode) {
      // Medical mode: clean discrete dots with subtle connecting line
      // Subtle dashed connecting line
      final linePaint = Paint()
        ..color = AppColors.heartColor.withValues(alpha: 0.15)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      if (points.length >= 2) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        canvas.drawPath(path, linePaint);
      }

      // Draw discrete dots
      for (int i = 0; i < points.length; i++) {
        final isLatest = i == points.length - 1;
        final dotRadius = isLatest ? 6.0 : 4.0;

        // Glow for each dot
        final glowPaint = Paint()
          ..color = AppColors.heartColor
              .withValues(alpha: isLatest ? 0.25 : 0.12)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, isLatest ? 8 : 4);
        canvas.drawCircle(points[i], dotRadius + 3, glowPaint);

        // Solid dot
        final dotPaint = Paint()
          ..color = AppColors.heartColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points[i], dotRadius, dotPaint);

        // White center for latest
        if (isLatest) {
          final centerPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(points[i], 2.5, centerPaint);
        }
      }
    } else {
      // Kids mode: fun icons at each point
      // We draw text emojis as the data point markers
      for (int i = 0; i < points.length; i++) {
        final isLatest = i == points.length - 1;
        final bpm = readings[i].bpm;

        // Choose fun icon — always happy & encouraging for kids!
        String icon;
        if (isLatest) {
          icon = '💖'; // Latest reading = big heart
        } else if (i % 3 == 0) {
          icon = '⭐'; // Stars
        } else if (i % 3 == 1) {
          icon = '🌟'; // Sparkle stars
        } else {
          icon = '💗'; // Pink hearts
        }

        final textPainter = TextPainter(
          text: TextSpan(
            text: icon,
            style: TextStyle(fontSize: isLatest ? 18 : 14),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            points[i].dx - textPainter.width / 2,
            points[i].dy - textPainter.height / 2,
          ),
        );
      }

      // Sparkle connecting line for kids
      if (points.length >= 2) {
        final sparklePaint = Paint()
          ..color = AppColors.kidsPrimary.withValues(alpha: 0.25)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        canvas.drawPath(path, sparklePaint);
      }
    }
  }

  void _drawThresholdBands(Canvas canvas, Size size, double padding,
      double graphHeight, double minBpm, double bpmRange) {
    // Warning low line
    _drawThresholdLine(canvas, size, padding, graphHeight, minBpm, bpmRange,
        Thresholds.hrMin, AppColors.warning);
    // Warning high line
    _drawThresholdLine(canvas, size, padding, graphHeight, minBpm, bpmRange,
        Thresholds.hrMax, AppColors.warning);
    // Critical low line
    _drawThresholdLine(canvas, size, padding, graphHeight, minBpm, bpmRange,
        Thresholds.hrCriticalMin, AppColors.danger);
    // Critical high line
    _drawThresholdLine(canvas, size, padding, graphHeight, minBpm, bpmRange,
        Thresholds.hrCriticalMax, AppColors.danger);
  }

  void _drawThresholdLine(Canvas canvas, Size size, double padding,
      double graphHeight, double minBpm, double bpmRange, double threshold,
      Color color) {
    if (threshold < minBpm || threshold > minBpm + bpmRange) return;

    final y = padding + (1 - (threshold - minBpm) / bpmRange) * graphHeight;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Dashed line
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _IntermittentTrendPainter old) => true;
}


