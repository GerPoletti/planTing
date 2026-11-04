import 'dart:math' as math;

/// Posición del sol: elevación sobre el horizonte y azimut
/// (0° = norte, sentido horario).
class SunPosition {
  const SunPosition(this.elevation, this.azimuth);

  final double elevation;
  final double azimuth;
}

/// Ventana de la casa: hacia dónde mira (azimut en grados) y la obstrucción,
/// que es la altura de edificios o árboles sobre el horizonte, en grados.
class WindowGeometry {
  const WindowGeometry({required this.azimuth, this.obstruction = 0});

  final double azimuth;
  final double obstruction;
}

/// Cálculos solares sin dependencias de Flutter. Todas las horas son
/// horas solares (12 = mediodía solar).
class SunEngine {
  const SunEngine._();

  static const double _rad = math.pi / 180;

  /// Día del año de 1 a 366, sin depender de la zona horaria ni del horario de verano.
  static int dayOfYear(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final start = DateTime.utc(date.year, 1, 1);
    return day.difference(start).inDays + 1;
  }

  /// Hora solar aproximada a partir de la hora UTC y la longitud
  /// (no corrige la ecuación del tiempo, que es de unos minutos).
  static double solarHour(DateTime utc, double longitude) {
    final h = utc.hour + utc.minute / 60 + utc.second / 3600 + longitude / 15;
    return h % 24;
  }

  /// Declinación solar en radianes.
  static double declination(int dayOfYear) {
    return 23.44 * math.sin(2 * math.pi * (284 + dayOfYear) / 365) * _rad;
  }

  /// Horas de luz solar del día en la latitud dada.
  static double dayLength(double latitude, int dayOfYear) {
    final c = -math.tan(latitude * _rad) * math.tan(declination(dayOfYear));
    if (c >= 1) return 0;
    if (c <= -1) return 24;
    return 24 / math.pi * math.acos(c);
  }

  /// Posición del sol a una hora solar dada.
  static SunPosition position(double latitude, int dayOfYear, double solarHour) {
    final dc = declination(dayOfYear);
    final hourAngle = (solarHour - 12) * 15 * _rad;
    final la = latitude * _rad;
    final elevation = math.asin(
      math.sin(la) * math.sin(dc) +
          math.cos(la) * math.cos(dc) * math.cos(hourAngle),
    );
    final azimuth = (math.atan2(
              math.sin(hourAngle),
              math.cos(hourAngle) * math.sin(la) - math.tan(dc) * math.cos(la),
            ) /
            _rad +
        180) %
        360;
    return SunPosition(elevation / _rad, azimuth);
  }

  /// Fracción del pico de luz del día a esa hora, siguiendo una curva senoidal
  /// entre la salida y la puesta del sol. Es 0 de noche.
  static double fractionOfPeak(double latitude, int dayOfYear, double solarHour) {
    final length = dayLength(latitude, dayOfYear);
    final sunrise = 12 - length / 2;
    if (solarHour > sunrise && solarHour < sunrise + length) {
      return math.sin(math.pi * (solarHour - sunrise) / length);
    }
    return 0;
  }

  /// Indica si el sol pega de frente en la ventana a esa hora.
  static bool isLit(
    WindowGeometry window,
    double latitude,
    int dayOfYear,
    double solarHour,
  ) {
    final sun = position(latitude, dayOfYear, solarHour);
    final horizon = math.max(3.0, window.obstruction);
    return sun.elevation > horizon &&
        math.cos((sun.azimuth - window.azimuth) * _rad) > 0.17;
  }

  /// Horas de sol directo del día en la ventana, con paso de 6 minutos.
  static double sunHours(WindowGeometry window, double latitude, int dayOfYear) {
    var count = 0;
    for (var i = 0; i < 240; i++) {
      if (isLit(window, latitude, dayOfYear, i / 10)) count++;
    }
    return count / 10;
  }

  /// Franja del día en celdas de 30 minutos: true cuando el sol entra.
  static List<bool> litStrip(
    WindowGeometry window,
    double latitude,
    int dayOfYear, {
    int cells = 48,
  }) {
    final step = 24 / cells;
    return List<bool>.generate(
      cells,
      (i) => isLit(window, latitude, dayOfYear, i * step + step / 2),
    );
  }

  /// Horas de sol directo para cada mes (día 15), para el gráfico anual.
  static List<double> monthlySunHours(
    WindowGeometry window,
    double latitude,
    int year,
  ) {
    return List<double>.generate(
      12,
      (m) => sunHours(window, latitude, dayOfYear(DateTime(year, m + 1, 15))),
    );
  }
}
