// lib/ui/widgets/syringe_progress.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class SyringeProgress extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double volumeDelivered;
  final double totalVolume;
  final String timeRemaining;
  final String elapsed;
  final double flowRate;

  const SyringeProgress({
    super.key,
    required this.progress,
    required this.volumeDelivered,
    required this.totalVolume,
    required this.timeRemaining,
    required this.elapsed,
    required this.flowRate,
  });

  @override
  State<SyringeProgress> createState() => _SyringeProgressState();
}

class _SyringeProgressState extends State<SyringeProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1E2E), const Color(0xFF2D1B69)]
              : [const Color(0xFFF0ECFF), const Color(0xFFE8E0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
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
              Icon(Icons.vaccines, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'SYRINGE PROGRESS',
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
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.accent.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(widget.progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Syringe bar
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 28,
                  child: Stack(
                    children: [
                      // Background
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // Fill
                      FractionallySizedBox(
                        widthFactor: widget.progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6C63FF),
                                Color(0xFF9B59B6),
                                Color(0xFFFF6B6B),
                              ],
                            ),
                          ),
                          child: CustomPaint(
                            painter: _WavePainter(
                              wavePhase: _waveController.value * 2 * pi,
                            ),
                          ),
                        ),
                      ),
                      // Tick marks
                      Row(
                        children: List.generate(
                          10,
                          (i) => Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06),
                                    width: i < 9 ? 1 : 0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              _StatChip(
                icon: Icons.water_drop,
                label: 'Delivered',
                value:
                    '${widget.volumeDelivered.toStringAsFixed(1)}/${widget.totalVolume.toStringAsFixed(0)} mL',
                color: AppColors.primary,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _StatChip(
                icon: Icons.timer_outlined,
                label: 'Remaining',
                value: widget.timeRemaining,
                color: AppColors.warning,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _StatChip(
                icon: Icons.speed,
                label: 'Flow',
                value: '${widget.flowRate.toStringAsFixed(1)} mL/hr',
                color: AppColors.safe,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double wavePhase;
  _WavePainter({required this.wavePhase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.5 + sin(x * 0.05 + wavePhase) * size.height * 0.2;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.wavePhase != wavePhase;
}
