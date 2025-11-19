import 'dart:math';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/tournament_data.dart';
import 'package:aravt/models/horde_data.dart'; // Needed for Step 2
import 'package:aravt/services/aravt_captain_service.dart';
import 'package:aravt/services/horde_ai_service.dart';
import 'package:aravt/services/unassigned_actions_service.dart';
import 'package:aravt/services/soldier_transfer_service.dart';
import 'package:aravt/services/settlement_ai_service.dart';
import 'package:aravt/services/npc_horde_turn_service.dart';
import 'package:aravt/services/aravt_assignment_service.dart';
import 'package:aravt/services/tournament_service.dart';
import 'package:aravt/models/combat_models.dart';


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


     // --- 7. ARAVT ASSIGNMENTS (Travel, Scout, Patrol, Hunt, etc.) ---
     await _step7_ResolveAravtAssignments(gameState);


     // --- 8. UNAVOIDABLE COMBAT (Phase 1) ---
     await _step8_ResolveUnavoidableCombat(gameState);


     // --- 9. INVENTORY & NPC COMBAT ---
     await _step9_UpdateInventoriesAndResolveNPCCombat(gameState);


     // --- 10. POST-COMBAT SURGERY/TRIAGE ---
     await _step10_ResolvePostCombatTriage(gameState);


     // --- 11. SOLDIER UPDATES (Aging, Health, Birthdays) ---
     await _step11_UpdateSoldiers(gameState);


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


 Future<void> _step11_UpdateSoldiers(GameState gameState) async {
   // Placeholder
 }


 // Step 11.5: Narrative Events & Tournaments
 Future<void> _step11_5_ResolveNarrativeEvents(GameState gameState) async {
   print("Step 11.5: Checking narrative triggers for ${gameState.gameDate}");


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
                 (b.strength + b.intelligence + b.ambition).compareTo(
                     a.strength + a.intelligence + a.ambition));
             offeredSoldier = aravtMembers.first;
           } else if (gameState.difficulty == 'hard') {
             // Offer WORST soldier
             aravtMembers.sort((a, b) =>
                 (a.strength + a.intelligence + a.ambition).compareTo(
                     b.strength + b.intelligence + b.ambition));
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
         }
       }
     }
   }


   // --- DAY 7: The Great Downsizing (April 28th, 1140) ---
   if (gameState.gameDate.year == 1140 &&
       gameState.gameDate.month == 4 &&
       gameState.gameDate.day == 28) {
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


     // 2. Run the Tournament
     final result = await _tournamentService.runTournament(
       name: "Great Downsizing Tournament",
       date: gameState.gameDate,
       events: TournamentEventType.values,
       participatingAravts: participatingAravts,
       gameState: gameState,
     );


     // 3. Save Results
     gameState.addTournamentResult(result);


     // 4. Execute Consequences: Exile the loser
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
           gameState.triggerGameOver(
               "Your Aravt finished last in the Great Downsizing Tournament and has been exiled to the harsh steppe without supplies. Your journey ends here.");
           return;
         }


         // Exile Friendly Aravt
         gameState.logEvent(
           "Aravt ${loserAravt.id} finished last and has been exiled from the horde.",
           category: EventCategory.general,
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


 Future<void> _step12_Autosave(GameState gameState) async {
   if (gameState.autoSaveEnabled && !gameState.isGameOver) {
     await gameState.autoSave();
   }
 }


 Future<void> _step13_PresentAvoidableCombat(GameState gameState) async {
   // Placeholder
 }


 void _step14_ReplenishPlayerTokens(GameState gameState) {
   gameState.resetInteractionTokens();
   print("Step 14: Replenishing player tokens. Turn complete.");
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
}

