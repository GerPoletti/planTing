import '../data/content.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../engine/watering.dart';
import '../data/dates.dart';

/// Lo que vence un día: riegos y tareas de tratamiento.
class DayReminder {
  const DayReminder(this.day, this.waterings, this.tasks);

  final DateTime day;
  final int waterings;
  final int tasks;

  int get total => waterings + tasks;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Próximo riego de una planta. Tiene en cuenta la especie, la estación, la luz
/// que recibe y la última revisión de humedad de la tierra.
DateTime nextWatering(
  PlantItem plant,
  Species? species, {
  MoistureReading? moisture,
  double? latitude,
  DateTime? now,
  double lightFactor = 1,
}) {
  if (species == null) {
    final interval = plant.careIntervalDays ?? 7;
    return addDays(plant.wateredAt ?? plant.createdAt, interval);
  }
  return WateringEngine.nextDue(
    species: species,
    plant: plant,
    moisture: moisture,
    latitude: latitude,
    now: now,
    lightFactor: lightFactor,
  );
}

/// Calcula qué avisar cada día de los próximos [days]. Un día sin nada
/// pendiente no aparece, y durante el modo viaje no se avisa.
/// El primer día con avisos (hoy, o el primero después del viaje) reúne también
/// lo atrasado; los siguientes, solo lo que vence ese día.
/// Si [skipToday] es true (porque el horario de hoy ya pasó), lo atrasado se
/// lleva al próximo horario futuro: mañana.
List<DayReminder> planReminders(
  AppStore store,
  Content content, {
  DateTime? now,
  int days = 14,
  bool skipToday = false,
}) {
  final today = _day(now ?? DateTime.now());
  final travelUntil =
      store.settings.travelUntil == null ? null : _day(store.settings.travelUntil!);
  final pending = store.pendingTasks(withinDays: days, now: now);
  final result = <DayReminder>[];
  var catchUp = true; // el primer día con avisos reúne también lo atrasado

  for (var i = skipToday ? 1 : 0; i < days; i++) {
    final day = addDays(today, i);
    if (travelUntil != null && !day.isAfter(travelUntil)) continue;

    var waterings = 0;
    for (final plant in store.plants) {
      if (content.speciesById(plant.speciesId)?.medium == 'air') continue;
      final due = nextWatering(
        plant,
        content.speciesById(plant.speciesId),
        moisture: store.lastMoisture(plant.id),
        latitude: store.settings.latitude,
        now: now,
        lightFactor: WateringEngine.plantLightFactor(store, content, plant),
      );
      if (catchUp ? !due.isAfter(day) : due == day) waterings++;
    }
    var tasks = 0;
    for (final task in pending) {
      final due = _day(task.due);
      if (catchUp ? !due.isAfter(day) : due == day) tasks++;
    }
    catchUp = false;
    if (waterings + tasks > 0) result.add(DayReminder(day, waterings, tasks));
  }
  return result;
}

/// Si el horario del aviso de hoy ([hour]:[minute]) ya pasó en [now].
bool todaySlotPassed(DateTime now, int hour, int minute) =>
    !DateTime(now.year, now.month, now.day, hour, minute).isAfter(now);
