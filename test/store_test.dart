import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/data/models.dart';
import 'package:plantapp/data/store.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mirasol_test_');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<AppStore> openStore() => AppStore.open(directory: dir);

  test('guarda y vuelve a leer ambientes, plantas y mediciones', () async {
    final store = await openStore();
    final room = store.addRoom(name: 'Living', exterior: false, x: 0, y: 0, w: 5, h: 4);
    final window = store.addWindow(room, name: 'Ventana', wall: 'l');
    final plant = store.addPlant(speciesId: 'monstera_deliciosa', nickname: 'Selva', x: 1.5, y: 2);
    store.addReading(Reading(
      id: newId(),
      plantId: plant.id,
      at: DateTime(2026, 6, 21, 13),
      lux: 2840,
      source: 'sun',
      ppfd: 52.54,
      dli: 1.9,
      peakPpfd: 53.6,
      sunFraction: 0.98,
      x: 1.5,
      y: 2,
    ));
    await store.flush();

    final again = await openStore();
    expect(again.rooms.single.name, 'Living');
    expect(again.rooms.single.windows.single.id, window.id);
    expect(again.plants.single.nickname, 'Selva');
    expect(again.plants.single.roomId, room.id);
    expect(again.plants.single.windowId, window.id);
    expect(again.readings.single.lux, 2840);
  });

  test('una planta se asocia a la ventana más cercana al moverla', () async {
    final store = await openStore();
    final room = store.addRoom(name: 'Cocina', exterior: false, x: 0, y: 0, w: 6, h: 4);
    final left = store.addWindow(room, name: 'Izquierda', wall: 'l');
    final right = store.addWindow(room, name: 'Derecha', wall: 'r');
    final plant = store.addPlant(speciesId: 'potus', x: 1, y: 2);
    expect(plant.windowId, left.id);
    store.movePlant(plant, 5, 2);
    expect(plant.windowId, right.id);
    store.movePlant(plant, 20, 20);
    expect(plant.roomId, isNull);
    expect(plant.windowId, isNull);
  });

  test('el lugar sugerido queda dentro del ambiente, junto a la ventana', () async {
    final store = await openStore();
    final room = store.addRoom(name: 'Living', exterior: false, x: 2, y: 1, w: 5, h: 4);
    final top = store.addWindow(room, wall: 't');
    var spot = store.defaultSpot(room);
    expect(spot.dx, closeTo(4.5, 1e-9)); // centro de la pared de arriba
    expect(spot.dy, closeTo(1.9, 1e-9)); // 0,9 m hacia adentro
    expect(room.contains(spot.dx, spot.dy), isTrue);
    store.updateWindow(top, (w) => w.wall = 'b');
    spot = store.defaultSpot(room);
    expect(spot.dy, closeTo(4.1, 1e-9));
    final empty = store.addRoom(name: 'Vacío', exterior: false, x: 10, y: 0, w: 2, h: 2);
    expect(store.defaultSpot(empty).dx, closeTo(11, 1e-9));
  });

  test('regar actualiza la planta y la historia', () async {
    final store = await openStore();
    final plant = store.addPlant(speciesId: 'potus', wateredAt: DateTime(2026, 1, 1));
    store.addEvent(plant.id, CareType.water);
    expect(plant.wateredAt!.year, DateTime.now().year);
    // El riego indicado al agregarla también queda en la historia.
    expect(store.eventsFor(plant.id).length, 2);
  });

  test('tratamiento: no duplica y calcula las tareas pendientes', () async {
    final store = await openStore();
    final plant = store.addPlant(speciesId: 'monstera_deliciosa');
    final t = store.startTreatment(plant.id, 'cochinilla', [0, 7, 14, 21, 28]);
    expect(store.startTreatment(plant.id, 'cochinilla', [0]).id, t.id);
    expect(t.tasks.length, 5);

    final pending = store.pendingTasks(withinDays: 3);
    expect(pending.length, 1); // solo la de hoy
    expect(pending.first.task.index, 0);

    store.completeTask(t, 0);
    expect(t.doneCount, 1);
    expect(store.pendingTasks(withinDays: 3), isEmpty);
    expect(store.pendingTasks(withinDays: 8).single.task.index, 1);
  });

  test('revisión final: resolver cierra y repetir abre un ciclo nuevo', () async {
    final store = await openStore();
    final plant = store.addPlant(speciesId: 'potus');
    final t = store.startTreatment(plant.id, 'trips', [0, 5, 10, 17]);
    store.completeTask(t, 3, outcome: 'repeat', repeatOffsets: [0, 5, 10, 17]);
    expect(t.active, isFalse);
    expect(t.outcome, 'repeat');
    final next = store.activeTreatment(plant.id, 'trips');
    expect(next, isNotNull);
    expect(next!.id, isNot(t.id));

    store.completeTask(next, 3, outcome: 'resolved');
    expect(store.activeTreatment(plant.id, 'trips'), isNull);
  });

  test('picos del día solo cuentan mediciones con sol bien medidas', () async {
    final store = await openStore();
    final plant = store.addPlant(speciesId: 'potus');
    final day = DateTime(2026, 6, 21);
    Reading make(String source, double fraction, {bool saturated = false}) => Reading(
          id: newId(),
          plantId: plant.id,
          at: DateTime(2026, 6, 21, 12),
          lux: 1000,
          source: source,
          ppfd: 18,
          dli: 1,
          peakPpfd: 20,
          sunFraction: fraction,
          saturated: saturated,
        );
    store.addReading(make('sun', 0.9));
    store.addReading(make('sun', 0.1)); // sol muy bajo
    store.addReading(make('ledCool', 1)); // luz artificial
    store.addReading(make('sun', 0.9, saturated: true));
    expect(store.peaksOfDay(plant.id, day), [20]);
  });

  test('las revisiones de humedad se guardan y se leen ordenadas', () async {
    final store = await openStore();
    final plant = store.addPlant(speciesId: 'potus');
    store.addMoisture(plant.id, MoistureLevel.wet, at: DateTime(2026, 6, 10));
    store.addMoisture(plant.id, MoistureLevel.dry,
        method: 'meter', percent: 12, at: DateTime(2026, 6, 14));
    expect(store.lastMoisture(plant.id)!.level, MoistureLevel.dry);
    expect(store.moistureFor(plant.id).map((m) => m.level),
        [MoistureLevel.dry, MoistureLevel.wet]);
    await store.flush();

    final again = await openStore();
    expect(again.moisture.length, 2);
    expect(again.lastMoisture(plant.id)!.percent, 12);
    again.removePlant(plant.id);
    expect(again.moisture, isEmpty);
  });

  test('exportar y borrar todo', () async {
    final store = await openStore();
    store.addPlant(speciesId: 'potus', nickname: 'Pothos');
    expect(store.exportJson(), contains('Pothos'));
    await store.wipe();
    expect(store.plants, isEmpty);
    final again = await openStore();
    expect(again.plants, isEmpty);
  });
}
