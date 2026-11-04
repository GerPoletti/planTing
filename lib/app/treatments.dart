import '../data/content.dart';
import '../data/models.dart';
import '../data/store.dart';

/// Inicia el tratamiento de una plaga en una planta con el cronograma de la plaga.
Treatment? startPestTreatment(AppStore store, Content content, String plantId, String pestId) {
  final pest = content.pestById(pestId);
  if (pest == null || store.plantById(plantId) == null) return null;
  return store.startTreatment(plantId, pestId, pest.taskOffsets);
}
