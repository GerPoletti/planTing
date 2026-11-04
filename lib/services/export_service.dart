import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';

/// Comparte una copia de todos los datos como archivo JSON.
class ExportService {
  const ExportService._();

  static Future<void> share(AppStore store, {String subject = 'Mirasol'}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/mirasol-datos.json');
    await file.writeAsString(store.exportJson());
    await Share.shareXFiles([XFile(file.path)], subject: subject);
  }
}
