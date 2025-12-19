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

class IndividualFletchingResult {
  final int soldierId;
  final String soldierName;
  final int arrowsCrafted;
  final double woodConsumed;
  final double scrapConsumed;
  final double performanceRating;

  IndividualFletchingResult({
    required this.soldierId,
    required this.soldierName,
    required this.arrowsCrafted,
    required this.woodConsumed,
    required this.scrapConsumed,
    required this.performanceRating,
  });

  Map<String, dynamic> toJson() {
    return {
      'soldierId': soldierId,
      'soldierName': soldierName,
      'arrowsCrafted': arrowsCrafted,
      'woodConsumed': woodConsumed,
      'scrapConsumed': scrapConsumed,
      'performanceRating': performanceRating,
    };
  }

  factory IndividualFletchingResult.fromJson(Map<String, dynamic> json) {
    return IndividualFletchingResult(
      soldierId: json['soldierId'] as int,
      soldierName: json['soldierName'] as String,
      arrowsCrafted: json['arrowsCrafted'] as int,
      woodConsumed: (json['woodConsumed'] as num).toDouble(),
      scrapConsumed: (json['scrapConsumed'] as num).toDouble(),
      performanceRating: (json['performanceRating'] as num).toDouble(),
    );
  }
}

class FletchingReport {
  final GameDate date;
  final String aravtId;
  final String aravtName;
  final int totalArrowsCrafted;
  final bool isLongArrows;
  final double totalWoodConsumed;
  final double totalScrapConsumed;
  final List<IndividualFletchingResult> individualResults;
  final int turn;

  FletchingReport({
    required this.date,
    required this.aravtId,
    required this.aravtName,
    required this.totalArrowsCrafted,
    this.isLongArrows = false,
    required this.totalWoodConsumed,
    required this.totalScrapConsumed,
    required this.individualResults,
    this.turn = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toJson(),
      'aravtId': aravtId,
      'aravtName': aravtName,
      'totalArrowsCrafted': totalArrowsCrafted,
      'isLongArrows': isLongArrows,
      'totalWoodConsumed': totalWoodConsumed,
      'totalScrapConsumed': totalScrapConsumed,
      'individualResults': individualResults.map((e) => e.toJson()).toList(),
      'turn': turn,
    };
  }

  factory FletchingReport.fromJson(Map<String, dynamic> json) {
    return FletchingReport(
      date: GameDate.fromJson(json['date']),
      aravtId: json['aravtId'] as String,
      aravtName: json['aravtName'] as String,
      totalArrowsCrafted: json['totalArrowsCrafted'] as int,
      isLongArrows: json['isLongArrows'] as bool? ?? false,
      totalWoodConsumed: (json['totalWoodConsumed'] as num).toDouble(),
      totalScrapConsumed: (json['totalScrapConsumed'] as num).toDouble(),
      individualResults: (json['individualResults'] as List)
          .map((e) => IndividualFletchingResult.fromJson(e))
          .toList(),
      turn: json['turn'] ?? 0,
    );
  }
}
