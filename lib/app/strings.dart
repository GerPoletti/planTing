import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:intl/intl.dart';
import '../data/dates.dart';

/// Idiomas de la app: español de España, español rioplatense e italiano.
const List<Locale> supportedAppLocales = [
  Locale('es', 'ES'),
  Locale('es', 'AR'),
  Locale('it'),
];

/// Códigos que se guardan en los ajustes.
const List<String> languageCodes = ['es_ES', 'es_AR', 'it'];

/// Elige el idioma: el guardado en ajustes o, si no hay, el del teléfono.
Locale resolveLocale(String? saved, Locale system) {
  switch (saved) {
    case 'it':
      return const Locale('it');
    case 'es_AR':
      return const Locale('es', 'AR');
    case 'es_ES':
      return const Locale('es', 'ES');
  }
  if (system.languageCode == 'it') return const Locale('it');
  if (system.languageCode == 'es' && system.countryCode == 'AR') {
    return const Locale('es', 'AR');
  }
  return const Locale('es', 'ES');
}

/// Textos de la interfaz. La base es español de España; el español rioplatense
/// solo reemplaza lo que cambia con el voseo.
class AppStrings {
  AppStrings._(this.locale, this._map);

  final Locale locale;
  final Map<String, String> _map;

  static Future<Map<String, Map<String, String>>> loadAll([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final all = <String, Map<String, String>>{};
    for (final name in ['es', 'es_AR', 'it']) {
      final raw = jsonDecode(await b.loadString('assets/l10n/$name.json')) as Map<String, dynamic>;
      all[name] = raw.map((k, v) => MapEntry(k, v as String));
    }
    return all;
  }

  factory AppStrings.forLocale(Locale locale, Map<String, Map<String, String>> all) {
    final isItalian = locale.languageCode == 'it';
    final merged = <String, String>{...?all[isItalian ? 'it' : 'es']};
    if (!isItalian && locale.countryCode == 'AR') {
      merged.addAll(all['es_AR'] ?? const {});
    }
    return AppStrings._(locale, merged);
  }

  /// Idioma del contenido (especies, plagas): 'it' o 'es'.
  String get lang => locale.languageCode == 'it' ? 'it' : 'es';

  /// Código para guardar en ajustes.
  String get code => locale.languageCode == 'it'
      ? 'it'
      : (locale.countryCode == 'AR' ? 'es_AR' : 'es_ES');

  /// Texto por clave. Los marcadores {nombre} se reemplazan con [args].
  String t(String key, [Map<String, Object?> args = const {}]) {
    var text = _map[key] ?? key;
    args.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    return text;
  }

  /// Plural: usa las claves `clave_one` y `clave_other`, con el marcador {n}.
  String plural(String key, int n, [Map<String, Object?> args = const {}]) {
    return t(n == 1 ? '${key}_one' : '${key}_other', {'n': n, ...args});
  }

  /// Número con los separadores del idioma (coma decimal en español e italiano).
  String number(double value, {int digits = 1}) {
    return NumberFormat.decimalPatternDigits(
      locale: locale.toString(),
      decimalDigits: digits,
    ).format(value);
  }

  String date(DateTime d) => DateFormat.yMMMd(locale.toString()).format(d);
  String dayMonth(DateTime d) => DateFormat.MMMd(locale.toString()).format(d);
  String weekday(DateTime d) => DateFormat.EEEE(locale.toString()).format(d);

  /// Inicial del mes (1 a 12) en el idioma, para los gráficos.
  String monthInitial(int month) =>
      DateFormat('MMMMM', locale.toString()).format(DateTime(2026, month, 1)).toUpperCase();

  String dayMonthTime(DateTime d) =>
      '${dayMonth(d)} · ${DateFormat.Hm(locale.toString()).format(d)}';

  /// Cuenta regresiva en días: hoy, mañana, en N días o atrasado.
  String relativeDay(DateTime due, {DateTime? now}) {
    final days = daysBetween(now ?? DateTime.now(), due);
    if (days < 0) return plural('rel.late', -days);
    if (days == 0) return t('rel.today');
    if (days == 1) return t('rel.tomorrow');
    return plural('rel.in_days', days);
  }
}
