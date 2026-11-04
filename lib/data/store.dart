import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

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
    if (!_file.existsSync()) return;
    try {
      final data = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      settings = Settings.fromJson(
        Map<String, dynamic>.from((data['settings'] as Map?) ?? {}),
      );
      _fill(rooms, data['rooms'], Room.fromJson);
      _fill(plants, data['plants'], PlantItem.fromJson);
      _fill(readings, data['readings'], Reading.fromJson);
      _fill(moisture, data['moisture'], MoistureReading.fromJson);
      _fill(events, data['events'], CareEvent.fromJson);
      _fill(treatments, data['treatments'], Treatment.fromJson);
    } catch (e) {
      // Archivo dañado: se conserva una copia y se empieza de cero.
      debugPrint('No se pudo leer mirasol.json: $e');
      try {
        await _file.copy('${_file.path}.dañado');
      } catch (_) {}
    }
  }

  void _fill<T>(List<T> target, Object? raw, T Function(Map<String, dynamic>) parse) {
    target.clear();
    for (final item in (raw as List?) ?? const []) {
      target.add(parse(Map<String, dynamic>.from(item as Map)));
    }
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
  Future<void> flush() async {
    _debounce?.cancel();
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    await tmp.rename(_file.path);
  }

  /// Borra todos los datos y las fotos.
  Future<void> wipe() async {
    _debounce?.cancel();
    settings = Settings();
    rooms.clear();
    plants.clear();
    readings.clear();
    moisture.clear();
    events.clear();
    treatments.clear();
    if (_file.existsSync()) await _file.delete();
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
    room.climateAt = DateTime.now();
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
      wateredAt: wateredAt ?? DateTime.now(),
    );
    _place(plant, x, y);
    plants.add(plant);
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
    plants.removeWhere((p) => p.id == plantId);
    readings.removeWhere((r) => r.plantId == plantId);
    moisture.removeWhere((m) => m.plantId == plantId);
    events.removeWhere((e) => e.plantId == plantId);
    treatments.removeWhere((t) => t.plantId == plantId);
    _changed();
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
    if (type == CareType.water && plant != null) plant.wateredAt = e.at;
    if (type == CareType.photo && plant != null && photoPath != null) {
      plant.photoPath = photoPath;
    }
    _changed();
    return e;
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
    return readings
        .where((r) =>
            r.plantId == plantId &&
            r.isSun &&
            !r.manual &&
            !r.saturated &&
            r.sunFraction > 0.25 &&
            r.at.year == day.year &&
            r.at.month == day.month &&
            r.at.day == day.day)
        .map((r) => r.peakPpfd)
        .toList();
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
    final limit = DateTime(today.year, today.month, today.day)
        .add(Duration(days: withinDays + 1));
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
