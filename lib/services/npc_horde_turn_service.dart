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

// services/npc_horde_turn_service.dart

import 'dart:math';
import 'package:aravt/models/horde_data.dart'; // Using the correct HordeData
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';

// Need Aravt
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/combat_report.dart';
import 'package:aravt/services/auto_resolve_service.dart';
import 'package:aravt/services/loot_distribution_service.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/area_data.dart';

// Represents the macro-level goal of an entire horde for the turn
enum NpcHordeGoal {
  Idle,
  Migrate, // Move camp to a new POI
  AttackHorde,
  RaidSettlement,
  SendEmissary,
  ShepherdFlocks, // Local area resource gathering
  Hunt, // Local area resource gathering
}

/// This service manages the "macro" turn-based decisions for NPC hordes,
/// such as moving on the map, declaring war, or raiding.
/// This is distinct from the HordeAIService, which manages *internal* aravt assignments.
class NpcHordeTurnService {
  final Random _random = Random();

  final AutoResolveService _autoResolveService = AutoResolveService();
  final LootDistributionService _lootDistributionService =
      LootDistributionService();

  Future<void> resolveNpcHordeTurns(GameState gameState) async {
    // We will loop through each NPC horde.
    // For now, we just have npcHorde1 and npcHorde2.
    // This logic can be expanded to a list of NPC Hordes later.

    if (gameState.npcHorde1.isNotEmpty) {
      await _resolveHordeAction(
        gameState,
        'npc_horde_1',
        gameState.npcHorde1, // Pass the list of soldiers
        gameState.npcAravts1, // Pass the list of aravts
      );
    }
    if (gameState.npcHorde2.isNotEmpty) {
      await _resolveHordeAction(
        gameState,
        'npc_horde_2',
        gameState.npcHorde2, // Pass the list of soldiers
        gameState.npcAravts2, // Pass the list of aravts
      );
    }

    // --- Splinter Hordes ---
    for (int i = 0; i < gameState.splinterHordes.length; i++) {
      await _resolveHordeAction(
        gameState,
        'splinter_horde_$i',
        gameState.splinterHordes[i],
        gameState.splinterAravts[i],
      );
    }

    // --- Check for Player Scout/Patrol on NPC Tiles ---
    await _checkPlayerScoutPatrol(gameState);
  }

  /// Resolves the single macro action for one NPC horde.
  Future<void> _resolveHordeAction(
    GameState gameState,
    String hordeId,
    List<Soldier>
        members, // This is the list of soldiers (e.g., gameState.npcHorde1)
    List<Aravt>
        aravts, // This is the list of aravts (e.g., gameState.npcAravts1)
  ) async {
    // 1. Find the leader
    Soldier? leader;
    try {
      leader = members.firstWhere((s) => s.role == SoldierRole.hordeLeader);
    } catch (e) {
      // Try to assign a new leader if members exist
      if (members.isNotEmpty) {
        members.sort((a, b) => b.leadership.compareTo(a.leadership));
        leader = members.first;
        leader.role = SoldierRole.hordeLeader;
        print("AI: Assigned new leader ${leader.name} to $hordeId");
      } else {
        print(
            "AI ERROR (Step 6): Cannot resolve horde turn. No soldiers in $hordeId.");
        return;
      }
    }

    // 2. Determine Goal (based on leader personality, needs, diplomacy)
    // This is a simplified version of the HordeAIService goal-setting
    NpcHordeGoal goal = _determineHordeGoal(leader, gameState);

    // 3. Execute Goal
    switch (goal) {
      case NpcHordeGoal.AttackHorde:
        // Find a target's soldier and aravt lists
        List<Soldier>? targetSoldiers;
        List<Aravt>? targetAravts;
        String targetHordeName = "a rival horde";

        // Simple logic: Horde 1 targets Horde 2, Horde 2 targets Horde 1
        // TODO: Expand this to include targeting the Player's horde
        if (hordeId == 'npc_horde_1' && gameState.npcHorde2.isNotEmpty) {
          try {
            final targetLeader = gameState.npcHorde2
                .firstWhere((s) => s.role == SoldierRole.hordeLeader);
            targetSoldiers = gameState.npcHorde2;
            targetAravts = gameState.npcAravts2;
            targetHordeName = "${targetLeader.name}'s Horde";
          } catch (e) {
            print(
                "AI (Step 6 - ${leader.name}): Could not find leader for target horde 2.");
          }
        } else if (hordeId == 'npc_horde_2' && gameState.npcHorde1.isNotEmpty) {
          try {
            final targetLeader = gameState.npcHorde1
                .firstWhere((s) => s.role == SoldierRole.hordeLeader);
            targetSoldiers = gameState.npcHorde1;
            targetAravts = gameState.npcAravts1;
            targetHordeName = "${targetLeader.name}'s Horde";
          } catch (e) {
            print(
                "AI (Step 6 - ${leader.name}): Could not find leader for target horde 1.");
          }
        }

        if (targetSoldiers != null && targetAravts != null) {
          print(
              "AI (Step 6 - ${leader.name}): Our horde marches to war against $targetHordeName!");

          // --- Call Auto-Resolve Service ---
          // We pass the raw lists of soldiers and aravts
          final CombatReport report = _autoResolveService.resolveCombat(
            gameState: gameState,
            attackerAravts: aravts,
            allAttackerSoldiers: members,
            defenderAravts: targetAravts,
            allDefenderSoldiers: targetSoldiers,
          );

          bool attackerWon = (report.result == CombatResult.playerVictory ||
              report.result == CombatResult.enemyRout);

          // --- Call Loot Distribution Service ---
          // We pass the report and the FULL list of soldiers for the WINNING side
          _lootDistributionService.distributePostCombatLoot(
            report: report,
            victoriousSoldiers: attackerWon ? members : targetSoldiers,
          );

          gameState.logEvent(
            "[${leader.name}'s Horde] has attacked $targetHordeName! ${attackerWon ? "They were victorious" : "They were defeated"}.",
            isPlayerKnown: false,
            category: EventCategory.general,
            severity: EventSeverity.critical,
          );
        } else {
          // No valid target found, default to idle
          print(
              "AI (Step 6 - ${leader.name}): We wish to attack, but have no rivals. We hold position.");
          gameState.logEvent(
            "[${leader.name}'s Horde] holds its position.",
            isPlayerKnown: false,
            category: EventCategory.general,
            severity: EventSeverity.low,
          );
        }
        break;

      case NpcHordeGoal.RaidSettlement:
        // TODO: Find a nearby settlement to raid
        print(
            "AI (Step 6 - ${leader.name}): We will raid the nearby settlements for their wealth! (Not yet implemented)");
        gameState.logEvent(
          "[${leader.name}'s Horde] is moving to raid a settlement.",
          isPlayerKnown: false,
          category: EventCategory.general,
          severity: EventSeverity.high,
        );
        break;
      case NpcHordeGoal.Migrate:
        // TODO: Find a new POI to move the camp to
        print(
            "AI (Step 6 - ${leader.name}): The lands here are thin. We move camp! (Not yet implemented)");
        gameState.logEvent(
          "[${leader.name}'s Horde] is migrating to new pastures.",
          isPlayerKnown: false,
          category: EventCategory.general,
          severity: EventSeverity.normal,
        );
        break;
      default:
        // Idle, ShepherdFlocks, Hunt, SendEmissary
        print(
            "AI (Step 6 - ${leader.name}): Our horde remains in its territory. (Idle/Local Activity)");
        gameState.logEvent(
          "[${leader.name}'s Horde] holds its position.",
          isPlayerKnown: false,
          category: EventCategory.general,
          severity: EventSeverity.low,
        );
        break;
    }

    // Simulate async work
    await Future.delayed(Duration(milliseconds: _random.nextInt(20) + 10));
  }

  NpcHordeGoal _determineHordeGoal(Soldier leader, GameState gameState) {
    // This logic should be driven by leader personality, just like in Step 2.
    // For now, we'll use a simple random roll.

    // High Ambition/Courage, Low Temperament -> Aggressive
    if (leader.ambition > 7 && leader.courage > 6 && leader.temperament < 4) {
      if (_random.nextDouble() < 0.5) {
        return NpcHordeGoal.AttackHorde;
      }
    }

    // High Ambition (proxy for Greed) -> Raid
    if (leader.ambition > 7) {
      if (_random.nextDouble() < 0.4) {
        return NpcHordeGoal.RaidSettlement;
      }
    }

    // Low Resources (implied) -> Migrate
    if (_random.nextDouble() < 0.1) {
      return NpcHordeGoal.Migrate;
    }

    // Default to local activity
    return NpcHordeGoal.Idle;
  }

  Future<void> _checkPlayerScoutPatrol(GameState gameState) async {
    for (var aravt in gameState.aravts) {
      final task = aravt.task;
      if (task is AssignedTask &&
          (task.assignment == AravtAssignment.Scout ||
              task.assignment == AravtAssignment.Patrol)) {
        // Check if on NPC tile
        final area = gameState.worldMap[task.areaId];
        if (area != null && area.type == AreaType.NpcCamp) {
          // Trigger combat!
          // Find which NPC horde is here
          String? npcHordeId;
          List<Soldier>? npcSoldiers;
          List<Aravt>? npcAravts;

          if (gameState.npcHorde1.isNotEmpty) {
            // Simplified check for now
            // Need a better way to map NPC horde to area, but for now let's assume NPC1 is at its camp
            npcHordeId = 'npc_horde_1';
            npcSoldiers = gameState.npcHorde1;
            npcAravts = gameState.npcAravts1;
          } else if (gameState.npcHorde2.isNotEmpty) {
            npcHordeId = 'npc_horde_2';
            npcSoldiers = gameState.npcHorde2;
            npcAravts = gameState.npcAravts2;
          }

          if (npcSoldiers != null && npcAravts != null) {
            gameState.logEvent(
                "Aravt ${aravt.id} encountered ${npcHordeId} while ${task.assignment.name}ing!",
                severity: EventSeverity.critical);
            // Trigger combat (simplified for now, ideally opens combat screen)
            final report = _autoResolveService.resolveCombat(
              gameState: gameState,
              attackerAravts: [aravt],
              allAttackerSoldiers:
                  gameState.horde.where((s) => s.aravt == aravt.id).toList(),
              defenderAravts:
                  npcAravts.take(3).toList(), // Fight 3 random aravts
              allDefenderSoldiers: npcSoldiers,
            );
            _lootDistributionService.distributePostCombatLoot(
              report: report,
              victoriousSoldiers: report.result == CombatResult.playerVictory
                  ? gameState.horde
                  : npcSoldiers,
            );
          }
        }

        // If Patrol, it persists. If Scout, it might complete after one turn?
        // For now, let's keep Patrol persisting but Scout completes.
        // If Patrol, it persists.
        // Scout tasks are handled in AravtAssignmentService, so we do NOT clear them here.
        // Clearing them here prevents them from ever being processed.
      }
    }
  }
}
