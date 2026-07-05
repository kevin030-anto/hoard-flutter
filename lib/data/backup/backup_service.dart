import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/app_providers.dart';

/// Exports/imports the dataset as a `.json` file. Supports partial backups
/// (selected data sets) and either sharing or saving to device storage.
class BackupService {
  static String _fileName() =>
      'finflow_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

  static String buildJson(AppNotifier notifier, {Set<String>? parts}) =>
      const JsonEncoder.withIndent('  ').convert(notifier.exportData(parts));

  /// Writes to a temp file and opens the share sheet (Drive/Files/etc.).
  static Future<void> share(String json) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_fileName()}');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'FinFlow backup'),
    );
  }

  /// Saves to a location the user picks via the system "Save as" dialog.
  /// Returns the saved path, or null if cancelled.
  static Future<String?> saveToDevice(String json) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save FinFlow backup',
      fileName: _fileName(),
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    if (path == null) return null;
    // On desktop the picker returns a path but does not write; ensure content.
    final f = File(path);
    if (!await f.exists() || (await f.length()) == 0) {
      await f.writeAsString(json);
    }
    return path;
  }

  /// Lets the user pick a `.json` backup and restores it. Returns true if data
  /// was restored, false if cancelled. Throws on invalid files.
  static Future<bool> restore(AppNotifier notifier) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return false;

    final picked = result.files.single;
    String content;
    if (picked.bytes != null) {
      content = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      content = await File(picked.path!).readAsString();
    } else {
      throw const FormatException('Could not read the selected file.');
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Not a valid FinFlow backup file.');
    }
    await notifier.importData(decoded);
    return true;
  }
}
