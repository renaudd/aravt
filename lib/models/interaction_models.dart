// models/interaction_models.dart

/// Type of interaction performed by the player.
enum InteractionType {
  scold,
  praise,
  inquire,
  listen,
  gift,
}

// --- NEW: Helper function ---
InteractionType _interactionTypeFromName(String? name) {
  for (final value in InteractionType.values) {
    if (value.name == name) return value;
  }
  return InteractionType.inquire;
}
// --- END NEW ---

/// Represents a single entry in a soldier's interaction log.
class InteractionLogEntry {
  final String dateString;
  final InteractionType type;
  final String interactionSummary;
  final String outcomeSummary;
  final String informationRevealed;

  InteractionLogEntry({
    required this.dateString,
    required this.type,
    required this.interactionSummary,
    required this.outcomeSummary,
    this.informationRevealed = '',
  });

  // --- NEW: JSON Serialization ---
  Map<String, dynamic> toJson() => {
        'dateString': dateString,
        'type': type.name,
        'interactionSummary': interactionSummary,
        'outcomeSummary': outcomeSummary,
        'informationRevealed': informationRevealed,
      };

  factory InteractionLogEntry.fromJson(Map<String, dynamic> json) {
    return InteractionLogEntry(
      dateString: json['dateString'],
      type: _interactionTypeFromName(json['type']),
      interactionSummary: json['interactionSummary'],
      outcomeSummary: json['outcomeSummary'],
      informationRevealed: json['informationRevealed'] ?? '',
    );
  }
  // --- END NEW ---
}

/// Used to log a soldier's significant positive or negative actions.
class PerformanceEvent {
  final int turnNumber;
  final String description;
  final bool isPositive;
  final double magnitude;

  PerformanceEvent({
    required this.turnNumber,
    required this.description,
    required this.isPositive,
    this.magnitude = 1.0,
  });

  // --- NEW: JSON Serialization ---
  Map<String, dynamic> toJson() => {
        'turnNumber': turnNumber,
        'description': description,
        'isPositive': isPositive,
        'magnitude': magnitude,
      };

  factory PerformanceEvent.fromJson(Map<String, dynamic> json) {
    return PerformanceEvent(
      turnNumber: json['turnNumber'],
      description: json['description'],
      isPositive: json['isPositive'],
      magnitude: json['magnitude'] ?? 1.0,
    );
  }
  // --- END NEW ---
}

/// Represents a piece of information a soldier wants to tell the player.
class QueuedListenItem {
  final String message;
  final String? eventId;
  final double urgency;
  final int turnNumber;

  QueuedListenItem({
    required this.message,
    required this.turnNumber,
    this.eventId,
    this.urgency = 1.0,
  });

  // --- NEW: JSON Serialization ---
  Map<String, dynamic> toJson() => {
        'message': message,
        'eventId': eventId,
        'urgency': urgency,
        'turnNumber': turnNumber,
      };

  factory QueuedListenItem.fromJson(Map<String, dynamic> json) {
    return QueuedListenItem(
      message: json['message'],
      turnNumber: json['turnNumber'],
      eventId: json['eventId'],
      urgency: json['urgency'] ?? 1.0,
    );
  }
  // --- END NEW ---
}

/// The result bundle returned from the InteractionService after processing.
/// This class does not need serialization as it's a temporary result,
/// not persistent state.
class InteractionResult {
  final bool success;
  final String outcomeSummary;
  final String statChangeSummary;
  final String informationRevealed;
  final InteractionLogEntry logEntry;

  InteractionResult({
    required this.success,
    required this.outcomeSummary,
    required this.statChangeSummary,
    this.informationRevealed = '',
    required this.logEntry,
  });
}
