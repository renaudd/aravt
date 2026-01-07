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

class IndividualShepherdingResult {
  final int soldierId;
  final String soldierName;
  final double performanceRating;
  final String eventDescription;

  IndividualShepherdingResult({
    required this.soldierId,
    required this.soldierName,
    required this.performanceRating,
    required this.eventDescription,
  });

  Map<String, dynamic> toJson() {
    return {
      'soldierId': soldierId,
      'soldierName': soldierName,
      'performanceRating': performanceRating,
      'eventDescription': eventDescription,
    };
  }

  factory IndividualShepherdingResult.fromJson(Map<String, dynamic> json) {
    return IndividualShepherdingResult(
      soldierId: json['soldierId'] as int,
      soldierName: json['soldierName'] as String,
      performanceRating: (json['performanceRating'] as num).toDouble(),
      eventDescription: json['eventDescription'] as String,
    );
  }
}

class ShepherdingReport {
  final GameDate date;
  final String aravtId;
  final String aravtName;
  final int totalAnimals;
  final double milkProduced;
  final List<String> events;
  final List<IndividualShepherdingResult> individualResults;
  final int turn;

  ShepherdingReport({
    required this.date,
    required this.aravtId,
    required this.aravtName,
    required this.totalAnimals,
    required this.milkProduced,
    required this.events,
    required this.individualResults,
    this.turn = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toJson(),
      'aravtId': aravtId,
      'aravtName': aravtName,
      'totalAnimals': totalAnimals,
      'milkProduced': milkProduced,
      'events': events,
      'individualResults': individualResults.map((e) => e.toJson()).toList(),
      'turn': turn,
    };
  }

  factory ShepherdingReport.fromJson(Map<String, dynamic> json) {
    return ShepherdingReport(
      date: GameDate.fromJson(json['date']),
      aravtId: json['aravtId'] as String,
      aravtName: json['aravtName'] as String,
      totalAnimals: json['totalAnimals'] as int,
      milkProduced: (json['milkProduced'] as num).toDouble(),
      events: List<String>.from(json['events']),
      individualResults: (json['individualResults'] as List)
          .map((e) => IndividualShepherdingResult.fromJson(e))
          .toList(),
      turn: json['turn'] ?? 0,
    );
  }
}
