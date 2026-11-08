import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'dates.dart';

/// Guarda todo en un único archivo JSON dentro del teléfono.
/// No hay cuentas ni nube: los datos no salen del dispositivo.
class AppStore extends ChangeNotifier {
  AppStore._(this._file, this.photosDir);

  final File _file;
  final Directory photosDir;

  Settings settings = Settings();
  final List<Room> rooms = [];
  final List<PlantItem> plants = [];
  final List<Reading> readings = [];
  final List<MoistureReading> moisture = [];
  final List<CareEvent> events = [];
  final List<Treatment> treatments = [];

  Timer? _debounce;
  bool _disposed = false;

  /// Sube con cada cambio. Sirve para saber cuándo recalcular el mapa de luz.
  int revision = 0;

  /// Abre la base. [directory] permite usar una carpeta distinta en las pruebas.
  static Future<AppStore> open({Directory? directory}) async {
    final base = directory ?? await getApplicationDocumentsDirectory();
    final photos = Directory('${base.path}/photos');
    if (!photos.existsSync()) photos.createSync(recursive: true);
    final store = AppStore._(File('${base.path}/mirasol.json'), photos);
    await store._load();
    return store;
  }

  Future<void> _load() async {
    for (final f in [_file, File('${_file.path}.bak')]) {
      if (!f.existsSync()) continue;
      try {
        loadFromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
        if (f.path == _file.path) {
          try {
            await f.copy('${_file.path}.bak');
          } catch (_) {}
        }
        return;
      } catch (e) {
        // Archivo dañado: se conserva una copia y se prueba con la anterior.
        debugPrint('No se pudo leer ${f.path}: $e');
        if (f.path == _file.path) {
          try {
            await f.copy('${_file.path}.dañado-${DateTime.now().millisecondsSinceEpoch}');
          } catch (_) {}
        }
      }
    }
  }

  /// Reemplaza todos los datos por los de [data]. Si algo falla no cambia nada.
  void loadFromJson(Map<String, dynamic> data) {
    List<T> parse<T>(Object? raw, T Function(Map<String, dynamic>) f) => [
          for (final item in (raw as List?) ?? const [])
            f(Map<String, dynamic>.from(item as Map)),
        ];
    final newSettings = Settings.fromJson(
      Map<String, dynamic>.from((data['settings'] as Map?) ?? {}),
    );
    final newRooms = parse(data['rooms'], Room.fromJson);
    final newPlants = parse(data['plants'], PlantItem.fromJson);
    final newReadings = parse(data['readings'], Reading.fromJson);
    final newMoisture = parse(data['moisture'], MoistureReading.fromJson);
    final newEvents = parse(data['events'], CareEvent.fromJson);
    final newTreatments = parse(data['treatments'], Treatment.fromJson);
    settings = newSettings;
    rooms..clear()..addAll(newRooms);
    plants..clear()..addAll(newPlants);
    readings..clear()..addAll(newReadings);
    moisture..clear()..addAll(newMoisture);
    events..clear()..addAll(newEvents);
    treatments..clear()..addAll(newTreatments);
    // Datos de antes: el último riego cargado al agregar la planta no tenía
    // evento. Se crea uno para que deshacer y la cronología lo respeten.
    for (final p in plants) {
      final w = p.wateredAt;
      if (w == null) continue;
      final last = _lastWaterEvent(p.id);
      if (last == null || w.isAfter(last)) {
        events.add(CareEvent(id: newId(), plantId: p.id, type: CareType.water, at: w, note: initialWaterNote));
      }
    }
    // El último riego guardado es un dato derivado: se recompone de los
    // eventos por si el archivo trae uno viejo o contradictorio.
    for (final p in plants) {
      _recomputeWatered(p);
    }
    revision++;
  }

  /// Nota del evento que registra el último riego indicado al agregar una planta.
  static const String initialWaterNote = 'initial';

  /// Versión del formato de datos que entiende esta app.
  static const int schemaVersion = 1;

  DateTime? _lastWaterEvent(String plantId) {
    DateTime? last;
    for (final e in events) {
      if (e.plantId == plantId && e.type == CareType.water && (last == null || e.at.isAfter(last))) {
        last = e.at;
      }
    }
    return last;
  }

  /// El último riego sale siempre de los eventos: registrar un riego pasado no
  /// lo hace retroceder y borrar uno vuelve al anterior.
  void _recomputeWatered(PlantItem plant) => plant.wateredAt = _lastWaterEvent(plant.id);

  /// Comprueba que [data] se pueda cargar sin cambiar nada. Lanza si no.
  /// Exige versión soportada, partes obligatorias, identificadores únicos,
  /// relaciones existentes y valores dentro de rango. Lanza [FormatException].
  void validateJson(Map<String, dynamic> data) {
    final v = data['version'];
    if (v is! num || v != v.roundToDouble() || v < 1 || v > schemaVersion) {
      throw FormatException('Versión de datos no soportada: $v');
    }
    // Todas las partes tienen que estar: si falta una lista, restaurar
    // borraría esa historia sin avisar.
    if (data['settings'] is! Map) throw const FormatException('Faltan los ajustes');
    for (final key in ['rooms', 'plants', 'readings', 'moisture', 'events', 'treatments']) {
      if (data[key] is! List) throw FormatException('Falta la lista «$key»');
    }
    _checkRawDates(data);
    final check = AppStore._(_file, photosDir);
    try {
      check.loadFromJson(data);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Datos ilegibles: $e');
    }
    check._checkIntegrity();
  }

  /// Las fechas ilegibles se rechazan antes de cargar: al cargar se
  /// reemplazarían por «ahora» y parecerían datos recientes.
  static void _checkRawDates(Map<String, dynamic> data) {
    bool valid(Object? v, {bool required = true}) =>
        v == null ? !required : (v is String && DateTime.tryParse(v) != null);
    void check(String key, String field, {bool required = true}) {
      for (final item in data[key] as List) {
        if (item is! Map || !valid(item[field], required: required)) {
          throw FormatException('Fecha ilegible en «$key»');
        }
      }
    }

    check('readings', 'at');
    check('moisture', 'at');
    check('events', 'at');
    check('treatments', 'startedAt');
    check('treatments', 'endedAt', required: false);
    check('plants', 'createdAt', required: false);
    check('plants', 'wateredAt', required: false);
    final st = data['settings'] as Map;
    if (!valid(st['travelUntil'], required: false)) throw const FormatException('Fecha ilegible en ajustes');
  }

  void _checkIntegrity() {
    Never fail(String why) => throw FormatException(why);
    void unique(String what, Iterable<String> ids) {
      final seen = <String>{};
      for (final id in ids) {
        if (!seen.add(id)) fail('Identificador repetido en $what: $id');
      }
    }

    bool finite(double v) => v.isFinite;
    unique('ambientes', rooms.map((r) => r.id));
    unique('ventanas', rooms.expand((r) => r.windows).map((w) => w.id));
    unique('plantas', plants.map((p) => p.id));
    unique('mediciones', readings.map((r) => r.id));
    unique('humedad', moisture.map((m) => m.id));
    unique('historia', events.map((e) => e.id));
    unique('tratamientos', treatments.map((t) => t.id));

    final st = settings;
    if (st.reminderHour < 0 || st.reminderHour > 23 || st.reminderMinute < 0 || st.reminderMinute > 59) {
      fail('Hora de aviso fuera de rango');
    }
    if ((st.latitude != null && st.latitude!.abs() > 90) ||
        (st.longitude != null && st.longitude!.abs() > 180)) {
      fail('Ubicación fuera de rango');
    }
    if (!(st.cameraCalibration >= 0.05 && st.cameraCalibration <= 20)) fail('Calibración de cámara fuera de rango');
    if (!st.northOffset.isFinite) fail('Orientación inválida');
    for (final r in rooms) {
      if (![r.x, r.y, r.w, r.h].every(finite) || r.w <= 0 || r.h <= 0) fail('Ambiente con medidas inválidas');
      if (!RoomKind.all.contains(r.kind)) fail('Tipo de ambiente desconocido: ${r.kind}');
      if (r.skyObstruction < 0 || r.skyObstruction > 60 || r.wallCm < 100 || r.wallCm > 2000 ||
          r.railingCm < 0 || r.railingCm > 300 ||
          !r.sides.values.every(SideType.all.contains)) {
        fail('Exterior con valores inválidos');
      }
      if ((r.humidity != null && (r.humidity! < 0 || r.humidity! > 100))) fail('Humedad fuera de rango');
      for (final w in r.windows) {
        if (!planSides.contains(w.wall) ||
            w.pos < 0 ||
            w.pos > 1 ||
            w.sillCm < 0 ||
            w.sillCm > 300 ||
            w.topCm <= w.sillCm ||
            w.topCm > 400 ||
            w.widthCm < 20 ||
            w.widthCm > 1000 ||
            w.obstruction < 0 ||
            w.obstruction > 60) {
          fail('Ventana con medidas inválidas');
        }
      }
    }
    final roomIds = rooms.map((r) => r.id).toSet();
    final windowIds = rooms.expand((r) => r.windows).map((w) => w.id).toSet();
    final plantIds = <String>{};
    for (final p in plants) {
      if (!finite(p.x) || !finite(p.y)) fail('Planta con posición inválida');
      if (p.roomId != null && !roomIds.contains(p.roomId)) fail('Planta en un ambiente que no existe');
      if (p.windowId != null && !windowIds.contains(p.windowId)) fail('Planta junto a una ventana que no existe');
      if (p.heightCm != null && (p.heightCm! < 0 || p.heightCm! > 400)) fail('Altura de planta fuera de rango');
      if (p.lampHours != null && (p.lampHours! < 1 || p.lampHours! > 24)) fail('Horas de lámpara fuera de rango');
      if (p.careIntervalDays != null && p.careIntervalDays! < 1) fail('Intervalo de riego inválido');
      plantIds.add(p.id);
    }
    const sources = ['sun', 'ledCool', 'ledWarm', 'fluorescent', 'hps'];
    for (final r in readings) {
      if (!sources.contains(r.source)) fail('Fuente de luz desconocida: ${r.source}');
      if (!(r.lux >= 0 && r.ppfd >= 0 && r.dli >= 0 && r.peakPpfd >= 0) ||
          !(r.sunFraction >= 0 && r.sunFraction <= 1) ||
          (r.heightCm != null && (r.heightCm! < 0 || r.heightCm! > 400)) ||
          (r.x != null && !finite(r.x!)) ||
          (r.y != null && !finite(r.y!))) {
        fail('Medición con valores inválidos');
      }
    }
    for (final m in moisture) {
      if (m.percent != null && (m.percent! < 0 || m.percent! > 100)) fail('Humedad de tierra fuera de rango');
      if (m.method != 'finger' && m.method != 'meter') fail('Método de humedad desconocido');
    }
    for (final t in treatments) {
      // Las tareas se identifican por su posición: 0, 1, 2… sin huecos ni repetidos.
      final indices = t.tasks.map((k) => k.index).toList()..sort();
      for (var i = 0; i < indices.length; i++) {
        if (indices[i] != i) fail('Tareas de tratamiento mal numeradas');
      }
      if (t.tasks.any((k) => k.dayOffset < 0)) fail('Tarea con día negativo');
    }
    bool known(String id) => plantIds.contains(id);
    if (!readings.every((r) => known(r.plantId) && r.lux.isFinite && r.dli.isFinite) ||
        !moisture.every((m) => known(m.plantId)) ||
        !events.every((e) => known(e.plantId)) ||
        !treatments.every((t) => known(t.plantId))) {
      fail('Hay registros de plantas que no existen o con valores inválidos');
    }
  }

  /// Reemplaza todos los datos (por ejemplo, al restaurar un respaldo) y guarda.
  void replaceAll(Map<String, dynamic> data) {
    loadFromJson(data);
    _changed();
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'settings': settings.toJson(),
        'rooms': rooms.map((e) => e.toJson()).toList(),
        'plants': plants.map((e) => e.toJson()).toList(),
        'readings': readings.map((e) => e.toJson()).toList(),
        'moisture': moisture.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'treatments': treatments.map((e) => e.toJson()).toList(),
      };

  /// Copia completa de los datos, para exportar.
  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  void _changed() {
    if (_disposed) return;
    revision++;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), flush);
  }

  /// Escribe ahora mismo en disco, de forma atómica.
  Future<void> _writing = Future<void>.value();

  /// Es true si la última escritura en disco falló.
  bool saveFailed = false;

  /// Escribe ahora mismo en disco, de forma atómica y de a una por vez.
  Future<void> flush() {
    _debounce?.cancel();
    _writing = _writing.then((_) => _writeNow());
    return _writing;
  }

  /// Como [flush], pero lanza si no se pudo escribir en el disco.
  Future<void> flushOrThrow() async {
    await flush();
    if (saveFailed) throw const FileSystemException('No se pudieron guardar los datos');
  }

  Future<void> _writeNow() async {
    try {
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(jsonEncode(toJson()), flush: true);
      await tmp.rename(_file.path);
      if (saveFailed) {
        saveFailed = false;
        if (!_disposed) notifyListeners();
      }
    } catch (e) {
      debugPrint('No se pudo guardar: $e');
      if (!saveFailed) {
        saveFailed = true;
        if (!_disposed) notifyListeners();
      }
    }
  }

  /// Borra todos los datos y las fotos.
  /// Borra todos los datos, las fotos y las copias internas (.bak, .tmp y
  /// copias de archivos dañados), para que nada vuelva al reabrir.
  Future<void> wipe() async {
    _debounce?.cancel();
    await _writing; // que no quede una escritura en curso que recree el archivo
    settings = Settings();
    rooms.clear();
    plants.clear();
    readings.clear();
    moisture.clear();
    events.clear();
    treatments.clear();
    String base(String path) => path.split(RegExp(r'[\\/]')).last;
    final name = base(_file.path);
    if (_file.parent.existsSync()) {
      for (final f in _file.parent.listSync().whereType<File>()) {
        final n = base(f.path);
        if (n == name || n.startsWith('$name.')) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }
    saveFailed = false;
    revision++;
    if (photosDir.existsSync()) {
      await photosDir.delete(recursive: true);
      photosDir.createSync(recursive: true);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- ajustes

  void updateSettings(void Function(Settings s) change) {
    change(settings);
    _changed();
  }

  // --------------------------------------------------------------- ambientes

  Room? roomAt(double x, double y) {
    for (final r in rooms) {
      if (r.contains(x, y)) return r;
    }
    return null;
  }

  Room? roomById(String? id) {
    if (id == null) return null;
    for (final r in rooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  WindowSpot? windowById(String? id) {
    if (id == null) return null;
    for (final r in rooms) {
      for (final w in r.windows) {
        if (w.id == id) return w;
      }
    }
    return null;
  }

  Room? roomOfWindow(String windowId) {
    for (final r in rooms) {
      if (r.windows.any((w) => w.id == windowId)) return r;
    }
    return null;
  }

  Room addRoom({
    required String name,
    required bool exterior,
    String? kind,
    double? x,
    double? y,
    double w = 4,
    double h = 3,
  }) {
    final bottom = rooms.isEmpty
        ? 0.0
        : rooms.map((r) => r.y + r.h).reduce((a, b) => a > b ? a : b);
    final room = Room(
      id: newId(),
      name: name,
      exterior: exterior,
      kind: kind,
      x: x ?? 0,
      y: y ?? bottom,
      w: w,
      h: h,
    );
    rooms.add(room);
    _changed();
    return room;
  }

  void updateRoom(Room room, void Function(Room r) change) {
    change(room);
    _changed();
  }

  /// Cambia la posición y el tamaño de un ambiente. Sus plantas se mueven con
  /// él y, si se achica, quedan dentro.
  void moveRoom(Room room, {required double x, required double y, double? w, double? h}) {
    final dx = x - room.x;
    final dy = y - room.y;
    final mine = plants.where((p) => p.roomId == room.id).toList();
    // Las mediciones tomadas dentro del ambiente se mueven con él, para que su
    // ajuste no se pierda ni pase a otro ambiente que quede en ese lugar.
    final inside = <int>[
      for (var i = 0; i < readings.length; i++)
        if (readings[i].x != null && readings[i].y != null && room.contains(readings[i].x!, readings[i].y!)) i,
    ];
    room.x = x;
    room.y = y;
    if (w != null) room.w = w;
    if (h != null) room.h = h;
    double cx(double v) => v.clamp(room.x + 0.1, room.x + room.w - 0.1).toDouble();
    double cy(double v) => v.clamp(room.y + 0.1, room.y + room.h - 0.1).toDouble();
    for (final p in mine) {
      p.x = cx(p.x + dx);
      p.y = cy(p.y + dy);
    }
    // Las mediciones solo se trasladan, nunca se recortan: si el ambiente se
    // achica, la que queda afuera deja de describir a la planta, que ahora
    // está en otro punto, en vez de fingir que se midió allí.
    for (final i in inside) {
      final r = readings[i];
      readings[i] = r.movedTo(r.x! + dx, r.y! + dy);
    }
    replaceAllPlants();
  }

  void removeRoom(String roomId) {
    final room = roomById(roomId);
    if (room == null) return;
    rooms.remove(room);
    for (final p in plants) {
      if (p.roomId == roomId) {
        p.roomId = null;
        p.windowId = null;
      }
    }
    // Las mediciones y la historia no se borran.
    _changed();
  }

  WindowSpot addWindow(Room room, {String name = '', String wall = 't'}) {
    final w = WindowSpot(
      id: newId(),
      name: name.isEmpty ? 'Ventana ${room.windows.length + 1}' : name,
      wall: wall,
    );
    room.windows.add(w);
    _changed();
    return w;
  }

  void updateWindow(WindowSpot window, void Function(WindowSpot w) change) {
    change(window);
    _changed();
  }

  void removeWindow(Room room, String windowId) {
    room.windows.removeWhere((w) => w.id == windowId);
    for (final p in plants) {
      if (p.windowId == windowId) p.windowId = null;
    }
    _changed();
  }

  void saveClimate(Room room, {double? temperature, double? humidity}) {
    room.temperature = temperature;
    room.humidity = humidity;
    room.climateAt = (temperature == null && humidity == null) ? null : DateTime.now();
    _changed();
  }

  // ----------------------------------------------------------------- plantas

  PlantItem? plantById(String? id) {
    if (id == null) return null;
    for (final p in plants) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Ventana más cercana de un ambiente a un punto del plano, en metros.
  WindowSpot? nearestWindow(Room room, double x, double y) {
    WindowSpot? best;
    var bestDistance = double.infinity;
    for (final w in room.windows) {
      final p = windowPoint(room, w);
      final d = (p.dx - x) * (p.dx - x) + (p.dy - y) * (p.dy - y);
      if (d < bestDistance) {
        bestDistance = d;
        best = w;
      }
    }
    return best;
  }

  /// Punto del plano donde está una ventana.
  static Offset windowPoint(Room room, WindowSpot w) {
    switch (w.wall) {
      case 'b':
        return Offset(room.x + w.pos * room.w, room.y + room.h);
      case 'r':
        return Offset(room.x + room.w, room.y + w.pos * room.h);
      case 'l':
        return Offset(room.x, room.y + w.pos * room.h);
      default:
        return Offset(room.x + w.pos * room.w, room.y);
    }
  }

  /// Lugar sugerido para una planta nueva en un ambiente: cerca de su primera
  /// ventana y hacia adentro del ambiente.
  Offset defaultSpot(Room room) {
    if (room.windows.isEmpty) {
      return Offset(room.x + room.w / 2, room.y + room.h / 2);
    }
    final p = windowPoint(room, room.windows.first);
    var x = p.dx;
    var y = p.dy;
    const inset = 0.9;
    switch (room.windows.first.wall) {
      case 'b':
        y -= inset;
      case 'l':
        x += inset;
      case 'r':
        x -= inset;
      default:
        y += inset;
    }
    return Offset(
      x.clamp(room.x + 0.2, room.x + room.w - 0.2).toDouble(),
      y.clamp(room.y + 0.2, room.y + room.h - 0.2).toDouble(),
    );
  }

  /// Lugar libre para una planta nueva: el más cercano al sugerido que esté a
  /// 0,7 m o más de las demás plantas del ambiente.
  Offset freeSpot(Room room) {
    final preferred = defaultSpot(room);
    final others = plants.where((p) => room.contains(p.x, p.y)).toList();
    bool free(Offset o) => others.every((p) => (Offset(p.x, p.y) - o).distance >= 0.7);
    if (free(preferred)) return preferred;
    Offset? best;
    var bestDistance = double.infinity;
    for (var i = 0.25; i < room.w; i += 0.5) {
      for (var j = 0.25; j < room.h; j += 0.5) {
        final o = Offset(room.x + i, room.y + j);
        if (!free(o)) continue;
        final d = (o - preferred).distance;
        if (d < bestDistance) {
          bestDistance = d;
          best = o;
        }
      }
    }
    return best ?? preferred;
  }

  PlantItem addPlant({
    required String speciesId,
    String nickname = '',
    double x = 1,
    double y = 1,
    DateTime? wateredAt,
  }) {
    final plant = PlantItem(
      id: newId(),
      speciesId: speciesId,
      nickname: nickname,
      wateredAt: wateredAt,
    );
    _place(plant, x, y);
    plants.add(plant);
    if (wateredAt != null) {
      events.add(CareEvent(
        id: newId(),
        plantId: plant.id,
        type: CareType.water,
        at: wateredAt,
        note: initialWaterNote,
      ));
    }
    _changed();
    return plant;
  }

  void _place(PlantItem plant, double x, double y) {
    plant.x = x;
    plant.y = y;
    final room = roomAt(x, y);
    plant.roomId = room?.id;
    plant.windowId = room == null ? null : nearestWindow(room, x, y)?.id;
  }

  /// Vuelve a asignar ambiente y ventana a cada planta según su posición,
  /// por ejemplo después de mover un ambiente o una ventana.
  void replaceAllPlants() {
    for (final p in plants) {
      _place(p, p.x, p.y);
    }
    _changed();
  }

  void movePlant(PlantItem plant, double x, double y) {
    _place(plant, x, y);
    _changed();
  }

  void updatePlant(PlantItem plant, void Function(PlantItem p) change) {
    change(plant);
    _changed();
  }

  void removePlant(String plantId) {
    final photos = <String>{
      for (final p in plants)
        if (p.id == plantId && p.photoPath != null) p.photoPath!,
      for (final e in events)
        if (e.plantId == plantId && e.photoPath != null) e.photoPath!,
    };
    plants.removeWhere((p) => p.id == plantId);
    readings.removeWhere((r) => r.plantId == plantId);
    moisture.removeWhere((m) => m.plantId == plantId);
    events.removeWhere((e) => e.plantId == plantId);
    treatments.removeWhere((t) => t.plantId == plantId);
    _deleteUnreferenced(photos);
    _changed();
  }

  /// Fotos que todavía usa alguna planta o evento.
  Set<String> referencedPhotos() => {
        for (final p in plants)
          if (p.photoPath != null) p.photoPath!,
        for (final e in events)
          if (e.photoPath != null) e.photoPath!,
      };

  /// Borra del teléfono las fotos de [paths] que ya nadie usa.
  void _deleteUnreferenced(Set<String> paths) {
    final used = referencedPhotos();
    for (final path in paths.difference(used)) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------- historia, riego

  CareEvent addEvent(
    String plantId,
    String type, {
    String note = '',
    String? photoPath,
    DateTime? at,
  }) {
    final e = CareEvent(
      id: newId(),
      plantId: plantId,
      type: type,
      at: at ?? DateTime.now(),
      note: note,
      photoPath: photoPath,
    );
    events.add(e);
    final plant = plantById(plantId);
    if (type == CareType.water && plant != null) _recomputeWatered(plant);
    if (type == CareType.photo && plant != null && photoPath != null) {
      plant.photoPath = photoPath;
    }
    _changed();
    return e;
  }

  /// Borra un evento de la historia. Si era un riego, el último riego de la
  /// planta pasa a ser el anterior (o queda sin dato).
  void removeEvent(String eventId) {
    final i = events.indexWhere((e) => e.id == eventId);
    if (i < 0) return;
    final removed = events.removeAt(i);
    final plant = plantById(removed.plantId);
    if (plant != null && removed.type == CareType.water) _recomputeWatered(plant);
    final photo = removed.photoPath;
    if (plant != null && photo != null) {
      if (plant.photoPath == photo) {
        // La foto de la planta pasa a ser la más reciente que quede.
        String? latest;
        DateTime? at;
        for (final e in events) {
          if (e.plantId == plant.id && e.photoPath != null && (at == null || e.at.isAfter(at))) {
            latest = e.photoPath;
            at = e.at;
          }
        }
        plant.photoPath = latest;
      }
      _deleteUnreferenced({photo});
    }
    _changed();
  }

  List<CareEvent> eventsFor(String plantId) {
    final list = events.where((e) => e.plantId == plantId).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  // ------------------------------------------------------------- mediciones

  Reading addReading(Reading reading) {
    readings.add(reading);
    _changed();
    return reading;
  }

  List<Reading> readingsFor(String plantId) {
    final list = readings.where((r) => r.plantId == plantId).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  /// Picos de PPFD de las mediciones con sol de una planta en el día de [day].
  List<double> peaksOfDay(String plantId, DateTime day) {
    final plant = plantById(plantId);
    final list = readings
        .where((r) =>
            r.plantId == plantId &&
            (plant == null || readingMatchesPlace(r, plant)) &&
            !r.probe &&
            r.isSun &&
            !r.manual &&
            !r.saturated &&
            r.sunFraction > 0.25 &&
            r.at.year == day.year &&
            r.at.month == day.month &&
            r.at.day == day.day)
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    // Mediciones muy seguidas cuentan una sola vez.
    final peaks = <double>[];
    DateTime? lastAt;
    for (final r in list) {
      if (lastAt == null || r.at.difference(lastAt).inMinutes >= 30) {
        peaks.add(r.peakPpfd);
        lastAt = r.at;
      }
    }
    return peaks;
  }

  /// Una medición describe el lugar actual de la planta si se tomó a menos de
  /// 35 cm en el plano y a menos de 15 cm de altura. Las mediciones viejas sin
  /// posición se aceptan porque no hay con qué compararlas.
  static bool readingMatchesPlace(Reading r, PlantItem p) {
    if (r.x == null || r.y == null) return true;
    final dx = r.x! - p.x;
    final dy = r.y! - p.y;
    if (dx * dx + dy * dy > 0.35 * 0.35) return false;
    final rh = r.heightCm ?? defaultPlantHeightCm;
    final ph = p.heightCm ?? defaultPlantHeightCm;
    return (rh - ph).abs() <= 15;
  }

  /// Si una medición sirve como evidencia de luz, sin mirar a qué planta o
  /// lugar corresponde: tomada con sensor (ni a ojo ni con el sensor al
  /// máximo), con posición conocida, no en el futuro, con el sol lo bastante
  /// alto para estimar el día (si es luz solar) y de menos de [maxAgeDays] días.
  /// Es la misma regla para la ficha, la calibración y la ubicación.
  static bool isUsableReading(Reading r, DateTime now, {int maxAgeDays = 180}) {
    if (r.manual || r.saturated) return false;
    if (r.x == null || r.y == null) return false;
    if (r.at.isAfter(now.add(const Duration(hours: 1)))) return false;
    if (daysBetween(r.at, now) > maxAgeDays) return false;
    if (r.isSun && r.sunFraction <= 0.25) return false;
    return r.dli > 0;
  }

  /// Medición que vale como luz actual de la planta: utilizable, no es una
  /// prueba en otro lugar y corresponde a su lugar y altura actuales.
  /// Las demás se conservan en la historia pero no deciden nada.
  Reading? lastPlantReading(String plantId, {int maxAgeDays = 180, DateTime? now}) {
    final plant = plantById(plantId);
    final today = now ?? DateTime.now();
    for (final r in readingsFor(plantId)) {
      if (r.probe || !isUsableReading(r, today, maxAgeDays: maxAgeDays)) continue;
      if (plant != null && !readingMatchesPlace(r, plant)) continue;
      return r;
    }
    return null;
  }

  DateTime? lastReadingAt(String plantId) {
    DateTime? last;
    for (final r in readings) {
      if (r.plantId == plantId && (last == null || r.at.isAfter(last))) last = r.at;
    }
    return last;
  }

  // ------------------------------------------------------- humedad de la tierra

  MoistureReading addMoisture(
    String plantId,
    MoistureLevel level, {
    String method = 'finger',
    double? percent,
    DateTime? at,
  }) {
    final m = MoistureReading(
      id: newId(),
      plantId: plantId,
      at: at ?? DateTime.now(),
      level: level,
      method: method,
      percent: percent,
    );
    moisture.add(m);
    _changed();
    return m;
  }

  /// Revisiones de humedad de una planta, de la más nueva a la más vieja.
  List<MoistureReading> moistureFor(String plantId) {
    final list = moisture.where((m) => m.plantId == plantId).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  MoistureReading? lastMoisture(String plantId) {
    final list = moistureFor(plantId);
    return list.isEmpty ? null : list.first;
  }

  // ------------------------------------------------------------ tratamientos

  Treatment? activeTreatment(String plantId, String pestId) {
    for (final t in treatments) {
      if (t.active && t.plantId == plantId && t.pestId == pestId) return t;
    }
    return null;
  }

  List<Treatment> treatmentsFor(String plantId, {bool onlyActive = false}) {
    return treatments
        .where((t) => t.plantId == plantId && (!onlyActive || t.active))
        .toList();
  }

  /// Inicia un tratamiento con tareas en los días indicados. Si ya hay uno
  /// activo para la misma plaga en esa planta, devuelve el existente.
  Treatment startTreatment(String plantId, String pestId, List<int> dayOffsets) {
    final existing = activeTreatment(plantId, pestId);
    if (existing != null) return existing;
    final t = Treatment(
      id: newId(),
      plantId: plantId,
      pestId: pestId,
      startedAt: DateTime.now(),
      tasks: [
        for (var i = 0; i < dayOffsets.length; i++)
          TreatmentTask(index: i, dayOffset: dayOffsets[i]),
      ],
    );
    treatments.add(t);
    addEvent(plantId, CareType.treatment, note: 'start:$pestId');
    return t;
  }

  /// Marca una tarea como hecha. En la última tarea (la revisión final)
  /// se indica [outcome]: 'resolved' cierra el tratamiento y 'repeat'
  /// lo cierra y abre un ciclo nuevo con [repeatOffsets].
  void completeTask(
    Treatment treatment,
    int taskIndex, {
    String? outcome,
    List<int>? repeatOffsets,
  }) {
    final task = treatment.tasks.firstWhere((t) => t.index == taskIndex);
    task.doneAt = DateTime.now();
    final isFinal = taskIndex == treatment.tasks.length - 1;
    if (isFinal) {
      treatment.endedAt = DateTime.now();
      treatment.outcome = outcome ?? 'resolved';
      addEvent(
        treatment.plantId,
        CareType.treatment,
        note: '${treatment.outcome}:${treatment.pestId}',
      );
      if (treatment.outcome == 'repeat' && repeatOffsets != null) {
        startTreatment(treatment.plantId, treatment.pestId, repeatOffsets);
        return;
      }
    }
    _changed();
  }

  /// Tareas sin hacer que vencen dentro de [withinDays] días o ya vencieron.
  List<PendingTask> pendingTasks({int withinDays = 3, DateTime? now}) {
    final today = now ?? DateTime.now();
    final limit = addDays(today, withinDays + 1);
    final result = <PendingTask>[];
    for (final t in treatments.where((t) => t.active)) {
      for (final task in t.tasks.where((k) => k.doneAt == null)) {
        final due = t.dueOf(task);
        if (due.isBefore(limit)) {
          result.add(PendingTask(
            treatment: t,
            task: task,
            due: due,
            isFinal: task.index == t.tasks.length - 1,
          ));
        }
      }
    }
    result.sort((a, b) => a.due.compareTo(b.due));
    return result;
  }
}
