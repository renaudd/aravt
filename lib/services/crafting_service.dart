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
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/justification_event.dart';
import 'package:aravt/models/fletching_report.dart';

class CraftingService {
  final Random _random = Random();

  Future<FletchingReport> resolveFletching({
    required Aravt aravt,
    required GameState gameState,
    bool isLongArrows = false,
  }) async {
    int totalArrowsCrafted = 0;
    double totalWoodConsumed = 0;
    double totalScrapConsumed = 0;
    int currentTurn = gameState.turn.turnNumber;
    List<IndividualFletchingResult> individualResults = [];

    for (var id in aravt.soldierIds) {
      final soldier = gameState.findSoldierById(id);
      if (soldier != null &&
          soldier.status == SoldierStatus.alive &&
          !soldier.isImprisoned) {
        if (gameState.communalWood < 3.75 || gameState.communalScrap < 15) {
          // Not enough resources for even a minimal batch
          break;
        }

        // Calculate productivity
        double score = (soldier.patience * 2.0) +
            soldier.experience +
            soldier.shieldSkill +
            (soldier.stamina * 0.5) +
            (_random.nextInt(20) - 10);

        int arrowsMade = 0;
        double performanceRating = 0.5;

        if (score > 35) {
          arrowsMade = 20; // Extra successful (Reduced from 30)
          performanceRating = 1.0;
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Crafted an exceptional batch of arrows.",
              isPositive: true,
              magnitude: 2.0));
          soldier.pendingJustifications.add(JustificationEvent(
              description: "Crafted exceptional arrows",
              type: JustificationType.praise,
              expiryTurn: currentTurn + 2,
              magnitude: 1.0));
        } else if (score > 20) {
          arrowsMade = 15; // Successful (Unchanged)
          performanceRating = 0.7;
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Crafted a standard batch of arrows.",
              isPositive: true,
              magnitude: 1.0));
          soldier.pendingJustifications.add(JustificationEvent(
              description: "Crafted arrows",
              type: JustificationType.praise,
              expiryTurn: currentTurn + 2,
              magnitude: 0.5));
        } else {
          arrowsMade =
              _random.nextInt(5); // Unsuccessful/Poor (Reduced from 10)
          performanceRating = 0.2;
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Wasted materials fletching arrows.",
              isPositive: false,
              magnitude: 2.0));
          soldier.pendingJustifications.add(JustificationEvent(
              description: "Wasted materials crafting",
              type: JustificationType.scold,
              expiryTurn: currentTurn + 2,
              magnitude: 0.5));
        }

        double woodCost = arrowsMade * 0.25;
        double scrapCost = arrowsMade * 1.0;

        if (gameState.communalWood >= woodCost &&
            gameState.communalScrap >= scrapCost) {
          gameState.addCommunalWood(-woodCost);
          gameState.removeCommunalScrap(scrapCost);
          totalArrowsCrafted += arrowsMade;
          totalWoodConsumed += woodCost;
          totalScrapConsumed += scrapCost;
          soldier.exhaustion = (soldier.exhaustion + 0.5).clamp(0, 10);

          individualResults.add(IndividualFletchingResult(
            soldierId: soldier.id,
            soldierName: soldier.name,
            arrowsCrafted: arrowsMade,
            woodConsumed: woodCost,
            scrapConsumed: scrapCost,
            performanceRating: performanceRating,
          ));
        } else {
          break;
        }
      }
    }

    if (totalArrowsCrafted > 0) {
      gameState.addCommunalArrows(totalArrowsCrafted, isLong: isLongArrows);
      gameState.logEvent(
        "${aravt.id} fletched $totalArrowsCrafted ${isLongArrows ? 'long' : 'short'} arrows (used ${totalWoodConsumed.toStringAsFixed(1)}kg wood, ${totalScrapConsumed.toStringAsFixed(0)} scrap).",
        category: EventCategory.general,
        aravtId: aravt.id,
      );
    } else {
      gameState.logEvent(
        "${aravt.id} could not fletch arrows due to lack of resources.",
        category: EventCategory.general,
        severity: EventSeverity.low,
        aravtId: aravt.id,
      );
    }

    // Sort individualResults so Captain is first
    individualResults.sort((a, b) {
      final soldierA = gameState.findSoldierById(a.soldierId);
      final soldierB = gameState.findSoldierById(b.soldierId);
      if (soldierA?.role == SoldierRole.aravtCaptain) return -1;
      if (soldierB?.role == SoldierRole.aravtCaptain) return 1;
      return 0;
    });

    return FletchingReport(
      date: gameState.gameDate.copy(),
      aravtId: aravt.id,
      aravtName: aravt.id,
      totalArrowsCrafted: totalArrowsCrafted,
      isLongArrows: isLongArrows,
      totalWoodConsumed: totalWoodConsumed,
      totalScrapConsumed: totalScrapConsumed,
      individualResults: individualResults,
      turn: currentTurn,
    );
  }
}
