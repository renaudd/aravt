// lib/models/narrative_models.dart

/// Types of narrative events that can occur in the game.
enum NarrativeEventType {
  day5Trade,
  tournamentConclusion,
}

/// Represents a narrative event that requires player interaction.
class NarrativeEvent {
  final NarrativeEventType type;
  final int instigatorId; // Captain ID or relevant entity
  final int targetId; // Soldier ID or relevant entity
  final String?
      description; // Optional detailed description (e.g., tournament results)

  NarrativeEvent({
    required this.type,
    required this.instigatorId,
    required this.targetId,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'instigatorId': instigatorId,
        'targetId': targetId,
        'description': description,
      };

  factory NarrativeEvent.fromJson(Map<String, dynamic> json) {
    return NarrativeEvent(
      type: NarrativeEventType.values.firstWhere((e) => e.name == json['type']),
      instigatorId: json['instigatorId'],
      targetId: json['targetId'],
      description: json['description'],
    );
  }
}
