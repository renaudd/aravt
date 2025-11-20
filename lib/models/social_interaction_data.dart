// lib/models/social_interaction_data.dart

/// Types of social interactions between soldiers
enum SocialInteractionType {
  insult,
  compliment,
  joke,
  intimidation,
  reprimand,
  advice,
}

/// Tracks a social interaction between two soldiers
class SocialInteractionHistory {
  final int targetSoldierId;
  final SocialInteractionType type;
  final int turnNumber;
  final bool wasPositive; // Whether the interaction was positive or negative

  SocialInteractionHistory({
    required this.targetSoldierId,
    required this.type,
    required this.turnNumber,
    required this.wasPositive,
  });

  Map<String, dynamic> toJson() => {
        'targetSoldierId': targetSoldierId,
        'type': type.name,
        'turnNumber': turnNumber,
        'wasPositive': wasPositive,
      };

  factory SocialInteractionHistory.fromJson(Map<String, dynamic> json) {
    return SocialInteractionHistory(
      targetSoldierId: json['targetSoldierId'],
      type: SocialInteractionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SocialInteractionType.compliment,
      ),
      turnNumber: json['turnNumber'],
      wasPositive: json['wasPositive'],
    );
  }
}

/// Represents a piece of information/gossip that can spread through the horde
class InformationPiece {
  final String content; // The actual information
  final int interestLevel; // 1-3, how interesting/important it is
  final bool isTrue; // Whether the information is accurate
  final int originTurn; // When this information was created
  final int? subjectSoldierId; // Who the information is about (if applicable)

  InformationPiece({
    required this.content,
    required this.interestLevel,
    required this.isTrue,
    required this.originTurn,
    this.subjectSoldierId,
  });

  Map<String, dynamic> toJson() => {
        'content': content,
        'interestLevel': interestLevel,
        'isTrue': isTrue,
        'originTurn': originTurn,
        'subjectSoldierId': subjectSoldierId,
      };

  factory InformationPiece.fromJson(Map<String, dynamic> json) {
    return InformationPiece(
      content: json['content'],
      interestLevel: json['interestLevel'],
      isTrue: json['isTrue'],
      originTurn: json['originTurn'],
      subjectSoldierId: json['subjectSoldierId'],
    );
  }
}
