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

// services/soldier_update_service.dart

import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/game_event.dart';

/// This service is responsible for Step 11:
/// Updating all soldiers' health, age, and experience at the end of a turn.
class SoldierUpdateService {
  /// Loops through the number of days to advance and processes daily updates
  /// for every soldier in the game.
  Future<void> updateAllSoldiers(GameState gameState, int daysToAdvance) async {
    print("Step 11: Updating soldier experience, age, and health...");

    // 1. Get a combined list of all soldiers
    final List<Soldier> allSoldiers = [
      ...gameState.horde,
      ...gameState.npcHorde1,
      ...gameState.npcHorde2,
    ];

    // 2. Create a temporary date to advance day by day
    // This is crucial so we don't miss birthdays on multi-day advances
    final GameDate tempDate = gameState.gameDate.copy();

    // 3. Loop through each day
    for (int i = 0; i < daysToAdvance; i++) {
      // Advance the temp date by one day
      tempDate.nextDay();

      // 4. Process daily updates for each soldier
      for (final soldier in allSoldiers) {
        // Skip updates for the dead
        if (soldier.status == SoldierStatus.killed) continue;

        _processDailyUpdate(soldier, tempDate, gameState);
      }
    }

    // This is a placeholder for a non-blocking async operation
    await Future.delayed(Duration(milliseconds: 20));
  }

  /// Processes daily checks for a single soldier.
  void _processDailyUpdate(
      Soldier soldier, GameDate currentDate, GameState gameState) {
    // Check for birthday
    if (soldier.dateOfBirth.month == currentDate.month &&
        soldier.dateOfBirth.day == currentDate.day) {
      _applyBirthdayAging(soldier, currentDate, gameState);
    }

    // Natural Healing (1 HP per day for all parts)
    if (soldier.bodyHealthCurrent < soldier.bodyHealthMax) {
      soldier.bodyHealthCurrent =
          (soldier.bodyHealthCurrent + 1).clamp(0, soldier.bodyHealthMax);
    }
    if (soldier.headHealthCurrent < soldier.headHealthMax) {
      soldier.headHealthCurrent =
          (soldier.headHealthCurrent + 1).clamp(0, soldier.headHealthMax);
    }
    if (soldier.rightArmHealthCurrent < soldier.rightArmHealthMax) {
      soldier.rightArmHealthCurrent = (soldier.rightArmHealthCurrent + 1)
          .clamp(0, soldier.rightArmHealthMax);
    }
    if (soldier.leftArmHealthCurrent < soldier.leftArmHealthMax) {
      soldier.leftArmHealthCurrent =
          (soldier.leftArmHealthCurrent + 1).clamp(0, soldier.leftArmHealthMax);
    }
    if (soldier.rightLegHealthCurrent < soldier.rightLegHealthMax) {
      soldier.rightLegHealthCurrent = (soldier.rightLegHealthCurrent + 1)
          .clamp(0, soldier.rightLegHealthMax);
    }
    if (soldier.leftLegHealthCurrent < soldier.leftLegHealthMax) {
      soldier.leftLegHealthCurrent =
          (soldier.leftLegHealthCurrent + 1).clamp(0, soldier.leftLegHealthMax);
    }

    // TODO: Add daily experience gain from assignments

    // 3. Update stats (Health, Stress, Exhaustion, Hygiene)
    // Natural recovery/decay
    soldier.stress =
        (soldier.stress + 0.1).clamp(0.0, 5.0); // Base stress increase
    soldier.hygiene =
        (soldier.hygiene - 0.1).clamp(0.0, 5.0); // Base hygiene decrease
    soldier.exhaustion =
        (soldier.exhaustion - 0.2).clamp(0.0, 5.0); // Base recovery
  }

  /// Applies all effects of a soldier's birthday.
  void _applyBirthdayAging(
      Soldier soldier, GameDate currentDate, GameState gameState) {
    soldier.age++;

    // Log event for player's horde
    if (gameState.horde.contains(soldier)) {
      gameState.logEvent(
        "${soldier.name} celebrates their ${soldier.age}th birthday.",
        category: EventCategory.general,
        severity: EventSeverity.low,
        soldierId: soldier.id,
      );
    }

    // 1. Recalculate Max Health based on new age
    _recalculateMaxHealth(soldier);

    // 2. TODO: Apply attribute penalties
    if (soldier.age > 35) {
      // _applyAgingAttributePenalties(soldier);
    }

    // 3. TODO: Apply experience penalties
    if (soldier.age > 35) {
      // _applyAgingExperiencePenalties(soldier);
    }
  }

  /// Updates the soldier's max health based on the logic from SoldierGenerator.
  void _recalculateMaxHealth(Soldier soldier) {
    int age = soldier.age;
    int basePotential = 10;
    int peakAge = 25;
    double health;

    if (age <= peakAge) {
      health = 6 + (basePotential - 6) * (age / peakAge);
    } else if (age <= 40) {
      health = basePotential - (age - peakAge) * 0.1;
    } else if (age <= 70) {
      double declineFrom40 = (40 - peakAge) * 0.1;
      health = basePotential - declineFrom40 - (age - 40) * 0.2;
    } else {
      double declineFrom40 = (40 - peakAge) * 0.1;
      double declineFrom70 = (70 - 40) * 0.2;
      health = basePotential - declineFrom40 - declineFrom70 - (age - 70) * 0.3;
    }

    // Don't apply the random bonus/penalty on level up, just the trend
    int newMaxHealth = health.clamp(1, 10).round();

    if (newMaxHealth != soldier.healthMax) {
      soldier.healthMax = newMaxHealth;

      // Recalculate all body part max HP
      soldier.headHealthMax = (newMaxHealth * 0.9).clamp(1, 10).round();
      soldier.bodyHealthMax = (newMaxHealth * 1.1).clamp(1, 10).round();
      soldier.rightArmHealthMax = newMaxHealth.clamp(1, 10);
      soldier.leftArmHealthMax = newMaxHealth.clamp(1, 10);
      soldier.rightLegHealthMax = newMaxHealth.clamp(1, 10);
      soldier.leftLegHealthMax = newMaxHealth.clamp(1, 10);

      // Clamp current health to new maxes (important if max health *decreased*)
      soldier.headHealthCurrent =
          soldier.headHealthCurrent.clamp(0, soldier.headHealthMax);
      soldier.bodyHealthCurrent =
          soldier.bodyHealthCurrent.clamp(0, soldier.bodyHealthMax);
      soldier.rightArmHealthCurrent =
          soldier.rightArmHealthCurrent.clamp(0, soldier.rightArmHealthMax);
      soldier.leftArmHealthCurrent =
          soldier.leftArmHealthCurrent.clamp(0, soldier.leftArmHealthMax);
      soldier.rightLegHealthCurrent =
          soldier.rightLegHealthCurrent.clamp(0, soldier.rightLegHealthMax);
      soldier.leftLegHealthCurrent =
          soldier.leftLegHealthCurrent.clamp(0, soldier.leftLegHealthMax);
    }
  }

  // TODO: Implement this when rules are defined
  // void _applyAgingAttributePenalties(Soldier soldier) {
  //   // e.g., -1 strength, +1 intelligence every 5 years over 40
  // }
}
