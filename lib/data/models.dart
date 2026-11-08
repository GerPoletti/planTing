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

/// Alturas rápidas para ubicar una maceta, en cm desde el piso.
enum PlantLevel {
  floor(0),
  table(75),
  shelf(150),
  hanging(190);

  const PlantLevel(this.cm);
  final double cm;

  /// Nivel más cercano a una altura.
  static PlantLevel nearest(double cm) {
    var best = PlantLevel.table;
    for (final l in PlantLevel.values) {
      if ((l.cm - cm).abs() < (best.cm - cm).abs()) best = l;
    }
    return best;
  }
}

/// Altura que se supone cuando una planta no la tiene cargada (una mesa).
const double defaultPlantHeightCm = 75;

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

  /// Si hoy cae dentro del modo viaje (incluye el último día elegido).
  bool travelingOn(DateTime now) {
    final t = travelUntil;
    if (t == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return !today.isAfter(DateTime(t.year, t.month, t.day));
  }

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
    this.sillCm = 90,
    this.topCm = 210,
    this.widthCm = 120,
  });

  final String id;
  String name;
  String wall;

  /// Altura del alféizar (borde de abajo del vidrio) desde el piso, en cm.
  /// Una puerta-ventana tiene 0.
  double sillCm;

  /// Altura del borde de arriba de la ventana desde el piso, en cm.
  double topCm;

  /// Ancho de la ventana, en cm.
  double widthCm;

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
        'sillCm': sillCm,
        'topCm': topCm,
        'widthCm': widthCm,
      };

  factory WindowSpot.fromJson(Map<String, dynamic> j) => WindowSpot(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        wall: j['wall'] as String? ?? 't',
        pos: _num(j['pos'], 0.5),
        obstruction: _num(j['obstruction'], 10),
        sillCm: _num(j['sillCm'], 90),
        topCm: _num(j['topCm'], 210),
        widthCm: _num(j['widthCm'], 120),
      );
}

/// Tipos de ambiente. Los exteriores reciben luz del cielo abierto según sus
/// lados; los interiores, solo por sus ventanas.
class RoomKind {
  static const indoor = 'indoor';
  static const balcony = 'balcony';
  static const terrace = 'terrace';
  static const garden = 'garden';
  static const all = [indoor, balcony, terrace, garden];
}

/// Qué hay en cada lado de un espacio exterior.
class SideType {
  /// Pared o fachada: tapa hasta la altura de las paredes.
  static const wall = 'wall';

  /// Baranda o muro bajo: tapa solo hasta su altura.
  static const railing = 'railing';

  /// Abierto: no tapa nada.
  static const open = 'open';
  static const all = [wall, railing, open];
}

/// Lados del plano: arriba, derecha, abajo, izquierda.
const List<String> planSides = ['t', 'r', 'b', 'l'];

/// Lados típicos de cada tipo de espacio exterior. [front] es el lado abierto
/// de un balcón.
Map<String, String> defaultSides(String kind, {String front = 't'}) {
  switch (kind) {
    case RoomKind.balcony:
      return {for (final k in planSides) k: k == front ? SideType.railing : SideType.wall};
    case RoomKind.terrace:
      return {for (final k in planSides) k: SideType.railing};
    case RoomKind.garden:
      return {for (final k in planSides) k: SideType.open};
    default:
      return {for (final k in planSides) k: SideType.wall};
  }
}

/// Ambiente de la casa dibujado en el plano. Las medidas son en metros.
class Room {
  Room({
    required this.id,
    required this.name,
    bool exterior = false,
    String? kind,
    Map<String, String>? sides,
    bool? covered,
    this.skyObstruction = 15,
    this.wallCm = 270,
    this.railingCm = 100,
    this.x = 0,
    this.y = 0,
    this.w = 4,
    this.h = 3,
    this.temperature,
    this.humidity,
    this.climateAt,
    List<WindowSpot>? windows,
  })  : windows = windows ?? [],
        kind = kind ?? (exterior ? RoomKind.balcony : RoomKind.indoor),
        sides = sides ?? defaultSides(kind ?? (exterior ? RoomKind.balcony : RoomKind.indoor)),
        covered = covered ?? (kind ?? (exterior ? RoomKind.balcony : RoomKind.indoor)) == RoomKind.balcony;

  final String id;
  String name;
  /// Uno de [RoomKind]. Se puede cambiar.
  String kind;

  bool get exterior => kind != RoomKind.indoor;

  /// En exteriores: qué hay en cada lado ('t', 'r', 'b', 'l'), uno de [SideType].
  final Map<String, String> sides;

  /// En exteriores: si tiene techo o el balcón de arriba (a la altura de [wallCm]).
  bool covered;

  /// En exteriores: altura de edificios o árboles alrededor, en grados.
  double skyObstruction;

  /// Altura de las paredes (y del techo, si tiene), en cm.
  double wallCm;

  /// Altura de la baranda o del muro bajo, en cm.
  double railingCm;

  String sideOf(String side) => sides[side] ?? SideType.wall;
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
        'kind': kind,
        'sides': sides,
        'covered': covered,
        'skyObstruction': skyObstruction,
        'wallCm': wallCm,
        'railingCm': railingCm,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'temperature': temperature,
        'humidity': humidity,
        'climateAt': climateAt?.toIso8601String(),
        'windows': windows.map((e) => e.toJson()).toList(),
      };

  factory Room.fromJson(Map<String, dynamic> j) {
    final windows = ((j['windows'] as List?) ?? [])
        .map((e) => WindowSpot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final exterior = j['exterior'] as bool? ?? false;
    final kind = j['kind'] as String? ?? (exterior ? RoomKind.balcony : RoomKind.indoor);
    Map<String, String>? sides;
    final rawSides = j['sides'];
    if (rawSides is Map) {
      sides = {for (final e in rawSides.entries) e.key as String: e.value as String};
    } else if (kind != RoomKind.indoor && windows.isNotEmpty) {
      // Datos de antes: un exterior con «ventanas» queda abierto (con baranda)
      // del lado de cada ventana.
      sides = defaultSides(RoomKind.balcony, front: windows.first.wall);
      for (final w in windows) {
        sides[w.wall] = SideType.railing;
      }
    }
    return Room(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        kind: kind,
        sides: sides,
        covered: j['covered'] as bool?,
        skyObstruction: _num(j['skyObstruction'], 15),
        wallCm: _num(j['wallCm'], 270),
        railingCm: _num(j['railingCm'], 100),
        x: _num(j['x']),
        y: _num(j['y']),
        w: _num(j['w'], 4),
        h: _num(j['h'], 3),
        temperature: (j['temperature'] as num?)?.toDouble(),
        humidity: (j['humidity'] as num?)?.toDouble(),
        climateAt: _date(j['climateAt']),
        windows: windows,
      );
  }
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
    this.lampHours,
    this.heightCm,
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

  /// Horas por día que la enciende una lámpara de cultivo. Si es null se usan 12.
  int? lampHours;

  /// Altura de la maceta desde el piso, en cm. Si es null se usa una mesa.
  double? heightCm;

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
        'lampHours': lampHours,
        'heightCm': heightCm,
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
        lampHours: (j['lampHours'] as num?)?.toInt(),
        heightCm: (j['heightCm'] as num?)?.toDouble(),
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
    this.probe = false,
    this.heightCm,
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

  /// Medición de prueba en otro lugar: sirve para el mapa de luz pero no
  /// describe la luz actual de la planta.
  final bool probe;

  /// Altura desde el piso donde se midió, en cm (null en datos viejos).
  final double? heightCm;

  bool get isSun => source == 'sun';

  /// La misma medición en otro punto del plano (al corregir el dibujo).
  Reading movedTo(double nx, double ny) => Reading(
        id: id,
        plantId: plantId,
        at: at,
        lux: lux,
        source: source,
        ppfd: ppfd,
        dli: dli,
        peakPpfd: peakPpfd,
        sunFraction: sunFraction,
        x: nx,
        y: ny,
        saturated: saturated,
        manual: manual,
        probe: probe,
        heightCm: heightCm,
      );

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
        'probe': probe,
        'heightCm': heightCm,
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
        probe: j['probe'] as bool? ?? false,
        heightCm: (j['heightCm'] as num?)?.toDouble(),
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

  DateTime dueOf(TreatmentTask t) =>
      DateTime(startedAt.year, startedAt.month, startedAt.day + t.dayOffset);

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
