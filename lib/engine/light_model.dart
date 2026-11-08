import 'dart:math' as math;

import 'sun_engine.dart';

/// Fuente de luz que ilumina la planta.
enum LightSource { sun, ledCool, ledWarm, fluorescent, hps }

extension LightSourceX on LightSource {
  /// Factor aproximado para pasar de lux a PPFD (µmol/m²/s por lux).
  double get ppfdPerLux {
    switch (this) {
      case LightSource.sun:
        return 0.0185;
      case LightSource.ledCool:
        return 0.017;
      case LightSource.ledWarm:
        return 0.014;
      case LightSource.fluorescent:
        return 0.013;
      case LightSource.hps:
        return 0.012;
    }
  }

  bool get isNatural => this == LightSource.sun;
}

/// Categoría de la luz según los lux.
enum LightCategory { shade, lowIndirect, brightIndirect, direct }

/// Resultado de comparar el DLI con lo que necesita una especie.
enum LightVerdict { low, ok, high }

enum Confidence { low, medium, high }

/// Resultado de estimar la luz diaria a partir de una medición puntual.
class DliEstimate {
  const DliEstimate({
    required this.ppfd,
    required this.peakPpfd,
    required this.equivalentHours,
    required this.dli,
    required this.dayLength,
    required this.sunFraction,
    required this.samples,
    required this.artificial,
  });

  /// PPFD de la medición actual.
  final double ppfd;

  /// PPFD estimado en el pico del día (promedio de las mediciones del día).
  final double peakPpfd;

  /// Horas equivalentes a pleno pico: 2/π de la duración del día con sol.
  final double equivalentHours;

  /// Luz diaria acumulada estimada, en mol/m²/día.
  final double dli;

  final double dayLength;

  /// Fracción del pico en la que se midió (0 a 1).
  final double sunFraction;

  /// Cantidad de mediciones de hoy usadas en el promedio.
  final int samples;

  final bool artificial;

  Confidence get confidence {
    if (artificial) return Confidence.low;
    if (samples >= 4) return Confidence.high;
    if (samples >= 2) return Confidence.medium;
    return Confidence.low;
  }

  /// Pico de esta medición sola (sin promediar con las anteriores del día).
  /// Es lo que se guarda, para que los promedios posteriores no se sesguen.
  double get measurementPeak =>
      (artificial || sunFraction <= 0.25) ? ppfd : ppfd / sunFraction;

  /// Con el sol muy bajo la proyección al pico no es confiable.
  bool get measuredAtGoodTime => artificial || sunFraction > 0.25;
}

class LightModel {
  const LightModel._();

  static double ppfdFromLux(double lux, LightSource source) =>
      lux * source.ppfdPerLux;

  /// DLI en mol/m²/día para un PPFD constante durante [hours] horas.
  static double dli(double ppfd, double hours) => ppfd * hours * 3.6 / 1000;

  static LightCategory category(double lux) {
    if (lux < 500) return LightCategory.shade;
    if (lux < 2500) return LightCategory.lowIndirect;
    if (lux < 10000) return LightCategory.brightIndirect;
    return LightCategory.direct;
  }

  /// Posición de la aguja del dial de 0 a 1. Cada categoría ocupa un cuarto
  /// del dial y dentro de cada una la escala es logarítmica.
  static double dialFraction(double lux) {
    const bounds = [10.0, 500.0, 2500.0, 10000.0, 100000.0];
    if (lux <= bounds.first) return 0;
    if (lux >= bounds.last) return 1;
    for (var i = 0; i < 4; i++) {
      if (lux < bounds[i + 1]) {
        final t = math.log(lux / bounds[i]) / math.log(bounds[i + 1] / bounds[i]);
        return (i + t) / 4;
      }
    }
    return 1;
  }

  /// Lux representativos de cada categoría para cargar la luz a ojo.
  static double manualLux(LightCategory c) {
    switch (c) {
      case LightCategory.shade:
        return 200;
      case LightCategory.lowIndirect:
        return 1200;
      case LightCategory.brightIndirect:
        return 5000;
      case LightCategory.direct:
        return 20000;
    }
  }

  static LightVerdict verdict(double dli, double minDli, double maxDli) {
    if (dli < minDli) return LightVerdict.low;
    if (dli > maxDli) return LightVerdict.high;
    return LightVerdict.ok;
  }

  /// Estima el DLI del día. Con luz solar proyecta la medición al pico usando
  /// la hora y la duración del día; con luz artificial usa el fotoperiodo.
  static DliEstimate estimate({
    required double lux,
    required LightSource source,
    required double latitude,
    required int dayOfYear,
    required double solarHour,
    List<double> earlierPeaksToday = const [],
    double artificialHours = 12,
  }) {
    final ppfd = ppfdFromLux(lux, source);
    final length = SunEngine.dayLength(latitude, dayOfYear);

    if (!source.isNatural) {
      return DliEstimate(
        ppfd: ppfd,
        peakPpfd: ppfd,
        equivalentHours: artificialHours,
        dli: dli(ppfd, artificialHours),
        dayLength: length,
        sunFraction: 1,
        samples: 1,
        artificial: true,
      );
    }

    final fraction = SunEngine.fractionOfPeak(latitude, dayOfYear, solarHour);
    final peaks = <double>[...earlierPeaksToday];
    if (fraction > 0.25) peaks.add(ppfd / fraction);
    final samples = peaks.length;
    final peak = samples == 0
        ? ppfd
        : peaks.reduce((a, b) => a + b) / samples;
    final hours = length * 2 / math.pi;

    return DliEstimate(
      ppfd: ppfd,
      peakPpfd: peak,
      equivalentHours: hours,
      dli: dli(peak, hours),
      dayLength: length,
      sunFraction: fraction,
      samples: samples,
      artificial: false,
    );
  }

  /// PPFD estimado del pico de ese día a partir de una medición, o null si el
  /// sol está demasiado bajo para proyectar (fracción menor a 0,25).
  static double? peakFromMeasurement({
    required double ppfd,
    required double sunFraction,
  }) {
    if (sunFraction <= 0.25) return null;
    return ppfd / sunFraction;
  }

  /// DLI estimado en una ventana a partir de sus horas de sol directo.
  /// Los valores de PPFD son supuestos a calibrar con mediciones reales.
  static double windowDli({
    required double sunHours,
    required double dayLength,
    required bool exterior,
  }) {
    final direct = exterior ? 600.0 : 250.0;
    final indirect = exterior ? 100.0 : 35.0;
    return (sunHours * direct + (dayLength - sunHours) * indirect) * 3.6 / 1000;
  }

  // Supuestos del mapa de luz, a calibrar con luxómetro (docs/VALIDACION.md).

  /// Parte de las horas de sol que en promedio están despejadas.
  static const double sunnyFraction = 0.6;

  /// Parte de la luz que pasa por un vidrio.
  static const double glassTransmission = 0.75;

  /// PPFD del sol directo sobre una superficie que lo mira de frente, con
  /// cielo despejado, según la elevación del sol en grados (masa de aire).
  static double beamPpfd(double elevation) {
    if (elevation <= 0) return 0;
    final airMass = 1 / math.max(math.sin(elevation * math.pi / 180), 0.05);
    return 2000 * math.pow(0.7, math.pow(airMass, 0.678)).toDouble();
  }

  /// PPFD medio de la luz del cielo (sin el sol directo) sobre una superficie
  /// horizontal con todo el cielo a la vista. Baja en invierno.
  static double skyPpfd(double latitude, int dayOfYear) {
    final declination = 23.44 * math.sin(2 * math.pi * (284 + dayOfYear) / 365);
    final noon = 90 - (latitude - declination).abs();
    return 60 + 280 * math.sin(math.max(noon, 0) * math.pi / 180);
  }

  /// Cuánta luz queda a [meters] de la ventana respecto de la que hay en ella.
  static double distanceFalloff(double meters) {
    return 1 / (1 + math.pow(meters / 1.3, 2));
  }

  /// Factor de ajuste de un ambiente a partir de los cocientes
  /// medido / previsto. Usa media geométrica y se suaviza con pocas mediciones.
  static double calibrationFactor(Iterable<double> ratios) {
    final list = ratios.map((r) => r.clamp(0.3, 3.0).toDouble()).toList();
    if (list.isEmpty) return 1;
    final meanLog =
        list.map(math.log).fold<double>(0, (a, b) => a + b) / list.length;
    final geometric = math.exp(meanLog);
    return 1 + (geometric - 1) * list.length / (list.length + 1);
  }
}
