import '../data/content.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'light_map.dart';
import 'light_model.dart';
import 'placement.dart';

/// Con qué se sabe la luz de una planta, de menos a más confiable.
enum LightEvidence {
  /// Sin especie identificada: no hay rango con qué comparar.
  noSpecies,

  /// No está en el plano o su ambiente no deja estimar nada.
  noData,

  /// Solo el cálculo del plano, sin mediciones en el ambiente.
  theoretical,

  /// Cálculo del plano ajustado con mediciones del ambiente.
  estimated,

  /// Medición válida en su lugar y altura actuales.
  measured,
}

/// Evaluación única de la luz de una planta. Todas las pantallas la usan para
/// no dar respuestas distintas sobre lo mismo.
class LightAssessment {
  const LightAssessment({
    required this.evidence,
    this.dli,
    this.low,
    this.high,
    this.verdict,
    this.reading,
  });

  final LightEvidence evidence;

  /// DLI medido o estimado, si lo hay.
  final double? dli;

  /// Rango probable cuando es una estimación.
  final double? low;
  final double? high;

  /// Veredicto solo cuando la evidencia alcanza: medición válida, o estimación
  /// ajustada cuyo rango cae entero dentro o fuera de lo que necesita.
  final LightVerdict? verdict;

  /// La medición en la que se basa, si es [LightEvidence.measured].
  final Reading? reading;
}

LightAssessment assessPlantLight({
  required AppStore store,
  required LightMap map,
  required Species? species,
  required PlantItem plant,
}) {
  if (species == null || species.isUnknown) {
    return const LightAssessment(evidence: LightEvidence.noSpecies);
  }
  final r = store.lastPlantReading(plant.id);
  if (r != null) {
    return LightAssessment(
      evidence: LightEvidence.measured,
      dli: r.dli,
      verdict: LightModel.verdict(r.dli, species.dliMin, species.dliMax),
      reading: r,
    );
  }
  final room = map.roomAt(plant.x, plant.y);
  if (room == null) return const LightAssessment(evidence: LightEvidence.noData);
  final dli = map.lightAt(plant.x, plant.y, heightCm: plant.heightCm);
  if (dli <= 0) return const LightAssessment(evidence: LightEvidence.noData);
  final n = map.readingsIn(room.id);
  final margin = placementMargin(n);
  final low = dli * (1 - margin);
  final high = dli * (1 + margin);
  if (n == 0) {
    return LightAssessment(evidence: LightEvidence.theoretical, dli: dli, low: low, high: high);
  }
  final verdict = switch (placementFit(low, high, species.dliMin, species.dliMax)) {
    PlacementFit.good => LightVerdict.ok,
    PlacementFit.low => LightVerdict.low,
    PlacementFit.high => LightVerdict.high,
    PlacementFit.uncertain => null,
  };
  return LightAssessment(
    evidence: LightEvidence.estimated,
    dli: dli,
    low: low,
    high: high,
    verdict: verdict,
  );
}
