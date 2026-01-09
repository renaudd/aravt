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

import 'package:flutter/material.dart';
import 'package:aravt/models/game_date.dart';

enum MetricCategory {
  fear, // Purple
  admiration, // Pink
  respect, // White
  loyalty, // Yellow
  wealth, // Green
  supply, // Brown
  herd, // Tan
  hordeSize, // Black
  misc, // Gray
  combat, // Silver
  health, // Red
  stats, // Blue
  food, // Orange
}

extension MetricCategoryExtension on MetricCategory {
  Color get color {
    switch (this) {
      case MetricCategory.fear:
        return Colors.purple;
      case MetricCategory.admiration:
        return Colors.pinkAccent;
      case MetricCategory.respect:
        return Colors.white;
      case MetricCategory.loyalty:
        return Colors.yellow;
      case MetricCategory.wealth:
        return Colors.green;
      case MetricCategory.supply:
        return Colors.brown;
      case MetricCategory.herd:
        return const Color(0xFFD2B48C); // Tan
      case MetricCategory.hordeSize:
        return Colors.black; // Might need high contrast handling on dark bg
      case MetricCategory.misc:
        return Colors.grey;
      case MetricCategory.combat:
        return const Color(0xFFC0C0C0); // Silver
      case MetricCategory.health:
        return Colors.red;
      case MetricCategory.stats:
        return Colors.blue;
      case MetricCategory.food:
        return Colors.orange;
    }
  }

  String get label {
    switch (this) {
      case MetricCategory.hordeSize:
        return "Horde Size";

      default:
        // Capitalize first letter
        return name[0].toUpperCase() + name.substring(1);
    }
  }
}

enum MetricType {
  // Fear
  fear,
  // Admiration
  admiration,
  // Respect
  respect,
  // Loyalty
  loyalty,

  // Wealth
  totalWealth, // Combined
  treasureWealth,
  rupees,
  debts,

  // Supply
  totalSupply, // Combined scarp value
  supplyWealth,
  scrap,
  wood,
  iron,
  arrows, // Short + Long

  // Herd
  totalAnimals,
  horses,
  cattle,

  // Horde
  population,

  // Combat
  combatRating, // Derived from wins/experience?

  // Health
  health,
  injuries,

  // Stats
  morale,
  discipline,
  stamina,

  // Food
  totalFood,
  meat,
  grain,
  dairy, // Milk + Cheese
  misc,
}

extension MetricTypeExtension on MetricType {
  MetricCategory get category {
    switch (this) {
      case MetricType.fear:
        return MetricCategory.fear;
      case MetricType.admiration:
        return MetricCategory.admiration;
      case MetricType.respect:
        return MetricCategory.respect;
      case MetricType.loyalty:
        return MetricCategory.loyalty;

      case MetricType.totalWealth:
      case MetricType.treasureWealth:
      case MetricType.rupees:
      case MetricType.debts:
        return MetricCategory.wealth;

      case MetricType.totalSupply:
      case MetricType.supplyWealth:
      case MetricType.scrap:
      case MetricType.wood:
      case MetricType.iron:
      case MetricType.arrows:
        return MetricCategory.supply;

      case MetricType.totalAnimals:
      case MetricType.horses:
      case MetricType.cattle:
        return MetricCategory.herd;

      case MetricType.population:
        return MetricCategory.hordeSize;

      case MetricType.combatRating:
        return MetricCategory.combat;

      case MetricType.health:
      case MetricType.injuries:
        return MetricCategory.health;

      case MetricType.morale:
      case MetricType.discipline:
      case MetricType.stamina:
        return MetricCategory.stats;

      case MetricType.totalFood:
      case MetricType.meat:
      case MetricType.grain:
      case MetricType.dairy:
        return MetricCategory.food;

      case MetricType.misc:
        return MetricCategory.misc;
    }
  }
}

class MetricValue {
  final double trueValue;
  final double perceivedValue;
  final double perceivedMin;
  final double perceivedMax;

  const MetricValue({
    required this.trueValue,
    required this.perceivedValue,
    required this.perceivedMin,
    required this.perceivedMax,
  });

  Map<String, dynamic> toJson() => {
        't': trueValue,
        'p': perceivedValue,
        'min': perceivedMin,
        'max': perceivedMax,
      };

  factory MetricValue.fromJson(Map<String, dynamic> json) {
    return MetricValue(
      trueValue: (json['t'] as num).toDouble(),
      perceivedValue: (json['p'] as num).toDouble(),
      perceivedMin: (json['min'] as num).toDouble(),
      perceivedMax: (json['max'] as num).toDouble(),
    );
  }
}

class EntitySnapshot {
  final String entityId; // "horde", "aravt_X", "soldier_Y"
  final Map<MetricType, MetricValue> metrics;

  EntitySnapshot({required this.entityId, required this.metrics});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> metricsJson = {};
    metrics.forEach((key, value) {
      metricsJson[key.name] = value.toJson();
    });
    return {
      'id': entityId,
      'm': metricsJson,
    };
  }

  factory EntitySnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> metricsMap = json['m'];
    final Map<MetricType, MetricValue> metrics = {};

    metricsMap.forEach((key, value) {
      // Find enum by name
      final type = MetricType.values.firstWhere((e) => e.name == key,
          orElse: () => MetricType.misc // Fallback if enum changed
          );
      if (type.toString() != "MetricType.misc") {
        // Hacky check or just accept
        metrics[type] = MetricValue.fromJson(value);
      }
    });

    return EntitySnapshot(
      entityId: json['id'],
      metrics: metrics,
    );
  }
}

class DailySnapshot {
  final int turnNumber;
  final GameDate date;
  final List<EntitySnapshot> entities;

  DailySnapshot({
    required this.turnNumber,
    required this.date,
    required this.entities,
  });

  Map<String, dynamic> toJson() => {
        'turn': turnNumber,
        'date': date.toJson(),
        'entities': entities.map((e) => e.toJson()).toList(),
      };

  factory DailySnapshot.fromJson(Map<String, dynamic> json) {
    return DailySnapshot(
      turnNumber: json['turn'],
      date: GameDate.fromJson(json['date']),
      entities: (json['entities'] as List)
          .map((e) => EntitySnapshot.fromJson(e))
          .toList(),
    );
  }
}
