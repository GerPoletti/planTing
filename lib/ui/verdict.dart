import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../engine/light_assessment.dart';
import '../engine/light_model.dart';
import 'theme.dart';
import 'widgets.dart';

/// Etiqueta «Poca luz», «Luz justa» o «Demasiada luz».
Widget verdictTag(AppStrings s, LightVerdict verdict) {
  switch (verdict) {
    case LightVerdict.low:
      return Tag(s.t('verdict.low'), color: MC.terraDark, background: MC.terraLight);
    case LightVerdict.ok:
      return Tag(s.t('verdict.ok'), color: MC.olive, background: MC.sage);
    case LightVerdict.high:
      return Tag(s.t('verdict.high'), color: MC.ink, background: MC.sunLight);
  }
}

/// Etiqueta de la evaluación de luz: veredicto solo si la evidencia alcanza.
Widget assessmentTag(AppStrings s, LightAssessment a) {
  final v = a.verdict;
  if (v != null) return verdictTag(s, v);
  final key = switch (a.evidence) {
    LightEvidence.noSpecies => 'light.tag.no_species',
    LightEvidence.estimated => 'light.tag.uncertain',
    _ => 'light.tag.not_measured',
  };
  return Tag(s.t(key), color: MC.muted, background: MC.sand);
}

/// Línea que explica de dónde sale la evaluación de luz.
String? assessmentDetail(AppStrings s, LightAssessment a) {
  switch (a.evidence) {
    case LightEvidence.measured:
      return s.t('light.detail.measured', {'dli': s.number(a.dli ?? 0), 'when': s.dayMonth(a.reading!.at)});
    case LightEvidence.estimated:
      return s.t('light.detail.estimated', {'low': s.number(a.low ?? 0), 'high': s.number(a.high ?? 0)});
    case LightEvidence.theoretical:
      return s.t('light.detail.theoretical', {'low': s.number(a.low ?? 0), 'high': s.number(a.high ?? 0)});
    case LightEvidence.noSpecies:
      return s.t('light.detail.no_species');
    case LightEvidence.noData:
      return null;
  }
}
