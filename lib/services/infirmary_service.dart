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

import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';
// import 'package:aravt/models/aravt_models.dart'; // Unused for now

class InfirmaryService {
  final Random _random = Random();

  void processDailyInfirmary(GameState gameState) {
    _admitPatients(gameState);
    _provideCare(gameState);
    _dischargePatients(gameState);
  }

  void _admitPatients(GameState gameState) {
    for (var soldier in gameState.horde) {
      if (soldier.status == SoldierStatus.killed ||
          soldier.status == SoldierStatus.fled) continue;
      if (soldier.isInfirm) continue; // Already in infirmary

      bool needsCare = false;

      // Check for disease
      if (soldier.currentDisease != null) {
        needsCare = true;
      }

      // Check for serious wounds (status wounded or low health)
      if (soldier.status == SoldierStatus.wounded) {
        needsCare = true;
      }

      // Check for specific body part damage (< 50%)
      if (_hasCriticalDamage(soldier)) {
        needsCare = true;
      }

      if (needsCare) {
        soldier.isInfirm = true;
        gameState.logEvent(
          "${soldier.name} has been moved to the infirmary.",
          category: EventCategory.health,
          severity: EventSeverity.normal,
        );
      }
    }
  }

  bool _hasCriticalDamage(Soldier soldier) {
    const double threshold = 0.5;
    return (soldier.headHealthCurrent / soldier.headHealthMax < threshold) ||
        (soldier.bodyHealthCurrent / soldier.bodyHealthMax < threshold) ||
        (soldier.rightArmHealthCurrent / soldier.rightArmHealthMax <
            threshold) ||
        (soldier.leftArmHealthCurrent / soldier.leftArmHealthMax < threshold) ||
        (soldier.rightLegHealthCurrent / soldier.rightLegHealthMax <
            threshold) ||
        (soldier.leftLegHealthCurrent / soldier.leftLegHealthMax < threshold);
  }

  void _provideCare(GameState gameState) {
    // Identify Medics
    // Medics are soldiers with SpecialSkill.surgeon or high knowledge
    List<Soldier> medics = gameState.horde
        .where((s) =>
            s.status == SoldierStatus.alive &&
            !s.isInfirm &&
            s.specialSkills.contains(SpecialSkill.surgeon))
        .toList();

    // Also include anyone with high knowledge (> 6) if no surgeons?
    if (medics.isEmpty) {
      medics = gameState.horde
          .where((s) =>
              s.status == SoldierStatus.alive && !s.isInfirm && s.knowledge > 6)
          .toList();
    }

    if (medics.isEmpty) return; // No one to give care

    double totalHealingPower = 0;
    for (var medic in medics) {
      double power = medic.knowledge.toDouble();
      if (medic.specialSkills.contains(SpecialSkill.surgeon)) {
        power *= 2.0;
      }
      totalHealingPower += power;
    }

    // Distribute care
    List<Soldier> patients = gameState.horde.where((s) => s.isInfirm).toList();
    if (patients.isEmpty) return;

    double healingPerPatient = totalHealingPower / patients.length;
    // Cap healing per patient to avoid instant full heal
    healingPerPatient = healingPerPatient.clamp(1.0, 10.0);

    for (var patient in patients) {
      _applyHealing(patient, healingPerPatient.round());

      // Disease treatment chance
      if (patient.currentDisease != null) {
        // Simple chance to cure based on healing power
        if (_random.nextDouble() < (healingPerPatient / 100.0)) {
          gameState.logEvent(
            "${patient.name} has recovered from ${patient.currentDisease!.type.name}.",
            category: EventCategory.health,
            severity: EventSeverity.high,
          );
          patient.currentDisease = null;
        }
      }
    }
  }

  void _applyHealing(Soldier soldier, int amount) {
    soldier.headHealthCurrent =
        min(soldier.headHealthMax, soldier.headHealthCurrent + amount);
    soldier.bodyHealthCurrent =
        min(soldier.bodyHealthMax, soldier.bodyHealthCurrent + amount);
    soldier.rightArmHealthCurrent =
        min(soldier.rightArmHealthMax, soldier.rightArmHealthCurrent + amount);
    soldier.leftArmHealthCurrent =
        min(soldier.leftArmHealthMax, soldier.leftArmHealthCurrent + amount);
    soldier.rightLegHealthCurrent =
        min(soldier.rightLegHealthMax, soldier.rightLegHealthCurrent + amount);
    soldier.leftLegHealthCurrent =
        min(soldier.leftLegHealthMax, soldier.leftLegHealthCurrent + amount);

    if (soldier.status == SoldierStatus.wounded && _isHealthyEnough(soldier)) {
      soldier.status = SoldierStatus.alive;
    }
  }

  void _dischargePatients(GameState gameState) {
    for (var soldier in gameState.horde) {
      if (!soldier.isInfirm) continue;

      if (soldier.currentDisease == null && _isHealthyEnough(soldier)) {
        soldier.isInfirm = false;
        gameState.logEvent(
          "${soldier.name} has been discharged from the infirmary.",
          category: EventCategory.health,
          severity: EventSeverity.high,
        );
      }
    }
  }

  bool _isHealthyEnough(Soldier soldier) {
    const double threshold = 0.8;
    return (soldier.headHealthCurrent / soldier.headHealthMax > threshold) &&
        (soldier.bodyHealthCurrent / soldier.bodyHealthMax > threshold) &&
        (soldier.rightArmHealthCurrent / soldier.rightArmHealthMax >
            threshold) &&
        (soldier.leftArmHealthCurrent / soldier.leftArmHealthMax > threshold) &&
        (soldier.rightLegHealthCurrent / soldier.rightLegHealthMax >
            threshold) &&
        (soldier.leftLegHealthCurrent / soldier.leftLegHealthMax > threshold);
  }
}
