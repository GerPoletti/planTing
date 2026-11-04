import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Idioma del contenido: 'it' para italiano y 'es' para cualquier español.
String contentLang(String languageCode) => languageCode == 'it' ? 'it' : 'es';

String _tr(Object? m, String lang) {
  final map = (m as Map?) ?? const {};
  return (map[lang] ?? map['es'] ?? '') as String;
}

List<String> _trList(Object? m, String lang) {
  final map = (m as Map?) ?? const {};
  final list = (map[lang] ?? map['es'] ?? const []) as List;
  return list.map((e) => e as String).toList();
}

/// Quita acentos y pasa a minúsculas para buscar sin importar la escritura.
String fold(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

class Species {
  Species(this._j);

  final Map<String, dynamic> _j;

  String get id => _j['id'] as String;
  String get scientific => _j['scientific'] as String;
  String get place => _j['place'] as String? ?? 'indoor';
  double get dliMin => (_j['dliMin'] as num).toDouble();
  double get dliMax => (_j['dliMax'] as num).toDouble();
  int get waterDays => (_j['waterDays'] as num).toInt();
  double get tempMin => (_j['tempMin'] as num).toDouble();
  double get humidityMin => (_j['humidityMin'] as num).toDouble();
  bool get toxicToPets => _j['toxicToPets'] as bool? ?? false;

  /// 'draft' mientras los datos no estén verificados con fuentes.
  String get confidence => _j['confidence'] as String? ?? 'draft';
  bool get isDraft => confidence != 'verified';

  List<String> names(String lang) => _trList(_j['names'], contentLang(lang));

  /// Nombre común principal; si no hay, el científico.
  String name(String lang) {
    final list = names(lang);
    return list.isEmpty ? scientific : list.first;
  }
}

class PestTask {
  PestTask(this._j);

  final Map<String, dynamic> _j;

  int get day => (_j['day'] as num).toInt();
  bool get isFinal => _j['final'] as bool? ?? false;
  String text(String lang) => _tr(_j['text'], contentLang(lang));
}

class Pest {
  Pest(this._j);

  final Map<String, dynamic> _j;

  String get id => _j['id'] as String;
  String get where => _j['where'] as String? ?? 'leaf';
  String get confidence => _j['confidence'] as String? ?? 'draft';
  List<String> names(String lang) => _trList(_j['names'], contentLang(lang));
  String name(String lang) => names(lang).first;
  String signs(String lang) => _tr(_j['signs'], contentLang(lang));
  String prevention(String lang) => _tr(_j['prevention'], contentLang(lang));
  String petNote(String lang) => _tr(_j['petNote'], contentLang(lang));

  List<PestTask> get tasks => ((_j['tasks'] as List?) ?? const [])
      .map((e) => PestTask(Map<String, dynamic>.from(e as Map)))
      .toList();

  /// Días de cada tarea, para crear un tratamiento.
  List<int> get taskOffsets => tasks.map((t) => t.day).toList();
}

class Cause {
  Cause(this._j);

  final Map<String, dynamic> _j;

  String title(String lang) => _tr(_j['title'], contentLang(lang));
  String why(String lang) => _tr(_j['why'], contentLang(lang));
  String? get pestId => _j['pestId'] as String?;

  List<String> steps(String lang) => ((_j['steps'] as List?) ?? const [])
      .map((s) => _tr(s, contentLang(lang)))
      .toList();
}

class SymptomOption {
  SymptomOption(this._j);

  final Map<String, dynamic> _j;

  String label(String lang) => _tr(_j['label'], contentLang(lang));
  Cause get cause => Cause(Map<String, dynamic>.from(_j['cause'] as Map));
}

class Symptom {
  Symptom(this._j);

  final Map<String, dynamic> _j;

  String get id => _j['id'] as String;
  String title(String lang) => _tr(_j['title'], contentLang(lang));
  String question(String lang) => _tr(_j['question'], contentLang(lang));

  List<SymptomOption> get options => ((_j['options'] as List?) ?? const [])
      .map((e) => SymptomOption(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Contenido de la app: especies, plagas y preguntas del Consultorio.
class Content {
  Content({
    required this.species,
    required this.pests,
    required this.symptoms,
  });

  final List<Species> species;
  final List<Pest> pests;
  final List<Symptom> symptoms;

  factory Content.fromJson({
    required Map<String, dynamic> species,
    required Map<String, dynamic> pests,
    required Map<String, dynamic> consultorio,
  }) {
    return Content(
      species: ((species['species'] as List?) ?? const [])
          .map((e) => Species(Map<String, dynamic>.from(e as Map)))
          .toList(),
      pests: ((pests['pests'] as List?) ?? const [])
          .map((e) => Pest(Map<String, dynamic>.from(e as Map)))
          .toList(),
      symptoms: ((consultorio['symptoms'] as List?) ?? const [])
          .map((e) => Symptom(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static Future<Content> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    Future<Map<String, dynamic>> read(String name) async =>
        jsonDecode(await b.loadString('assets/data/$name')) as Map<String, dynamic>;
    return Content.fromJson(
      species: await read('species.json'),
      pests: await read('pests.json'),
      consultorio: await read('consultorio.json'),
    );
  }

  Species? speciesById(String? id) {
    for (final s in species) {
      if (s.id == id) return s;
    }
    return null;
  }

  Pest? pestById(String? id) {
    for (final p in pests) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Busca especies por nombre común o científico, sin importar acentos.
  List<Species> searchSpecies(String query, String lang) {
    final q = fold(query.trim());
    if (q.isEmpty) return List<Species>.from(species);
    return species.where((s) {
      if (fold(s.scientific).contains(q)) return true;
      return s.names(lang).any((n) => fold(n).contains(q));
    }).toList();
  }

  List<Pest> searchPests(String query, String lang) {
    final q = fold(query.trim());
    if (q.isEmpty) return List<Pest>.from(pests);
    return pests.where((p) {
      return p.names(lang).any((n) => fold(n).contains(q)) ||
          fold(p.signs(lang)).contains(q);
    }).toList();
  }
}
