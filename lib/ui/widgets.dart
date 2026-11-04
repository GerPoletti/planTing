import 'package:flutter/material.dart';

import 'theme.dart';

/// Tarjeta redondeada del estilo de la app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = MC.card,
    this.borderColor,
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!, width: 1.5),
    );
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Etiqueta pequeña, por ejemplo «Poca luz» o «Tóxica».
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = MC.ink, this.background = MC.sunLight});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Título de sección con tipografía de títulos.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: displayStyle(18))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Barra de progreso fina.
class SlimProgress extends StatelessWidget {
  const SlimProgress(this.value, {super.key, this.color = MC.olive});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: MC.sand,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Hoja del ícono de plantas, dibujada a mano.
class LeafGlyph extends StatelessWidget {
  const LeafGlyph({super.key, this.size = 24, this.color = MC.olive});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _LeafPainter(color)));
  }
}

/// Dibuja la hoja del ícono de plantas dentro de un cuadrado de lado [size]
/// cuya esquina superior izquierda es [topLeft].
void drawLeaf(Canvas canvas, Offset topLeft, double size, Color color, {double stroke = 1.7}) {
  final k = size / 24;
  Offset p(double x, double y) => Offset(topLeft.dx + x * k, topLeft.dy + y * k);
  final path = Path()
    ..moveTo(p(12, 21).dx, p(12, 21).dy)
    ..cubicTo(p(7, 21).dx, p(7, 21).dy, p(4, 18).dx, p(4, 18).dy, p(4, 13).dx, p(4, 13).dy)
    ..cubicTo(p(9, 13).dx, p(9, 13).dy, p(12, 16).dx, p(12, 16).dy, p(12, 21).dx, p(12, 21).dy)
    ..close()
    ..moveTo(p(12, 21).dx, p(12, 21).dy)
    ..cubicTo(p(12, 15).dx, p(12, 15).dy, p(15, 11).dx, p(15, 11).dy, p(20, 9).dx, p(20, 9).dy)
    ..cubicTo(p(20, 15).dx, p(20, 15).dy, p(17, 19).dx, p(17, 19).dy, p(12, 21).dx, p(12, 21).dy)
    ..close();
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * k
      ..strokeJoin = StrokeJoin.round,
  );
}

class _LeafPainter extends CustomPainter {
  _LeafPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    drawLeaf(canvas, Offset.zero, size.width, color);
  }

  @override
  bool shouldRepaint(covariant _LeafPainter old) => old.color != color;
}

/// Romu, el gatito maine coon gris, dibujado con formas simples.
class RomuFace extends StatelessWidget {
  const RomuFace({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _RomuPainter()));
  }
}

class _RomuPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 44;
    Paint fill(Color c) => Paint()..color = c;
    final ear = fill(const Color(0xFF8E949B));
    canvas.drawPath(
      Path()
        ..moveTo(7 * k, 16 * k)
        ..lineTo(9 * k, 3 * k)
        ..lineTo(19 * k, 10 * k)
        ..close(),
      ear,
    );
    canvas.drawPath(
      Path()
        ..moveTo(37 * k, 16 * k)
        ..lineTo(35 * k, 3 * k)
        ..lineTo(25 * k, 10 * k)
        ..close(),
      ear,
    );
    canvas.drawCircle(Offset(22 * k, 24 * k), 16 * k, fill(MC.kitten));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(22 * k, 29 * k), width: 16 * k, height: 12 * k),
      fill(const Color(0xFFC9CDD1)),
    );
    canvas.drawCircle(Offset(16 * k, 22 * k), 1.8 * k, fill(MC.ink));
    canvas.drawCircle(Offset(28 * k, 22 * k), 1.8 * k, fill(MC.ink));
    canvas.drawPath(
      Path()
        ..moveTo(20.5 * k, 26 * k)
        ..lineTo(23.5 * k, 26 * k)
        ..lineTo(22 * k, 28 * k)
        ..close(),
      fill(const Color(0xFFC98A84)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frase de Romu en cursiva, con su cara al costado.
class RomuSays extends StatelessWidget {
  const RomuSays(this.text, {super.key, this.size = 38});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RomuFace(size: size),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontStyle: FontStyle.italic, color: MC.muted, fontSize: 14, height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// Círculo de color con un ícono, como en las listas de las pantallas.
class IconBubble extends StatelessWidget {
  const IconBubble({super.key, required this.child, this.background = MC.sage, this.size = 44});

  final Widget child;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Pantalla con título grande, margen estándar y desplazamiento.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.showBack = false,
    this.bottom,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack
          ? AppBar(actions: actions)
          : null,
      body: SafeArea(
        bottom: bottom == null,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(24, showBack ? 4 : 20, 24, 24),
                children: [
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(color: MC.muted, fontSize: 13)),
                  Text(title, style: displayStyle(30)),
                  const SizedBox(height: 12),
                  ...children,
                ],
              ),
            ),
            if (bottom != null)
              SafeArea(
                top: false,
                child: Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16), child: bottom),
              ),
          ],
        ),
      ),
    );
  }
}
