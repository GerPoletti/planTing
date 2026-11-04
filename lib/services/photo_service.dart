import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../data/store.dart';

/// Elige o saca una foto y la guarda dentro de la carpeta de la app.
class PhotoService {
  const PhotoService._();

  static final ImagePicker _picker = ImagePicker();

  /// Devuelve la ruta de la copia guardada, o null si se canceló.
  static Future<String?> pick(AppStore store, {required bool camera}) async {
    final picked = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return null;
    final dest = File('${store.photosDir.path}/${newId()}.jpg');
    await File(picked.path).copy(dest.path);
    return dest.path;
  }
}
