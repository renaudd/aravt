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

// lib/models/disease_data.dart

/// Types of diseases (placeholder for future disease system)
enum DiseaseType {
  plague,
  dysentery,
  fever,
  infection,
}

/// How contagious a disease is
enum DiseaseContagiousness {
  none,
  low,
  medium,
  high,
}

/// Represents a disease affecting a soldier (placeholder)
class Disease {
  final DiseaseType type;
  final DiseaseContagiousness contagiousness;
  final int severity; // 1-10
  final int turnContracted;

  Disease({
    required this.type,
    required this.contagiousness,
    required this.severity,
    required this.turnContracted,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'contagiousness': contagiousness.name,
        'severity': severity,
        'turnContracted': turnContracted,
      };

  factory Disease.fromJson(Map<String, dynamic> json) {
    return Disease(
      type: DiseaseType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DiseaseType.plague,
      ),
      contagiousness: DiseaseContagiousness.values.firstWhere(
        (e) => e.name == json['contagiousness'],
        orElse: () => DiseaseContagiousness.none,
      ),
      severity: json['severity'],
      turnContracted: json['turnContracted'],
    );
  }
}
