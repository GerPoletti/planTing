import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/engine/light_model.dart';
import 'package:plantapp/engine/sun_engine.dart';

// Los valores esperados se calcularon con la misma lógica del prototipo web.
const double _tol = 1e-6;

void main() {
  group('SunEngine', () {
    test('día del año', () {
      expect(SunEngine.dayOfYear(DateTime(2026, 1, 1)), 1);
      expect(SunEngine.dayOfYear(DateTime(2026, 6, 21)), 172);
      expect(SunEngine.dayOfYear(DateTime(2026, 12, 21)), 355);
    });

    test('duración del día', () {
      expect(SunEngine.dayLength(45.5, 172), closeTo(15.49070542579853, _tol));
      expect(SunEngine.dayLength(45.5, 355), closeTo(8.509294574201471, _tol));
      expect(SunEngine.dayLength(-34.6, 355), closeTo(14.32043604123551, _tol));
    });

    test('posición del sol', () {
      final noon = SunEngine.position(45.5, 172, 12);
      expect(noon.elevation, closeTo(67.93978293941629, _tol));
      expect(noon.azimuth, closeTo(180, _tol));
      final morning = SunEngine.position(45.5, 172, 9);
      expect(morning.elevation, closeTo(47.598611873574015, _tol));
      expect(morning.azimuth, closeTo(105.8273546659225, _tol));
    });

    test('horas de sol directo por ventana', () {
      const south = WindowGeometry(azimuth: 180, obstruction: 10);
      const north = WindowGeometry(azimuth: 0, obstruction: 10);
      const east = WindowGeometry(azimuth: 90, obstruction: 10);
      expect(SunEngine.sunHours(south, 45.5, 172), closeTo(6.9, _tol));
      expect(SunEngine.sunHours(south, 45.5, 355), closeTo(5.9, _tol));
      expect(SunEngine.sunHours(north, 45.5, 172), closeTo(2.8, _tol));
      expect(SunEngine.sunHours(east, 45.5, 172), closeTo(6.4, _tol));
    });

    test('hora solar a partir de UTC y longitud', () {
      expect(SunEngine.solarHour(DateTime.utc(2026, 6, 21, 12), 0), closeTo(12, _tol));
      expect(SunEngine.solarHour(DateTime.utc(2026, 6, 21, 12), 9.2), closeTo(12.6133333, 1e-6));
      expect(SunEngine.solarHour(DateTime.utc(2026, 6, 21, 23), 15), closeTo(0, _tol));
      expect(SunEngine.solarHour(DateTime.utc(2026, 6, 21, 2), -45), closeTo(23, _tol));
    });

    test('la franja del día tiene 48 celdas', () {
      const south = WindowGeometry(azimuth: 180, obstruction: 10);
      final strip = SunEngine.litStrip(south, 45.5, 172);
      expect(strip.length, 48);
      expect(strip[24], isTrue); // mediodía
      expect(strip[2], isFalse); // madrugada
    });

    test('promedios mensuales: 12 valores', () {
      const south = WindowGeometry(azimuth: 180, obstruction: 10);
      expect(SunEngine.monthlySunHours(south, 45.5, 2026).length, 12);
    });
  });

  group('LightModel', () {
    test('PPFD y DLI de luz constante', () {
      final ppfd = LightModel.ppfdFromLux(2840, LightSource.sun);
      expect(ppfd, closeTo(52.54, _tol));
      expect(LightModel.dli(ppfd, 12), closeTo(2.269728, _tol));
    });

    test('categorías de luz', () {
      expect(LightModel.category(100), LightCategory.shade);
      expect(LightModel.category(1000), LightCategory.lowIndirect);
      expect(LightModel.category(5000), LightCategory.brightIndirect);
      expect(LightModel.category(20000), LightCategory.direct);
    });

    test('posición de la aguja del dial', () {
      expect(LightModel.dialFraction(5), 0);
      expect(LightModel.dialFraction(10), 0);
      expect(LightModel.dialFraction(500), closeTo(0.25, _tol));
      expect(LightModel.dialFraction(2500), closeTo(0.5, _tol));
      expect(LightModel.dialFraction(10000), closeTo(0.75, _tol));
      expect(LightModel.dialFraction(100000), 1);
      expect(LightModel.dialFraction(1000), inExclusiveRange(0.25, 0.5));
      expect(LightModel.category(LightModel.manualLux(LightCategory.lowIndirect)),
          LightCategory.lowIndirect);
      expect(LightModel.category(LightModel.manualLux(LightCategory.shade)),
          LightCategory.shade);
    });

    test('veredicto frente al rango de la especie', () {
      expect(LightModel.verdict(3, 6, 15), LightVerdict.low);
      expect(LightModel.verdict(8, 6, 15), LightVerdict.ok);
      expect(LightModel.verdict(20, 6, 15), LightVerdict.high);
    });

    test('estimación con sol proyecta al pico del día', () {
      final e = LightModel.estimate(
        lux: 2840,
        source: LightSource.sun,
        latitude: 45.5,
        dayOfYear: 172,
        solarHour: 13,
      );
      expect(e.sunFraction, closeTo(0.9795054536909006, _tol));
      expect(e.peakPpfd, closeTo(53.63931339230693, _tol));
      expect(e.equivalentHours, closeTo(9.861689361985118, _tol));
      expect(e.dli, closeTo(1.904307286554357, _tol));
      expect(e.confidence, Confidence.low);
      expect(e.measuredAtGoodTime, isTrue);
    });

    test('la confianza sube con las mediciones del día', () {
      final e = LightModel.estimate(
        lux: 2840,
        source: LightSource.sun,
        latitude: 45.5,
        dayOfYear: 172,
        solarHour: 13,
        earlierPeaksToday: [50, 55, 52],
      );
      expect(e.samples, 4);
      expect(e.confidence, Confidence.high);
    });

    test('con luz artificial usa el fotoperiodo', () {
      final e = LightModel.estimate(
        lux: 2840,
        source: LightSource.ledCool,
        latitude: 45.5,
        dayOfYear: 172,
        solarHour: 13,
      );
      expect(e.artificial, isTrue);
      expect(e.dli, closeTo(2840 * 0.017 * 12 * 3.6 / 1000, _tol));
    });

    test('medición con el sol muy bajo no es confiable', () {
      final e = LightModel.estimate(
        lux: 500,
        source: LightSource.sun,
        latitude: 45.5,
        dayOfYear: 172,
        solarHour: 4.5,
      );
      expect(e.measuredAtGoodTime, isFalse);
    });

    test('DLI de ventana interior y exterior', () {
      expect(
        LightModel.windowDli(sunHours: 5, dayLength: 15.5, exterior: false),
        closeTo(5.823, _tol),
      );
      expect(
        LightModel.windowDli(sunHours: 10, dayLength: 15.5, exterior: true),
        closeTo(23.58, _tol),
      );
    });

    test('caída de la luz con la distancia', () {
      expect(LightModel.distanceFalloff(0), closeTo(1, _tol));
      expect(LightModel.distanceFalloff(1.3), closeTo(0.5, _tol));
    });

    test('factor de calibración por ambiente', () {
      expect(LightModel.calibrationFactor([]), 1);
      expect(LightModel.calibrationFactor([2]), closeTo(1.5, _tol));
      expect(
        LightModel.calibrationFactor([1.5, 2, 0.9]),
        closeTo(1.2943574875628752, _tol),
      );
    });
  });
}
