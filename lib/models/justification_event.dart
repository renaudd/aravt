enum JustificationType {
  praise,
  scold,
  gift,
  any, // Can be used for generic justifications
}

class JustificationEvent {
  final String description;
  final JustificationType type;
  final int expiryTurn;
  final double magnitude; // 0.0 to 1.0 multiplier for effect

  JustificationEvent({
    required this.description,
    required this.type,
    required this.expiryTurn,
    this.magnitude = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'type': type.name,
        'expiryTurn': expiryTurn,
        'magnitude': magnitude,
      };

  factory JustificationEvent.fromJson(Map<String, dynamic> json) {
    return JustificationEvent(
      description: json['description'],
      type: JustificationType.values.firstWhere((e) => e.name == json['type'],
          orElse: () => JustificationType.any),
      expiryTurn: json['expiryTurn'],
      magnitude: (json['magnitude'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
