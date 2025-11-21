// lib/models/culinary_news.dart

import 'package:aravt/models/game_date.dart';

enum CulinaryEventType {
  legendaryMeal,
  newRecipe,
  newSpice,
  feastReport,
  cookPromotion,
  disasterMeal,
}

class CulinaryNews {
  final GameDate date;
  final CulinaryEventType type;
  final String description;
  final int? cookId;
  final String? dishName;
  final int? qualityRating; // 1-10 scale

  CulinaryNews({
    required this.date,
    required this.type,
    required this.description,
    this.cookId,
    this.dishName,
    this.qualityRating,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toJson(),
        'type': type.name,
        'description': description,
        'cookId': cookId,
        'dishName': dishName,
        'qualityRating': qualityRating,
      };

  factory CulinaryNews.fromJson(Map<String, dynamic> json) {
    return CulinaryNews(
      date: GameDate.fromJson(json['date'] as Map<String, dynamic>),
      type: CulinaryEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CulinaryEventType.feastReport,
      ),
      description: json['description'] as String,
      cookId: json['cookId'] as int?,
      dishName: json['dishName'] as String?,
      qualityRating: json['qualityRating'] as int?,
    );
  }
}
