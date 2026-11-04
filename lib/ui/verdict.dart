import 'package:flutter/material.dart';

import '../app/strings.dart';
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
