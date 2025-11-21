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
