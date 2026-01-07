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

// lib/models/wealth_event.dart

import 'package:aravt/models/game_date.dart';

enum WealthEventType {
  tribute,
  pillage,
  combatSpoils,
  robbery,
  giftReceived,
  giftSent,
  trade,
  taxation,
  fine,
  reward,
}

class WealthEvent {
  final GameDate date;
  final WealthEventType type;
  final double rupeesChange;
  final double scrapChange;
  final String description;
  final int? relatedSoldierId;
  final String? relatedLocationName;

  WealthEvent({
    required this.date,
    required this.type,
    required this.rupeesChange,
    required this.scrapChange,
    required this.description,
    this.relatedSoldierId,
    this.relatedLocationName,
  });

  bool get isGain => rupeesChange > 0 || scrapChange > 0;
  bool get isLoss => rupeesChange < 0 || scrapChange < 0;

  Map<String, dynamic> toJson() => {
        'date': date.toJson(),
        'type': type.name,
        'rupeesChange': rupeesChange,
        'scrapChange': scrapChange,
        'description': description,
        'relatedSoldierId': relatedSoldierId,
        'relatedLocationName': relatedLocationName,
      };

  factory WealthEvent.fromJson(Map<String, dynamic> json) {
    return WealthEvent(
      date: GameDate.fromJson(json['date'] as Map<String, dynamic>),
      type: WealthEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => WealthEventType.trade,
      ),
      rupeesChange: (json['rupeesChange'] as num).toDouble(),
      scrapChange: (json['scrapChange'] as num).toDouble(),
      description: json['description'] as String,
      relatedSoldierId: json['relatedSoldierId'] as int?,
      relatedLocationName: json['relatedLocationName'] as String?,
    );
  }
}
