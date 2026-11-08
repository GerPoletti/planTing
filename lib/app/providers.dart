import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../engine/light_map.dart';
import '../engine/sun_engine.dart';
import '../services/reminders.dart';
import '../services/weather_service.dart';
import 'strings.dart';

String _missing(String name) => '$name debe sobrescribirse en main()';

/// Base de datos local. Se sobrescribe al iniciar la app.
final storeProvider = ChangeNotifierProvider<AppStore>(
  (ref) => throw UnimplementedError(_missing('storeProvider')),
);

/// Especies, plagas y preguntas del Consultorio.
final contentProvider = Provider<Content>(
  (ref) => throw UnimplementedError(_missing('contentProvider')),
);

/// Todos los textos de la interfaz, cargados al iniciar.
final allStringsProvider = Provider<Map<String, Map<String, String>>>(
  (ref) => throw UnimplementedError(_missing('allStringsProvider')),
);

final weatherServiceProvider = Provider<WeatherService>(
  (ref) => throw UnimplementedError(_missing('weatherServiceProvider')),
);

/// Idioma del sistema; la app lo actualiza si cambia.
final systemLocaleProvider = StateProvider<Locale>((ref) => const Locale('es', 'ES'));

final localeProvider = Provider<Locale>((ref) {
  final saved = ref.watch(storeProvider.select((s) => s.settings.languageCode));
  return resolveLocale(saved, ref.watch(systemLocaleProvider));
});

final stringsProvider = Provider<AppStrings>((ref) {
  return AppStrings.forLocale(ref.watch(localeProvider), ref.watch(allStringsProvider));
});

/// Pronóstico de la zona, solo si hay ubicación y el clima está activado.
final weatherProvider = FutureProvider<WeatherSnapshot?>((ref) async {
  final key = ref.watch(storeProvider.select(
    (s) => (s.settings.latitude, s.settings.longitude, s.settings.weatherEnabled),
  ));
  final (lat, lon, enabled) = key;
  if (!enabled || lat == null || lon == null) return null;
  return ref.watch(weatherServiceProvider).get(lat, lon);
});

/// Alertas de frío, calor y lluvia para las plantas que están en exterior.
final weatherAlertsProvider = Provider<List<WeatherAlert>>((ref) {
  final weather = ref.watch(weatherProvider).valueOrNull;
  if (weather == null) return const [];
  final store = ref.watch(storeProvider);
  final content = ref.watch(contentProvider);
  final plants = <ExteriorPlant>[];
  for (final p in store.plants) {
    final room = store.roomById(p.roomId);
    final species = content.speciesById(p.speciesId);
    if (room != null && room.exterior && species != null) {
      plants.add(ExteriorPlant(p.id, species.tempMin));
    }
  }
  return computeWeatherAlerts(weather, plants);
});

/// Qué hay que avisar cada día de las próximas dos semanas.
final reminderPlanProvider = Provider<List<DayReminder>>((ref) {
  final store = ref.watch(storeProvider);
  return planReminders(store, ref.watch(contentProvider));
});

/// Latitud de referencia cuando no hay ubicación (centro de España e Italia).
const double fallbackLatitude = 40;

/// Mapa de luz de hoy. Se recalcula cuando cambian los datos.
final lightMapProvider = Provider<LightMap>((ref) {
  final store = ref.watch(storeProvider);
  return LightMap(
    rooms: List<Room>.of(store.rooms),
    readings: List<Reading>.of(store.readings),
    northOffset: store.settings.northOffset,
    latitude: store.settings.latitude ?? fallbackLatitude,
    dayOfYear: SunEngine.dayOfYear(DateTime.now()),
  );
});
