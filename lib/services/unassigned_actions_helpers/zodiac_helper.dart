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

// lib/services/unassigned_actions_helpers/zodiac_helper.dart

import 'package:aravt/models/soldier_data.dart';

/// Helper class for zodiac-based interactions
class ZodiacHelper {
  /// Traditional Chinese zodiac compatibility matrix
  static final Map<Zodiac, List<Zodiac>> _compatiblePairs = {
    Zodiac.rat: [Zodiac.ox, Zodiac.dragon, Zodiac.monkey],
    Zodiac.ox: [Zodiac.rat, Zodiac.snake, Zodiac.rooster],
    Zodiac.tiger: [Zodiac.horse, Zodiac.dog],
    Zodiac.rabbit: [Zodiac.goat, Zodiac.pig, Zodiac.dog],
    Zodiac.dragon: [Zodiac.rat, Zodiac.monkey, Zodiac.rooster],
    Zodiac.snake: [Zodiac.ox, Zodiac.rooster],
    Zodiac.horse: [Zodiac.tiger, Zodiac.goat, Zodiac.dog],
    Zodiac.goat: [Zodiac.rabbit, Zodiac.horse, Zodiac.pig],
    Zodiac.monkey: [Zodiac.rat, Zodiac.dragon],
    Zodiac.rooster: [Zodiac.ox, Zodiac.snake, Zodiac.dragon],
    Zodiac.dog: [Zodiac.tiger, Zodiac.rabbit, Zodiac.horse],
    Zodiac.pig: [Zodiac.rabbit, Zodiac.goat],
  };

  static final Map<Zodiac, List<Zodiac>> _incompatiblePairs = {
    Zodiac.rat: [Zodiac.horse],
    Zodiac.ox: [Zodiac.goat],
    Zodiac.tiger: [Zodiac.snake, Zodiac.monkey],
    Zodiac.rabbit: [Zodiac.rooster],
    Zodiac.dragon: [Zodiac.dog],
    Zodiac.snake: [Zodiac.tiger, Zodiac.pig],
    Zodiac.horse: [Zodiac.rat],
    Zodiac.goat: [Zodiac.ox],
    Zodiac.monkey: [Zodiac.tiger],
    Zodiac.rooster: [Zodiac.rabbit],
    Zodiac.dog: [Zodiac.dragon],
    Zodiac.pig: [Zodiac.snake],
  };

  /// Check if two zodiacs are compatible
  static bool areCompatible(Zodiac zodiac1, Zodiac zodiac2) {
    return _compatiblePairs[zodiac1]?.contains(zodiac2) ?? false;
  }

  /// Check if two zodiacs are incompatible
  static bool areIncompatible(Zodiac zodiac1, Zodiac zodiac2) {
    return _incompatiblePairs[zodiac1]?.contains(zodiac2) ?? false;
  }

  /// Get compatibility modifier (1.5x for compatible, 0.5x for incompatible, 1.0x otherwise)
  static double getCompatibilityModifier(Zodiac zodiac1, Zodiac zodiac2) {
    if (areCompatible(zodiac1, zodiac2)) return 1.5;
    if (areIncompatible(zodiac1, zodiac2)) return 0.5;
    return 1.0;
  }

  /// Determine if a zodiac interaction should occur (1% baseline)
  static bool shouldZodiacInteractionOccur(
      Zodiac zodiac1, Zodiac zodiac2, double roll) {
    double baseProb = 0.01; // 1% baseline
    double modifier = getCompatibilityModifier(zodiac1, zodiac2);
    return roll < (baseProb * modifier);
  }

  /// Determine if the interaction is positive or negative
  /// 50/50 baseline, modified by compatibility and temperament
  static bool isZodiacInteractionPositive(
      Soldier soldier1, Soldier soldier2, double roll) {
    bool compatible = areCompatible(soldier1.zodiac, soldier2.zodiac);
    bool incompatible = areIncompatible(soldier1.zodiac, soldier2.zodiac);

    // Base 50/50
    double positiveChance = 0.5;

    // Modify by compatibility
    if (compatible) {
      positiveChance += 0.2; // 70% positive
    } else if (incompatible) {
      positiveChance -= 0.2; // 30% positive
    }

    // Modify by temperament
    if (soldier1.temperament >= 7) {
      positiveChance += 0.1; // Friendly people are more positive
    } else if (soldier1.temperament <= 3) {
      positiveChance -= 0.1; // Unfriendly people are more negative
    }

    return roll < positiveChance;
  }

  /// Generate a description for a zodiac interaction
  static String generateZodiacInteractionDescription(
      Soldier soldier1, Soldier soldier2, bool isPositive) {
    if (isPositive) {
      return "${soldier1.name} and ${soldier2.name} bonded over their zodiac compatibility (${soldier1.zodiac.name} and ${soldier2.zodiac.name}).";
    } else {
      return "${soldier1.name} and ${soldier2.name} clashed due to their zodiac signs (${soldier1.zodiac.name} and ${soldier2.zodiac.name}).";
    }
  }
}
