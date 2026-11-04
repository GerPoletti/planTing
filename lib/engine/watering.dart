import 'dart:math' as math;

import '../data/content.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'light_model.dart';

/// Cuánto le gusta a una especie la tierra húmeda.
enum ThirstGroup {
  /// Se riega cuando la tierra se secó por completo (suculentas y similares).
  succulent,

  /// Se riega cuando se seca la parte de arriba.
  average,

  /// Prefiere la tierra apenas húmeda (helechos, hierbas).
  thirsty,
}

enum WateringAction { waterNow, waterSoon, wait, check, skipRain }

enum WateringReason {
  moistureDry,
  moistureDryingWait,
  moistureDryingSoon,
  moistureDryingNow,
  moistureMoist,
  moistureWet,
  drainage,
  scheduleDue,
  scheduleCheck,
  scheduleWait,
  rain,
}

/// Recomendación de riego para una planta.
class WateringAdvice {
  const WateringAdvice({
    required this.action,
    required this.reason,
    required this.due,
    this.level,
  });

  final WateringAction action;
  final WateringReason reason;

  /// Día estimado del próximo riego.
  final DateTime due;

  /// Humedad que se usó para decidir, si hubo una revisión reciente.
  final MoistureLevel? level;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Reglas generales de riego. Son aproximaciones: la revisión de la tierra
/// manda sobre el calendario.
class WateringEngine {
  const WateringEngine._();

  static ThirstGroup groupOf(Species species) {
    if (species.waterDays >= 12) return ThirstGroup.succulent;
    if (species.waterDays <= 5) return ThirstGroup.thirsty;
    return ThirstGroup.average;
  }

  /// Las plantas usan menos agua en invierno. En el hemisferio sur las
  /// estaciones están invertidas.
  static double seasonFactor(double? latitude, int month) {
    final south = (latitude ?? 1) < 0;
    final m = south ? (month + 5) % 12 + 1 : month;
    if (m == 12 || m <= 2) return 1.4;
    if (m <= 5) return 1.1;
    if (m <= 8) return 1.0;
    return 1.1;
  }

  /// Menos luz, la planta consume menos agua; más luz, más.
  static double lightFactor(LightVerdict? verdict) {
    switch (verdict) {
      case LightVerdict.low:
        return 1.15;
      case LightVerdict.high:
        return 0.9;
      case LightVerdict.ok:
      case null:
        return 1;
    }
  }

  /// Cada cuántos días regar hoy. Si la persona fijó un intervalo propio, se
  /// respeta tal cual.
  static int intervalDays({
    required Species species,
    int? override,
    double? latitude,
    required DateTime now,
    double lightFactor = 1,
    bool hot = false,
  }) {
    if (override != null) return math.max(1, override);
    final factor = seasonFactor(latitude, now.month) * lightFactor * (hot ? 0.8 : 1);
    return math.max(1, (species.waterDays * factor).round());
  }

  /// Revisión de humedad posterior al último riego y de menos de una semana.
  static MoistureReading? _usable(MoistureReading? m, DateTime lastWatered, DateTime now) {
    if (m == null) return null;
    if (!m.at.isAfter(lastWatered)) return null;
    if (_day(now).difference(_day(m.at)).inDays > 7) return null;
    return m;
  }

  /// Día estimado del próximo riego.
  static DateTime nextDue({
    required Species species,
    required PlantItem plant,
    MoistureReading? moisture,
    double? latitude,
    DateTime? now,
    double lightFactor = 1,
    bool hot = false,
  }) {
    final today = _day(now ?? DateTime.now());
    final watered = plant.wateredAt ?? plant.createdAt;
    final interval = intervalDays(
      species: species,
      override: plant.careIntervalDays,
      latitude: latitude,
      now: today,
      lightFactor: lightFactor,
      hot: hot,
    );
    final reading = _usable(moisture, watered, today);
    if (reading == null) return _day(watered).add(Duration(days: interval));

    final base = _day(reading.at);
    final group = groupOf(species);
    switch (reading.level) {
      case MoistureLevel.dry:
        return base;
      case MoistureLevel.drying:
        final days = group == ThirstGroup.succulent
            ? (interval * 0.3).round()
            : (group == ThirstGroup.average ? 1 : 0);
        return base.add(Duration(days: days));
      case MoistureLevel.moist:
        return base.add(Duration(days: math.max(1, (interval * 0.4).round())));
      case MoistureLevel.wet:
        return base.add(Duration(days: math.max(2, (interval * 0.6).round())));
    }
  }

  /// Qué hacer hoy con el riego de una planta. [recentMoisture] va de la
  /// revisión más nueva a la más vieja.
  static WateringAdvice advise({
    required Species species,
    required PlantItem plant,
    List<MoistureReading> recentMoisture = const [],
    double? latitude,
    DateTime? now,
    bool exterior = false,
    double? rainTodayMm,
    double lightFactor = 1,
    bool hot = false,
  }) {
    final today = _day(now ?? DateTime.now());
    final watered = plant.wateredAt ?? plant.createdAt;
    final latest = recentMoisture.isEmpty ? null : recentMoisture.first;
    final due = nextDue(
      species: species,
      plant: plant,
      moisture: latest,
      latitude: latitude,
      now: today,
      lightFactor: lightFactor,
      hot: hot,
    );

    if (exterior && (rainTodayMm ?? 0) >= 5) {
      return WateringAdvice(
        action: WateringAction.skipRain,
        reason: WateringReason.rain,
        due: today.add(const Duration(days: 1)),
      );
    }

    final fresh = _usable(latest, watered, today);
    if (fresh != null && today.difference(_day(fresh.at)).inDays <= 3) {
      final group = groupOf(species);
      switch (fresh.level) {
        case MoistureLevel.dry:
          return WateringAdvice(
            action: WateringAction.waterNow,
            reason: WateringReason.moistureDry,
            due: due,
            level: fresh.level,
          );
        case MoistureLevel.drying:
          final (action, reason) = switch (group) {
            ThirstGroup.succulent => (WateringAction.wait, WateringReason.moistureDryingWait),
            ThirstGroup.average => (WateringAction.waterSoon, WateringReason.moistureDryingSoon),
            ThirstGroup.thirsty => (WateringAction.waterNow, WateringReason.moistureDryingNow),
          };
          return WateringAdvice(action: action, reason: reason, due: due, level: fresh.level);
        case MoistureLevel.moist:
          return WateringAdvice(
            action: WateringAction.wait,
            reason: WateringReason.moistureMoist,
            due: due,
            level: fresh.level,
          );
        case MoistureLevel.wet:
          final stillWet = recentMoisture
              .where((m) => m.at.isAfter(watered) && m.level == MoistureLevel.wet)
              .toList();
          final persistent = stillWet.length >= 2 &&
              stillWet.first.at.difference(stillWet.last.at).inHours >= 48;
          return WateringAdvice(
            action: WateringAction.wait,
            reason: persistent ? WateringReason.drainage : WateringReason.moistureWet,
            due: due,
            level: fresh.level,
          );
      }
    }

    final days = due.difference(today).inDays;
    if (days <= 0) {
      return WateringAdvice(action: WateringAction.waterNow, reason: WateringReason.scheduleDue, due: due);
    }
    if (days == 1) {
      return WateringAdvice(action: WateringAction.check, reason: WateringReason.scheduleCheck, due: due);
    }
    return WateringAdvice(action: WateringAction.wait, reason: WateringReason.scheduleWait, due: due);
  }

  /// Ajuste por la luz que recibe la planta según su última medición.
  static double plantLightFactor(AppStore store, Content content, PlantItem plant) {
    final species = content.speciesById(plant.speciesId);
    final readings = store.readingsFor(plant.id);
    if (species == null || readings.isEmpty) return 1;
    final last = readings.first;
    if (last.manual || last.saturated) return 1;
    return lightFactor(LightModel.verdict(last.dli, species.dliMin, species.dliMax));
  }
}
