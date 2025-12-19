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

class PillageReport {
  final DateTime date;
  final String locationName;
  final List<String> attackerAravtIds;
  final double scrapPillaged;
  final int prisonersTaken;
  final int animalsTaken;
  final double totalValue;

  PillageReport({
    required this.date,
    required this.locationName,
    required this.attackerAravtIds,
    required this.scrapPillaged,
    required this.prisonersTaken,
    required this.animalsTaken,
    required this.totalValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'locationName': locationName,
      'attackerAravtIds': attackerAravtIds,
      'scrapPillaged': scrapPillaged,
      'prisonersTaken': prisonersTaken,
      'animalsTaken': animalsTaken,
      'totalValue': totalValue,
    };
  }

  factory PillageReport.fromJson(Map<String, dynamic> json) {
    return PillageReport(
      date: DateTime.parse(json['date']),
      locationName: json['locationName'],
      attackerAravtIds: List<String>.from(json['attackerAravtIds']),
      scrapPillaged: json['scrapPillaged'].toDouble(),
      prisonersTaken: json['prisonersTaken'],
      animalsTaken: json['animalsTaken'],
      totalValue: json['totalValue'].toDouble(),
    );
  }
}
