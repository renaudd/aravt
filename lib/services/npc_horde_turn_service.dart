// services/npc_horde_turn_service.dart

import 'dart:math';
import 'package:aravt/models/horde_data.dart'; // Using the correct HordeData
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';

// --- NEW IMPORTS ---
import 'package:aravt/models/aravt_models.dart'; // Need Aravt
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/combat_report.dart';
import 'package:aravt/services/auto_resolve_service.dart';
import 'package:aravt/services/loot_distribution_service.dart';
// --- END NEW IMPORTS ---

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

  // --- NEW: Instantiate services ---
  final AutoResolveService _autoResolveService = AutoResolveService();
  final LootDistributionService _lootDistributionService =
      LootDistributionService();
  // --- END NEW ---

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
      print(
          "AI ERROR (Step 6): Cannot resolve horde turn. No leader found for $hordeId.");
      return;
    }

    // 2. Determine Goal (based on leader personality, needs, diplomacy)
    // This is a simplified version of the HordeAIService goal-setting
    NpcHordeGoal goal = _determineHordeGoal(leader, gameState);

    // 3. Execute Goal
    switch (goal) {
      // --- MODIFIED: AttackHorde case ---
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
            category: EventCategory
                .general, // [GEMINI-FIX] Player doesn't know about NPC vs NPC combat
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
      // --- END MODIFIED ---

      case NpcHordeGoal.RaidSettlement:
        // TODO: Find a nearby settlement to raid
        print(
            "AI (Step 6 - ${leader.name}): We will raid the nearby settlements for their wealth! (Not yet implemented)");
        gameState.logEvent(
          "[${leader.name}'s Horde] is moving to raid a settlement.",
          isPlayerKnown: false,
          category: EventCategory
              .general, // [GEMINI-FIX] Player doesn't know about NPC raids
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
      } else {
        return NpcHordeGoal.RaidSettlement;
      }
    }

    // High Judgment/Patience -> Peaceful
    if (leader.judgment > 7 && leader.patience > 6) {
      if (_random.nextDouble() < 0.2) {
        return NpcHordeGoal.SendEmissary;
      } else {
        return NpcHordeGoal.Idle; // Represents local shepherding/hunting
      }
    }

    // Default: 80% chance to stay idle, 20% chance to do something else
    double roll = _random.nextDouble();
    if (roll < 0.80) {
      return NpcHordeGoal.Idle;
    } else if (roll < 0.90) {
      return NpcHordeGoal.Migrate;
    } else {
      return NpcHordeGoal.RaidSettlement;
    }
  }
}
