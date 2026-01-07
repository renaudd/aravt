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
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/training_report.dart';
import 'package:aravt/models/aravt_models.dart';

class TrainingService {
  Future<void> resolveTraining({
    required Aravt aravt,
    required GameState gameState,
  }) async {
    final captain = gameState.findSoldierById(aravt.captainId);
    final drillSergeantId = aravt.dutyAssignments[AravtDuty.drillSergeant];
    final drillSergeant = drillSergeantId != null
        ? gameState.findSoldierById(drillSergeantId)
        : null;

    if (captain == null) return;

    // Determine training focus based on Captain's best skill
    int skillType = getTrainingSkillType(captain);
    String trainingType = getTrainingName(skillType);

    List<IndividualTrainingResult> results = [];
    int currentTurn = gameState.turn.turnNumber;

    for (var id in aravt.soldierIds) {
      final soldier = gameState.findSoldierById(id);
      if (soldier == null ||
          soldier.status != SoldierStatus.alive ||
          soldier.isImprisoned) continue;

      // Base Skill gain (Float-based)
      final _random = Random();

      double skillGain = 0.06 + (_random.nextDouble() * 0.12); // 0.06 to 0.18
      if (drillSergeant != null) {
        skillGain += (drillSergeant.intelligence / 10.0) * 0.06;
      }
      if (captain.leadership > 7) {
        skillGain += 0.03;
      }

      // Apply Skill to the focused skill
      switch (skillType) {
        case 0:
          soldier.swordSkill = (soldier.swordSkill + skillGain).clamp(0, 10.0);
          break;
        case 1:
          soldier.spearSkill = (soldier.spearSkill + skillGain).clamp(0, 10.0);
          break;
        case 2:
          soldier.mountedArcherySkill =
              (soldier.mountedArcherySkill + skillGain).clamp(0, 10.0);
          break;
        case 3:
          soldier.shieldSkill =
              (soldier.shieldSkill + skillGain).clamp(0, 10.0);
          break;
        case 4:
          soldier.longRangeArcherySkill =
              (soldier.longRangeArcherySkill + skillGain).clamp(0, 10.0);
          break;
      }

      // Exhaustion and Stress
      soldier.exhaustion = (soldier.exhaustion + 2.0).clamp(0, 5.0);
      soldier.stress =
          (soldier.stress + 0.5).clamp(0, 5.0); // Training is stressful

      // Performance Rating for report
      double performanceRating = skillGain / 6.0; // Max possible is around 6

      results.add(IndividualTrainingResult(
        soldierId: soldier.id,
        soldierName: soldier.name,
        skillTrained: trainingType,
        xpGained:
            skillGain, // Keeping field name for now to avoid breaking changes, but value is skill gain
        performanceRating: performanceRating,
        exhaustionGained: 2,
      ));
    }

    // Sort results so Captain is first
    results.sort((a, b) {
      final soldierA = gameState.findSoldierById(a.soldierId);
      final soldierB = gameState.findSoldierById(b.soldierId);
      if (soldierA?.role == SoldierRole.aravtCaptain) return -1;
      if (soldierB?.role == SoldierRole.aravtCaptain) return 1;
      return 0;
    });

    final report = TrainingReport(
      date: gameState.gameDate.copy(),
      aravtId: aravt.id,
      aravtName: aravt.id, // Use Aravt ID as name
      captainName: captain.name,
      drillSergeantName: drillSergeant?.name ?? "None",
      trainingType: trainingType,
      individualResults: results,
      turn: currentTurn,
      isPlayerReport: gameState.aravts.contains(aravt),
    );

    print(
        "DEBUG: Created TrainingReport for ${aravt.id} with date ${report.date} and turn ${report.turn}");
    gameState.addTrainingReport(report);

    if (gameState.aravts.contains(aravt)) {
      gameState.logEvent(
        "${aravt.id} completed $trainingType training led by Captain ${captain.name}.",
        category: EventCategory.general,
        aravtId: aravt.id,
      );
    }
  }

  static int getTrainingSkillType(Soldier captain) {
    int skillType =
        0; // 0: Sword, 1: Spear, 2: Mounted Archery, 3: Shield, 4: Long Range
    double maxSkill = captain.swordSkill;
    if (captain.spearSkill > maxSkill) {
      maxSkill = captain.spearSkill;
      skillType = 1;
    }
    if (captain.mountedArcherySkill > maxSkill) {
      maxSkill = captain.mountedArcherySkill;
      skillType = 2;
    }
    if (captain.shieldSkill > maxSkill) {
      maxSkill = captain.shieldSkill;
      skillType = 3;
    }
    if (captain.longRangeArcherySkill > maxSkill) {
      maxSkill = captain.longRangeArcherySkill;
      skillType = 4;
    }
    return skillType;
  }

  static String getTrainingName(int skillType) {
    switch (skillType) {
      case 0:
        return "Swordplay";
      case 1:
        return "Spear Drills";
      case 2:
        return "Mounted Archery";
      case 3:
        return "Shield Wall";
      case 4:
        return "Archery Range";
      default:
        return "General";
    }
  }
}
