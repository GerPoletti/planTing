import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/data/content.dart';
import 'package:plantapp/data/models.dart';
import 'package:plantapp/engine/light_model.dart';
import 'package:plantapp/engine/watering.dart';

Species _species(int waterDays) => Species({
      'id': 's$waterDays',
      'scientific': 'X',
      'dliMin': 4,
      'dliMax': 10,
      'waterDays': waterDays,
      'tempMin': 10,
      'humidityMin': 40,
      'names': {'es': ['X'], 'it': ['X']},
    });

final DateTime _now = DateTime(2026, 6, 15, 10); // verano, hemisferio norte

PlantItem _plant({DateTime? watered, int? interval}) => PlantItem(
      id: 'p',
      speciesId: 'x',
      createdAt: DateTime(2026, 1, 1),
      wateredAt: watered ?? DateTime(2026, 6, 8),
      careIntervalDays: interval,
    );

MoistureReading _m(MoistureLevel level, DateTime at) =>
    MoistureReading(id: 'm${at.millisecondsSinceEpoch}', plantId: 'p', at: at, level: level);

void main() {
  group('Grupos y estaciones', () {
    test('grupo según los días entre riegos', () {
      expect(WateringEngine.groupOf(_species(14)), ThirstGroup.succulent);
      expect(WateringEngine.groupOf(_species(12)), ThirstGroup.succulent);
      expect(WateringEngine.groupOf(_species(7)), ThirstGroup.average);
      expect(WateringEngine.groupOf(_species(5)), ThirstGroup.thirsty);
      expect(WateringEngine.groupOf(_species(3)), ThirstGroup.thirsty);
    });

    test('el invierno pide menos riego, y se invierte en el sur', () {
      expect(WateringEngine.seasonFactor(45, 1), 1.4);
      expect(WateringEngine.seasonFactor(45, 7), 1.0);
      expect(WateringEngine.seasonFactor(45, 4), 1.1);
      expect(WateringEngine.seasonFactor(45, 10), 1.1);
      expect(WateringEngine.seasonFactor(-34, 1), 1.0);
      expect(WateringEngine.seasonFactor(-34, 7), 1.4);
      expect(WateringEngine.seasonFactor(null, 1), 1.4);
    });

    test('intervalo con estación, luz y calor', () {
      final sp = _species(7);
      expect(WateringEngine.intervalDays(species: sp, now: DateTime(2026, 7, 10), latitude: 45), 7);
      expect(WateringEngine.intervalDays(species: sp, now: DateTime(2026, 1, 10), latitude: 45), 10);
      expect(WateringEngine.intervalDays(species: sp, now: DateTime(2026, 7, 10), latitude: 45, lightFactor: 1.15), 8);
      expect(WateringEngine.intervalDays(species: sp, now: DateTime(2026, 7, 10), latitude: 45, hot: true), 6);
      // Un intervalo fijado por la persona se respeta tal cual.
      expect(WateringEngine.intervalDays(species: sp, override: 5, now: DateTime(2026, 1, 10), latitude: 45), 5);
    });

    test('la luz de la planta ajusta el riego', () {
      expect(WateringEngine.lightFactor(LightVerdict.low), 1.15);
      expect(WateringEngine.lightFactor(LightVerdict.high), 0.9);
      expect(WateringEngine.lightFactor(LightVerdict.ok), 1);
      expect(WateringEngine.lightFactor(null), 1);
    });
  });

  group('Próximo riego', () {
    final today = DateTime(2026, 6, 15);

    test('sin revisión usa el calendario', () {
      final due = WateringEngine.nextDue(species: _species(7), plant: _plant(), latitude: 45, now: _now);
      expect(due, DateTime(2026, 6, 15));
    });

    test('tierra seca: hoy', () {
      final due = WateringEngine.nextDue(
        species: _species(7),
        plant: _plant(watered: DateTime(2026, 6, 14)),
        moisture: _m(MoistureLevel.dry, DateTime(2026, 6, 15, 9)),
        latitude: 45,
        now: _now,
      );
      expect(due, today);
    });

    test('tierra húmeda o mojada: se posterga', () {
      final plant = _plant(watered: DateTime(2026, 6, 14));
      DateTime due(MoistureLevel l) => WateringEngine.nextDue(
            species: _species(7),
            plant: plant,
            moisture: _m(l, DateTime(2026, 6, 15, 9)),
            latitude: 45,
            now: _now,
          );
      expect(due(MoistureLevel.moist), today.add(const Duration(days: 3)));
      expect(due(MoistureLevel.wet), today.add(const Duration(days: 4)));
    });

    test('seca arriba depende de la especie', () {
      DateTime due(int days) => WateringEngine.nextDue(
            species: _species(days),
            plant: _plant(watered: DateTime(2026, 6, 14)),
            moisture: _m(MoistureLevel.drying, DateTime(2026, 6, 15, 9)),
            latitude: 45,
            now: _now,
          );
      expect(due(14), today.add(const Duration(days: 4)));
      expect(due(7), today.add(const Duration(days: 1)));
      expect(due(3), today);
    });

    test('una revisión vieja o anterior al riego se ignora', () {
      final plant = _plant(watered: DateTime(2026, 6, 12));
      final old = WateringEngine.nextDue(
        species: _species(7),
        plant: plant,
        moisture: _m(MoistureLevel.dry, DateTime(2026, 6, 1)),
        latitude: 45,
        now: _now,
      );
      expect(old, DateTime(2026, 6, 19)); // calendario
      final beforeWatering = WateringEngine.nextDue(
        species: _species(7),
        plant: plant,
        moisture: _m(MoistureLevel.dry, DateTime(2026, 6, 11)),
        latitude: 45,
        now: _now,
      );
      expect(beforeWatering, DateTime(2026, 6, 19));
    });
  });

  group('Recomendación', () {
    WateringAdvice advise(
      int days,
      MoistureLevel level, {
      DateTime? watered,
      DateTime? at,
    }) =>
        WateringEngine.advise(
          species: _species(days),
          plant: _plant(watered: watered ?? DateTime(2026, 6, 14)),
          recentMoisture: [_m(level, at ?? DateTime(2026, 6, 15, 9))],
          latitude: 45,
          now: _now,
        );

    test('tierra seca: regar hoy', () {
      final a = advise(7, MoistureLevel.dry);
      expect(a.action, WateringAction.waterNow);
      expect(a.reason, WateringReason.moistureDry);
    });

    test('seca arriba: succulenta espera, promedio pronto, sedienta hoy', () {
      expect(advise(14, MoistureLevel.drying).action, WateringAction.wait);
      expect(advise(7, MoistureLevel.drying).action, WateringAction.waterSoon);
      expect(advise(3, MoistureLevel.drying).action, WateringAction.waterNow);
    });

    test('húmeda: esperar', () {
      final a = advise(7, MoistureLevel.moist);
      expect(a.action, WateringAction.wait);
      expect(a.reason, WateringReason.moistureMoist);
    });

    test('mojada: esperar, y si sigue mojada días después, revisar el drenaje', () {
      expect(advise(7, MoistureLevel.wet).reason, WateringReason.moistureWet);
      final persistent = WateringEngine.advise(
        species: _species(7),
        plant: _plant(watered: DateTime(2026, 6, 10)),
        recentMoisture: [
          _m(MoistureLevel.wet, DateTime(2026, 6, 15, 9)),
          _m(MoistureLevel.wet, DateTime(2026, 6, 12, 9)),
        ],
        latitude: 45,
        now: _now,
      );
      expect(persistent.reason, WateringReason.drainage);
    });

    test('lluvia fuerte en una planta de exterior: no regar', () {
      final a = WateringEngine.advise(
        species: _species(7),
        plant: _plant(),
        latitude: 45,
        now: _now,
        exterior: true,
        rainTodayMm: 8,
      );
      expect(a.action, WateringAction.skipRain);
      final indoor = WateringEngine.advise(
        species: _species(7),
        plant: _plant(),
        latitude: 45,
        now: _now,
        rainTodayMm: 8,
      );
      expect(indoor.action, isNot(WateringAction.skipRain));
    });

    test('sin revisión reciente decide el calendario', () {
      WateringAdvice byCalendar(DateTime watered) => WateringEngine.advise(
            species: _species(7),
            plant: _plant(watered: watered),
            latitude: 45,
            now: _now,
          );
      expect(byCalendar(DateTime(2026, 6, 8)).action, WateringAction.waterNow);
      expect(byCalendar(DateTime(2026, 6, 8)).reason, WateringReason.scheduleDue);
      expect(byCalendar(DateTime(2026, 6, 9)).action, WateringAction.check);
      expect(byCalendar(DateTime(2026, 6, 12)).action, WateringAction.wait);
    });
  });

  test('los medidores se pasan al nivel más cercano', () {
    expect(MoistureLevel.fromMeter(10), MoistureLevel.dry);
    expect(MoistureLevel.fromMeter(30), MoistureLevel.drying);
    expect(MoistureLevel.fromMeter(60), MoistureLevel.moist);
    expect(MoistureLevel.fromMeter(90), MoistureLevel.wet);
  });
}
