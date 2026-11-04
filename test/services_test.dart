import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/data/content.dart';
import 'package:plantapp/data/models.dart';
import 'package:plantapp/data/store.dart';
import 'package:plantapp/services/compass_service.dart';
import 'package:plantapp/services/location_service.dart';
import 'package:plantapp/services/reminders.dart';
import 'package:plantapp/services/weather_service.dart';

const _openMeteoSample = {
  'latitude': 45.5,
  'longitude': 9.2,
  'current': {
    'time': '2026-10-31T10:00',
    'temperature_2m': 14.2,
    'relative_humidity_2m': 71,
  },
  'daily': {
    'time': ['2026-10-31', '2026-11-01', '2026-11-02'],
    'temperature_2m_max': [16.1, 15.0, 36.2],
    'temperature_2m_min': [8.2, 7.0, 3.1],
    'precipitation_sum': [6.5, 2.3, 0.0],
  },
};

Content _miniContent() => Content.fromJson(
      species: {
        'species': [
          {
            'id': 'potus',
            'scientific': 'Epipremnum aureum',
            'names': {'es': ['Potus'], 'it': ['Pothos']},
            'dliMin': 4,
            'dliMax': 10,
            'waterDays': 7,
            'tempMin': 12,
            'humidityMin': 40,
            'toxicToPets': true,
          }
        ]
      },
      pests: {'pests': []},
      consultorio: {'symptoms': []},
    );

void main() {
  group('Ubicación y brújula', () {
    test('las coordenadas se redondean a una décima', () {
      expect(LocationService.round1(45.4642), 45.5);
      expect(LocationService.round1(9.1859), 9.2);
      expect(LocationService.round1(-34.6037), -34.6);
    });

    test('se ajusta al punto cardinal más cercano', () {
      expect(CompassService.snapToEight(268), 270);
      expect(CompassService.snapToEight(-10), 0);
      expect(CompassService.snapToEight(22), 0);
      expect(CompassService.snapToEight(23), 45);
      expect(CompassService.snapToEight(359), 0);
    });

    test('el promedio de ángulos cruza el norte sin errores', () {
      final mean = CompassService.circularMean([350, 10]);
      final distance = mean < 180 ? mean : 360 - mean;
      expect(distance, closeTo(0, 1e-6));
      expect(CompassService.circularMean([80, 100]), closeTo(90, 1e-6));
    });
  });

  group('Clima', () {
    test('interpreta la respuesta de Open-Meteo', () {
      final w = WeatherSnapshot.fromOpenMeteo(
        Map<String, dynamic>.from(_openMeteoSample),
        DateTime(2026, 10, 31, 10),
      );
      expect(w.currentTemp, 14.2);
      expect(w.currentHumidity, 71);
      expect(w.days.length, 3);
      expect(w.days[2].min, 3.1);
      expect(w.days[0].precipitationMm, 6.5);
    });

    test('se guarda y se lee igual', () {
      final w = WeatherSnapshot.fromOpenMeteo(
        Map<String, dynamic>.from(_openMeteoSample),
        DateTime(2026, 10, 31, 10),
      );
      final again = WeatherSnapshot.fromJson(w.toJson());
      expect(again.days.length, 3);
      expect(again.currentTemp, 14.2);
      expect(again.fetchedAt, w.fetchedAt);
    });

    test('alertas de frío, calor y lluvia para plantas de exterior', () {
      final w = WeatherSnapshot.fromOpenMeteo(
        Map<String, dynamic>.from(_openMeteoSample),
        DateTime(2026, 10, 31, 10),
      );
      final alerts = computeWeatherAlerts(w, const [
        ExteriorPlant('echeveria', 5),
        ExteriorPlant('lavanda', -5),
      ]);
      final cold = alerts.where((a) => a.type == WeatherAlertType.cold).toList();
      expect(cold.length, 1);
      expect(cold.first.plantIds, ['echeveria']); // 3,1 °C < 5 °C, pero no < -5 °C
      expect(alerts.where((a) => a.type == WeatherAlertType.heat).length, 1);
      expect(alerts.where((a) => a.type == WeatherAlertType.rain).length, 1);
    });

    test('sin plantas de exterior no hay alertas', () {
      final w = WeatherSnapshot.fromOpenMeteo(
        Map<String, dynamic>.from(_openMeteoSample),
        DateTime(2026, 10, 31, 10),
      );
      expect(computeWeatherAlerts(w, const []), isEmpty);
    });
  });

  group('Recordatorios', () {
    late Directory dir;
    late AppStore store;
    final content = _miniContent();

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mirasol_rem_');
      store = await AppStore.open(directory: dir);
    });

    tearDown(() async {
      store.dispose();
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    test('el riego se avisa el día en que vence', () {
      final now = DateTime(2026, 10, 31, 8);
      // En otoño el intervalo de 7 días pasa a 8 (factor de estación 1,1).
      store.addPlant(speciesId: 'potus', wateredAt: DateTime(2026, 10, 24));
      final plan = planReminders(store, content, now: now);
      expect(plan.length, 1);
      expect(plan.first.day, DateTime(2026, 11, 1));
      expect(plan.first.waterings, 1);
    });

    test('lo atrasado se reúne en el primer día', () {
      final now = DateTime(2026, 10, 31, 8);
      store.addPlant(speciesId: 'potus', wateredAt: DateTime(2026, 10, 10));
      final plan = planReminders(store, content, now: now);
      expect(plan.first.day, DateTime(2026, 10, 31));
      expect(plan.first.waterings, 1);
    });

    test('el modo viaje silencia los avisos y al volver se avisa lo atrasado', () {
      final now = DateTime(2026, 10, 31, 8);
      store.addPlant(speciesId: 'potus', wateredAt: DateTime(2026, 10, 25));
      store.updateSettings((s) => s.travelUntil = DateTime(2026, 11, 3));
      final plan = planReminders(store, content, now: now);
      // Durante el viaje no hay avisos; al volver se reúne lo atrasado.
      expect(plan.first.day, DateTime(2026, 11, 4));
      expect(plan.first.waterings, 1);
      expect(plan.length, 1);
    });

    test('un día sin nada pendiente no genera aviso', () {
      final now = DateTime(2026, 10, 31, 8);
      store.addPlant(speciesId: 'potus', wateredAt: now);
      final plan = planReminders(store, content, now: now, days: 5);
      expect(plan, isEmpty); // vence en 7 días, fuera de la ventana
    });

    test('las tareas de tratamiento se suman a los riegos', () {
      final plant = store.addPlant(speciesId: 'potus', wateredAt: DateTime.now());
      store.startTreatment(plant.id, 'trips', [0, 2]);
      final plan = planReminders(store, content);
      expect(plan.first.tasks, 1);
      final dayTwo = plan.where((d) => d.tasks > 0).toList();
      expect(dayTwo.length, 2);
    });
  });
}
