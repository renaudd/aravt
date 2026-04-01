import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  static File? _logFile;

  static Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/aravt_crash_log.txt');
      await _logFile?.writeAsString("--- NEW SESSION START ---\n", mode: FileMode.write, flush: true);
    } catch (_) {}
  }

  static void log(String message) {
    print(message);
    if (_logFile != null) {
      try {
        _logFile!.writeAsStringSync("${DateTime.now().toIso8601String()}: $message\n", mode: FileMode.append, flush: true);
      } catch (_) {}
    }
  }
}
