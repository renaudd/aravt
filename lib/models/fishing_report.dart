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

class CaughtFish {
  final String fishId;
  final String fishName;
  final double meatYield;
  final String techniqueUsed;

  CaughtFish({
    required this.fishId,
    required this.fishName,
    required this.meatYield,
    required this.techniqueUsed,
  });

  Map<String, dynamic> toJson() => {
        'fishId': fishId,
        'fishName': fishName,
        'meatYield': meatYield,
        'techniqueUsed': techniqueUsed,
      };

  factory CaughtFish.fromJson(Map<String, dynamic> json) {
    return CaughtFish(
      fishId: json['fishId'],
      fishName: json['fishName'],
      meatYield: (json['meatYield'] as num).toDouble(),
      techniqueUsed: json['techniqueUsed'],
    );
  }
}

class IndividualFishingResult {
  final int soldierId;
  final String soldierName;
  final List<CaughtFish> catches;
  final double totalMeat;

  IndividualFishingResult({
    required this.soldierId,
    required this.soldierName,
    required this.catches,
  }) : totalMeat = catches.fold(0.0, (sum, c) => sum + c.meatYield);

  Map<String, dynamic> toJson() => {
        'soldierId': soldierId,
        'soldierName': soldierName,
        'catches': catches.map((c) => c.toJson()).toList(),
        'totalMeat': totalMeat,
      };

  factory IndividualFishingResult.fromJson(Map<String, dynamic> json) {
    return IndividualFishingResult(
      soldierId: json['soldierId'],
      soldierName: json['soldierName'],
      catches:
          (json['catches'] as List).map((c) => CaughtFish.fromJson(c)).toList(),
    );
  }
}

class FishingTripReport {
  final GameDate date;
  final String aravtId;
  final String aravtName;
  final String locationName;
  final List<IndividualFishingResult> individualResults;
  final double totalMeat;
  final int totalFishCaught;
  final int turn;

  FishingTripReport({
    required this.date,
    required this.aravtId,
    required this.aravtName,
    required this.locationName,
    required this.individualResults,
    this.turn = 0, // Default for migration
  })  : totalMeat =
            individualResults.fold(0.0, (sum, res) => sum + res.totalMeat),
        totalFishCaught =
            individualResults.fold(0, (sum, res) => sum + res.catches.length);

  Map<String, dynamic> toJson() => {
        'date': date.toJson(),
        'aravtId': aravtId,
        'aravtName': aravtName,
        'locationName': locationName,
        'individualResults': individualResults.map((r) => r.toJson()).toList(),
        'totalMeat': totalMeat,
        'turn': turn,
      };

  factory FishingTripReport.fromJson(Map<String, dynamic> json) {
    return FishingTripReport(
      date: GameDate.fromJson(json['date']),
      aravtId: json['aravtId'],
      aravtName: json['aravtName'] ?? 'Unknown Aravt',
      locationName: json['locationName'],
      individualResults: (json['individualResults'] as List)
          .map((r) => IndividualFishingResult.fromJson(r))
          .toList(),
      turn: json['turn'] ?? 0,
    );
  }
}
