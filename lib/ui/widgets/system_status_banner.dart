// lib/ui/widgets/system_status_banner.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

/// Visual status indicator for FSR pressure/occlusion.
/// IR syringe-empty is handled by the hardware alarm string, not shown here.
class SystemStatusBanner extends StatefulWidget {
  final bool fsrWarning;
  final bool fsrCritical;
  final bool irBlocked;
  final bool hasAnyAlarm;

  const SystemStatusBanner({
    super.key,
    required this.fsrWarning,
    required this.fsrCritical,
    required this.irBlocked,
    required this.hasAnyAlarm,
  });

  @override
  State<SystemStatusBanner> createState() => _SystemStatusBannerState();
}

class _SystemStatusBannerState extends State<SystemStatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(SystemStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDanger && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_isDanger && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isDanger => widget.fsrCritical || widget.irBlocked;
  bool get _isWarning => widget.fsrWarning && !widget.fsrCritical;
  bool get _isStable => !widget.fsrWarning && !widget.fsrCritical && !widget.irBlocked;

  Color get _statusColor {
    if (_isDanger) return AppColors.danger;
    if (_isWarning) return AppColors.warning;
    return AppColors.safe;
  }

  IconData get _statusIcon {
    if (_isDanger) return Icons.error_rounded;
    if (_isWarning) return Icons.warning_amber_rounded;
    return Icons.check_circle_rounded;
  }

  String get _statusTitle {
    if (widget.irBlocked) return 'Syringe Empty!';
    if (widget.fsrCritical) return 'Occlusion Detected!';
    if (widget.fsrWarning) return 'High Pressure Warning';
    return 'All Systems Normal';
  }

  String get _statusSubtitle {
    if (widget.irBlocked) return 'IR sensor detects plunger at end position. Replace syringe immediately.';
    if (widget.fsrCritical) return 'Critical line pressure detected. Check for blockages in the IV line.';
    if (widget.fsrWarning) return 'Line pressure is elevated. Monitor closely for potential occlusion.';
    return 'Pressure and syringe sensors are within safe operating range.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isDanger && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseVal = _isDanger ? _pulseController.value : 0.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            border: Border.all(
              color: _statusColor.withValues(alpha: 0.3 + pulseVal * 0.4),
              width: _isStable ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _statusColor.withValues(alpha: _isStable ? 0.08 : 0.15 + pulseVal * 0.15),
                blurRadius: _isStable ? 12 : 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          // Status icon with animated glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _statusColor.withValues(alpha: 0.2),
                  _statusColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                _statusIcon,
                key: ValueKey(_statusIcon),
                color: _statusColor,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status pill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _statusColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        _isDanger ? 'ALERT' : _isWarning ? 'WARNING' : 'STABLE',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _statusColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusTitle,
                    key: ValueKey(_statusTitle),
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _statusSubtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.3,
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
