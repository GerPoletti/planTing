import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_compass/flutter_compass.dart';

/// Brújula del teléfono para orientar el plano y las ventanas.
class CompassService {
  const CompassService._();

  static double normalize(double degrees) => degrees % 360;

  /// Redondea al punto cardinal más cercano (0, 45, 90, ... 315).
  static double snapToEight(double degrees) {
    return ((normalize(degrees) / 45).round() % 8) * 45.0;
  }

  /// Promedio de ángulos (maneja bien el cruce entre 359° y 1°).
  static double circularMean(List<double> degrees) {
    var s = 0.0;
    var c = 0.0;
    for (final d in degrees) {
      final r = d * math.pi / 180;
      s += math.sin(r);
      c += math.cos(r);
    }
    return normalize(math.atan2(s, c) * 180 / math.pi);
  }

  static Stream<double> headings() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream<double>.empty();
    return events
        .where((e) => e.heading != null)
        .map((e) => normalize(e.heading!));
  }

  /// Lee algunas muestras y devuelve el promedio, o null si no hay brújula.
  static Future<double?> readOnce({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final samples = <double>[];
    try {
      await for (final h in headings().timeout(timeout)) {
        samples.add(h);
        if (samples.length >= 6) break;
      }
    } on TimeoutException {
      // Se usan las muestras que haya.
    }
    if (samples.isEmpty) return null;
    return circularMean(samples);
  }
}
