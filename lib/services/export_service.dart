import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup.dart';
import '../data/store.dart';

/// Respaldo y restauración de todos los datos, con fotos, en un ZIP.
class ExportService {
  const ExportService._();

  /// Arma el respaldo y abre la hoja para compartirlo o guardarlo.
  static Future<void> share(AppStore store, {String subject = 'Mirasol'}) async {
    await store.flush();
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final stamp = '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/mirasol-respaldo-$stamp.zip');
    await file.writeAsBytes(Backup.build(store), flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: subject);
  }

  /// Pide un archivo de respaldo. Devuelve sus bytes, o null si se canceló.
  static Future<List<int>?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final picked = result?.files.single;
    if (picked == null) return null;
    if (picked.bytes != null) return picked.bytes;
    final path = picked.path;
    if (path == null) return null;
    return await File(path).readAsBytes();
  }
}
