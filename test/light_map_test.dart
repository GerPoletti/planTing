import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/data/content.dart';
import 'package:plantapp/data/models.dart';
import 'package:plantapp/data/store.dart';
import 'package:plantapp/engine/light_map.dart';
import 'package:plantapp/engine/sun_engine.dart';

const double _lat = 45.5;
const int _june21 = 172;

Room _living() => Room(
      id: 'r1',
      name: 'Living',
      x: 0,
      y: 0,
      w: 5,
      h: 4,
      windows: [WindowSpot(id: 'w1', name: 'Ventana', wall: 'l', obstruction: 10)],
    );

Reading _reading(double dli, {double x = 1.3, double y = 2}) => Reading(
      id: 'm${dli}_$x',
      plantId: 'p1',
      at: DateTime(2026, 6, 21, 13),
      lux: 3000,
      source: 'sun',
      ppfd: 55,
      dli: dli,
      peakPpfd: 55,
      sunFraction: 1,
      x: x,
      y: y,
    );

LightMap _map(List<Reading> readings, {double north = 0}) => LightMap(
      rooms: [_living()],
      readings: readings,
      northOffset: north,
      latitude: _lat,
      dayOfYear: _june21,
      now: DateTime(2026, 6, 22), // vigencia de las mediciones fija para la prueba
    );

void main() {
  test('la orientación de la ventana depende de la pared y del plano', () {
    final w = WindowSpot(id: 'a', name: '', wall: 'l');
    expect(windowAzimuth(w, 0), 270);
    expect(windowAzimuth(w, 90), 0);
    expect(windowAzimuth(WindowSpot(id: 'b', name: '', wall: 't'), 180), 180);
  });

  test('las horas de sol de la ventana salen de su orientación', () {
    final map = _map([]);
    final hours = SunEngine.sunHours(
      const WindowGeometry(azimuth: 270, obstruction: 10),
      _lat,
      _june21,
    );
    expect(map.sunHoursOf('w1'), closeTo(hours, 1e-9));
    expect(map.windowDliOf('w1'), greaterThan(0));
  });

  test('la luz cae con la distancia a la ventana', () {
    final map = _map([]);
    expect(map.lightAt(0.3, 2), greaterThan(map.lightAt(1.3, 2)));
    expect(map.lightAt(1.3, 2), greaterThan(map.lightAt(4, 2)));
    expect(map.lightAt(4, 2), greaterThan(0));
    expect(map.lightAt(50, 50), 0); // fuera de la casa
  });

  test('cerca de la ventana, una maceta en el suelo recibe menos que en una mesa', () {
    final map = _map([]);
    final floor = map.lightAt(0.3, 2, heightCm: 0);
    final table = map.lightAt(0.3, 2, heightCm: 75);
    expect(floor, lessThan(table));
    expect(map.sunHoursAt(0.3, 2, heightCm: 0), lessThanOrEqualTo(map.sunHoursAt(0.3, 2, heightCm: 75)));
  });

  test('una ventana más alta deja entrar el sol más adentro', () {
    Room withTop(double topCm) => Room(
          id: 'r1', name: 'S', x: 0, y: 0, w: 5, h: 4,
          windows: [WindowSpot(id: 'w', name: '', wall: 't', obstruction: 0, topCm: topCm)],
        );
    LightMap mapOf(double topCm) => LightMap(
          rooms: [withTop(topCm)], readings: const [], northOffset: 180,
          latitude: _lat, dayOfYear: 355, // invierno, ventana al sur
        );
    expect(
      mapOf(300).sunHoursAt(2.5, 2.5, heightCm: 75),
      greaterThanOrEqualTo(mapOf(150).sunHoursAt(2.5, 2.5, heightCm: 75)),
    );
    expect(mapOf(210).sunHoursAt(2.5, 1.5, heightCm: 75), greaterThan(0));
  });

  group('espacios exteriores', () {
    Room space(String kind, {bool? covered}) => Room(
          id: 'e', name: 'E', kind: kind, covered: covered,
          x: 0, y: 0, w: 4, h: 2, skyObstruction: 10,
        );
    LightMap mapOf(Room r, {int day = _june21}) => LightMap(
          rooms: [r], readings: const [], northOffset: 180, // arriba mira al sur
          latitude: _lat, dayOfYear: day,
        );

    test('no necesitan ventanas', () {
      expect(mapOf(space(RoomKind.garden)).lightAt(2, 1), greaterThan(10));
    });

    test('un jardín recibe más luz que una terraza y que un balcón techado', () {
      final garden = mapOf(space(RoomKind.garden)).lightAt(2, 1);
      final terrace = mapOf(space(RoomKind.terrace)).lightAt(2, 1, heightCm: 0);
      final balcony = mapOf(space(RoomKind.balcony)).lightAt(2, 1.6, heightCm: 0);
      expect(garden, greaterThanOrEqualTo(terrace));
      expect(terrace, greaterThan(balcony));
    });

    test('el techo tapa el sol alto del verano', () {
      final open = mapOf(space(RoomKind.balcony, covered: false)).sunHoursAt(2, 1.5);
      final roofed = mapOf(space(RoomKind.balcony, covered: true)).sunHoursAt(2, 1.5);
      expect(roofed, lessThan(open));
    });

    test('la baranda da sombra al suelo pero no a una mesa', () {
      final map = mapOf(space(RoomKind.terrace), day: 355);
      expect(map.sunHoursAt(2, 0.3, heightCm: 0), lessThan(map.sunHoursAt(2, 0.3, heightCm: 120)));
    });

    test('los datos viejos de un exterior con ventana quedan abiertos de ese lado', () {
      final r = Room.fromJson({
        'id': 'b', 'name': 'Balcón', 'exterior': true,
        'windows': [
          {'id': 'w', 'wall': 'b'},
        ],
      });
      expect(r.kind, RoomKind.balcony);
      expect(r.sideOf('b'), SideType.railing);
      expect(r.sideOf('t'), SideType.wall);
      final again = Room.fromJson(r.toJson());
      expect(again.sides, r.sides);
      expect(again.covered, r.covered);
    });
  });

  test('una medición mayor a lo previsto sube el ambiente', () {
    final base = _map([]);
    final predicted = base.lightAt(1.3, 2);
    final map = _map([_reading(predicted * 2)]);
    expect(map.factorOf('r1'), closeTo(1.5, 1e-6)); // 1 + (2 - 1) * 1/2
    expect(map.readingsIn('r1'), 1);
    expect(map.lightAt(1.3, 2), closeTo(predicted * 1.5, 1e-6));
  });

  test('las mediciones manuales, saturadas o con luz artificial no ajustan', () {
    final base = _map([]);
    final predicted = base.lightAt(1.3, 2);
    final manual = Reading(
      id: 'm1', plantId: 'p1', at: DateTime(2026, 6, 21), lux: 5000, source: 'sun',
      ppfd: 90, dli: predicted * 3, peakPpfd: 90, sunFraction: 1, x: 1.3, y: 2, manual: true,
    );
    final lamp = Reading(
      id: 'm2', plantId: 'p1', at: DateTime(2026, 6, 21), lux: 5000, source: 'ledCool',
      ppfd: 90, dli: predicted * 3, peakPpfd: 90, sunFraction: 1, x: 1.3, y: 2,
    );
    final map = _map([manual, lamp]);
    expect(map.factorOf('r1'), 1);
    expect(map.readingsIn('r1'), 0);
  });

  test('el mejor lugar cae dentro del rango cuando existe', () {
    final map = _map([]);
    final mid = map.lightAt(1.5, 2);
    final species = Species({
      'id': 'x', 'scientific': 'X', 'dliMin': mid - 0.5, 'dliMax': mid + 0.5,
      'waterDays': 7, 'tempMin': 10, 'humidityMin': 40, 'place': 'indoor',
      'names': {'es': ['X'], 'it': ['X']},
    });
    final spot = map.bestSpot(species)!;
    expect(spot.inRange, isTrue);
    expect(spot.dli, closeTo(mid, 0.5));
    // Una planta que necesita muchísima más luz que la disponible: sin lugar adecuado.
    final hungry = Species({
      'id': 'y', 'scientific': 'Y', 'dliMin': 500, 'dliMax': 600,
      'waterDays': 7, 'tempMin': 10, 'humidityMin': 40, 'place': 'indoor',
      'names': {'es': ['Y'], 'it': ['Y']},
    });
    expect(map.bestSpot(hungry)!.inRange, isFalse);
  });

  test('las plantas de interior no se sugieren en un balcón', () {
    final balcony = Room(
      id: 'b', name: 'Balcón', exterior: true, x: 0, y: 0, w: 4, h: 2,
      windows: [WindowSpot(id: 'wb', name: '', wall: 'b')],
    );
    final map = LightMap(
      rooms: [balcony], readings: const [], northOffset: 0, latitude: _lat, dayOfYear: _june21,
    );
    final indoor = Species({
      'id': 'x', 'scientific': 'X', 'dliMin': 1, 'dliMax': 40, 'waterDays': 7,
      'tempMin': 10, 'humidityMin': 40, 'place': 'indoor',
      'names': {'es': ['X'], 'it': ['X']},
    });
    expect(map.bestSpot(indoor), isNull);
  });

  group('qué medir', () {
    late Directory dir;
    late AppStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mirasol_sug_');
      store = await AppStore.open(directory: dir);
    });
    tearDown(() async {
      store.dispose();
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    test('prioriza plantas sin medir, después viejas y por último ambientes', () {
      final room = store.addRoom(name: 'Living', exterior: false, x: 0, y: 0, w: 5, h: 4);
      store.addRoom(name: 'Cocina', exterior: false, x: 5, y: 0, w: 3, h: 4);
      final measured = store.addPlant(speciesId: 'a', x: 1, y: 1);
      final stale = store.addPlant(speciesId: 'b', x: 2, y: 2);
      final never = store.addPlant(speciesId: 'c', x: 3, y: 3);
      final now = DateTime(2026, 7, 1);
      store.addReading(_reading(3).copyWithPlant(measured.id, DateTime(2026, 6, 30), 1, 1));
      store.addReading(_reading(3).copyWithPlant(stale.id, DateTime(2026, 5, 1), 2, 2));

      final list = measureSuggestions(store, now: now);
      expect(list.first.kind, SuggestionKind.neverMeasured);
      expect(list.first.plantId, never.id);
      expect(list[1].kind, SuggestionKind.stale);
      expect(list[1].plantId, stale.id);
      expect(list[1].daysAgo, 61);
      expect(list.last.kind, SuggestionKind.roomWithoutReadings); // la cocina
      expect(list.any((s) => s.roomId == room.id), isFalse);
    });
  });
}

extension on Reading {
  Reading copyWithPlant(String plantId, DateTime at, double x, double y) => Reading(
        id: '${id}_$plantId',
        plantId: plantId,
        at: at,
        lux: lux,
        source: source,
        ppfd: ppfd,
        dli: dli,
        peakPpfd: peakPpfd,
        sunFraction: sunFraction,
        x: x,
        y: y,
      );
}
