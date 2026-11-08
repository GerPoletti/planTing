// Pruebas de los cambios del plan aprobado tras la auditoría (puntos 1 a 12).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/data/backup.dart';
import 'package:plantapp/data/content.dart';
import 'package:plantapp/data/models.dart';
import 'package:plantapp/data/store.dart';
import 'package:plantapp/engine/light_map.dart';
import 'package:plantapp/engine/light_model.dart';
import 'package:plantapp/engine/placement.dart';
import 'package:plantapp/engine/watering.dart';
import 'package:plantapp/services/reminders.dart';
import 'package:plantapp/services/weather_service.dart';

Content _content() => Content.fromJson(
      species: {
        'species': [
          {
            'id': 'potus',
            'scientific': 'Epipremnum aureum',
            'names': {'es': ['Potus'], 'it': ['Pothos']},
            'place': 'indoor',
            'dliMin': 4,
            'dliMax': 10,
            'waterDays': 7,
            'tempMin': 12,
            'humidityMin': 40,
            'toxicToPets': true,
          },
          {
            'id': 'cactus',
            'scientific': 'Cactaceae',
            'names': {'es': ['Cactus'], 'it': ['Cactus']},
            'place': 'indoor',
            'dliMin': 15,
            'dliMax': 30,
            'waterDays': 14,
            'tempMin': 5,
            'humidityMin': 20,
          },
        ]
      },
      pests: {'pests': []},
      consultorio: {'symptoms': []},
    );

Reading _reading(
  String plantId, {
  required DateTime at,
  double dli = 5,
  double peak = 300,
  double fraction = 0.9,
  bool probe = false,
  double? x,
  double? y,
}) =>
    Reading(
      id: newId(),
      plantId: plantId,
      at: at,
      lux: 5000,
      source: 'sun',
      ppfd: peak * fraction,
      dli: dli,
      peakPpfd: peak,
      sunFraction: fraction,
      x: x,
      y: y,
      probe: probe,
    );

void main() {
  late Directory dir;
  late AppStore store;
  final content = _content();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mirasol_plan_');
    store = await AppStore.open(directory: dir);
  });

  tearDown(() async {
    store.dispose();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  group('1. Avisos', () {
    test('si el horario de hoy ya pasó, lo atrasado va al próximo horario', () {
      final now = DateTime(2026, 10, 31, 20);
      store.addPlant(speciesId: 'potus', wateredAt: DateTime(2026, 10, 10));
      expect(todaySlotPassed(now, 9, 0), isTrue);
      expect(todaySlotPassed(DateTime(2026, 10, 31, 8), 9, 0), isFalse);
      final plan = planReminders(store, content, now: now, skipToday: true);
      expect(plan.first.day, DateTime(2026, 11, 1));
      expect(plan.first.waterings, 1);
    });

    test('el modo viaje incluye el último día elegido', () {
      final s = Settings(travelUntil: DateTime(2026, 11, 3));
      expect(s.travelingOn(DateTime(2026, 11, 3, 22)), isTrue);
      expect(s.travelingOn(DateTime(2026, 11, 4, 1)), isFalse);
      expect(Settings().travelingOn(DateTime(2026, 11, 4)), isFalse);
    });
  });

  group('2. Clima', () {
    final snapshot = WeatherSnapshot(
      fetchedAt: DateTime(2026, 10, 30, 10),
      latitude: 45.5,
      longitude: 9.2,
      currentTemp: 14,
      currentHumidity: 70,
      days: [
        WeatherDay(date: DateTime(2026, 10, 30), min: -2, max: 10, precipitationMm: 12),
        WeatherDay(date: DateTime(2026, 10, 31), min: 8, max: 15, precipitationMm: 0),
        WeatherDay(date: DateTime(2026, 11, 1), min: 9, max: 16, precipitationMm: 7),
      ],
    );

    test('usa el día que coincide con hoy, no el primero de la copia', () {
      expect(snapshot.dayOf(DateTime(2026, 10, 31, 12))!.precipitationMm, 0);
      expect(snapshot.dayOf(DateTime(2026, 11, 5)), isNull);
    });

    test('las alertas descartan los días ya pasados', () {
      final alerts = computeWeatherAlerts(
        snapshot,
        const [ExteriorPlant('p', 5)],
        now: DateTime(2026, 10, 31, 8),
      );
      expect(alerts.any((a) => a.type == WeatherAlertType.cold), isFalse);
      expect(alerts.where((a) => a.type == WeatherAlertType.rain).single.day, DateTime(2026, 11, 1));
    });
  });

  group('4. Plantas superpuestas', () {
    test('freeSpot deja al menos 0,7 m entre plantas', () {
      final room = store.addRoom(name: 'Living', exterior: false, x: 0, y: 0, w: 4, h: 3);
      store.addWindow(room, wall: 't');
      final a = store.freeSpot(room);
      store.addPlant(speciesId: 'potus', x: a.dx, y: a.dy);
      final b = store.freeSpot(room);
      expect((b - a).distance, greaterThanOrEqualTo(0.7));
      expect(room.contains(b.dx, b.dy), isTrue);
    });
  });

  group('5. Especie desconocida', () {
    test('existe, no tiene dato de toxicidad y no está en la colección', () {
      final unknown = content.speciesById(unknownSpeciesId);
      expect(unknown, isNotNull);
      expect(unknown!.isUnknown, isTrue);
      expect(content.species.any((s) => s.isUnknown), isFalse);
      expect(content.searchSpecies('', 'es').any((s) => s.isUnknown), isFalse);
      expect(unknown.name('it'), isNotEmpty);
    });
  });

  group('6. Riego', () {
    test('sin último riego conocido, pide revisar la tierra', () {
      final plant = store.addPlant(speciesId: 'potus');
      expect(plant.wateredAt, isNull);
      final advice = WateringEngine.advise(
        species: content.speciesById('potus')!,
        plant: plant,
        now: DateTime.now(),
      );
      expect(advice.reason, WateringReason.unknownLast);
      expect(advice.action, WateringAction.check);
    });

    test('borrar un riego vuelve al anterior', () {
      final plant = store.addPlant(speciesId: 'potus');
      store.addEvent(plant.id, CareType.water, at: DateTime(2026, 10, 1));
      final last = store.addEvent(plant.id, CareType.water, at: DateTime(2026, 10, 5));
      expect(plant.wateredAt, DateTime(2026, 10, 5));
      store.removeEvent(last.id);
      expect(plant.wateredAt, DateTime(2026, 10, 1));
      store.removeEvent(store.eventsFor(plant.id).single.id);
      expect(plant.wateredAt, isNull);
    });
  });

  group('7. Mediciones de prueba', () {
    test('lastPlantReading y el ajuste de riego ignoran las pruebas', () {
      final plant = store.addPlant(speciesId: 'potus', wateredAt: DateTime.now());
      // La planta está en (1, 1): la lectura válida se tomó en su lugar.
      store.addReading(_reading(plant.id, at: DateTime.now().subtract(const Duration(days: 2)), dli: 2, x: 1, y: 1)); // poca luz
      store.addReading(_reading(plant.id, at: DateTime.now().subtract(const Duration(days: 1)), dli: 30, probe: true, x: 1, y: 1));
      expect(store.lastPlantReading(plant.id)!.dli, 2);
      expect(WateringEngine.plantLightFactor(store, content, plant), 1.15);
    });

    test('peaksOfDay no cuenta pruebas ni mediciones a menos de 30 min', () {
      final plant = store.addPlant(speciesId: 'potus');
      store.addReading(_reading(plant.id, at: DateTime(2026, 6, 21, 11), peak: 400));
      store.addReading(_reading(plant.id, at: DateTime(2026, 6, 21, 11, 10), peak: 900));
      store.addReading(_reading(plant.id, at: DateTime(2026, 6, 21, 13), peak: 500, probe: true));
      store.addReading(_reading(plant.id, at: DateTime(2026, 6, 21, 14), peak: 600));
      expect(store.peaksOfDay(plant.id, DateTime(2026, 6, 21)), [400, 600]);
    });
  });

  group('8. Medición', () {
    test('se guarda el pico de la medición sola, no el promedio del día', () {
      final e = LightModel.estimate(
        lux: 20000,
        source: LightSource.sun,
        latitude: 45,
        dayOfYear: 172,
        solarHour: 12,
        earlierPeaksToday: const [100],
      );
      expect(e.peakPpfd, lessThan(e.measurementPeak)); // el promedio baja por el 100
      expect(e.measurementPeak, closeTo(e.ppfd / e.sunFraction, 1e-6));
    });

    test('las horas de lámpara cambian el DLI con luz artificial', () {
      double dli(double hours) => LightModel.estimate(
            lux: 3000,
            source: LightSource.ledCool,
            latitude: 45,
            dayOfYear: 172,
            solarHour: 12,
            artificialHours: hours,
          ).dli;
      expect(dli(16), closeTo(dli(8) * 2, 1e-9));
    });
  });

  group('9. ¿Dónde la pongo?', () {
    test('margen según mediciones en el ambiente', () {
      expect(placementMargin(0), 0.40);
      expect(placementMargin(1), 0.25);
      expect(placementMargin(2), 0.25);
      expect(placementMargin(3), 0.15);
    });

    test('ajuste según el rango probable', () {
      expect(placementFit(5, 8, 4, 10), PlacementFit.good);
      expect(placementFit(3, 6, 4, 10), PlacementFit.uncertain);
      expect(placementFit(1, 3, 4, 10), PlacementFit.low);
      expect(placementFit(11, 14, 4, 10), PlacementFit.high);
    });

    LightMap mapOf(AppStore s) => LightMap(
          rooms: s.rooms,
          readings: s.readings,
          northOffset: 180, // la pared de arriba mira al sur
          latitude: 45,
          dayOfYear: 172,
        );

    test('hasta 3 lugares separados, con explicación y supuestos', () {
      final room = store.addRoom(name: 'Living', exterior: false, x: 0, y: 0, w: 5, h: 4);
      store.addWindow(room, name: 'Ventana', wall: 't');
      final result = PlacementEngine.suggest(
        map: mapOf(store),
        species: content.speciesById('potus')!,
        hasLocation: false,
      );
      expect(result.options.length, 3);
      for (var i = 0; i < 3; i++) {
        for (var j = i + 1; j < 3; j++) {
          final a = result.options[i];
          final b = result.options[j];
          expect((Offset(a.x, a.y) - Offset(b.x, b.y)).distance, greaterThanOrEqualTo(1.0));
        }
      }
      final first = result.options.first;
      expect(first.window, isNotNull);
      expect(first.margin, 0.40);
      expect(first.low, closeTo(first.dli * 0.6, 1e-9));
      expect(result.assumptions, contains(PlacementAssumption.noLocation));
      expect(result.assumptions, contains(PlacementAssumption.theoretical));
    });

    test('evita los lugares ocupados por otras plantas', () {
      final room = store.addRoom(name: 'Living', exterior: false, x: 0, y: 0, w: 5, h: 4);
      store.addWindow(room, wall: 't');
      final free = PlacementEngine.suggest(map: mapOf(store), species: content.speciesById('potus')!);
      final taken = free.options.first;
      store.addPlant(speciesId: 'potus', x: taken.x, y: taken.y);
      final again = PlacementEngine.suggest(
        map: mapOf(store),
        species: content.speciesById('potus')!,
        plants: store.plants,
      );
      expect(again.options.any((o) => o.x == taken.x && o.y == taken.y), isFalse);
    });

    test('sin ambientes compatibles o sin ventanas no inventa lugares', () {
      final balcony = store.addRoom(name: 'Balcón', exterior: true);
      store.addWindow(balcony, wall: 't');
      var r = PlacementEngine.suggest(map: mapOf(store), species: content.speciesById('potus')!);
      expect(r.options, isEmpty);
      expect(r.assumptions, contains(PlacementAssumption.noCompatibleRoom));
      store.addRoom(name: 'Pasillo', exterior: false);
      r = PlacementEngine.suggest(map: mapOf(store), species: content.speciesById('potus')!);
      expect(r.assumptions, contains(PlacementAssumption.noWindows));
    });
  });

  group('11. Respaldo', () {
    test('ZIP con fotos: se restaura igual en otra carpeta', () async {
      final plant = store.addPlant(speciesId: 'potus', nickname: 'Pothos');
      final photo = File('${store.photosDir.path}/foto1.jpg')..writeAsBytesSync([1, 2, 3]);
      store.addEvent(plant.id, CareType.photo, photoPath: photo.path);
      final zip = Backup.build(store);

      final other = await Directory.systemTemp.createTemp('mirasol_restore_');
      final target = await AppStore.open(directory: other);
      await Backup.restore(target, zip);
      expect(target.plants.single.nickname, 'Pothos');
      final restored = target.plants.single.photoPath!;
      expect(restored.startsWith(target.photosDir.path), isTrue);
      expect(File(restored).readAsBytesSync(), [1, 2, 3]);
      target.dispose();
      await other.delete(recursive: true);
    });

    test('un archivo inválido no cambia nada', () async {
      store.addPlant(speciesId: 'potus');
      await expectLater(Backup.restore(store, [1, 2, 3, 4, 5]), throwsFormatException);
      expect(store.plants.length, 1);
    });

    test('acepta el JSON exportado por versiones anteriores', () async {
      final json = store.exportJson().replaceFirst('"plants": []', '"plants": [{"id": "a", "speciesId": "potus"}]');
      await Backup.restore(store, json.codeUnits);
      expect(store.plants.single.id, 'a');
    });
  });

  group('12. Ambientes', () {
    test('al mover un ambiente se mueven sus plantas', () {
      final room = store.addRoom(name: 'Living', exterior: false, x: 0, y: 0, w: 4, h: 3);
      final plant = store.addPlant(speciesId: 'potus', x: 1, y: 1);
      store.moveRoom(room, x: 10, y: 5);
      expect(plant.x, 11);
      expect(plant.y, 6);
      expect(plant.roomId, room.id);
    });

    test('se puede guardar la humedad sin temperatura', () {
      final room = store.addRoom(name: 'Baño', exterior: false);
      store.saveClimate(room, humidity: 70);
      expect(room.humidity, 70);
      expect(room.temperature, isNull);
      expect(room.climateAt, isNotNull);
      store.saveClimate(room);
      expect(room.climateAt, isNull);
    });
  });
}
