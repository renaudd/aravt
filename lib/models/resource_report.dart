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
  final String aravtId; // [GEMINI-NEW]
  final String aravtName; // [GEMINI-NEW]
  final String locationName;
  final ResourceType type;
  final double totalGathered;
  final List<IndividualResourceResult> individualResults;
  // [GEMINI-NEW] Turn number for highlighting
  final int turn;

  ResourceReport({
    required this.date,
    required this.aravtId, // [GEMINI-NEW]
    required this.aravtName, // [GEMINI-NEW]
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
      'aravtId': aravtId, // [GEMINI-NEW]
      'aravtName': aravtName, // [GEMINI-NEW]
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
      aravtId: json['aravtId'] ?? '', // [GEMINI-NEW]
      aravtName: json['aravtName'] ?? 'Unknown Aravt', // [GEMINI-NEW]
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
