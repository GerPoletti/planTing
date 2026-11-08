import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../data/content.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'light_map.dart';

/// Qué tan bien le queda un lugar a una especie, teniendo en cuenta el rango
/// de incertidumbre de la estimación.
enum PlacementFit {
  /// Todo el rango estimado cae dentro de lo que necesita la especie.
  good,

  /// El rango estimado se superpone con lo que necesita: conviene medir.
  uncertain,

  /// Le falta luz aun en el mejor caso.
  low,

  /// Le sobra luz aun en el peor caso.
  high,
}

/// Supuestos que la persona tiene que conocer para confiar en la sugerencia.
enum PlacementAssumption {
  /// No hay ubicación: se usa una latitud de referencia.
  noLocation,

  /// Algún lugar sugerido está en un ambiente sin mediciones.
  theoretical,

  /// No hay ambientes del tipo que necesita la especie (interior o exterior).
  noCompatibleRoom,

  /// Ningún ambiente compatible tiene ventanas cargadas.
  noWindows,

  /// La especie no está identificada: no hay rango de luz propio.
  unknownSpecies,
}

/// Margen relativo de la estimación según cuántas mediciones con sol hay en
/// el ambiente: ±40 % sin mediciones, ±25 % con una o dos y ±15 % con tres o más.
double placementMargin(int readingsInRoom) {
  if (readingsInRoom >= 3) return 0.15;
  if (readingsInRoom >= 1) return 0.25;
  return 0.40;
}

PlacementFit placementFit(double low, double high, double dliMin, double dliMax) {
  if (high < dliMin) return PlacementFit.low;
  if (low > dliMax) return PlacementFit.high;
  if (low >= dliMin && high <= dliMax) return PlacementFit.good;
  return PlacementFit.uncertain;
}

/// Un lugar posible para una planta, con su explicación.
class PlacementOption {
  const PlacementOption({
    required this.room,
    required this.x,
    required this.y,
    required this.dli,
    required this.low,
    required this.high,
    required this.margin,
    required this.readings,
    required this.fit,
    this.window,
    this.windowDistance,
    this.sunHours = 0,
  });

  final Room room;
  final double x;
  final double y;

  /// DLI estimado en el lugar.
  final double dli;

  /// Rango probable del DLI según la confianza.
  final double low;
  final double high;
  final double margin;

  /// Mediciones con sol del ambiente que ajustan la estimación.
  final int readings;
  final PlacementFit fit;

  /// Ventana más cercana (null en exteriores) y su distancia en metros.
  /// [sunHours] son las horas de sol directo de hoy en el lugar y a la altura
  /// de la planta.
  final WindowSpot? window;
  final double? windowDistance;
  final double sunHours;

  bool get measured => readings > 0;

  /// Se puede proponer como ubicación: el ambiente tiene mediciones vigentes y
  /// todo el rango probable cae dentro de lo que necesita la especie. Si es
  /// dudoso o no hay mediciones, el siguiente paso es medir ese lugar.
  bool get actionable => measured && fit == PlacementFit.good;
}

class PlacementResult {
  const PlacementResult(this.options, this.assumptions);

  final List<PlacementOption> options;
  final Set<PlacementAssumption> assumptions;

  /// Hay al menos un lugar medido que le sirve.
  bool get hasGood => options.any((o) => o.measured && o.fit == PlacementFit.good);

  /// Ningún lugar tiene mediciones: todo es un cálculo para orientar qué medir.
  bool get onlyCandidates => options.every((o) => !o.measured);
}

/// Busca los mejores lugares de la casa para una especie según el mapa de luz.
class PlacementEngine {
  const PlacementEngine._();

  /// Devuelve hasta [count] lugares, separados al menos [minSeparation]
  /// metros entre sí y de las demás plantas (salvo [ignorePlantId], que es la
  /// planta que se quiere mover).
  static PlacementResult suggest({
    required LightMap map,
    required Species species,
    List<PlantItem> plants = const [],
    String? ignorePlantId,
    bool hasLocation = true,
    int count = 3,
    double step = 0.5,
    double minSeparation = 1.0,
    double plantClearance = 0.5,
    double? heightCm,
  }) {
    final assumptions = <PlacementAssumption>{};
    if (species.isUnknown) {
      return PlacementResult(const [], {PlacementAssumption.unknownSpecies});
    }
    if (!hasLocation) assumptions.add(PlacementAssumption.noLocation);

    final rooms = map.rooms.where((r) => _compatible(species, r)).toList();
    if (rooms.isEmpty) {
      assumptions.add(PlacementAssumption.noCompatibleRoom);
      return PlacementResult(const [], assumptions);
    }
    if (rooms.every((r) => !r.exterior && r.windows.isEmpty)) {
      assumptions.add(PlacementAssumption.noWindows);
      return PlacementResult(const [], assumptions);
    }

    final others = [
      for (final p in plants)
        if (p.id != ignorePlantId) Offset(p.x, p.y),
    ];
    final mid = math.sqrt(math.max(species.dliMin, 0.1) * math.max(species.dliMax, 0.1));
    final candidates = <(double, PlacementOption)>[];

    for (final room in rooms) {
      if (!room.exterior && room.windows.isEmpty) continue;
      final readings = map.readingsIn(room.id);
      final margin = placementMargin(readings);
      for (var i = step / 2; i < room.w; i += step) {
        for (var j = step / 2; j < room.h; j += step) {
          final x = room.x + i;
          final y = room.y + j;
          final spot = Offset(x, y);
          if (others.any((o) => (o - spot).distance < plantClearance)) continue;
          final dli = map.lightAt(x, y, heightCm: heightCm);
          if (dli <= 0) continue;
          final low = dli * (1 - margin);
          final high = dli * (1 + margin);
          final fit = placementFit(low, high, species.dliMin, species.dliMax);

          WindowSpot? nearest;
          var distance = double.infinity;
          for (final w in room.exterior ? const <WindowSpot>[] : room.windows) {
            final d = (AppStore.windowPoint(room, w) - spot).distance;
            if (d < distance) {
              distance = d;
              nearest = w;
            }
          }

          // Primero el ajuste; dentro de cada grupo, lo más cerca del centro
          // del rango (en escala logarítmica) y, a igualdad, lo medido.
          final score = fit.index * 1000 +
              (math.log(dli / mid)).abs() * 10 +
              (readings > 0 ? 0 : 0.5);
          candidates.add((
            score,
            PlacementOption(
              room: room,
              x: x,
              y: y,
              dli: dli,
              low: low,
              high: high,
              margin: margin,
              readings: readings,
              fit: fit,
              window: nearest,
              windowDistance: nearest == null ? null : distance,
              sunHours: map.sunHoursAt(x, y, heightCm: heightCm),
            ),
          ));
        }
      }
    }

    candidates.sort((a, b) => a.$1.compareTo(b.$1));
    final picked = <PlacementOption>[];
    for (final (_, option) in candidates) {
      final spot = Offset(option.x, option.y);
      if (picked.any((p) => (Offset(p.x, p.y) - spot).distance < minSeparation)) continue;
      picked.add(option);
      if (picked.length >= count) break;
    }
    if (picked.any((o) => !o.measured)) assumptions.add(PlacementAssumption.theoretical);
    return PlacementResult(picked, assumptions);
  }

  static bool _compatible(Species species, Room room) {
    if (species.place == 'indoor' && room.exterior) return false;
    if (species.place == 'outdoor' && !room.exterior) return false;
    return true;
  }
}
