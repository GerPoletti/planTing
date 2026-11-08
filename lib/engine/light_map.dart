import 'dart:math' as math;

import '../data/content.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'light_model.dart';
import 'sun_engine.dart';
import '../data/dates.dart';

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

/// Posición del sol en un instante, ya pasada a direcciones del plano.
class _SunSample {
  const _SunSample(this.elevation, this.tanElevation, this.cosElevation, this.sinElevation,
      this.beam, this.dx, this.dy);

  /// Elevación en grados.
  final double elevation;
  final double tanElevation;
  final double cosElevation;
  final double sinElevation;

  /// PPFD del sol de frente con cielo despejado.
  final double beam;

  /// Dirección horizontal hacia el sol en el plano (x a la derecha, y hacia abajo).
  final double dx;
  final double dy;
}

/// Mapa de luz de la casa para un día. Calcula, para cada punto y altura:
/// - En interiores: el sol directo que entra por cada ventana según su alféizar,
///   su borde superior y su ancho, y la luz del cielo que se ve por ella.
/// - En exteriores: el sol y el cielo que dejan pasar sus lados (pared, baranda
///   o abierto), el techo si lo tiene y los edificios o árboles alrededor.
/// Después aplica el ajuste que se aprende de las mediciones guardadas.
class LightMap {
  LightMap({
    required this.rooms,
    required this.readings,
    required this.northOffset,
    required this.latitude,
    required this.dayOfYear,
    DateTime? now,
  }) : now = now ?? DateTime.now() {
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

  /// Momento de referencia para la vigencia de las mediciones.
  final DateTime now;

  static const double _rad = math.pi / 180;

  /// Paso entre muestras del sol, en horas.
  static const double _step = 0.1;

  final Map<String, double> _sunHours = {};
  final Map<String, double> _windowDli = {};
  final Map<String, double> _roomFactor = {};
  final Map<String, int> _roomReadings = {};
  final Map<int, List<_SunSample>> _samples = {};
  final Map<String, (double, double)> _memo = {};

  /// Horas de sol directo de hoy en una ventana (sin tener en cuenta alturas).
  double sunHoursOf(String windowId) => _sunHours[windowId] ?? 0;

  /// DLI de referencia junto a una ventana, para su ficha.
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

  /// Sol del día en pasos de 6 minutos, solo con el sol sobre el horizonte.
  List<_SunSample> _sunOf(int doy) => _samples.putIfAbsent(doy, () {
        final list = <_SunSample>[];
        for (var i = 0; i < 24 / _step; i++) {
          final sun = SunEngine.position(latitude, doy, i * _step + _step / 2);
          if (sun.elevation <= 0) continue;
          final rel = (sun.azimuth - northOffset) * _rad;
          final e = sun.elevation * _rad;
          list.add(_SunSample(
            sun.elevation,
            math.tan(math.min(sun.elevation, 89.5) * _rad),
            math.cos(e),
            math.sin(e),
            LightModel.beamPpfd(sun.elevation),
            math.sin(rel),
            -math.cos(rel),
          ));
        }
        return list;
      });

  /// Normal hacia afuera de una pared del plano.
  static (double, double) _normal(String wall) => switch (wall) {
        'r' => (1.0, 0.0),
        'b' => (0.0, 1.0),
        'l' => (-1.0, 0.0),
        _ => (0.0, -1.0),
      };

  /// Fracción de la luz del cielo que recibe una superficie horizontal desde
  /// un sector que va de [low] a [high] grados de elevación y abarca [span]
  /// radianes de azimut (cielo uniforme).
  static double _skyFraction(double low, double high, double span) {
    final lo = math.max(0.0, low) * _rad;
    final hi = math.min(90.0, high) * _rad;
    if (hi <= lo) return 0;
    final f = math.pow(math.sin(hi), 2) - math.pow(math.sin(lo), 2);
    return span * f / (2 * math.pi);
  }

  /// Fracción de la luz del cielo que recibe una superficie vertical que mira
  /// hacia una ventana, vista entre las elevaciones [low] y [high] (grados) y
  /// entre los ángulos laterales [left] y [right] (radianes). Vale 0,5 con
  /// todo el cielo de enfrente a la vista.
  static double _windowSky(double low, double high, double left, double right) {
    final lo = math.max(0.0, low) * _rad;
    final hi = math.min(90.0, high) * _rad;
    if (hi <= lo || right <= left) return 0;
    double g(double a) => (a + math.sin(a) * math.cos(a)) / 2;
    return (math.sin(right) - math.sin(left)) * (g(hi) - g(lo)) / math.pi;
  }

  /// Horas de sol directo y DLI previsto (sin ajuste) en un punto y altura.
  (double, double) _point(Room room, double x, double y, double heightCm, int doy) {
    final key = '${room.id}:${x.toStringAsFixed(2)}:${y.toStringAsFixed(2)}:${heightCm.round()}:$doy';
    final cached = _memo[key];
    if (cached != null) return cached;
    final result = room.exterior
        ? _outdoor(room, x, y, heightCm / 100, doy)
        : _indoor(room, x, y, heightCm / 100, doy);
    _memo[key] = result;
    return result;
  }

  (double, double) _indoor(Room room, double x, double y, double h, int doy) {
    if (room.windows.isEmpty) return (0, 0);
    final sun = _sunOf(doy);
    final length = SunEngine.dayLength(latitude, doy);
    // Por cada momento del día, el sol que llega por la ventana que más deja pasar.
    final lit = List<double>.filled(sun.length, 0);
    var sky = 0.0;
    for (final w in room.windows) {
      final p = AppStore.windowPoint(room, w);
      final (nx, ny) = _normal(w.wall);
      final (tx, ty) = (-ny, nx);
      final vx = p.dx - x;
      final vy = p.dy - y;
      final d = math.max(0.05, vx * nx + vy * ny); // distancia a la pared
      final lat = -(vx * tx + vy * ty); // corrimiento lateral respecto del centro
      final sill = w.sillCm / 100;
      final top = math.max(w.topCm, w.sillCm + 10) / 100;
      final half = math.max(w.widthCm, 20) / 200;
      final horizon = math.max(3.0, w.obstruction);

      // Sol directo: el rayo hacia el sol tiene que pasar por el hueco.
      for (var i = 0; i < sun.length; i++) {
        final s = sun[i];
        if (s.elevation <= horizon) continue;
        final cosRel = s.dx * nx + s.dy * ny;
        if (cosRel <= 0.17) continue;
        final t = d / cosRel;
        final z = h + t * s.tanElevation;
        if (z < sill || z > top) continue;
        final side = lat + t * (s.dx * tx + s.dy * ty);
        if (side.abs() > half) continue;
        // Hoja que mira hacia la ventana: el sol llega inclinado.
        final ppfd = s.beam * s.cosElevation * cosRel * LightModel.glassTransmission;
        if (ppfd > lit[i]) lit[i] = ppfd;
      }

      // Cielo visible por la ventana, para una hoja que mira hacia ella.
      final low = math.max(math.atan2(sill - h, d) / _rad, w.obstruction);
      final high = math.atan2(top - h, d) / _rad;
      sky += _windowSky(
        low,
        high,
        math.atan2(lat - half, d),
        math.atan2(lat + half, d),
      );
    }
    final sunHours = lit.where((v) => v > 0).length * _step;
    final direct = lit.fold<double>(0, (a, b) => a + b) * _step * LightModel.sunnyFraction;
    final ppfdHours = direct +
        length * LightModel.skyPpfd(latitude, doy) * LightModel.glassTransmission * math.min(sky, 1.0);
    return (sunHours, ppfdHours * 3.6 / 1000);
  }

  /// Distancia horizontal desde (x, y) hasta el borde del ambiente en la
  /// dirección (dx, dy), y el lado por el que sale.
  static (double, String) _exit(Room r, double x, double y, double dx, double dy) {
    var best = double.infinity;
    var side = 't';
    if (dx > 1e-9) {
      final t = (r.x + r.w - x) / dx;
      if (t < best) {
        best = t;
        side = 'r';
      }
    } else if (dx < -1e-9) {
      final t = (r.x - x) / dx;
      if (t < best) {
        best = t;
        side = 'l';
      }
    }
    if (dy > 1e-9) {
      final t = (r.y + r.h - y) / dy;
      if (t < best) {
        best = t;
        side = 'b';
      }
    } else if (dy < -1e-9) {
      final t = (r.y - y) / dy;
      if (t < best) {
        best = t;
        side = 't';
      }
    }
    return (math.max(0.01, best), side);
  }

  /// Elevación mínima que deja ver un lado a una distancia [t] desde la altura [h].
  static double _sideBlock(Room r, String side, double t, double h) {
    final height = switch (r.sideOf(side)) {
      SideType.open => 0.0,
      SideType.railing => r.railingCm / 100,
      _ => r.wallCm / 100,
    };
    if (height <= h) return 0;
    return math.atan2(height - h, t) / _rad;
  }

  (double, double) _outdoor(Room room, double x, double y, double h, int doy) {
    final sun = _sunOf(doy);
    final length = SunEngine.dayLength(latitude, doy);
    final roof = room.wallCm / 100;
    final covered = room.covered && h < roof;
    final horizon = math.max(3.0, room.skyObstruction);

    var sunHours = 0.0;
    var direct = 0.0;
    for (final s in sun) {
      if (s.elevation <= horizon) continue;
      final (t, side) = _exit(room, x, y, s.dx, s.dy);
      if (s.elevation <= _sideBlock(room, side, t, h)) continue;
      if (covered && h + t * s.tanElevation > roof) continue; // pega en el techo
      sunHours += _step;
      direct += s.beam * s.sinElevation * _step; // superficie horizontal
    }

    var sky = 0.0;
    const sectors = 16;
    for (var k = 0; k < sectors; k++) {
      final a = (k + 0.5) * 2 * math.pi / sectors;
      final (t, side) = _exit(room, x, y, math.sin(a), -math.cos(a));
      final low = math.max(room.skyObstruction, _sideBlock(room, side, t, h));
      final high = covered ? math.atan2(roof - h, t) / _rad : 90.0;
      sky += _skyFraction(low, high, 2 * math.pi / sectors);
    }
    final ppfdHours = direct * LightModel.sunnyFraction +
        length * LightModel.skyPpfd(latitude, doy) * math.min(sky, 1.0);
    return (sunHours, ppfdHours * 3.6 / 1000);
  }

  /// Mediciones que pueden ajustar el mapa: con sol, con sensor, sin saturar,
  /// con posición y con el sol lo bastante alto para proyectar el día. Las
  /// repetidas (a menos de 50 cm y de 30 minutos de otra) cuentan una sola vez,
  /// para que repetir la misma medición no aumente la confianza.
  ///
  /// Usa la misma regla de lectura utilizable que la ficha
  /// ([AppStore.isUsableReading]), con vigencia de [maxAgeDays] días: una
  /// medición de hace años no describe la casa de hoy. Dos lecturas solo son
  /// repetidas si además están en el mismo ambiente ([roomOf]) y a menos de
  /// 15 cm de altura entre sí.
  static List<Reading> independentReadings(
    Iterable<Reading> all, {
    DateTime? now,
    int maxAgeDays = 365,
    String? Function(Reading r)? roomOf,
  }) {
    final today = now ?? DateTime.now();
    final list = all
        .where((r) => r.isSun && AppStore.isUsableReading(r, today, maxAgeDays: maxAgeDays))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    // El ambiente de cada lectura se calcula una sola vez.
    final roomById = <Reading, String?>{for (final r in list) r: roomOf?.call(r)};
    final kept = <Reading>[];
    for (final r in list) {
      final room = roomById[r];
      final height = r.heightCm ?? defaultPlantHeightCm;
      final repeated = kept.any((k) {
        if (roomById[k] != room) return false;
        if (((k.heightCm ?? defaultPlantHeightCm) - height).abs() > 15) return false;
        final dx = k.x! - r.x!;
        final dy = k.y! - r.y!;
        return dx * dx + dy * dy < 0.25 && r.at.difference(k.at).inMinutes.abs() < 30;
      });
      if (!repeated) kept.add(r);
    }
    return kept;
  }

  void _calibrate() {
    final ratios = <String, List<double>>{};
    for (final r in independentReadings(readings, now: now, roomOf: (r) => roomAt(r.x!, r.y!)?.id)) {
      final room = roomAt(r.x!, r.y!);
      if (room == null) continue;
      // Se compara con lo previsto para el día y la altura en que se midió.
      final (_, predicted) = _point(
        room,
        r.x!,
        r.y!,
        r.heightCm ?? defaultPlantHeightCm,
        SunEngine.dayOfYear(r.at),
      );
      if (predicted <= 0.3) continue;
      ratios.putIfAbsent(room.id, () => []).add(r.dli / predicted);
    }
    ratios.forEach((roomId, list) {
      _roomFactor[roomId] = LightModel.calibrationFactor(list);
      _roomReadings[roomId] = list.length;
    });
  }

  /// DLI estimado en un punto del plano y a una altura (cm desde el piso),
  /// con el ajuste del ambiente.
  double lightAt(double x, double y, {double? heightCm}) {
    final room = roomAt(x, y);
    if (room == null) return 0;
    final (_, dli) = _point(room, x, y, heightCm ?? defaultPlantHeightCm, dayOfYear);
    return dli * factorOf(room.id);
  }

  /// Horas de sol directo de hoy en un punto y a una altura.
  double sunHoursAt(double x, double y, {double? heightCm}) {
    final room = roomAt(x, y);
    if (room == null) return 0;
    final (hours, _) = _point(room, x, y, heightCm ?? defaultPlantHeightCm, dayOfYear);
    return hours;
  }

  /// Mejor lugar para una especie: dentro de su rango y lo más cerca del
  /// punto medio. Solo mira ambientes del tipo que le corresponde.
  SpotSuggestion? bestSpot(Species species, {double? heightCm}) {
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
          final v = lightAt(x, y, heightCm: heightCm);
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
    final last = store.lastPlantReading(p.id, now: today)?.at;
    if (last == null) {
      result.add(MeasureSuggestion(kind: SuggestionKind.neverMeasured, plantId: p.id));
    }
  }
  for (final p in store.plants) {
    final last = store.lastPlantReading(p.id, now: today)?.at;
    if (last != null) {
      final days = daysBetween(last, today);
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
