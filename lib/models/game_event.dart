// models/game_event.dart

import 'package:aravt/models/game_date.dart';

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
}

// --- NEW: Helper function for serialization ---
EventCategory _eventCategoryFromName(String? name) {
  for (final value in EventCategory.values) {
    if (value.name == name) return value;
  }
  return EventCategory.general; // Default fallback
}
// --- END NEW ---

// Enum for styling the log
enum EventSeverity {
  low, // Simple info (e.g., day change)
  normal, // Standard event (e.g., assignment)
  high, // Important event (e.g., competition result)
  critical // Urgent event (e.g., death, major injury)
}

// --- NEW: Helper function for serialization ---
EventSeverity _eventSeverityFromName(String? name) {
  for (final value in EventSeverity.values) {
    if (value.name == name) return value;
  }
  return EventSeverity.normal; // Default fallback
}
// --- END NEW ---

class GameEvent {
  final String message;
  final GameDate date;
  final bool isPlayerKnown; // Key for omniscient mode
  final EventCategory category;
  final EventSeverity severity;
  
  // Optional: links to related data
  final int? relatedSoldierId;
  final String? relatedAravtId;

  GameEvent({
    required this.message,
    required this.date,
    this.isPlayerKnown = true,
    this.category = EventCategory.general,
    this.severity = EventSeverity.normal,
    this.relatedSoldierId,
    this.relatedAravtId,
  });

  // --- NEW: JSON Serialization ---
  Map<String, dynamic> toJson() => {
    'message': message,
    'date': date.toJson(),
    'isPlayerKnown': isPlayerKnown,
    'category': category.name,
    'severity': severity.name,
    'relatedSoldierId': relatedSoldierId,
    'relatedAravtId': relatedAravtId,
  };

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      message: json['message'],
      date: GameDate.fromJson(json['date']),
      isPlayerKnown: json['isPlayerKnown'] ?? true,
      category: _eventCategoryFromName(json['category']),
      severity: _eventSeverityFromName(json['severity']),
      relatedSoldierId: json['relatedSoldierId'],
      relatedAravtId: json['relatedAravtId'],
    );
  }
  // --- END NEW ---
}

