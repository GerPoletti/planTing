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
  if (species == null) return null;
  final history = store.moistureFor(plant.id);
  final room = store.roomById(plant.roomId);
  final days = ref.watch(weatherProvider).valueOrNull?.days;
  final rain = (days != null && days.isNotEmpty) ? days.first.precipitationMm : null;
  return WateringEngine.advise(
    species: species,
    plant: plant,
    recentMoisture: history.take(6).toList(),
    latitude: store.settings.latitude,
    exterior: room?.exterior ?? false,
    rainTodayMm: rain,
    lightFactor: WateringEngine.plantLightFactor(store, content, plant),
  );
}
