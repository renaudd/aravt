// models/save_file_info.dart
import 'package:aravt/models/game_date.dart';

/// A lightweight class to hold metadata about a save file.
class SaveFileInfo {
  /// The actual file name on disk, e.g., "save_0.json"
  final String fullFileName;
  
  /// The user-facing display name, e.g., "Temujin - Jan 1, 1140"
  final String displayName;
  
  /// The in-game date of the save.
  final GameDate saveDate;

  /// The real-world date the file was saved.
  final DateTime fileTimestamp;

  SaveFileInfo({
    required this.fullFileName,
    required this.displayName,
    required this.saveDate,
    required this.fileTimestamp,
  });

  // We only need fromJson, as toJson will be handled by the service
  factory SaveFileInfo.fromJson(Map<String, dynamic> json) {
    return SaveFileInfo(
      // These fields are added by the SaveLoadService, not from the save file itself
      fullFileName: json['fullFileName'] ?? 'unknown.json',
      fileTimestamp: json['fileTimestamp'] != null
          ? DateTime.parse(json['fileTimestamp'])
          : DateTime.now(),
      
      // These fields come from the 'meta' block *inside* the save file
      displayName: json['displayName'] ?? 'Unknown Save',
      saveDate: json['saveDate'] != null
          ? GameDate.fromJson(json['saveDate'])
          : GameDate(1140, 1, 1),
    );
  }

  // Helper for sorting
  int compareTo(SaveFileInfo other) {
    // Sorts by real-world timestamp, newest first
    return other.fileTimestamp.compareTo(fileTimestamp);
  }
}

