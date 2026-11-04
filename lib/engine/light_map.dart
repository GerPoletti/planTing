import 'dart:ui' show Offset;

import '../data/content.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'light_model.dart';
import 'sun_engine.dart';

const Map<String, double> _wallAngle = {'t': 0, 'r': 90, 'b': 180, 'l': 270};

/// Hacia dónde mira una ventana, en grados desde el norte. Depende de la pared
/// del plano donde está y de hacia dónde mira la pared de arriba del plano.
double windowAzimuth(WindowSpot window, double northOffset) {
  return ((_wallAngle[window.wall] ?? 0) + northOffset) % 360;
}

/// Lugar sugerido para una planta.
class SpotSuggestion {
  const SpotSuggestion({
    required this.room,
    required this.x,
    required this.y,
    required this.dli,
    required this.inRange,
  });

  final Room room;
  final double x;
  final double y;
  final double dli;

  /// La luz estimada cae dentro del rango que la especie necesita.
  final bool inRange;
}

/// Mapa de luz de la casa para un día. Combina la geometría solar de cada
/// ventana, la caída de la luz con la distancia y el ajuste que se aprende
/// de las mediciones guardadas.
class LightMap {
  LightMap({
    required this.rooms,
    required this.readings,
    required this.northOffset,
    required this.latitude,
    required this.dayOfYear,
  }) {
    final length = SunEngine.dayLength(latitude, dayOfYear);
    for (final room in rooms) {
      for (final w in room.windows) {
        final geometry = WindowGeometry(
          azimuth: windowAzimuth(w, northOffset),
          obstruction: w.obstruction,
        );
        final hours = SunEngine.sunHours(geometry, latitude, dayOfYear);
        _sunHours[w.id] = hours;
        _windowDli[w.id] = LightModel.windowDli(
          sunHours: hours,
          dayLength: length,
          exterior: room.exterior,
        );
      }
    }
    _calibrate();
  }

  final List<Room> rooms;
  final List<Reading> readings;
  final double northOffset;
  final double latitude;
  final int dayOfYear;

  final Map<String, double> _sunHours = {};
  final Map<String, double> _windowDli = {};
  final Map<String, double> _roomFactor = {};
  final Map<String, int> _roomReadings = {};

  /// Horas de sol directo de hoy en una ventana.
  double sunHoursOf(String windowId) => _sunHours[windowId] ?? 0;

  /// DLI estimado junto a una ventana, sin el ajuste de las mediciones.
  double windowDliOf(String windowId) => _windowDli[windowId] ?? 0;

  /// Ajuste aprendido de las mediciones de un ambiente (1 si no hay).
  double factorOf(String roomId) => _roomFactor[roomId] ?? 1;

  /// Cantidad de mediciones con sol que se usaron en un ambiente.
  int readingsIn(String roomId) => _roomReadings[roomId] ?? 0;

  Room? roomAt(double x, double y) {
    for (final r in rooms) {
      if (r.contains(x, y)) return r;
    }
    return null;
  }

  final Map<String, double> _byDay = {};

  /// DLI junto a una ventana en un día cualquiera del año (con memoria).
  double _windowDliOnDay(Room room, WindowSpot w, int doy) {
    if (doy == dayOfYear) return _windowDli[w.id] ?? 0;
    return _byDay.putIfAbsent('${w.id}:$doy', () {
      final geometry = WindowGeometry(
        azimuth: windowAzimuth(w, northOffset),
        obstruction: w.obstruction,
      );
      return LightModel.windowDli(
        sunHours: SunEngine.sunHours(geometry, latitude, doy),
        dayLength: SunEngine.dayLength(latitude, doy),
        exterior: room.exterior,
      );
    });
  }

  /// DLI previsto en un punto para un día, sin ajuste.
  double _raw(double x, double y, [int? doy]) {
    final room = roomAt(x, y);
    if (room == null) return 0;
    var total = 0.0;
    for (final w in room.windows) {
      final p = AppStore.windowPoint(room, w);
      final distance = (Offset(x, y) - p).distance;
      total += _windowDliOnDay(room, w, doy ?? dayOfYear) * LightModel.distanceFalloff(distance);
    }
    return total;
  }

  void _calibrate() {
    final ratios = <String, List<double>>{};
    for (final r in readings) {
      if (!r.isSun || r.manual || r.saturated || r.x == null || r.y == null) continue;
      final room = roomAt(r.x!, r.y!);
      if (room == null) continue;
      // Se compara con lo previsto para el día en que se midió.
      final predicted = _raw(r.x!, r.y!, SunEngine.dayOfYear(r.at));
      if (predicted <= 0.3 || r.dli <= 0) continue;
      ratios.putIfAbsent(room.id, () => []).add(r.dli / predicted);
    }
    ratios.forEach((roomId, list) {
      _roomFactor[roomId] = LightModel.calibrationFactor(list);
      _roomReadings[roomId] = list.length;
    });
  }

  /// DLI estimado en un punto del plano, con el ajuste del ambiente.
  double lightAt(double x, double y) {
    final room = roomAt(x, y);
    if (room == null) return 0;
    return _raw(x, y) * factorOf(room.id);
  }

  /// Mejor lugar para una especie: dentro de su rango y lo más cerca del
  /// punto medio. Solo mira ambientes del tipo que le corresponde.
  SpotSuggestion? bestSpot(Species species) {
    final mid = (species.dliMin + species.dliMax) / 2;
    SpotSuggestion? best;
    var bestScore = double.infinity;
    for (final room in rooms) {
      if (species.place == 'indoor' && room.exterior) continue;
      if (species.place == 'outdoor' && !room.exterior) continue;
      for (var i = 0.5; i < room.w; i += 0.5) {
        for (var j = 0.5; j < room.h; j += 0.5) {
          final x = room.x + i;
          final y = room.y + j;
          final v = lightAt(x, y);
          final ok = v >= species.dliMin && v <= species.dliMax;
          final score = (ok ? 0 : 1000) + (v - mid).abs();
          if (score < bestScore) {
            bestScore = score;
            best = SpotSuggestion(room: room, x: x, y: y, dli: v, inRange: ok);
          }
        }
      }
    }
    return best;
  }
}

/// Qué conviene medir ahora.
enum SuggestionKind { neverMeasured, stale, roomWithoutReadings }

class MeasureSuggestion {
  const MeasureSuggestion({
    required this.kind,
    this.plantId,
    this.roomId,
    this.daysAgo,
  });

  final SuggestionKind kind;
  final String? plantId;
  final String? roomId;
  final int? daysAgo;
}

/// Plantas sin mediciones, con mediciones viejas y ambientes sin ninguna,
/// en ese orden de importancia.
List<MeasureSuggestion> measureSuggestions(
  AppStore store, {
  DateTime? now,
  int staleDays = 14,
  int limit = 4,
}) {
  final today = now ?? DateTime.now();
  final result = <MeasureSuggestion>[];

  for (final p in store.plants) {
    final last = store.lastReadingAt(p.id);
    if (last == null) {
      result.add(MeasureSuggestion(kind: SuggestionKind.neverMeasured, plantId: p.id));
    }
  }
  for (final p in store.plants) {
    final last = store.lastReadingAt(p.id);
    if (last != null) {
      final days = today.difference(last).inDays;
      if (days > staleDays) {
        result.add(MeasureSuggestion(kind: SuggestionKind.stale, plantId: p.id, daysAgo: days));
      }
    }
  }
  for (final room in store.rooms) {
    final measured = store.readings.any((r) {
      if (r.x == null || r.y == null) return false;
      return room.contains(r.x!, r.y!);
    });
    if (!measured) {
      result.add(MeasureSuggestion(kind: SuggestionKind.roomWithoutReadings, roomId: room.id));
    }
  }
  return result.take(limit).toList();
}
