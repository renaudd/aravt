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
