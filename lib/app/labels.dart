import '../data/content.dart';
import '../data/models.dart';
import 'strings.dart';

/// Nombre para mostrar de una planta: el apodo o el de su especie.
String plantName(PlantItem plant, Content content, String lang) {
  if (plant.nickname.trim().isNotEmpty) return plant.nickname.trim();
  return content.speciesById(plant.speciesId)?.name(lang) ?? plant.speciesId;
}

const List<String> _dirKeys = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];

/// Punto cardinal más cercano a un azimut, por ejemplo 268° -> «Oeste».
String directionName(AppStrings s, double azimuth) {
  final i = ((azimuth % 360) / 45).round() % 8;
  return s.t('dir.${_dirKeys[i]}');
}

/// Lee un número escrito a mano; acepta coma o punto decimal.
double? parseNum(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Número sin ceros de más, para mostrarlo en un campo de texto.
String plainNum(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();
