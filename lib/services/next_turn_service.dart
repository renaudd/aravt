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
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/tournament_data.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/services/aravt_captain_service.dart';
import 'package:aravt/services/horde_ai_service.dart';
import 'package:aravt/services/unassigned_actions_service.dart';
import 'package:aravt/services/soldier_transfer_service.dart';
import 'package:aravt/services/settlement_ai_service.dart';
import 'package:aravt/services/npc_horde_turn_service.dart';
import 'package:aravt/services/aravt_assignment_service.dart';
import 'package:aravt/services/tournament_service.dart';
import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/narrative_models.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/game_data/item_templates.dart';

import 'package:aravt/services/daily_maintenance_service.dart';
import 'package:aravt/services/training_discipline_service.dart';
import 'package:aravt/services/morale_narrative_service.dart';
import 'package:aravt/services/leadership_reports_service.dart';
import 'package:aravt/services/horde_transition_service.dart';
import 'package:aravt/services/infirmary_service.dart';

/// NextTurnService is the main "conductor" for all game logic that
/// happens when the player ends their turn.
class NextTurnService {
  final AravtCaptainService _aravtCaptainService = AravtCaptainService();
  final HordeAIService _hordeAIService = HordeAIService();
  final UnassignedActionsService _unassignedActionsService =
      UnassignedActionsService();
  final SoldierTransferService _soldierTransferService =
      SoldierTransferService();
  final SettlementAIService _settlementAIService = SettlementAIService();
  final NpcHordeTurnService _npcHordeTurnService = NpcHordeTurnService();
  final AravtAssignmentService _aravtAssignmentService =
      AravtAssignmentService();
  final TournamentService _tournamentService = TournamentService();
  final DailyMaintenanceService _dailyMaintenanceService =
      DailyMaintenanceService();
  final TrainingDisciplineService _trainingDisciplineService =
      TrainingDisciplineService();
  final MoraleNarrativeService _moraleNarrativeService =
      MoraleNarrativeService();
  final LeadershipReportsService _leadershipReportsService =
      LeadershipReportsService();
  final HordeTransitionService _hordeTransitionService =
      HordeTransitionService();
  final InfirmaryService _infirmaryService = InfirmaryService();

  final Random _random = Random();

  // Map to track soldier state for Step 3
  Map<int, String> _originalAravtAssignments = {};

  Future<void> executeNextTurn(GameState gameState) async {
    gameState.setLoading(true);


    // Record state BEFORE any logic runs for transfer tracking
    _originalAravtAssignments.clear();
    for (var soldier in gameState.horde) {
      _originalAravtAssignments[soldier.id] = soldier.aravt;
    }

    try {
      // --- 7. ARAVT ASSIGNMENTS (Travel, Scout, Patrol, Hunt, etc.) ---
      await _step7_ResolveAravtAssignments(gameState);

      // --- 1. ARAVT CAPTAIN AI ---
      await _step1_ResolveAravtCaptainDecisions(gameState);

      // --- 2. HORDE LEADER AI ---
      await _step2_ResolveHordeLeaderDecisions(gameState);

      // --- 3. SOLDIER TRANSFERS ---
      await _step3_ResolveSoldierTransfers(gameState);

      // --- 4. UNASSIGNED ACTIONS ---
      await _step4_ResolveUnassignedActions(gameState);

      // --- 5. NEARBY SETTLEMENT AI ---
      await _step5_ResolveSettlementActions(gameState);

      // --- 6. NEARBY HORDE AI ---
      await _step6_ResolveNearbyHordeActions(gameState);

      // --- 8. UNAVOIDABLE COMBAT (Phase 1) ---
      await _step8_ResolveUnavoidableCombat(gameState);

      // --- 9. INVENTORY & NPC COMBAT ---
      await _step9_UpdateInventoriesAndResolveNPCCombat(gameState);

      // --- 10. POST-COMBAT SURGERY/TRIAGE ---
      await _step10_ResolvePostCombatTriage(gameState);

      // --- 10.5 DAILY MAINTENANCE (Cook, Equerry) ---
      await _step10_5_ResolveDailyMaintenance(gameState);

      // --- 10.6 TRAINING & DISCIPLINE (Drill Sergeant, Disciplinarian) ---
      await _step10_6_ResolveTrainingAndDiscipline(gameState);

      // --- 10.7 MORALE & NARRATIVE (Tuulch, Chaplain) ---
      await _step10_7_ResolveMoraleAndNarrativeRoles(gameState);
      await _resolveListenItems(gameState);

      // --- 10.8 LEADERSHIP & REPORTS (Lieutenant, Chronicler) ---
      await _step10_8_ResolveLeadershipAndReports(gameState);

      // --- 10.9 INFIRMARY (Medic) ---
      _infirmaryService.processDailyInfirmary(gameState);

      // --- 11. SOLDIER UPDATES (Aging, Health, Birthdays) ---
      await _step11_UpdateSoldiers(gameState);
      _cleanupEmptyAravts(gameState);

      // --- 11.5 NARRATIVE EVENTS (Trade, Tournaments) ---
      await _step11_5_ResolveNarrativeEvents(gameState);

      // --- CHECK GAME OVER CONDITIONS BEFORE SAVE ---
      if (_checkGameOver(gameState)) {
        gameState.setLoading(false);
        return; // Stop turn processing if game ended
      }

      // --- 12. AUTOSAVE ---
      await _step12_Autosave(gameState);

      // --- 13. PRESENT AVOIDABLE COMBAT ---
      await _step13_PresentAvoidableCombat(gameState);

      // --- 14. REPLENISH TOKENS & END ---
      _step14_ReplenishPlayerTokens(gameState);

      // --- ADVANCE CLOCK (Strictly 1 Day) ---
      gameState.gameDate.nextDay();
      gameState.turn.incrementTurn();
      gameState.communalCattle.resetDailyTracker();
    } catch (e, stack) {
      print("CRITICAL ERROR during Next Turn processing: $e");
      print(stack);
    } finally {
      gameState.setLoading(false);
    }
  }

  // --- STEP IMPLEMENTATIONS ---

  Future<void> _step1_ResolveAravtCaptainDecisions(GameState gameState) async {
    print("Step 1: Resolving Aravt Captain decisions...");
    await _aravtCaptainService.resolveAravtCaptainTurns(gameState);
  }

  Future<void> _step2_ResolveHordeLeaderDecisions(GameState gameState) async {
    print("Step 2: Resolving Horde Leader decisions...");

    // Helper function to find a leader in a list of soldiers
    Soldier? findLeader(List<Soldier> horde) {
      try {
        return horde.firstWhere((s) => s.role == SoldierRole.hordeLeader);
      } catch (e) {
        return null; // No leader found
      }
    }

    // 1. Player Horde (Run AI only if player is NOT the leader)
    final Soldier? playerHordeLeader = findLeader(gameState.horde);
    // We check the new flag to see if AI should run for player's horde
    if (gameState.isPlayerHordeAutomated &&
        playerHordeLeader != null &&
        gameState.player != null &&
        gameState.player!.id != playerHordeLeader.id) {
      final playerHordeData = HordeData(
        id: 'player_horde',
        leaderId: playerHordeLeader.id,
        memberIds: gameState.horde.map((s) => s.id).toList(),
        aravtIds: gameState.aravts.map((a) => a.id).toList(),
        communalKilosOfMeat: gameState.communalMeat,
        communalKilosOfRice: gameState.communalRice,
      );
      await _hordeAIService.resolveHordeLeaderTurn(playerHordeData, gameState);
    }

    // 2. NPC Horde 1
    final Soldier? npc1Leader = findLeader(gameState.npcHorde1);
    if (npc1Leader != null && gameState.npcAravts1.isNotEmpty) {
      final npcHorde1Data = HordeData(
        id: 'npc_horde_1',
        leaderId: npc1Leader.id,
        memberIds: gameState.npcHorde1.map((s) => s.id).toList(),
        aravtIds: gameState.npcAravts1.map((a) => a.id).toList(),
        // NPC hordes theoretically have their own resources, but we don't track them in GameState yet.
        // Passing 0 for now is fine as the AI will just try to get more.
        communalKilosOfMeat: 0,
        communalKilosOfRice: 0,
      );
      await _hordeAIService.resolveHordeLeaderTurn(npcHorde1Data, gameState);
    }

    // 3. NPC Horde 2
    final Soldier? npc2Leader = findLeader(gameState.npcHorde2);
    if (npc2Leader != null && gameState.npcAravts2.isNotEmpty) {
      final npcHorde2Data = HordeData(
        id: 'npc_horde_2',
        leaderId: npc2Leader.id,
        memberIds: gameState.npcHorde2.map((s) => s.id).toList(),
        aravtIds: gameState.npcAravts2.map((a) => a.id).toList(),
        communalKilosOfMeat: 0,
        communalKilosOfRice: 0,
      );
      await _hordeAIService.resolveHordeLeaderTurn(npcHorde2Data, gameState);
    }
  }

  Future<void> _step3_ResolveSoldierTransfers(GameState gameState) async {
    print("Step 3: Resolving soldier transfers...");
    await _soldierTransferService.resolveSoldierTransfers(
        gameState, _originalAravtAssignments);
    _originalAravtAssignments.clear();
  }

  Future<void> _step4_ResolveUnassignedActions(GameState gameState) async {
    print("Step 4: Resolving unassigned soldier actions...");
    await _unassignedActionsService.resolveUnassignedActions(gameState);
  }

  Future<void> _step5_ResolveSettlementActions(GameState gameState) async {
    print("Step 5: Resolving nearby settlement actions...");
    for (final settlement in gameState.settlements) {
      await _settlementAIService.resolveSettlementTurn(settlement, gameState);
    }
  }

  Future<void> _step6_ResolveNearbyHordeActions(GameState gameState) async {
    print("Step 6: Resolving nearby horde actions...");
    await _npcHordeTurnService.resolveNpcHordeTurns(gameState);
  }

  Future<void> _step7_ResolveAravtAssignments(GameState gameState) async {
    // print("Step 7: Resolving Aravt assignments...");
    await _aravtAssignmentService.resolveAravtAssignments(gameState);
  }

  Future<void> _step8_ResolveUnavoidableCombat(GameState gameState) async {
    // Placeholder
  }

  Future<void> _step9_UpdateInventoriesAndResolveNPCCombat(
      GameState gameState) async {
    // Placeholder
  }

  Future<void> _step10_ResolvePostCombatTriage(GameState gameState) async {
    // Placeholder
  }

  Future<void> _step10_5_ResolveDailyMaintenance(GameState gameState) async {
    await _dailyMaintenanceService.resolveDailyMaintenance(gameState);
  }

  Future<void> _step10_6_ResolveTrainingAndDiscipline(
      GameState gameState) async {
    await _trainingDisciplineService.resolveTrainingAndDiscipline(gameState);
  }

  Future<void> _step10_7_ResolveMoraleAndNarrativeRoles(
      GameState gameState) async {
    await _moraleNarrativeService.resolveMoraleAndNarrativeRoles(gameState);
  }

  Future<void> _step10_8_ResolveLeadershipAndReports(
      GameState gameState) async {
    await _leadershipReportsService.resolveLeadershipAndReports(gameState);
  }

  Future<void> _step11_UpdateSoldiers(GameState gameState) async {
    print("Step 11: Updating soldiers (Health, Age)...");

    for (final soldier in List<Soldier>.from(gameState.horde)) {
      // --- 1. HEALING ---
      if (soldier.status == SoldierStatus.alive && !soldier.isInfirm) {
        int healingAmount = 1; // Base natural healing

        // Apply Medic Bonus
        final aravt = gameState.findAravtById(soldier.aravt);
        if (aravt != null) {
          final medicId = aravt.dutyAssignments[AravtDuty.medic];
          if (medicId != null) {
            final medic = gameState.findSoldierById(medicId);
            if (medic != null && medic.status == SoldierStatus.alive) {
              healingAmount += 1; // Base medic bonus
              if (medic.knowledge >= 7) healingAmount += 1;
              if (medic.specialSkills.contains(SpecialSkill.surgeon)) {
                healingAmount += 1;
              }
            }
          }
        }

        // Apply healing to all limbs
        soldier.headHealthCurrent = (soldier.headHealthCurrent + healingAmount)
            .clamp(0, soldier.headHealthMax);
        soldier.bodyHealthCurrent = (soldier.bodyHealthCurrent + healingAmount)
            .clamp(0, soldier.bodyHealthMax);
        soldier.rightArmHealthCurrent =
            (soldier.rightArmHealthCurrent + healingAmount)
                .clamp(0, soldier.rightArmHealthMax);
        soldier.leftArmHealthCurrent =
            (soldier.leftArmHealthCurrent + healingAmount)
                .clamp(0, soldier.leftArmHealthMax);
        soldier.rightLegHealthCurrent =
            (soldier.rightLegHealthCurrent + healingAmount)
                .clamp(0, soldier.rightLegHealthMax);
        soldier.leftLegHealthCurrent =
            (soldier.leftLegHealthCurrent + healingAmount)
                .clamp(0, soldier.leftLegHealthMax);
      }

      // --- 2. AGING ---
      if (gameState.gameDate.month == soldier.dateOfBirth.month &&
          gameState.gameDate.day == soldier.dateOfBirth.day) {
        soldier.age++;
        gameState.logEvent(
          "${soldier.name} has turned ${soldier.age} years old today.",
          category: EventCategory.general,
          severity: EventSeverity.normal,
          soldierId: soldier.id,
        );

        //  Birthday Gifts for Player
        if (soldier.isPlayer) {
          _handlePlayerBirthdayGifts(gameState, soldier);
        }
      }

      // --- 3. DEATH (Old Age & Leader Transition) ---
      bool died = false;
      final turn = gameState.turn.turnNumber;
      final bool isLeader = soldier.role == SoldierRole.hordeLeader;
      final bool isPlayer = soldier.id == gameState.player?.id;

      if (soldier.age > 60 && soldier.status == SoldierStatus.alive) {
        // Protect leader from old age death before turn 15
        if (!isLeader || turn >= 15) {
          // Simple probability: (age - 60) * 0.5% per turn
          double deathProb = (soldier.age - 60) * 0.005;
          if (_random.nextDouble() < deathProb) {
            died = true;
            soldier.deathReason = DeathReason.oldAge;
          }
        }
      }

      // Special Leader Death Probability (Turn-based)
      // Only if not already dead, is leader, and not the player
      if (!died &&
          isLeader &&
          soldier.status == SoldierStatus.alive &&
          !isPlayer) {
        double leaderDeathProb = 0.0;
        if (turn >= 15 && turn <= 40) {
          // Linear interpolation from 1% at turn 15 to 10% at turn 40
          leaderDeathProb = 0.01 + (turn - 15) * (0.09 / 25.0);
        } else if (turn > 40 && turn <= 50) {
          leaderDeathProb = 0.10;
        } else if (turn > 50) {
          leaderDeathProb =
              1.0; // Guaranteed death after turn 50 for testing/demo
        }

        if (_random.nextDouble() < leaderDeathProb) {
          died = true;
          soldier.deathReason = DeathReason.oldAge; // Keep it simple for now
        }
      }

      if (died) {
        soldier.status = SoldierStatus.killed;
        gameState.logEvent(
          "${soldier.name} has died at ${soldier.age}.",
          category: EventCategory.general,
          severity: EventSeverity.critical,
          soldierId: soldier.id,
        );

        if (soldier.role == SoldierRole.hordeLeader) {
          await _hordeTransitionService.handleLeaderDeath(gameState, soldier);
        }


        gameState.removeDeadSoldier(soldier);
      }
    }
  }

  // Step 11.5: Narrative Events & Tournaments
  Future<void> _step11_5_ResolveNarrativeEvents(GameState gameState) async {
    print("Step 11.5: Checking narrative triggers for ${gameState.gameDate}");

    // --- 1. Check for Active Tournament ---
    if (gameState.activeTournament != null) {
      print(
          "Continuing Active Tournament: ${gameState.activeTournament!.name}");
      final result = await _tournamentService.processDailyStage(gameState);

      if (result != null) {
        // Tournament Concluded!
        gameState.addTournamentResult(result);

        // Execute Consequences: Exile the loser
        String? loserAravtId;
        int minScore = 99999;
        result.finalAravtStandings.forEach((aravtId, score) {
          if (score < minScore) {
            minScore = score;
            loserAravtId = aravtId;
          }
        });

        if (loserAravtId != null) {
          final loserAravt = gameState.findAravtById(loserAravtId!);
          if (loserAravt != null) {
            // Is it the player?
            if (loserAravt.soldierIds.contains(gameState.player?.id)) {
              // Generate tournament results summary
              final StringBuffer results = StringBuffer();
              results
                  .writeln("The Great Downsizing Tournament has concluded.\n");
              results.writeln("Final Standings:");

              final sortedStandings = result.finalAravtStandings.entries
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              for (int i = 0; i < sortedStandings.length; i++) {
                final aravt = gameState.findAravtById(sortedStandings[i].key);
                final score = sortedStandings[i].value;
                final isPlayer =
                    aravt?.soldierIds.contains(gameState.player?.id) ?? false;
                final marker = isPlayer ? " (YOUR ARAVT)" : "";
                results.writeln(
                    "  ${i + 1}. Aravt ${aravt?.id ?? 'Unknown'}: $score points$marker");
              }

              results.writeln(
                  "\nYour Aravt finished last and will be exiled from the horde.");

              // Trigger narrative event to show results before game over
              gameState.startNarrativeEvent(NarrativeEvent(
                type: NarrativeEventType.tournamentConclusion,
                instigatorId: 0, // Not used for this event type
                targetId: 0, // Not used for this event type
                description: results.toString(),
              ));
              return;
            }

            // Exile Friendly Aravt
            gameState.logEvent(
              "Aravt ${loserAravt.id} finished last and has been exiled from the horde.",
              category: EventCategory.general,
              severity: EventSeverity.critical,
            );

            // Log Games category event for tournament completion
            gameState.logEvent(
              "The Great Downsizing Tournament has concluded! Check the Games tab for full results.",
              category: EventCategory.games,
              severity: EventSeverity.critical,
            );

            // Remove soldiers
            for (var id in List.from(loserAravt.soldierIds)) {
              final s = gameState.findSoldierById(id);
              if (s != null) {
                gameState.horde.remove(s);
              }
            }
            // Remove Aravt
            gameState.aravts.remove(loserAravt);
          }
        }
      }
    }

    // --- DAY 5: Trade Offer (April 26th, 1140) ---
    if (gameState.gameDate.year == 1140 &&
        gameState.gameDate.month == 4 &&
        gameState.gameDate.day == 26 &&
        !gameState.hasDay5TradeOccurred) {
      print("TRIGGERING DAY 5 EVENT (Internal)");

      // 1. Find a FRIENDLY captain (not player, not horde leader)
      final friendlyAravts = gameState.aravts.where((a) {
        // Exclude player's aravt
        if (a.soldierIds.contains(gameState.player?.id)) return false;
        // Exclude horde leader's aravt
        final leader = gameState.horde
            .firstWhere((s) => s.role == SoldierRole.hordeLeader);
        if (a.id == leader.aravt) return false;
        return true;
      }).toList();

      if (friendlyAravts.isNotEmpty) {
        friendlyAravts.shuffle(_random);
        final targetAravt = friendlyAravts.first;
        final captain = gameState.findSoldierById(targetAravt.captainId);

        if (captain != null) {
          // 2. Find a soldier to offer based on Difficulty from THEIR aravt
          final aravtMembers = gameState.horde
              .where((s) => s.aravt == targetAravt.id && s.id != captain.id)
              .toList();

          if (aravtMembers.isNotEmpty) {
            Soldier offeredSoldier;
            if (gameState.difficulty == 'easy') {
              // Offer BEST soldier (Highest stats)
              aravtMembers.sort((a, b) =>
                  (b.strength + b.intelligence + b.ambition)
                      .compareTo(a.strength + a.intelligence + a.ambition));
              offeredSoldier = aravtMembers.first;
            } else if (gameState.difficulty == 'hard') {
              // Offer WORST soldier
              aravtMembers.sort((a, b) =>
                  (a.strength + a.intelligence + a.ambition)
                      .compareTo(b.strength + b.intelligence + b.ambition));
              offeredSoldier = aravtMembers.first;
            } else {
              // Medium: Random soldier
              offeredSoldier =
                  aravtMembers[_random.nextInt(aravtMembers.length)];
            }

            // 3. Trigger the event
            gameState.startNarrativeEvent(NarrativeEvent(
              type: NarrativeEventType.day5Trade,
              instigatorId: captain.id,
              targetId: offeredSoldier.id,
            ));

            gameState.hasDay5TradeOccurred = true;
          }
        }
      }
    }

    // --- DAY 7: The Great Downsizing (April 29th, 1140) ---
    if (gameState.gameDate.year == 1140 &&
        gameState.gameDate.month == 4 &&
        gameState.gameDate.day == 29) {
      print("TRIGGERING DAY 7 TOURNAMENT");

      // 1. Identify Participants: All Player Horde Aravts EXCEPT the Leader's
      final leader =
          gameState.horde.firstWhere((s) => s.role == SoldierRole.hordeLeader);
      final participatingAravts =
          gameState.aravts.where((a) => a.id != leader.aravt).toList();

      if (participatingAravts.isEmpty) {
        print("CRITICAL: No aravts available for tournament.");
        return;
      }

      // Start Tournament
      _tournamentService.startTournament(
        name: "Great Downsizing Tournament",
        date: gameState.gameDate,
        events: TournamentEventType.values,
        participatingAravts: participatingAravts,
        gameState: gameState,
      );
    }
  }

  Future<void> _resolveListenItems(GameState gameState) async {
    print("Step 10.8: Resolving Listen Items...");
    final int currentTurn = gameState.gameDate.totalDays;

    // 1. Clear expired items
    for (var soldier in gameState.horde) {
      if (soldier.queuedListenItem != null) {
        // Expire if from previous turn (or older)
        if (soldier.queuedListenItem!.turnNumber < currentTurn) {
          soldier.queuedListenItem = null;
        }
      }
    }

    // 2. Generate new items (randomly for now)
    // Chance per soldier: 5%
    // Cap total active items: 3
    int activeCount =
        gameState.horde.where((s) => s.queuedListenItem != null).length;

    if (activeCount < 3) {
      final candidates = gameState.horde
          .where((s) =>
              !s.isPlayer &&
              s.queuedListenItem == null &&
              s.status == SoldierStatus.alive)
          .toList();

      if (candidates.isNotEmpty) {
        candidates.shuffle(_random);
        // Add up to 1-2 new items per turn
        int newItems = 1 + _random.nextInt(2);

        for (int i = 0;
            i < newItems && i < candidates.length && activeCount < 3;
            i++) {
          final soldier = candidates[i];

          final messages = [
            "I have concerns about the rations.",
            "I saw something strange on patrol.",
            "My family is struggling.",
            "I wish to discuss my future.",
            "The horses are restless.",
            "I had a dream about wolves.",
            "Can we speak privately?",
          ];

          soldier.queuedListenItem = QueuedListenItem(
            message: messages[_random.nextInt(messages.length)],
            turnNumber: currentTurn,
            urgency: 1.0,
          );
          activeCount++;
          print("Generated Listen Item for ${soldier.name}");
        }
      }
    }
  }

  // --- 12. AUTOSAVE ---
  Future<void> _step12_Autosave(GameState gameState) async {
    print("Step 12: Autosaving...");
    // TODO: Implement autosave logic
    // await gameState.saveGame();
  }

  // --- 13. PRESENT AVOIDABLE COMBAT ---
  Future<void> _step13_PresentAvoidableCombat(GameState gameState) async {
    print("Step 13: Checking for avoidable combat...");
    // TODO: Implement avoidable combat logic
  }

  // --- 14. REPLENISH TOKENS & END ---
  void _step14_ReplenishPlayerTokens(GameState gameState) {
    print("Step 14: Replenishing player tokens...");
    gameState.resetInteractionTokens();
  }

  void _handlePlayerBirthdayGifts(GameState gameState, Soldier player) {
    print("It's the player's birthday! Checking for gifts...");
    for (final other in gameState.horde) {
      if (other.id == player.id || other.status != SoldierStatus.alive) {
        continue;
      }

      final rel = other.getRelationship(player.id);
      if (rel.admiration >= 4.0) {
        // High admiration, give a gift
        final giftType = other.giftTypePreference; // Or random
        InventoryItem? gift;

        // Try to give preferred type, fallback to random
        if (_random.nextDouble() < 0.7) {
          // 70% chance to give preferred type if available in templates
          // For simplicity, we'll just create a random item of that type for now,
          // or a default gift if type is supplies/treasure.
          if (giftType == GiftTypePreference.horse) {
            gift = ItemDatabase.createItemInstance('mount_horse');
          } else if (giftType == GiftTypePreference.sword) {
            gift = ItemDatabase.createItemInstance('wep_iron_sword');
          } else if (giftType == GiftTypePreference.spear) {
            gift = ItemDatabase.createItemInstance('wep_spear');
          } else if (giftType == GiftTypePreference.bow) {
            gift = ItemDatabase.createItemInstance('wep_short_bow');
          } else if (giftType == GiftTypePreference.armor) {
            gift = ItemDatabase.createItemInstance('arm_leather_lamellar');
          } else if (giftType == GiftTypePreference.supplies) {
            player.fungibleScrap += 10.0;
          } else if (giftType == GiftTypePreference.treasure) {
            player.fungibleRupees += 5.0;
          }
        }

        if (gift == null &&
            giftType != GiftTypePreference.supplies &&
            giftType != GiftTypePreference.treasure) {
          // Fallback gift
          gift = ItemDatabase.createItemInstance('trade_pelt');
        }

        if (gift != null) {
          player.personalInventory.add(gift);
          gameState.logEvent(
            "${other.name} gave you a gift for your birthday: ${gift.name}!",
            category: EventCategory.general,
            severity: EventSeverity.high,
            soldierId: other.id,
          );
        } else if (giftType == GiftTypePreference.supplies ||
            giftType == GiftTypePreference.treasure) {
          gameState.logEvent(
            "${other.name} gave you some ${giftType == GiftTypePreference.supplies ? 'supplies' : 'rupees'} for your birthday!",
            category: EventCategory.general,
            severity: EventSeverity.high,
            soldierId: other.id,
          );
        }
      }
    }
  }

  // Final check for Game Over conditions
  bool _checkGameOver(GameState gameState) {
    if (gameState.player == null) return false;

    // 1. Player Dead (Already handled by GameState trigger, but good as backup)
    if (gameState.player!.status == SoldierStatus.killed) {
      gameState.triggerGameOver("You have died.");
      return true;
    }

    // 2. Player Expelled (checked during regular gameplay, but good as a failsafe)
    if (gameState.player!.isExpelled) {
      gameState.triggerGameOver("You have been expelled from the horde.");
      return true;
    }

    return false;
  }

  void _cleanupEmptyAravts(GameState gameState) {
    // Remove Aravts that have no soldiers
    final emptyAravts =
        gameState.aravts.where((a) => a.soldierIds.isEmpty).toList();

    for (var aravt in emptyAravts) {
      print("Cleaning up empty Aravt: ${aravt.id}");
      gameState.aravts.remove(aravt);
    }
  }
}
