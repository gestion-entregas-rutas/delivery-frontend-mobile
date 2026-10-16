import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_screen.dart' show AppColors;

class AnimatedRoute extends StatefulWidget {
  const AnimatedRoute({super.key});
  @override
  State<AnimatedRoute> createState() => _AnimatedRouteState();
}

class _AnimatedRouteState extends State<AnimatedRoute>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = .45;
    } else {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _RoutePainter(_motion)),
      ),
    ),
  );
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 300);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c * 96 - 30, r * 86 - 20, 76, 64),
            const Radius.circular(14),
          ),
          Paint()..color = const Color(0x35FFFFFF),
        );
      }
    }
    final path = Path()
      ..moveTo(40, 238)
      ..cubicTo(125, 240, 90, 100, 190, 132)
      ..cubicTo(290, 174, 255, 54, 350, 62);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x30FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22,
    );
    final line = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (double d = 0; d < metric.length; d += 14) {
      canvas.drawPath(metric.extractPath(d, d + 5), line);
    }
    for (final point in [const Offset(40, 238), const Offset(350, 62)]) {
      canvas.drawCircle(point, 12, Paint()..color = Colors.white);
      canvas.drawCircle(point, 5, Paint()..color = AppColors.ink);
    }
    final t = motion.value;
    final alpha = math.min(1.0, math.min(t * 12, (1 - t) * 12));
    final p = metric.getTangentForOffset(metric.length * t)!.position;
    canvas.drawCircle(
      p,
      25,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.local_shipping_rounded.codePoint),
        style: TextStyle(
          fontSize: 26,
          fontFamily: Icons.local_shipping_rounded.fontFamily,
          color: AppColors.ink.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, p - Offset(icon.width / 2, icon.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) => oldDelegate.motion != motion;
}
