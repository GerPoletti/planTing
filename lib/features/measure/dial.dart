import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Dial semicircular con cuatro zonas de luz y una aguja.
class LightDial extends StatelessWidget {
  const LightDial({
    super.key,
    required this.fraction,
    required this.labels,
    this.highlight,
    this.semanticsLabel,
  });

  /// Posición de la aguja de 0 a 1.
  final double fraction;

  /// Nombres de las cuatro zonas, de izquierda a derecha.
  final List<String> labels;

  /// Zona resaltada (0 a 3), si hay una medición.
  final int? highlight;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          label: semanticsLabel,
          child: AspectRatio(
            aspectRatio: 320 / 185,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: fraction),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CustomPaint(painter: _DialPainter(value)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < labels.length; i++)
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: highlight == i ? MC.ink : MC.muted,
                    fontWeight: highlight == i ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.fraction);

  final double fraction;

  static const List<Color> _zones = [
    Color(0xFF9DB0B5),
    Color(0xFFA9BE9C),
    Color(0xFFE2BE62),
    Color(0xFFC9793F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 320;
    final center = Offset(160 * k, 160 * k);
    final radius = 130 * k;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        rect,
        math.pi + i * math.pi / 4,
        math.pi / 4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24 * k
          ..color = _zones[i],
      );
    }

    final angle = math.pi + fraction.clamp(0.0, 1.0) * math.pi;
    final tip = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 14 * k);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = MC.ink
        ..strokeWidth = 4 * k
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 9 * k, Paint()..color = MC.ink);
    canvas.drawCircle(center, 3.5 * k, Paint()..color = MC.cream);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.fraction != fraction;
}
