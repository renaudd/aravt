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

import 'package:aravt/models/game_date.dart';

enum ResourceType { wood, ironOre, scrap, arrows }

class IndividualResourceResult {
  final int soldierId;
  final String soldierName;
  final double amountGathered;
  final double performanceRating; // 0.0 to 1.0+ (for coloring/sorting)

  IndividualResourceResult({
    required this.soldierId,
    required this.soldierName,
    required this.amountGathered,
    this.performanceRating = 0.5,
  });

  // JSON Serialization
  Map<String, dynamic> toJson() {
    return {
      'soldierId': soldierId,
      'soldierName': soldierName,
      'amountGathered': amountGathered,
      'performanceRating': performanceRating,
    };
  }

  factory IndividualResourceResult.fromJson(Map<String, dynamic> json) {
    return IndividualResourceResult(
      soldierId: json['soldierId'] as int,
      soldierName: json['soldierName'] as String,
      amountGathered: (json['amountGathered'] as num).toDouble(),
      performanceRating: (json['performanceRating'] as num).toDouble(),
    );
  }
}

class ResourceReport {
  final GameDate date;
  final String aravtId;
  final String aravtName;
  final String locationName;
  final ResourceType type;
  final double totalGathered;
  final List<IndividualResourceResult> individualResults;
  //  Turn number for highlighting
  final int turn;

  ResourceReport({
    required this.date,
    required this.aravtId,
    required this.aravtName,
    required this.locationName,
    required this.type,
    required this.totalGathered,
    required this.individualResults,
    this.turn = 0, // Default for migration
  });

  // JSON Serialization
  Map<String, dynamic> toJson() {
    return {
      'date': date.toJson(),
      'aravtId': aravtId,
      'aravtName': aravtName,
      'locationName': locationName,
      'type': type.index, // Storing enum as index
      'totalGathered': totalGathered,
      'individualResults': individualResults.map((e) => e.toJson()).toList(),
      'turn': turn,
    };
  }

  factory ResourceReport.fromJson(Map<String, dynamic> json) {
    return ResourceReport(
      date: GameDate.fromJson(json['date']),
      aravtId: json['aravtId'] ?? '',
      aravtName: json['aravtName'] ?? 'Unknown Aravt',
      locationName: json['locationName'] as String,
      type: ResourceType.values[json['type'] as int],
      totalGathered: (json['totalGathered'] as num).toDouble(),
      individualResults: (json['individualResults'] as List)
          .map((e) => IndividualResourceResult.fromJson(e))
          .toList(),
      turn: json['turn'] ?? 0,
    );
  }
}
