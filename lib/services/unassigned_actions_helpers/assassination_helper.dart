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

// lib/services/unassigned_actions_helpers/assassination_helper.dart

import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/aravt_models.dart';

/// Types of assassination attempts
enum AssassinationType {
  poisoning,
  strangleInSleep,
  createAccident,
  confront,
}

/// Result of an assassination attempt
class AssassinationResult {
  final bool success;
  final bool discovered;
  final String description;
  final AssassinationType type;
  final int? injuryDamage; // If target survives but is injured

  AssassinationResult({
    required this.success,
    required this.discovered,
    required this.description,
    required this.type,
    this.injuryDamage,
  });
}

/// Helper class for assassination mechanics
class AssassinationHelper {
  static final Random _random = Random();

  /// Select assassination type based on assassin's role and circumstances
  static AssassinationType selectAssassinationType(
      Soldier assassin, Soldier target, GameState gameState) {
    List<({AssassinationType type, double weight})> options = [];

    // Check if assassin is cook (poisoning easier)
    bool isCook = _isAssignedAsRole(assassin, AravtDuty.cook, gameState);
    if (isCook) {
      options.add((type: AssassinationType.poisoning, weight: 50.0));
    } else {
      options.add((type: AssassinationType.poisoning, weight: 10.0));
    }

    // Check if assassin is lieutenant (strangle easier)
    bool isLieutenant =
        _isAssignedAsRole(assassin, AravtDuty.lieutenant, gameState);
    if (isLieutenant) {
      options.add((type: AssassinationType.strangleInSleep, weight: 50.0));
    } else {
      options.add((type: AssassinationType.strangleInSleep, weight: 15.0));
    }

    // Check if assassin is medic (accident easier)
    bool isMedic = _isAssignedAsRole(assassin, AravtDuty.medic, gameState);
    if (isMedic) {
      options.add((type: AssassinationType.createAccident, weight: 50.0));
    } else {
      options.add((type: AssassinationType.createAccident, weight: 10.0));
    }

    // Confront is always an option (higher for high courage/strength)
    double confrontWeight = 20.0;
    if (assassin.courage > 70 && assassin.strength > 70) {
      confrontWeight = 40.0;
    }
    options.add((type: AssassinationType.confront, weight: confrontWeight));

    // Select weighted random
    double totalWeight = options.fold(0.0, (sum, opt) => sum + opt.weight);
    double roll = _random.nextDouble() * totalWeight;
    double cumulative = 0.0;

    for (var option in options) {
      cumulative += option.weight;
      if (roll <= cumulative) {
        return option.type;
      }
    }

    return AssassinationType.confront; // Fallback
  }

  /// Execute assassination attempt
  static AssassinationResult executeAssassination(Soldier assassin,
      Soldier target, AssassinationType type, GameState gameState) {
    switch (type) {
      case AssassinationType.poisoning:
        return _executePoisoning(assassin, target, gameState);
      case AssassinationType.strangleInSleep:
        return _executeStrangulation(assassin, target, gameState);
      case AssassinationType.createAccident:
        return _executeAccident(assassin, target, gameState);
      case AssassinationType.confront:
        return _executeConfrontation(assassin, target, gameState);
    }
  }

  /// Poisoning attempt
  static AssassinationResult _executePoisoning(
      Soldier assassin, Soldier target, GameState gameState) {
    double successChance = 0.3; // Base 30%

    // Assassin skills
    successChance += (assassin.intelligence / 200.0); // Up to +50%
    successChance += (assassin.patience / 20.0); // Up to +50%

    // Role advantage
    if (_isAssignedAsRole(assassin, AravtDuty.cook, gameState)) {
      successChance += 0.4; // +40% if cook
    }

    // Cook's perception (if different from assassin)
    Soldier? cook = _findRoleHolder(target, AravtDuty.cook, gameState);
    if (cook != null && cook.id != assassin.id) {
      // Cook might notice
      successChance -= (cook.perception / 200.0); // Up to -50%

      // Cook's loyalty to target
      final cookLoyalty = cook.getRelationship(target.id).admiration;
      if (cookLoyalty > 3.0) {
        successChance -= 0.2; // -20% if loyal
      }
      if (cookLoyalty > 4.0) {
        successChance -= 0.3; // Additional -30% if insanely loyal
      }
    }

    // Target's defenses
    successChance -= (target.hygiene / 200.0); // Up to -50%
    successChance -= (target.perception / 200.0); // Up to -50%
    successChance -= (target.stamina / 400.0); // Up to -25%

    // Clamp to reasonable range
    successChance = successChance.clamp(0.05, 0.95);

    bool success = _random.nextDouble() < successChance;
    bool discovered = false;

    if (!success) {
      // Check if discovered (higher chance if target has high perception)
      double discoveryChance = 0.3 + (target.perception / 200.0);
      discovered = _random.nextDouble() < discoveryChance;
    }

    String description;
    if (success) {
      description =
          "${assassin.name} successfully poisoned ${target.name}. ${target.name} died from the poison.";
    } else if (discovered) {
      description =
          "${assassin.name} attempted to poison ${target.name}, but was discovered!";
    } else {
      description =
          "${assassin.name} attempted to poison ${target.name}, but ${target.name} survived.";
    }

    return AssassinationResult(
      success: success,
      discovered: discovered,
      description: description,
      type: AssassinationType.poisoning,
      injuryDamage: success ? null : (_random.nextInt(20) + 10),
    );
  }

  /// Strangulation attempt
  static AssassinationResult _executeStrangulation(
      Soldier assassin, Soldier target, GameState gameState) {
    double successChance = 0.25; // Base 25%

    // Assassin skills
    successChance += (assassin.patience / 20.0); // Up to +50%
    successChance += (assassin.judgment / 200.0); // Up to +50%
    successChance += (assassin.strength / 200.0); // Up to +50%

    // Role advantage
    if (_isAssignedAsRole(assassin, AravtDuty.lieutenant, gameState)) {
      successChance += 0.35; // +35% if lieutenant
    }

    // Lieutenant's perception (if different from assassin)
    Soldier? lieutenant =
        _findRoleHolder(target, AravtDuty.lieutenant, gameState);
    if (lieutenant != null && lieutenant.id != assassin.id) {
      successChance -= (lieutenant.perception / 200.0); // Up to -50%

      // Lieutenant's loyalty to target
      final ltLoyalty = lieutenant.getRelationship(target.id).admiration;
      if (ltLoyalty > 3.0) {
        successChance -= 0.25; // -25% if loyal
      }
      if (ltLoyalty > 4.0) {
        successChance -= 0.35; // Additional -35% if insanely loyal
      }
    }

    // Target's defenses
    successChance -= (target.perception / 200.0); // Up to -50%
    successChance -= (target.strength / 300.0); // Up to -33%
    successChance -= (target.stamina / 300.0); // Up to -33%

    successChance = successChance.clamp(0.05, 0.95);

    bool success = _random.nextDouble() < successChance;
    bool discovered = false;

    if (!success) {
      // High chance of discovery in failed strangulation
      double discoveryChance = 0.7 + (target.perception / 200.0);
      discovered = _random.nextDouble() < discoveryChance;
    }

    String description;
    if (success) {
      description =
          "${assassin.name} strangled ${target.name} in their sleep. ${target.name} is dead.";
    } else if (discovered) {
      description =
          "${assassin.name} attempted to strangle ${target.name}, but was caught in the act!";
    } else {
      description =
          "${assassin.name} attempted to strangle ${target.name}, but ${target.name} fought back and survived.";
    }

    return AssassinationResult(
      success: success,
      discovered: discovered,
      description: description,
      type: AssassinationType.strangleInSleep,
      injuryDamage: success ? null : (_random.nextInt(30) + 20),
    );
  }

  /// Create accident attempt
  static AssassinationResult _executeAccident(
      Soldier assassin, Soldier target, GameState gameState) {
    double successChance = 0.2; // Base 20%

    // Assassin skills
    successChance += (assassin.patience / 20.0); // Up to +50%
    successChance += (assassin.knowledge / 200.0); // Up to +50%
    successChance += (assassin.intelligence / 200.0); // Up to +50%
    successChance += (assassin.charisma / 300.0); // Up to +33%
    successChance += (assassin.strength / 300.0); // Up to +33%

    // Role advantage
    if (_isAssignedAsRole(assassin, AravtDuty.medic, gameState)) {
      successChance += 0.45; // +45% if medic
    }

    // Medic's perception (if different from assassin)
    Soldier? medic = _findRoleHolder(target, AravtDuty.medic, gameState);
    if (medic != null && medic.id != assassin.id) {
      successChance -= (medic.perception / 200.0); // Up to -50%

      // Medic's loyalty to target
      final medicLoyalty = medic.getRelationship(target.id).admiration;
      if (medicLoyalty > 3.0) {
        successChance -= 0.2; // -20% if loyal
      }
      if (medicLoyalty > 4.0) {
        successChance -= 0.3; // Additional -30% if insanely loyal
      }
    }

    // Target's defenses
    successChance -= (target.perception / 200.0); // Up to -50%
    successChance -= (target.judgment / 200.0); // Up to -50%
    successChance -= (target.knowledge / 300.0); // Up to -33%
    successChance -= (target.experience / 2000.0); // Up to -50%

    successChance = successChance.clamp(0.05, 0.95);

    bool success = _random.nextDouble() < successChance;
    bool discovered = false;

    if (!success) {
      // Moderate chance of discovery
      double discoveryChance = 0.4 + (target.perception / 300.0);
      discovered = _random.nextDouble() < discoveryChance;
    }

    String description;
    if (success) {
      description =
          "${assassin.name} orchestrated a fatal accident. ${target.name} died in what appeared to be a tragic mishap.";
    } else if (discovered) {
      description =
          "${assassin.name} tried to create a fatal accident for ${target.name}, but the sabotage was discovered!";
    } else {
      description =
          "${assassin.name} tried to create a fatal accident for ${target.name}, but ${target.name} narrowly avoided serious harm.";
    }

    return AssassinationResult(
      success: success,
      discovered: discovered,
      description: description,
      type: AssassinationType.createAccident,
      injuryDamage: success ? null : (_random.nextInt(40) + 30),
    );
  }

  /// Direct confrontation (wrestling match)
  static AssassinationResult _executeConfrontation(
      Soldier assassin, Soldier target, GameState gameState) {
    // Use simplified wrestling logic
    double assassinScore = 0.0;
    double targetScore = 0.0;

    // Assassin stats
    assassinScore += assassin.strength;
    assassinScore += assassin.stamina;
    assassinScore += assassin.courage;
    assassinScore += assassin.swordSkill * 0.5; // Combat experience helps
    assassinScore += _random.nextInt(50).toDouble(); // Random factor

    // Target stats
    targetScore += target.strength;
    targetScore += target.stamina;
    targetScore += target.courage;
    targetScore += target.swordSkill * 0.5;
    targetScore += _random.nextInt(50).toDouble();

    bool success = assassinScore > targetScore;
    bool discovered = true; // Confrontation is always discovered

    String description;
    if (success) {
      description =
          "${assassin.name} confronted ${target.name} in a fight to the death. ${assassin.name} emerged victorious, killing ${target.name}.";
    } else {
      description =
          "${assassin.name} confronted ${target.name} in a fight to the death, but ${target.name} won and killed ${assassin.name} instead!";
    }

    return AssassinationResult(
      success: success,
      discovered: discovered,
      description: description,
      type: AssassinationType.confront,
      injuryDamage: null, // One of them dies
    );
  }

  // --- Helper Methods ---

  static bool _isAssignedAsRole(
      Soldier soldier, AravtDuty role, GameState gameState) {
    final aravt = gameState.findAravtById(soldier.aravt);
    if (aravt == null) return false;

    return aravt.dutyAssignments[role] == soldier.id;
  }

  static Soldier? _findRoleHolder(
      Soldier target, AravtDuty role, GameState gameState) {
    final aravt = gameState.findAravtById(target.aravt);
    if (aravt == null) return null;

    final holderId = aravt.dutyAssignments[role];
    if (holderId == null) return null;

    return gameState.findSoldierById(holderId);
  }
}
