import 'dart:math' as math;

double _num(Object? v, [double fallback = 0]) => (v as num?)?.toDouble() ?? fallback;

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);

final math.Random _rng = math.Random();

/// Identificador corto y único para registros nuevos.
String newId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = _rng.nextInt(46656).toRadixString(36).padLeft(3, '0');
  return '$t$r';
}

/// Ajustes de la persona usuaria.
class Settings {
  Settings({
    this.latitude,
    this.longitude,
    this.placeName,
    this.northOffset = 0,
    this.languageCode,
    this.reminderEnabled = false,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.travelUntil,
    this.cameraCalibration = 1,
    this.onboardingDone = false,
    this.weatherEnabled = true,
    List<String>? primersShown,
  }) : primersShown = primersShown ?? [];

  /// Ubicación aproximada, ya redondeada a una décima de grado.
  double? latitude;
  double? longitude;
  String? placeName;

  /// Hacia dónde mira la pared de arriba del plano, en grados desde el norte.
  double northOffset;

  /// Código de idioma elegido, o null para seguir al sistema.
  String? languageCode;

  bool reminderEnabled;
  int reminderHour;
  int reminderMinute;

  /// Mientras sea posterior a hoy, no se envían avisos.
  DateTime? travelUntil;

  /// Factor para ajustar la estimación de luz con la cámara del iPhone.
  double cameraCalibration;

  bool onboardingDone;
  bool weatherEnabled;

  /// Avisos previos a permisos que ya se mostraron (location, camera, notifications).
  List<String> primersShown;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'placeName': placeName,
        'northOffset': northOffset,
        'languageCode': languageCode,
        'reminderEnabled': reminderEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'travelUntil': travelUntil?.toIso8601String(),
        'cameraCalibration': cameraCalibration,
        'onboardingDone': onboardingDone,
        'weatherEnabled': weatherEnabled,
        'primersShown': primersShown,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        placeName: j['placeName'] as String?,
        northOffset: _num(j['northOffset']),
        languageCode: j['languageCode'] as String?,
        reminderEnabled: j['reminderEnabled'] as bool? ?? false,
        reminderHour: (j['reminderHour'] as num?)?.toInt() ?? 9,
        reminderMinute: (j['reminderMinute'] as num?)?.toInt() ?? 0,
        travelUntil: _date(j['travelUntil']),
        cameraCalibration: _num(j['cameraCalibration'], 1),
        onboardingDone: j['onboardingDone'] as bool? ?? false,
        weatherEnabled: j['weatherEnabled'] as bool? ?? true,
        primersShown: ((j['primersShown'] as List?) ?? const []).map((e) => e as String).toList(),
      );
}

/// Ventana de un ambiente. [wall] es la pared del plano donde está:
/// t (arriba), r (derecha), b (abajo) o l (izquierda).
class WindowSpot {
  WindowSpot({
    required this.id,
    required this.name,
    required this.wall,
    this.pos = 0.5,
    this.obstruction = 10,
  });

  final String id;
  String name;
  String wall;

  /// Posición a lo largo de la pared, de 0 a 1.
  double pos;

  /// Altura de edificios o árboles sobre el horizonte, en grados.
  double obstruction;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'wall': wall,
        'pos': pos,
        'obstruction': obstruction,
      };

  factory WindowSpot.fromJson(Map<String, dynamic> j) => WindowSpot(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        wall: j['wall'] as String? ?? 't',
        pos: _num(j['pos'], 0.5),
        obstruction: _num(j['obstruction'], 10),
      );
}

/// Ambiente de la casa dibujado en el plano. Las medidas son en metros.
class Room {
  Room({
    required this.id,
    required this.name,
    this.exterior = false,
    this.x = 0,
    this.y = 0,
    this.w = 4,
    this.h = 3,
    this.temperature,
    this.humidity,
    this.climateAt,
    List<WindowSpot>? windows,
  }) : windows = windows ?? [];

  final String id;
  String name;
  bool exterior;
  double x;
  double y;
  double w;
  double h;
  double? temperature;
  double? humidity;
  DateTime? climateAt;
  final List<WindowSpot> windows;

  bool contains(double px, double py) =>
      px >= x && px <= x + w && py >= y && py <= y + h;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exterior': exterior,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'temperature': temperature,
        'humidity': humidity,
        'climateAt': climateAt?.toIso8601String(),
        'windows': windows.map((e) => e.toJson()).toList(),
      };

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        exterior: j['exterior'] as bool? ?? false,
        x: _num(j['x']),
        y: _num(j['y']),
        w: _num(j['w'], 4),
        h: _num(j['h'], 3),
        temperature: (j['temperature'] as num?)?.toDouble(),
        humidity: (j['humidity'] as num?)?.toDouble(),
        climateAt: _date(j['climateAt']),
        windows: ((j['windows'] as List?) ?? [])
            .map((e) => WindowSpot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Planta de la casa.
class PlantItem {
  PlantItem({
    required this.id,
    required this.speciesId,
    this.nickname = '',
    this.roomId,
    this.windowId,
    this.x = 0,
    this.y = 0,
    DateTime? createdAt,
    this.wateredAt,
    this.careIntervalDays,
    this.photoPath,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String speciesId;
  String nickname;
  String? roomId;
  String? windowId;
  double x;
  double y;
  final DateTime createdAt;
  DateTime? wateredAt;

  /// Cada cuántos días regar. Si es null se usa el de la especie.
  int? careIntervalDays;
  String? photoPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'speciesId': speciesId,
        'nickname': nickname,
        'roomId': roomId,
        'windowId': windowId,
        'x': x,
        'y': y,
        'createdAt': createdAt.toIso8601String(),
        'wateredAt': wateredAt?.toIso8601String(),
        'careIntervalDays': careIntervalDays,
        'photoPath': photoPath,
      };

  factory PlantItem.fromJson(Map<String, dynamic> j) => PlantItem(
        id: j['id'] as String,
        speciesId: j['speciesId'] as String? ?? '',
        nickname: j['nickname'] as String? ?? '',
        roomId: j['roomId'] as String?,
        windowId: j['windowId'] as String?,
        x: _num(j['x']),
        y: _num(j['y']),
        createdAt: _date(j['createdAt']),
        wateredAt: _date(j['wateredAt']),
        careIntervalDays: (j['careIntervalDays'] as num?)?.toInt(),
        photoPath: j['photoPath'] as String?,
      );
}

/// Medición de luz guardada.
class Reading {
  Reading({
    required this.id,
    required this.plantId,
    required this.at,
    required this.lux,
    required this.source,
    required this.ppfd,
    required this.dli,
    required this.peakPpfd,
    required this.sunFraction,
    this.x,
    this.y,
    this.saturated = false,
    this.manual = false,
  });

  final String id;
  final String plantId;
  final DateTime at;
  final double lux;

  /// Nombre del valor de LightSource (sun, ledCool, ...).
  final String source;
  final double ppfd;
  final double dli;
  final double peakPpfd;
  final double sunFraction;

  /// Dónde estaba la planta en el plano al medir.
  final double? x;
  final double? y;

  /// El sensor llegó a su tope: la luz real es mayor o igual.
  final bool saturated;

  /// Cargada a ojo, sin sensor.
  final bool manual;

  bool get isSun => source == 'sun';

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'at': at.toIso8601String(),
        'lux': lux,
        'source': source,
        'ppfd': ppfd,
        'dli': dli,
        'peakPpfd': peakPpfd,
        'sunFraction': sunFraction,
        'x': x,
        'y': y,
        'saturated': saturated,
        'manual': manual,
      };

  factory Reading.fromJson(Map<String, dynamic> j) => Reading(
        id: j['id'] as String,
        plantId: j['plantId'] as String,
        at: _date(j['at']) ?? DateTime.now(),
        lux: _num(j['lux']),
        source: j['source'] as String? ?? 'sun',
        ppfd: _num(j['ppfd']),
        dli: _num(j['dli']),
        peakPpfd: _num(j['peakPpfd']),
        sunFraction: _num(j['sunFraction']),
        x: (j['x'] as num?)?.toDouble(),
        y: (j['y'] as num?)?.toDouble(),
        saturated: j['saturated'] as bool? ?? false,
        manual: j['manual'] as bool? ?? false,
      );
}

/// Humedad de la tierra de una maceta, de más seca a más mojada.
enum MoistureLevel {
  dry,
  drying,
  moist,
  wet;

  /// Convierte la lectura de un medidor (0 a 100 %) al nivel más cercano.
  static MoistureLevel fromMeter(double percent) {
    if (percent < 25) return MoistureLevel.dry;
    if (percent < 45) return MoistureLevel.drying;
    if (percent < 70) return MoistureLevel.moist;
    return MoistureLevel.wet;
  }
}

/// Revisión de la humedad de la tierra de una planta.
class MoistureReading {
  MoistureReading({
    required this.id,
    required this.plantId,
    required this.at,
    required this.level,
    this.method = 'finger',
    this.percent,
  });

  final String id;
  final String plantId;
  final DateTime at;
  final MoistureLevel level;

  /// 'finger' (con el dedo) o 'meter' (con un medidor).
  final String method;
  final double? percent;

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'at': at.toIso8601String(),
        'level': level.index,
        'method': method,
        'percent': percent,
      };

  factory MoistureReading.fromJson(Map<String, dynamic> j) => MoistureReading(
        id: j['id'] as String,
        plantId: j['plantId'] as String,
        at: _date(j['at']) ?? DateTime.now(),
        level: MoistureLevel.values[((j['level'] as num?)?.toInt() ?? 1).clamp(0, 3)],
        method: j['method'] as String? ?? 'finger',
        percent: (j['percent'] as num?)?.toDouble(),
      );
}

/// Tipos de evento de la historia de una planta.
class CareType {
  static const water = 'water';
  static const fertilize = 'fertilize';
  static const repot = 'repot';
  static const prune = 'prune';
  static const note = 'note';
  static const photo = 'photo';
  static const problem = 'problem';
  static const treatment = 'treatment';
}

/// Evento de la historia de una planta.
class CareEvent {
  CareEvent({
    required this.id,
    required this.plantId,
    required this.type,
    required this.at,
    this.note = '',
    this.photoPath,
  });

  final String id;
  final String plantId;
  final String type;
  final DateTime at;
  final String note;
  final String? photoPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'type': type,
        'at': at.toIso8601String(),
        'note': note,
        'photoPath': photoPath,
      };

  factory CareEvent.fromJson(Map<String, dynamic> j) => CareEvent(
        id: j['id'] as String,
        plantId: j['plantId'] as String,
        type: j['type'] as String? ?? CareType.note,
        at: _date(j['at']) ?? DateTime.now(),
        note: j['note'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
      );
}

/// Tarea de un tratamiento. El texto sale de los datos de la plaga por [index].
class TreatmentTask {
  TreatmentTask({required this.index, required this.dayOffset, this.doneAt});

  final int index;
  final int dayOffset;
  DateTime? doneAt;

  Map<String, dynamic> toJson() => {
        'index': index,
        'dayOffset': dayOffset,
        'doneAt': doneAt?.toIso8601String(),
      };

  factory TreatmentTask.fromJson(Map<String, dynamic> j) => TreatmentTask(
        index: (j['index'] as num).toInt(),
        dayOffset: (j['dayOffset'] as num).toInt(),
        doneAt: _date(j['doneAt']),
      );
}

/// Tratamiento de una plaga en una planta.
class Treatment {
  Treatment({
    required this.id,
    required this.plantId,
    required this.pestId,
    required this.startedAt,
    required this.tasks,
    this.endedAt,
    this.outcome,
  });

  final String id;
  final String plantId;
  final String pestId;
  final DateTime startedAt;
  final List<TreatmentTask> tasks;
  DateTime? endedAt;

  /// 'resolved' o 'repeat' cuando se cierra.
  String? outcome;

  bool get active => endedAt == null;

  DateTime dueOf(TreatmentTask t) => DateTime(
        startedAt.year,
        startedAt.month,
        startedAt.day,
      ).add(Duration(days: t.dayOffset));

  int get doneCount => tasks.where((t) => t.doneAt != null).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'pestId': pestId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'outcome': outcome,
        'tasks': tasks.map((e) => e.toJson()).toList(),
      };

  factory Treatment.fromJson(Map<String, dynamic> j) => Treatment(
        id: j['id'] as String,
        plantId: j['plantId'] as String,
        pestId: j['pestId'] as String,
        startedAt: _date(j['startedAt']) ?? DateTime.now(),
        endedAt: _date(j['endedAt']),
        outcome: j['outcome'] as String?,
        tasks: ((j['tasks'] as List?) ?? [])
            .map((e) => TreatmentTask.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Tarea pendiente lista para mostrar en pantalla.
class PendingTask {
  const PendingTask({
    required this.treatment,
    required this.task,
    required this.due,
    required this.isFinal,
  });

  final Treatment treatment;
  final TreatmentTask task;
  final DateTime due;
  final bool isFinal;
}
