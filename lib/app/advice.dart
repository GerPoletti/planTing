import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../engine/watering.dart';
import 'providers.dart';

/// Recomendación de riego de una planta con todo lo que se sabe hoy: especie,
/// estación, luz, revisiones de la tierra y lluvia. Se llama desde build().
WateringAdvice? wateringAdviceFor(WidgetRef ref, PlantItem plant) {
  final store = ref.watch(storeProvider);
  final content = ref.watch(contentProvider);
  final species = content.speciesById(plant.speciesId);
  // Sin especie cargada o sin tierra (plantas aéreas) no hay revisión con el dedo.
  if (species == null || species.medium == 'air') return null;
  final history = store.moistureFor(plant.id);
  final room = store.roomById(plant.roomId);
  final weather = ref.watch(weatherProvider).valueOrNull;
  final rain = weather?.dayOf(DateTime.now())?.precipitationMm;
  return WateringEngine.advise(
    species: species,
    plant: plant,
    recentMoisture: history.take(6).toList(),
    latitude: store.settings.latitude,
    // La lluvia solo cuenta si la maceta queda a la intemperie.
    exterior: (room?.exterior ?? false) && !(room?.covered ?? false),
    rainTodayMm: rain,
    lightFactor: WateringEngine.plantLightFactor(store, content, plant),
  );
}
