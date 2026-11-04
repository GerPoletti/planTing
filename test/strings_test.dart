import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/app/strings.dart';

Map<String, String> _read(String name) {
  final raw = jsonDecode(File('assets/l10n/$name.json').readAsStringSync()) as Map<String, dynamic>;
  return raw.map((k, v) => MapEntry(k, v as String));
}

Set<String> _markers(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  final es = _read('es');
  final it = _read('it');
  final esAr = _read('es_AR');
  final all = {'es': es, 'es_AR': esAr, 'it': it};

  test('español e italiano tienen las mismas claves y marcadores', () {
    expect(it.keys.toSet(), es.keys.toSet());
    for (final k in es.keys) {
      expect(_markers(it[k]!), _markers(es[k]!), reason: k);
    }
  });

  test('el voseo solo reemplaza claves que existen', () {
    for (final k in esAr.keys) {
      expect(es.containsKey(k), isTrue, reason: k);
      expect(_markers(esAr[k]!), _markers(es[k]!), reason: k);
    }
  });

  test('cada plural tiene singular y plural', () {
    for (final k in es.keys.where((k) => k.endsWith('_one'))) {
      final base = k.substring(0, k.length - 4);
      expect(es.containsKey('${base}_other'), isTrue, reason: base);
    }
    for (final k in es.keys.where((k) => k.endsWith('_other'))) {
      final base = k.substring(0, k.length - 6);
      expect(es.containsKey('${base}_one'), isTrue, reason: base);
    }
  });

  test('se elige el idioma guardado o el del teléfono', () {
    expect(resolveLocale('it', const Locale('es', 'ES')), const Locale('it'));
    expect(resolveLocale('es_AR', const Locale('it')), const Locale('es', 'AR'));
    expect(resolveLocale(null, const Locale('it', 'IT')), const Locale('it'));
    expect(resolveLocale(null, const Locale('es', 'AR')), const Locale('es', 'AR'));
    expect(resolveLocale(null, const Locale('es', 'MX')), const Locale('es', 'ES'));
    expect(resolveLocale(null, const Locale('en', 'US')), const Locale('es', 'ES'));
  });

  test('el español rioplatense pisa solo lo que cambia', () {
    final base = {'a': 'Mide', 'b': 'Hola'};
    final data = {
      'es': base,
      'es_AR': {'a': 'Medí'},
      'it': {'a': 'Misura', 'b': 'Ciao'},
    };
    expect(AppStrings.forLocale(const Locale('es', 'ES'), data).t('a'), 'Mide');
    expect(AppStrings.forLocale(const Locale('es', 'AR'), data).t('a'), 'Medí');
    expect(AppStrings.forLocale(const Locale('es', 'AR'), data).t('b'), 'Hola');
    expect(AppStrings.forLocale(const Locale('it'), data).t('b'), 'Ciao');
  });

  test('marcadores, plurales y claves faltantes', () {
    final s = AppStrings.forLocale(const Locale('es', 'ES'), all);
    expect(s.plural('rel.in_days', 1), 'en 1 día');
    expect(s.plural('rel.in_days', 3), 'en 3 días');
    expect(s.t('clave.inexistente'), 'clave.inexistente');
    expect(s.t('rel.today'), 'hoy');
    final italian = AppStrings.forLocale(const Locale('it'), all);
    expect(italian.plural('rel.late', 2), 'in ritardo di 2 giorni');
    expect(italian.lang, 'it');
    expect(s.code, 'es_ES');
  });

  test('cuenta regresiva en días', () {
    final s = AppStrings.forLocale(const Locale('es', 'ES'), all);
    final now = DateTime(2026, 10, 31, 9);
    expect(s.relativeDay(DateTime(2026, 10, 31), now: now), 'hoy');
    expect(s.relativeDay(DateTime(2026, 11, 1), now: now), 'mañana');
    expect(s.relativeDay(DateTime(2026, 11, 4), now: now), 'en 4 días');
    expect(s.relativeDay(DateTime(2026, 10, 30), now: now), 'atrasada 1 día');
  });
}
