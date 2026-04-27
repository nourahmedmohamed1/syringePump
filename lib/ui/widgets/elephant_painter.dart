// lib/ui/widgets/elephant_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Cute cartoon elephant drawn entirely with CustomPainter.
/// Animated via external parameters: bounce, earFlap, trunkSway, blinkAmount, breathe.
class ElephantPainter extends CustomPainter {
  final double bounce;       // 0..1 vertical bounce
  final double earFlap;      // 0..1 ear flap amount
  final double trunkSway;    // -1..1 trunk swing left/right
  final double blinkAmount;  // 0..1 (1 = fully closed)
  final double breathe;      // 0..1 belly expansion
  final double celebrate;    // 0..1 celebration mode (trunk up)

  ElephantPainter({
    this.bounce = 0,
    this.earFlap = 0,
    this.trunkSway = 0,
    this.blinkAmount = 0,
    this.breathe = 0,
    this.celebrate = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55 - bounce * 8;
    final scale = size.width / 200; // base design at 200 logical px

    // Paints
    final bodyPaint = Paint()..color = AppColors.elephantBody;
    final darkPaint = Paint()..color = AppColors.elephantDark;
    final lightPaint = Paint()..color = AppColors.elephantLight;
    final earPaint = Paint()..color = AppColors.elephantEar;
    final cheekPaint = Paint()..color = AppColors.elephantCheek.withValues(alpha: 0.5);
    final whitePaint = Paint()..color = Colors.white;
    final eyePaint = Paint()..color = const Color(0xFF2D1B69);
    final eyeHighlight = Paint()..color = Colors.white;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    // ── Ears (behind body) ──
    final earAngle = earFlap * 0.15;

    // Left ear
    canvas.save();
    canvas.translate(-42, -15);
    canvas.rotate(-0.2 - earAngle);
    _drawEar(canvas, earPaint, darkPaint, false);
    canvas.restore();

    // Right ear
    canvas.save();
    canvas.translate(42, -15);
    canvas.rotate(0.2 + earAngle);
    _drawEar(canvas, earPaint, darkPaint, true);
    canvas.restore();

    // ── Body (belly) ──
    final bellyExpand = breathe * 3;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 30),
        width: 70 + bellyExpand,
        height: 55 + bellyExpand,
      ),
      bodyPaint,
    );

    // Belly highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 32),
        width: 45 + bellyExpand * 0.5,
        height: 35,
      ),
      lightPaint,
    );

    // ── Legs ──
    _drawLeg(canvas, -20, 52, bodyPaint, darkPaint);
    _drawLeg(canvas, 20, 52, bodyPaint, darkPaint);

    // ── Arms (small) ──
    // Left arm
    canvas.save();
    canvas.translate(-30, 25);
    canvas.rotate(-0.3 + celebrate * 1.2); // raises arm when celebrating
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -3, 18, 10),
        const Radius.circular(5),
      ),
      bodyPaint,
    );
    canvas.restore();

    // Right arm
    canvas.save();
    canvas.translate(30, 25);
    canvas.rotate(0.3 - celebrate * 1.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -3, 18, 10),
        const Radius.circular(5),
      ),
      bodyPaint,
    );
    canvas.restore();

    // ── Head ──
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -10),
        width: 72,
        height: 65,
      ),
      bodyPaint,
    );

    // ── Face ──
    // Cheeks
    canvas.drawCircle(const Offset(-22, 2), 8, cheekPaint);
    canvas.drawCircle(const Offset(22, 2), 8, cheekPaint);

    // Eyes
    final eyeOpenHeight = 10.0 * (1.0 - blinkAmount);
    // Left eye
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-15, -12),
        width: 12,
        height: max(1, eyeOpenHeight),
      ),
      whitePaint,
    );
    if (blinkAmount < 0.8) {
      canvas.drawCircle(const Offset(-15, -11), 4, eyePaint);
      canvas.drawCircle(const Offset(-13.5, -13), 1.5, eyeHighlight);
    }

    // Right eye
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(15, -12),
        width: 12,
        height: max(1, eyeOpenHeight),
      ),
      whitePaint,
    );
    if (blinkAmount < 0.8) {
      canvas.drawCircle(const Offset(15, -11), 4, eyePaint);
      canvas.drawCircle(const Offset(16.5, -13), 1.5, eyeHighlight);
    }

    // ── Trunk ──
    _drawTrunk(canvas, bodyPaint, darkPaint, trunkSway, celebrate);

    // ── Mouth (smile) ──
    final smilePaint = Paint()
      ..color = AppColors.elephantDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final smilePath = Path();
    smilePath.moveTo(-6, 5);
    smilePath.quadraticBezierTo(0, 10 + celebrate * 3, 6, 5);
    canvas.drawPath(smilePath, smilePaint);

    canvas.restore();
  }

  void _drawEar(Canvas canvas, Paint earPaint, Paint darkPaint, bool isRight) {
    final path = Path();
    if (!isRight) {
      path.moveTo(0, -15);
      path.quadraticBezierTo(-35, -10, -30, 20);
      path.quadraticBezierTo(-20, 30, 0, 15);
      path.close();
    } else {
      path.moveTo(0, -15);
      path.quadraticBezierTo(35, -10, 30, 20);
      path.quadraticBezierTo(20, 30, 0, 15);
      path.close();
    }
    canvas.drawPath(path, earPaint);

    // Inner ear
    canvas.save();
    canvas.scale(0.6);
    canvas.translate(isRight ? 5 : -5, 2);
    final innerPaint = Paint()..color = AppColors.elephantCheek.withValues(alpha: 0.3);
    canvas.drawPath(path, innerPaint);
    canvas.restore();
  }

  void _drawLeg(Canvas canvas, double x, double y, Paint bodyPaint, Paint darkPaint) {
    // Leg body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 8, y, 16, 22),
        const Radius.circular(8),
      ),
      bodyPaint,
    );
    // Foot (toenails)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + 22),
        width: 18,
        height: 8,
      ),
      darkPaint,
    );
  }

  void _drawTrunk(Canvas canvas, Paint bodyPaint, Paint darkPaint, double sway, double celeb) {
    final trunkPaint = Paint()
      ..color = AppColors.elephantBody
      ..style = PaintingStyle.fill;

    final path = Path();
    // Trunk starts from the face center
    final startX = 0.0;
    final startY = 2.0;

    // When celebrating, trunk goes UP; otherwise curves down with sway
    if (celeb > 0.3) {
      // Trunk up celebration
      final upAmount = celeb;
      path.moveTo(startX - 5, startY);
      path.quadraticBezierTo(
        startX + sway * 8,
        startY - 20 * upAmount,
        startX + 8 * upAmount + sway * 5,
        startY - 30 * upAmount,
      );
      path.quadraticBezierTo(
        startX + 12 * upAmount,
        startY - 32 * upAmount,
        startX + 5,
        startY,
      );
    } else {
      // Normal hanging trunk with sway
      path.moveTo(startX - 4, startY);
      path.cubicTo(
        startX - 3 + sway * 6, startY + 12,
        startX + 2 + sway * 10, startY + 20,
        startX + sway * 12, startY + 28,
      );
      // Curl at end
      path.quadraticBezierTo(
        startX + sway * 14 + 4, startY + 30,
        startX + sway * 10 + 3, startY + 25,
      );
      path.cubicTo(
        startX + 3 + sway * 8, startY + 18,
        startX + 4 + sway * 4, startY + 10,
        startX + 4, startY,
      );
    }
    path.close();
    canvas.drawPath(path, trunkPaint);
  }

  @override
  bool shouldRepaint(ElephantPainter oldDelegate) =>
      bounce != oldDelegate.bounce ||
      earFlap != oldDelegate.earFlap ||
      trunkSway != oldDelegate.trunkSway ||
      blinkAmount != oldDelegate.blinkAmount ||
      breathe != oldDelegate.breathe ||
      celebrate != oldDelegate.celebrate;
}
