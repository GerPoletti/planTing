import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../engine/light_map.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class _World {
  const _World(this.minX, this.minY, this.width, this.height);

  final double minX;
  final double minY;
  final double width;
  final double height;
}

_World _worldOf(List<Room> rooms) {
  if (rooms.isEmpty) return const _World(0, 0, 6, 4);
  final minX = rooms.map((r) => r.x).reduce(math.min);
  final minY = rooms.map((r) => r.y).reduce(math.min);
  final maxX = rooms.map((r) => r.x + r.w).reduce(math.max);
  final maxY = rooms.map((r) => r.y + r.h).reduce(math.max);
  // Margen alrededor y lugar a la derecha para la flecha del norte.
  return _World(minX - 0.5, minY - 0.5, maxX - minX + 2.2, maxY - minY + 1.0);
}

/// Dibuja el plano y avisa qué se tocó. Mide en metros y se ajusta al ancho.
class PlanView extends StatelessWidget {
  const PlanView({
    super.key,
    required this.rooms,
    required this.plants,
    required this.readings,
    required this.map,
    required this.showLight,
    required this.northOffset,
    required this.semanticsLabel,
    required this.onTapPlant,
    required this.onTapPoint,
    this.selectedRoomId,
    this.selectedPlantId,
  });

  final List<Room> rooms;
  final List<PlantItem> plants;
  final List<Reading> readings;
  final LightMap map;
  final bool showLight;
  final double northOffset;
  final String semanticsLabel;
  final String? selectedRoomId;
  final String? selectedPlantId;
  final void Function(String plantId) onTapPlant;
  final void Function(Offset point, Room? room) onTapPoint;

  @override
  Widget build(BuildContext context) {
    final world = _worldOf(rooms);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = width / world.width;
        final height = world.height * scale;
        return Semantics(
          label: semanticsLabel,
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final point = Offset(
                  details.localPosition.dx / scale + world.minX,
                  details.localPosition.dy / scale + world.minY,
                );
                PlantItem? nearest;
                var best = 0.55;
                for (final p in plants) {
                  final d = (Offset(p.x, p.y) - point).distance;
                  if (d < best) {
                    best = d;
                    nearest = p;
                  }
                }
                if (nearest != null) {
                  onTapPlant(nearest.id);
                  return;
                }
                Room? room;
                for (final r in rooms) {
                  if (r.contains(point.dx, point.dy)) {
                    room = r;
                    break;
                  }
                }
                onTapPoint(point, room);
              },
              child: CustomPaint(
                painter: _PlanPainter(
                  world: world,
                  rooms: rooms,
                  plants: plants,
                  readings: readings,
                  map: map,
                  showLight: showLight,
                  northOffset: northOffset,
                  selectedRoomId: selectedRoomId,
                  selectedPlantId: selectedPlantId,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlanPainter extends CustomPainter {
  _PlanPainter({
    required this.world,
    required this.rooms,
    required this.plants,
    required this.readings,
    required this.map,
    required this.showLight,
    required this.northOffset,
    required this.selectedRoomId,
    required this.selectedPlantId,
  });

  final _World world;
  final List<Room> rooms;
  final List<PlantItem> plants;
  final List<Reading> readings;
  final LightMap map;
  final bool showLight;
  final double northOffset;
  final String? selectedRoomId;
  final String? selectedPlantId;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / world.width;
    Offset pt(double x, double y) => Offset((x - world.minX) * scale, (y - world.minY) * scale);

    for (final room in rooms) {
      _paintRoom(canvas, room, scale, pt);
    }
    for (final room in rooms) {
      _paintWindows(canvas, room, scale, pt);
    }
    for (final r in readings) {
      if (r.x == null || r.y == null) continue;
      final c = pt(r.x!, r.y! + 0.45);
      canvas.drawCircle(c, 3.5, Paint()..color = MC.cream);
      canvas.drawCircle(c, 2.5, Paint()..color = MC.olive);
    }
    for (final p in plants) {
      _paintPlant(canvas, p, scale, pt);
    }
    _paintNorth(canvas, scale, pt);
  }

  void _paintRoom(Canvas canvas, Room room, double scale, Offset Function(double, double) pt) {
    final rect = Rect.fromPoints(pt(room.x, room.y), pt(room.x + room.w, room.y + room.h));
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = showLight ? MC.sand.withValues(alpha: 0.55) : MC.card);

    if (showLight) {
      canvas.save();
      canvas.clipRRect(rrect);
      for (var cx = 0.0; cx < room.w - 1e-9; cx += 0.5) {
        for (var cy = 0.0; cy < room.h - 1e-9; cy += 0.5) {
          final cw = math.min(0.5, room.w - cx);
          final ch = math.min(0.5, room.h - cy);
          final v = map.lightAt(room.x + cx + cw / 2, room.y + cy + ch / 2);
          final alpha = (v / 14).clamp(0.0, 0.85);
          if (alpha <= 0.02) continue;
          canvas.drawRect(
            Rect.fromPoints(
              pt(room.x + cx, room.y + cy),
              pt(room.x + cx + cw, room.y + cy + ch),
            ).inflate(0.4),
            Paint()..color = MC.sun.withValues(alpha: alpha),
          );
        }
      }
      canvas.restore();
    }

    final selected = room.id == selectedRoomId;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 3 : 1.5
      ..color = selected ? MC.olive : MC.ink.withValues(alpha: 0.55);
    if (room.exterior) {
      // Pared: línea continua; baranda: guiones; abierto: línea tenue.
      final corners = {
        't': (rect.topLeft, rect.topRight),
        'r': (rect.topRight, rect.bottomRight),
        'b': (rect.bottomRight, rect.bottomLeft),
        'l': (rect.bottomLeft, rect.topLeft),
      };
      corners.forEach((side, ends) {
        final (a, b) = ends;
        switch (room.sideOf(side)) {
          case SideType.wall:
            canvas.drawLine(a, b, outline);
          case SideType.railing:
            _dashed(canvas, a, b, outline);
          default:
            canvas.drawLine(a, b, Paint()
              ..strokeWidth = 1
              ..color = outline.color.withValues(alpha: 0.25));
        }
      });
    } else {
      canvas.drawRRect(rrect, outline);
    }

    final label = TextPainter(
      text: TextSpan(
        text: room.name,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: MC.ink),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(10, rect.width - 12));
    label.paint(canvas, rect.topLeft + const Offset(7, 5));
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 7.0;
    const gap = 5.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final end = math.min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * end, paint);
      d += dash + gap;
    }
  }

  void _paintWindows(Canvas canvas, Room room, double scale, Offset Function(double, double) pt) {
    final paint = Paint()
      ..color = MC.olive
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    if (room.exterior) return; // en exteriores la luz entra por los lados
    for (final w in room.windows) {
      final p = AppStore.windowPoint(room, w);
      final horizontal = w.wall == 't' || w.wall == 'b';
      final a = horizontal ? pt(p.dx - 0.35, p.dy) : pt(p.dx, p.dy - 0.35);
      final b = horizontal ? pt(p.dx + 0.35, p.dy) : pt(p.dx, p.dy + 0.35);
      canvas.drawLine(a, b, paint);
    }
  }

  void _paintPlant(Canvas canvas, PlantItem plant, double scale, Offset Function(double, double) pt) {
    final c = pt(plant.x, plant.y);
    final r = (0.32 * scale).clamp(11.0, 18.0);
    final selected = plant.id == selectedPlantId;
    if (selected) {
      canvas.drawCircle(c, r + 5, Paint()..color = MC.terracotta.withValues(alpha: 0.25));
    }
    canvas.drawCircle(c, r, Paint()..color = MC.card);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1.5
        ..color = selected ? MC.terracotta : MC.olive,
    );
    final leaf = r * 1.35;
    drawLeaf(canvas, c - Offset(leaf / 2, leaf / 2), leaf, MC.olive);
  }

  void _paintNorth(Canvas canvas, double scale, Offset Function(double, double) pt) {
    final c = pt(world.minX + world.width - 0.9, world.minY + 1.0);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-northOffset * math.pi / 180);
    canvas.drawPath(
      Path()
        ..moveTo(0, -15)
        ..lineTo(7, 9)
        ..lineTo(-7, 9)
        ..close(),
      Paint()..color = MC.olive,
    );
    canvas.restore();
    final n = TextPainter(
      text: const TextSpan(text: 'N', style: TextStyle(fontSize: 10, color: MC.ink, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    n.paint(canvas, c + Offset(-n.width / 2, 14));
  }

  @override
  bool shouldRepaint(covariant _PlanPainter old) => true;
}
