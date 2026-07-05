import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persists receipt images under `{appDocuments}/receipts/`. Transactions store
/// only the resulting file path (so backups stay small — image binaries are not
/// embedded).
class ImageStore {
  ImageStore._();
  static const _uuid = Uuid();

  /// Copies a picked image into the receipts folder and returns its path.
  static Future<String> add(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/receipts');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final dest = '${dir.path}/${_uuid.v4()}.$ext';
    await File(sourcePath).copy(dest);
    return dest;
  }

  static Future<void> remove(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
