import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'models.dart';
import 'store.dart';

/// Respaldo completo en un ZIP: `mirasol.json` con los datos y `photos/` con
/// las fotos. Las rutas de las fotos se guardan relativas (`photos/xxx.jpg`)
/// para poder restaurarlas en otro teléfono.
class Backup {
  const Backup._();

  static const String dataName = 'mirasol.json';
  static const String photosPrefix = 'photos/';

  static String _base(String path) => path.split(RegExp(r'[\\/]')).last;

  /// Cambia cada ruta de foto de [data] con [map]. Modifica [data].
  static void _mapPhotos(Map<String, dynamic> data, String? Function(String) map) {
    for (final key in ['plants', 'events']) {
      for (final item in (data[key] as List?) ?? const []) {
        final m = item as Map;
        final p = m['photoPath'];
        if (p is String && p.isNotEmpty) m['photoPath'] = map(p);
      }
    }
  }

  /// Arma el ZIP con los datos y las fotos de [store].
  static List<int> build(AppStore store) {
    final data = jsonDecode(jsonEncode(store.toJson())) as Map<String, dynamic>;
    _mapPhotos(data, (p) => '$photosPrefix${_base(p)}');
    final archive = Archive();
    final json = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    archive.addFile(ArchiveFile(dataName, json.length, json));
    // Solo las fotos que usa alguna planta o evento: las de plantas borradas no viajan.
    for (final path in store.referencedPhotos()) {
      final f = File(path);
      if (!f.existsSync()) continue;
      final bytes = f.readAsBytesSync();
      archive.addFile(ArchiveFile('$photosPrefix${_base(f.path)}', bytes.length, bytes));
    }
    return ZipEncoder().encode(archive) ?? const [];
  }

  /// Lee un respaldo (ZIP de Mirasol o el JSON exportado antes) y reemplaza
  /// todos los datos de [store]. Si el archivo no es válido lanza
  /// [FormatException] y no cambia nada.
  /// Tamaño máximo de un respaldo y cantidad máxima de fotos.
  static const int maxBytes = 400 * 1024 * 1024;
  static const int maxPhotos = 5000;

  /// Tamaño máximo de todo lo que se descomprime.
  static const int maxUnpackedBytes = 800 * 1024 * 1024;

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Nombres de foto (sin carpeta) que usan los datos.
  static Set<String> _referenced(Map<String, dynamic> data) {
    final names = <String>{};
    for (final key in ['plants', 'events']) {
      for (final item in (data[key] as List?) ?? const []) {
        final p = (item as Map)['photoPath'];
        if (p is String && p.isNotEmpty) names.add(_base(p));
      }
    }
    return names;
  }

  static Future<void> restore(AppStore store, List<int> bytes) async {
    if (bytes.length > maxBytes) throw const FormatException('El respaldo es demasiado grande');
    final Map<String, dynamic> data;
    final photos = <String, List<int>>{};
    final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    try {
      if (isZip) {
        final archive = ZipDecoder().decodeBytes(bytes);
        // Límite de lo descomprimido, antes de leer el contenido.
        var unpacked = 0;
        for (final f in archive.files) {
          unpacked += f.size;
          if (unpacked > maxUnpackedBytes) throw const FormatException('El respaldo es demasiado grande');
        }
        Map<String, dynamic>? found;
        for (final f in archive.files) {
          if (!f.isFile) continue;
          final name = f.name;
          if (_base(name) == dataName) {
            found = jsonDecode(utf8.decode(f.content as List<int>)) as Map<String, dynamic>;
          } else if (name.startsWith(photosPrefix) && _base(name).isNotEmpty) {
            if (photos.length >= maxPhotos) throw const FormatException('Demasiadas fotos');
            photos[_base(name)] = f.content as List<int>;
          }
        }
        if (found == null) throw const FormatException('Falta mirasol.json');
        data = found;
      } else {
        data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Respaldo ilegible: $e');
    }

    // Todas las fotos que usan los datos tienen que venir en el ZIP (o, en el
    // formato JSON viejo, estar ya en el teléfono). No se informa una
    // restauración completa si faltan.
    final needed = _referenced(data);
    final missing = needed.where((n) =>
        isZip ? !photos.containsKey(n) : !File('${store.photosDir.path}/$n').existsSync());
    if (missing.isNotEmpty) {
      throw FormatException('Faltan ${missing.length} fotos en el respaldo');
    }

    // Primero se valida todo; recién después se tocan las fotos y los datos.
    store.validateJson(data);

    final previous = jsonDecode(jsonEncode(store.toJson())) as Map<String, dynamic>;
    final created = <File>[];
    final renamed = <String, String>{};
    try {
      if (!store.photosDir.existsSync()) store.photosDir.createSync(recursive: true);
      for (final entry in photos.entries) {
        if (!needed.contains(entry.key)) continue; // fotos que nadie usa no se copian
        var name = entry.key;
        var dest = File('${store.photosDir.path}/$name');
        if (dest.existsSync()) {
          // Mismo nombre no garantiza misma foto: si el contenido difiere se
          // guarda con otro nombre, sin pisar la que ya hay en el teléfono.
          if (_sameBytes(dest.readAsBytesSync(), entry.value)) continue;
          final dot = name.lastIndexOf('.');
          final stem = dot > 0 ? name.substring(0, dot) : name;
          final ext = dot > 0 ? name.substring(dot) : '';
          name = '$stem-${newId()}$ext';
          dest = File('${store.photosDir.path}/$name');
          renamed[entry.key] = name;
        }
        final tmp = File('${dest.path}.tmp');
        await tmp.writeAsBytes(entry.value, flush: true);
        await tmp.rename(dest.path);
        created.add(dest);
      }
      _mapPhotos(data, (p) {
        final base = _base(p);
        return '${store.photosDir.path}/${renamed[base] ?? base}';
      });
      store.replaceAll(data);
      // Recién se informa éxito cuando los datos quedaron escritos en el disco.
      await store.flushOrThrow();
    } catch (_) {
      // Vuelve todo como estaba: datos anteriores y sin las fotos nuevas.
      store.replaceAll(previous);
      await store.flush();
      for (final f in created) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }
  }
}
