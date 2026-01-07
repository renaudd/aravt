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

// models/game_event.dart

import 'package:aravt/models/game_date.dart';
import 'package:uuid/uuid.dart';

// Enum for filtering events in your reports
enum EventCategory {
  general,
  combat,
  health,
  finance,
  horses,
  herds,
  food,
  hunting,
  games,
  system,
  travel,
  diplomacy,
  industry,
  medical,
  training,
}

// --- Helper function for serialization ---
EventCategory _eventCategoryFromName(String? name) {
  for (final value in EventCategory.values) {
    if (value.name == name) return value;
  }
  return EventCategory.general; // Default fallback
}

// Enum for styling the log
enum EventSeverity {
  low, // Simple info (e.g., day change)
  normal, // Standard event (e.g., assignment)
  high, // Important event (e.g., competition result)
  critical // Urgent event (e.g., death, major injury)
}

// --- Helper function for serialization ---
EventSeverity _eventSeverityFromName(String? name) {
  for (final value in EventSeverity.values) {
    if (value.name == name) return value;
  }
  return EventSeverity.normal; // Default fallback
}

class GameEvent {
  final String id;
  final String message;
  final GameDate date;
  final bool isPlayerKnown; // Key for omniscient mode
  final EventCategory category;
  final EventSeverity severity;

  // Optional: links to related data
  final int? relatedSoldierId;
  final String? relatedAravtId;
  final int turn;

  GameEvent({
    String? id,
    required this.message,
    required this.date,
    this.isPlayerKnown = true,
    this.category = EventCategory.general,
    this.severity = EventSeverity.normal,
    this.relatedSoldierId,
    this.relatedAravtId,
    this.turn = 0, // Default for migration
  }) : id = id ?? const Uuid().v4();

  // --- JSON Serialization ---
  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'date': date.toJson(),
        'isPlayerKnown': isPlayerKnown,
        'category': category.name,
        'severity': severity.name,
        'relatedSoldierId': relatedSoldierId,
        'relatedAravtId': relatedAravtId,
        'turn': turn,
      };

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'],
      message: json['message'],
      date: GameDate.fromJson(json['date']),
      isPlayerKnown: json['isPlayerKnown'] ?? true,
      category: _eventCategoryFromName(json['category']),
      severity: _eventSeverityFromName(json['severity']),
      relatedSoldierId: json['relatedSoldierId'],
      relatedAravtId: json['relatedAravtId'],
      turn: json['turn'] ?? 0,
    );
  }
}
