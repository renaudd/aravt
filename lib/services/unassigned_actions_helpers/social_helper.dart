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

// lib/services/unassigned_actions_helpers/social_helper.dart

import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/social_interaction_data.dart';
import 'package:aravt/providers/game_state.dart';

/// Helper class for social interactions between soldiers
class SocialHelper {
  static final Random _random = Random();

  /// Calculate probability of social interaction
  /// 2% for aravt mates, 1% for random horde members
  /// Increases by 0.5% per previous interaction (max +5%)
  static double getSocialInteractionProbability(
      Soldier soldier, Soldier target, GameState gameState) {
    bool sameAravt = soldier.aravt == target.aravt;
    double baseProb = sameAravt ? 0.02 : 0.01;

    // Count previous interactions
    int previousInteractions = soldier.socialHistory
        .where((h) => h.targetSoldierId == target.id)
        .length;

    double historyBonus = (previousInteractions * 0.005).clamp(0.0, 0.05);

    return baseProb + historyBonus;
  }

  /// Select specific interaction type based on relationships and attributes
  static SocialInteractionType selectInteractionType(
      Soldier soldier, Soldier target, GameState gameState) {
    final rel = soldier.getRelationship(target.id);
    List<({SocialInteractionType type, double weight})> options = [];

    // Compliment (higher for high admiration, gregarious)
    double complimentWeight = rel.admiration * 2.0;
    if (soldier.attributes.contains(SoldierAttribute.gregarious)) {
      complimentWeight *= 2.0;
    }
    options.add(
        (type: SocialInteractionType.compliment, weight: complimentWeight));

    // Joke (higher for gregarious)
    double jokeWeight = 3.0;
    if (soldier.attributes.contains(SoldierAttribute.gregarious)) {
      jokeWeight *= 2.0;
    }
    options.add((type: SocialInteractionType.joke, weight: jokeWeight));

    // Advice (higher for mentor)
    double adviceWeight = 2.0;
    if (soldier.attributes.contains(SoldierAttribute.mentor)) {
      adviceWeight *= 3.0;
    }
    options.add((type: SocialInteractionType.advice, weight: adviceWeight));

    // Insult (higher for low admiration, bully)
    double insultWeight = (5.0 - rel.admiration) * 1.5;
    if (soldier.attributes.contains(SoldierAttribute.bully)) {
      insultWeight *= 3.0;
    }
    options.add((type: SocialInteractionType.insult, weight: insultWeight));

    // Intimidation (higher for bully, high courage)
    double intimidationWeight = soldier.courage / 20.0;
    if (soldier.attributes.contains(SoldierAttribute.bully)) {
      intimidationWeight *= 3.0;
    }
    options.add(
        (type: SocialInteractionType.intimidation, weight: intimidationWeight));

    // Reprimand (higher for high respect, mentor)
    double reprimandWeight = rel.respect * 1.5;
    if (soldier.attributes.contains(SoldierAttribute.mentor)) {
      reprimandWeight *= 2.0;
    }
    options
        .add((type: SocialInteractionType.reprimand, weight: reprimandWeight));

    // Weighted random selection
    double totalWeight = options.fold(0.0, (sum, opt) => sum + opt.weight);
    double roll = _random.nextDouble() * totalWeight;

    double cumulativeWeight = 0.0;
    for (var option in options) {
      cumulativeWeight += option.weight;
      if (roll <= cumulativeWeight) {
        return option.type;
      }
    }

    return SocialInteractionType.compliment; // Fallback
  }

  /// Execute social interaction and apply relationship changes
  static void executeSocialInteraction(Soldier soldier, Soldier target,
      SocialInteractionType type, GameState gameState) {
    final rel = target.getRelationship(soldier.id);
    bool wasPositive = false;

    switch (type) {
      case SocialInteractionType.compliment:
        rel.updateAdmiration(0.1);
        rel.updateRespect(0.05);
        wasPositive = true;
        break;
      case SocialInteractionType.joke:
        rel.updateAdmiration(0.05);
        wasPositive = true;
        break;
      case SocialInteractionType.advice:
        rel.updateRespect(0.1);
        wasPositive = true;
        break;
      case SocialInteractionType.insult:
        rel.updateAdmiration(-0.15);
        rel.updateRespect(-0.05);
        wasPositive = false;
        break;
      case SocialInteractionType.intimidation:
        rel.updateFear(0.2);
        rel.updateAdmiration(-0.1);
        wasPositive = false;
        break;
      case SocialInteractionType.reprimand:
        rel.updateRespect(0.05);
        rel.updateFear(0.05);
        wasPositive = true; // Generally constructive
        break;
    }

    // Log the interaction
    soldier.socialHistory.add(SocialInteractionHistory(
      targetSoldierId: target.id,
      type: type,
      turnNumber: gameState.turn.turnNumber,
      wasPositive: wasPositive,
    ));
  }

  /// Generate description for social interaction
  static String generateInteractionDescription(
      Soldier soldier, Soldier target, SocialInteractionType type) {
    switch (type) {
      case SocialInteractionType.compliment:
        return "${soldier.name} complimented ${target.name}.";
      case SocialInteractionType.joke:
        return "${soldier.name} shared a joke with ${target.name}.";
      case SocialInteractionType.advice:
        return "${soldier.name} gave advice to ${target.name}.";
      case SocialInteractionType.insult:
        return "${soldier.name} insulted ${target.name}.";
      case SocialInteractionType.intimidation:
        return "${soldier.name} intimidated ${target.name}.";
      case SocialInteractionType.reprimand:
        return "${soldier.name} reprimanded ${target.name}.";
    }
  }
}
