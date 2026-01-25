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

// lib/services/settlement_ai_service.dart

import 'dart:math';
import 'package:aravt/models/settlement_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/assignment_data.dart';

/// This service manages the turn-based decisions for a single settlement.
class SettlementAIService {
  final Random _random = Random();

  Future<void> resolveSettlementTurn(
      Settlement settlement, GameState gameState) async {
    // 1. Determine new goal (if idle)
    if (settlement.currentGoal == SettlementGoal.Idle) {
      _determineNewGoal(settlement, gameState);
    }

    // 2. Execute the current goal
    await _executeGoal(settlement, gameState);

    //  2.5 Assign Garrison Tasks
    _assignGarrisonTasks(settlement, gameState);

    // 3. Log action for omniscient mode
    gameState.logEvent(
      "[Settlement: ${settlement.name}] resolves turn. Goal: ${settlement.currentGoal.name}",
      isPlayerKnown: false,
      category: EventCategory.general,
      severity: EventSeverity.low,
    );
  }

  /// Determines what the settlement should focus on this turn.
  void _determineNewGoal(Settlement settlement, GameState gameState) {
    // Placeholder random logic for Phase 1.
    double roll = _random.nextDouble();
    if (roll < 0.20) {
      settlement.currentGoal = SettlementGoal.ProduceFood;
    } else if (roll < 0.40) {
      settlement.currentGoal = SettlementGoal.ProduceSupplies;
    } else if (roll < 0.50) {
      settlement.currentGoal = SettlementGoal.ProduceWealth;
    } else if (roll < 0.60) {
      // Militia training is abstract, but we can simulate it
      settlement.currentGoal = SettlementGoal.TrainMilitia;
    } else if (roll < 0.70) {
      settlement.currentGoal = SettlementGoal.MineIron;
    } else if (roll < 0.80) {
      settlement.currentGoal = SettlementGoal.ManageHerd;
    } else {
      settlement.currentGoal = SettlementGoal.Idle;
    }
  }

  /// Executes the logic for the settlement's chosen goal.
  Future<void> _executeGoal(Settlement settlement, GameState gameState) async {
    switch (settlement.currentGoal) {
      case SettlementGoal.ProduceFood:
        // Peasant population drives basic food production
        double produced = (settlement.peasantPopulation * 0.1) *
            (_random.nextDouble() * 0.5 + 0.75);
        settlement.foodStockpile += produced;
        break;

      case SettlementGoal.ProduceSupplies:
        double produced = (settlement.peasantPopulation * 0.05) *
            (_random.nextDouble() * 0.5 + 0.75);
        settlement.suppliesStockpile += produced;
        break;

      case SettlementGoal.ProduceWealth:
        double produced = (settlement.peasantPopulation * 0.02) *
            (_random.nextDouble() * 0.5 + 0.75);
        settlement.treasureWealth += produced;
        break;

      case SettlementGoal.TrainMilitia:
        // Abstract militia training
        break;

      case SettlementGoal.MineIron:
        settlement.ironOreStockpile += (_random.nextInt(5) + 1);
        break;

      // --- Handle all other goals to fix non-exhaustive switch error ---
      default:
        break;
    }

    // Universal daily consumption
    double foodNeeds = (settlement.peasantPopulation * 0.1);
    settlement.foodStockpile =
        (settlement.foodStockpile - foodNeeds).clamp(0.0, double.infinity);

    // Reset to idle to pick a new goal next turn
    settlement.currentGoal = SettlementGoal.Idle;

    await Future.delayed(Duration.zero);
  }

  void _assignGarrisonTasks(Settlement settlement, GameState gameState) {
    if (settlement.garrisonAravtIds.isEmpty) return;

    // Find settlement POI
    final poi = gameState.findPoiByIdWorld(settlement.poiId);
    if (poi == null) return;

    for (String aravtId in settlement.garrisonAravtIds) {
      // Find Aravt object
      Aravt? aravt;
      try {
        aravt = gameState.garrisonAravts.firstWhere((a) => a.id == aravtId);
      } catch (e) {
        continue;
      }

      // Skip if already has a task (unless we want to override daily?)
      // Garrison tasks are usually 1-day, so we can re-assign
      if (aravt.task != null) continue;

      // Assign based on goal
      switch (settlement.currentGoal) {
        case SettlementGoal.MineIron:
          // Assign to Mine
          aravt.task = AssignedTask(
            assignment: AravtAssignment.Mine,
            poiId: poi.id,
            startTime: gameState.gameDate.toDateTime(),
            durationInSeconds: 8 * 3600.0,
          );
          break;
        case SettlementGoal.ManageHerd:
          // Assign to Shepherd
          aravt.task = AssignedTask(
            assignment: AravtAssignment.Shepherd,
            poiId: poi.id,
            startTime: gameState.gameDate.toDateTime(),
            durationInSeconds: 8 * 3600.0,
          );
          break;
        case SettlementGoal.TrainMilitia:
          // Assign to Train
          aravt.task = AssignedTask(
            assignment: AravtAssignment.Train,
            poiId: poi.id,
            startTime: gameState.gameDate.toDateTime(),
            durationInSeconds: 8 * 3600.0,
          );
          break;
        default:
          // Default to Patrol or Guard
          if (_random.nextBool()) {
            aravt.task = AssignedTask(
              assignment: AravtAssignment.Patrol,
              areaId: gameState.worldMap.values
                  .firstWhere((a) => a.pointsOfInterest.contains(poi))
                  .id,
              startTime: gameState.gameDate.toDateTime(),
              durationInSeconds: 8 * 3600.0,
            );
          } else {
            aravt.task = AssignedTask(
              assignment: AravtAssignment.Defend,
              poiId: poi.id,
              startTime: gameState.gameDate.toDateTime(),
              durationInSeconds: 24 * 3600.0,
            );
          }
          break;
      }
    }
  }
}
