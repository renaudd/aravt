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

class IndividualTrainingResult {
  final int soldierId;
  final String soldierName;
  final String skillTrained;
  final double xpGained;
  final double performanceRating;
  final int exhaustionGained;

  IndividualTrainingResult({
    required this.soldierId,
    required this.soldierName,
    required this.skillTrained,
    required this.xpGained,
    required this.performanceRating,
    required this.exhaustionGained,
  });

  Map<String, dynamic> toJson() {
    return {
      'soldierId': soldierId,
      'soldierName': soldierName,
      'skillTrained': skillTrained,
      'xpGained': xpGained,
      'performanceRating': performanceRating,
      'exhaustionGained': exhaustionGained,
    };
  }

  factory IndividualTrainingResult.fromJson(Map<String, dynamic> json) {
    return IndividualTrainingResult(
      soldierId: json['soldierId'] as int,
      soldierName: json['soldierName'] as String,
      skillTrained: json['skillTrained'] as String,
      xpGained: (json['xpGained'] as num).toDouble(),
      performanceRating: (json['performanceRating'] as num).toDouble(),
      exhaustionGained: json['exhaustionGained'] as int? ?? 0,
    );
  }
}

class TrainingReport {
  final GameDate date;
  final String aravtId;
  final String aravtName;
  final String captainName;
  final String drillSergeantName;
  final String trainingType;
  final List<IndividualTrainingResult> individualResults;
  final int turn;
  final bool isPlayerReport;

  TrainingReport({
    required this.date,
    required this.aravtId,
    required this.aravtName,
    required this.captainName,
    required this.drillSergeantName,
    required this.trainingType,
    required this.individualResults,
    this.turn = 0,
    this.isPlayerReport = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toJson(),
      'aravtId': aravtId,
      'aravtName': aravtName,
      'captainName': captainName,
      'drillSergeantName': drillSergeantName,
      'trainingType': trainingType,
      'individualResults': individualResults.map((e) => e.toJson()).toList(),
      'turn': turn,
      'isPlayerReport': isPlayerReport,
    };
  }

  factory TrainingReport.fromJson(Map<String, dynamic> json) {
    return TrainingReport(
      date: GameDate.fromJson(json['date']),
      aravtId: json['aravtId'] as String,
      aravtName: json['aravtName'] as String,
      captainName: json['captainName'] as String,
      drillSergeantName: json['drillSergeantName'] as String,
      trainingType: json['trainingType'] as String,
      individualResults: (json['individualResults'] as List)
          .map((e) => IndividualTrainingResult.fromJson(e))
          .toList(),
      turn: json['turn'] ?? 0,
      isPlayerReport: json['isPlayerReport'] ?? false,
    );
  }
}
