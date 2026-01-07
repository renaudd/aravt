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

// lib/models/narrative_models.dart

/// Types of narrative events that can occur in the game.
enum NarrativeEventType {
  day5Trade,
  tournamentConclusion,
  combatVictory,
  combatDefeat,
  hordeLeaderTransition,
  assassinationPoison,
  assassinationAccident,
  assassinationStrangle,
  assassinationConfront,
}

/// Represents a narrative event that requires player interaction.
class NarrativeEvent {
  final NarrativeEventType type;
  final int instigatorId; // Captain ID or relevant entity
  final int targetId; // Soldier ID or relevant entity
  final String? description; // Optional detailed description
  final bool? success; // For assassination results

  NarrativeEvent({
    required this.type,
    required this.instigatorId,
    required this.targetId,
    this.description,
    this.success,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'instigatorId': instigatorId,
        'targetId': targetId,
        'description': description,
        'success': success,
      };

  factory NarrativeEvent.fromJson(Map<String, dynamic> json) {
    return NarrativeEvent(
      type: NarrativeEventType.values.firstWhere((e) => e.name == json['type']),
      instigatorId: json['instigatorId'],
      targetId: json['targetId'],
      description: json['description'],
      success: json['success'],
    );
  }
}
