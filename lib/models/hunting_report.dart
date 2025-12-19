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
import 'package:aravt/models/animal_data.dart';

class HuntedAnimal {
  final String animalId;
  final String animalName;
  final MeatType meatType;
  final double meatYield;
  final int peltYield;
  final String weaponUsed;

  HuntedAnimal({
    required this.animalId,
    required this.animalName,
    required this.meatType,
    required this.meatYield,
    required this.peltYield,
    required this.weaponUsed,
  });

  Map<String, dynamic> toJson() => {
        'animalId': animalId,
        'animalName': animalName,
        'meatType': meatType.name,
        'meatYield': meatYield,
        'peltYield': peltYield,
        'weaponUsed': weaponUsed,
      };

  factory HuntedAnimal.fromJson(Map<String, dynamic> json) {
    return HuntedAnimal(
      animalId: json['animalId'],
      animalName: json['animalName'],
      meatType: MeatType.values.firstWhere((e) => e.name == json['meatType']),
      meatYield: (json['meatYield'] as num).toDouble(),
      peltYield: json['peltYield'] as int,
      weaponUsed: json['weaponUsed'],
    );
  }
}

class IndividualHuntResult {
  final int soldierId;
  final String soldierName;
  final List<HuntedAnimal> kills;
  final double totalMeat;
  final int totalPelts;
  // Track if they were injured during the hunt (e.g. by a boar or wolf)
  final bool wasInjured;

  IndividualHuntResult({
    required this.soldierId,
    required this.soldierName,
    required this.kills,
    this.wasInjured = false,
  })  : totalMeat = kills.fold(0.0, (sum, kill) => sum + kill.meatYield),
        totalPelts = kills.fold(0, (sum, kill) => sum + kill.peltYield);

  Map<String, dynamic> toJson() => {
        'soldierId': soldierId,
        'soldierName': soldierName,
        'kills': kills.map((k) => k.toJson()).toList(),
        'totalMeat': totalMeat,
        'totalPelts': totalPelts,
        'wasInjured': wasInjured,
      };

  factory IndividualHuntResult.fromJson(Map<String, dynamic> json) {
    return IndividualHuntResult(
      soldierId: json['soldierId'],
      soldierName: json['soldierName'],
      kills:
          (json['kills'] as List).map((k) => HuntedAnimal.fromJson(k)).toList(),
      wasInjured: json['wasInjured'] ?? false,
    );
  }
}

class HuntingTripReport {
  final GameDate date;
  final String aravtId;
  final String aravtName; // Added aravtName
  final String locationName;
  final List<IndividualHuntResult> individualResults;
  final double totalMeat;
  final int totalPelts;
  final int turn;

  HuntingTripReport({
    required this.date,
    required this.aravtId,
    required this.aravtName,
    required this.locationName,
    required this.individualResults,
    this.turn = 0, // Default for migration
  })  : totalMeat =
            individualResults.fold(0.0, (sum, res) => sum + res.totalMeat),
        totalPelts =
            individualResults.fold(0, (sum, res) => sum + res.totalPelts);

  Map<String, dynamic> toJson() => {
        'date': date.toJson(),
        'aravtId': aravtId,
        'aravtName': aravtName,
        'locationName': locationName,
        'individualResults': individualResults.map((r) => r.toJson()).toList(),
        'totalMeat': totalMeat,
        'totalPelts': totalPelts,
        'turn': turn,
      };

  factory HuntingTripReport.fromJson(Map<String, dynamic> json) {
    return HuntingTripReport(
      date: GameDate.fromJson(json['date']),
      aravtId: json['aravtId'],
      aravtName: json['aravtName'] ?? 'Unknown Aravt',
      locationName: json['locationName'],
      individualResults: (json['individualResults'] as List)
          .map((r) => IndividualHuntResult.fromJson(r))
          .toList(),
      turn: json['turn'] ?? 0,
    );
  }
}
