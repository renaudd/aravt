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

enum JustificationType {
  praise,
  scold,
  gift,
  any, // Can be used for generic justifications
}

class JustificationEvent {
  final String description;
  final JustificationType type;
  final int expiryTurn;
  final double magnitude; // 0.0 to 1.0 multiplier for effect

  JustificationEvent({
    required this.description,
    required this.type,
    required this.expiryTurn,
    this.magnitude = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'type': type.name,
        'expiryTurn': expiryTurn,
        'magnitude': magnitude,
      };

  factory JustificationEvent.fromJson(Map<String, dynamic> json) {
    return JustificationEvent(
      description: json['description'],
      type: JustificationType.values.firstWhere((e) => e.name == json['type'],
          orElse: () => JustificationType.any),
      expiryTurn: json['expiryTurn'],
      magnitude: (json['magnitude'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
