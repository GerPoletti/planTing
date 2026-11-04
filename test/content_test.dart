import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp/data/content.dart';

Map<String, dynamic> _read(String name) =>
    jsonDecode(File('assets/data/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  late Content content;

  setUpAll(() {
    content = Content.fromJson(
      species: _read('species.json'),
      pests: _read('pests.json'),
      consultorio: _read('consultorio.json'),
    );
  });

  test('las especies son consistentes', () {
    expect(content.species.length, greaterThanOrEqualTo(40));
    final ids = content.species.map((s) => s.id).toSet();
    expect(ids.length, content.species.length);
    for (final s in content.species) {
      expect(s.dliMin, lessThan(s.dliMax), reason: s.id);
      expect(s.waterDays, greaterThan(0), reason: s.id);
      expect(s.names('es'), isNotEmpty, reason: s.id);
      expect(s.names('it'), isNotEmpty, reason: s.id);
      expect(s.isDraft, isTrue); // hasta verificar con fuentes
    }
  });

  test('cada plaga tiene una sola revisión final al cierre', () {
    for (final p in content.pests) {
      final tasks = p.tasks;
      expect(tasks.last.isFinal, isTrue, reason: p.id);
      expect(tasks.where((t) => t.isFinal).length, 1, reason: p.id);
      final days = p.taskOffsets;
      expect([...days]..sort(), days, reason: '${p.id} fuera de orden');
      for (final lang in ['es', 'it']) {
        expect(p.signs(lang), isNotEmpty);
        expect(p.prevention(lang), isNotEmpty);
        expect(p.petNote(lang), isNotEmpty);
        for (final t in tasks) {
          expect(t.text(lang), isNotEmpty);
        }
      }
    }
    expect(content.pestById('cochinilla')!.taskOffsets, [0, 7, 14, 21, 28]);
  });

  test('el Consultorio apunta a plagas que existen', () {
    for (final s in content.symptoms) {
      expect(s.options, isNotEmpty);
      for (final o in s.options) {
        final c = o.cause;
        expect(c.steps('es').length, 3);
        expect(c.steps('it').length, 3);
        expect(c.title('it'), isNotEmpty);
        if (c.pestId != null) {
          expect(content.pestById(c.pestId), isNotNull, reason: c.pestId);
        }
      }
    }
  });

  test('la búsqueda ignora acentos y mayúsculas', () {
    expect(content.searchSpecies('COSTILLA', 'es').map((s) => s.id),
        contains('monstera_deliciosa'));
    expect(content.searchSpecies('lingua di', 'it').map((s) => s.id),
        contains('dracaena_trifasciata'));
    expect(content.searchSpecies('arbol de jade', 'es').map((s) => s.id),
        contains('crassula_ovata'));
    expect(content.searchSpecies('', 'es').length, content.species.length);
    expect(content.searchPests('mosquito', 'es').map((p) => p.id), contains('mosquito'));
  });
}
