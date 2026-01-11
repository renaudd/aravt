// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// services/save_load_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/save_file_info.dart';

class SaveLoadService {
  static const int _maxSaveSlots = 10;
  static const String _saveFileNamePrefix = 'save_';
  static const String _saveFileExtension = '.json';

  /// Gets the platform-specific directory for storing app data.
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Gets a File handle for a specific save slot.
  Future<File?> _getSaveFile(String fileName) async {
    if (kIsWeb) return null;
    final path = await _localPath;
    return File('$path/$fileName');
  }

  /// Creates a complete JSON map of the *entire* game state.
  /// This is the master object that will be written to disk.
  Map<String, dynamic> createSaveData({
    required String displayName,
    required GameDate saveDate,
    required Map<String, dynamic> gameStateJson,
  }) {
    return {
      'meta': {
        'displayName': displayName,
        'saveDate': saveDate.toJson(),
        'fileTimestamp': DateTime.now().toIso8601String(),
      },
      'gameState': gameStateJson,
    };
  }

  /// Writes the provided game state JSON to a specific file.
  Future<void> writeSaveFile(
      String fileName, Map<String, dynamic> saveData) async {
    try {
      final jsonString = json.encode(saveData);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(fileName, jsonString);
        print("Web Save successful: $fileName");
      } else {
        final file = await _getSaveFile(fileName);
        if (file != null) {
          await file.writeAsString(jsonString);
          print("Desktop Save successful: $fileName");
        }
      }
    } catch (e) {
      print("Error writing save file $fileName: $e");
      rethrow;
    }
  }

  /// Reads a save file and returns the full JSON map.
  Future<Map<String, dynamic>?> readSaveFile(String fileName) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString(fileName);
        if (jsonString != null) {
          return json.decode(jsonString);
        }
      } else {
        final file = await _getSaveFile(fileName);
        if (file != null && await file.exists()) {
          final jsonString = await file.readAsString();
          return json.decode(jsonString);
        }
      }
      return null;
    } catch (e) {
      print("Error reading save file $fileName: $e");
      return null;
    }
  }

  /// Returns the name for the next available save slot, e.g., "save_0.json".
  /// This will overwrite the oldest save if all 10 slots are full.
  Future<String> getNextAvailableSaveSlot() async {
    final List<SaveFileInfo> saves = await getSaveFileList();

    // 1. If there's an empty slot, use it.
    for (int i = 0; i < _maxSaveSlots; i++) {
      final fileName = '$_saveFileNamePrefix$i$_saveFileExtension';
      if (!saves.any((s) => s.fullFileName == fileName)) {
        return fileName;
      }
    }

    // 2. If all slots are full, find the *oldest* save and return its name.
    if (saves.isNotEmpty) {
      saves.sort(
          (a, b) => a.fileTimestamp.compareTo(b.fileTimestamp)); // Oldest first
      return saves.first.fullFileName;
    }

    // 3. Fallback, should never happen if maxSaveSlots > 0
    return '${_saveFileNamePrefix}0$_saveFileExtension';
  }

  /// Scans the app directory for all valid save files and returns
  /// their metadata for the "Load Game" screen.
  Future<List<SaveFileInfo>> getSaveFileList() async {
    final List<SaveFileInfo> saveFiles = [];
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_saveFileNamePrefix)) {
          final jsonString = prefs.getString(key);
          if (jsonString != null) {
            final data = json.decode(jsonString);
            if (data.containsKey('meta')) {
              final meta = data['meta'];
              meta['fullFileName'] = key;
              // For web, use a fixed timestamp if not stored, or metadata timestamp
              meta['fileTimestamp'] =
                  meta['fileTimestamp'] ?? DateTime.now().toIso8601String();
              saveFiles.add(SaveFileInfo.fromJson(meta));
            }
          }
        }
      }
    } else {
      final path = await _localPath;
      final dir = Directory(path);

      if (await dir.exists()) {
        final List<FileSystemEntity> entities = await dir.list().toList();

        for (final entity in entities) {
          if (entity is File &&
              entity.path.endsWith(_saveFileExtension) &&
              entity.path.contains(_saveFileNamePrefix)) {
            final String fileName = entity.uri.pathSegments.last;
            try {
              final jsonString = await entity.readAsString();
              final Map<String, dynamic> data = json.decode(jsonString);

              if (data.containsKey('meta')) {
                final Map<String, dynamic> meta = data['meta'];
                // Add the file's own info to the metadata map
                meta['fullFileName'] = fileName;
                meta['fileTimestamp'] =
                    (await entity.lastModified()).toIso8601String();

                saveFiles.add(SaveFileInfo.fromJson(meta));
              }
            } catch (e) {
              print("Error parsing save file $fileName: $e");
            }
          }
        }
      }
    }

    // Sort by timestamp, newest first
    saveFiles.sort((a, b) => b.fileTimestamp.compareTo(a.fileTimestamp));
    return saveFiles;
  }
}
