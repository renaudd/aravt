// lib/models/request_data.dart

/// Types of requests soldiers can make to the player
enum RequestType {
  switchAravts, // Request to switch to a different aravt
  becomeCaptain, // Request to become an aravt captain
  stopBeingCaptain, // Request to step down as captain
  giftItem, // Request a specific item as a gift
  requestItem, // Request to borrow/use an item
  proposeTrade, // Propose a trade route or diplomatic action
  suggestAction, // Suggest a strategic action
}

/// Represents a request from a soldier to the player
class SoldierRequest {
  final int soldierId; // Who is making the request
  final RequestType type;
  final int turnRequested;
  final int? targetSoldierId; // For requests involving another soldier
  final String? requestedItem; // For item-related requests
  final String? details; // Additional context

  SoldierRequest({
    required this.soldierId,
    required this.type,
    required this.turnRequested,
    this.targetSoldierId,
    this.requestedItem,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'soldierId': soldierId,
        'type': type.name,
        'turnRequested': turnRequested,
        'targetSoldierId': targetSoldierId,
        'requestedItem': requestedItem,
        'details': details,
      };

  factory SoldierRequest.fromJson(Map<String, dynamic> json) {
    return SoldierRequest(
      soldierId: json['soldierId'],
      type: RequestType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RequestType.switchAravts,
      ),
      turnRequested: json['turnRequested'],
      targetSoldierId: json['targetSoldierId'],
      requestedItem: json['requestedItem'],
      details: json['details'],
    );
  }
}
