import 'dart:math';
import 'package:aravt/models/soldier_action.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/soldier_data.dart';


/// Service to handle all of Step 4: Unassigned Soldier Actions
class UnassignedActionsService {
 final Random _random = Random();


 /// Main entry point. Resolves unassigned actions for all soldiers.
 Future<void> resolveUnassignedActions(GameState gameState) async {
   print("Step 4: Resolving unassigned soldier actions...");


   List<Soldier> allSoldiers = gameState.horde; // Get all soldiers
   List<Soldier> soldiersToProcess = List.from(allSoldiers);
   List<Soldier> processedSoldiers = [];


   // --- 4.l: Resolve plot-driven actions first ---
   // (We'll need a way to flag soldiers with plot actions)
   // ...


   // --- Process remaining soldiers in random order ---
   soldiersToProcess.shuffle(_random);


   for (Soldier soldier in soldiersToProcess) {
     if (processedSoldiers.contains(soldier)) {
       continue; // Soldier was involved in another action and "used" their turn
     }


     // 1. Generate the "event chart" for this soldier
     List<SoldierActionProposal> actionTable =
         _generateActionTable(soldier, gameState);


     // 2. Select and execute one action from the chart
     SoldierActionProposal chosenAction = _selectAction(actionTable);


     // 3. Execute the action
     await _executeAction(chosenAction, gameState, processedSoldiers);
    
     processedSoldiers.add(soldier);
   }
 }


 /// 1. Generates the weighted "event chart" for a single soldier
 List<SoldierActionProposal> _generateActionTable(
     Soldier soldier, GameState gameState) {
   List<SoldierActionProposal> table = [];


   // --- 4: Barter ---
   table.addAll(_generateBarterActions(soldier, gameState));


   // --- 4.a: Hostile Actions (Fight, Murder) ---
   table.addAll(_generateHostileActions(soldier, gameState));


   // --- 4.b: Lodge Request ---
   table.addAll(_generateRequestActions(soldier, gameState));
  
   // --- 4.c / 4.c.1: Social Interaction (Insult, Compliment, Zodiac) ---
   table.addAll(_generateSocialActions(soldier, gameState));


   // --- 4.d: Responsive Action (Mourning, etc.) ---
   table.addAll(_generateResponsiveActions(soldier, gameState));


   // --- 4.e, 4.f, 4.g, 4.h: Trait-Based Actions ---
   table.addAll(_generateTraitActions(soldier, gameState));


   // --- 4.i: Proselytize ---
   table.addAll(_generateProselytizeActions(soldier, gameState));


   // --- 4.j: Gossip ---
   table.addAll(_generateGossipActions(soldier, gameState));
  
   // --- 4.k: Give Advice ---
   table.addAll(_generateAdviceActions(soldier, gameState));


   // --- 4.m: Spread Disease ---
   table.addAll(_generateDiseaseActions(soldier, gameState));
  
   // --- 4.n: Gifting ---
   table.addAll(_generateGiftingActions(soldier, gameState));


   // --- 4.o: Divulge Info (Default for player's Aravt) ---
   table.addAll(_generateDivulgeInfoActions(soldier, gameState));


   // Add a default "Idle" action with a low probability
   table.add(SoldierActionProposal(
       actionType: UnassignedActionType.idle,
       soldier: soldier,
       probability: 1.0)); // Always have at least one option


   return table;
 }


 /// 2. Selects one action based on weighted probabilities
 SoldierActionProposal _selectAction(List<SoldierActionProposal> actionTable) {
   if (actionTable.isEmpty) {
     throw Exception("Action table was empty.");
   }


   double totalWeight =
       actionTable.fold(0.0, (prev, e) => prev + e.probability);
   double roll = _random.nextDouble() * totalWeight;


   double cumulativeWeight = 0.0;
   for (var proposal in actionTable) {
     cumulativeWeight += proposal.probability;
     if (roll <= cumulativeWeight) {
       return proposal;
     }
   }
   return actionTable.last; // Fallback
 }


 /// 3. Executes the chosen action
 Future<void> _executeAction(SoldierActionProposal action,
     GameState gameState, List<Soldier> processedSoldiers) async {
      
   // --- 4.l: Check for multi-soldier actions and add them to processed list
   if (action.targetSoldierId != null) {
     final targetSoldier = gameState.findSoldierById(action.targetSoldierId!);
     if (targetSoldier != null) {
        // This action consumes the target's turn as well
        processedSoldiers.add(targetSoldier);
     }
   }


   // TODO: Implement logic for each action type
   switch (action.actionType) {
     case UnassignedActionType.barter:
       print("ACTION: ${action.soldier.name} tries to barter with ${action.targetSoldierId}...");
       break;
     case UnassignedActionType.startFight:
       print("ACTION: ${action.soldier.name} starts a fight with ${action.targetSoldierId}!");
       break;
     case UnassignedActionType.murderAttempt:
       print("ACTION: ${action.soldier.name} attempts to murder ${action.targetSoldierId}!");
       break;
     case UnassignedActionType.lodgeRequest:
       print("ACTION: ${action.soldier.name} lodges a request with the player.");
       break;
     case UnassignedActionType.socialInteraction:
       print("ACTION: ${action.soldier.name} has a social interaction with ${action.targetSoldierId}.");
       break;
     case UnassignedActionType.gossip:
       print("ACTION: ${action.soldier.name} gossips with ${action.targetSoldierId}.");
       break;
     case UnassignedActionType.giveAdvice:
       print("ACTION: ${action.soldier.name} gives advice to ${action.targetSoldierId}.");
       break;
     case UnassignedActionType.proselytize:
       print("ACTION: ${action.soldier.name} proselytizes to ${action.targetSoldierId}.");
       break;
     case UnassignedActionType.giftItem:
       print("ACTION: ${action.soldier.name} gives a gift to ${action.targetSoldierId}.");
       break;
     case UnassignedActionType.traitActionSurgeon:
       print("ACTION: ${action.soldier.name} (Surgeon) cuts hair.");
       break;
     case UnassignedActionType.traitActionFalconer:
       print("ACTION: ${action.soldier.name} (Falconer) baits birds.");
       break;
     case UnassignedActionType.tendHorses:
       print("ACTION: ${action.soldier.name} tends to their horses.");
       break;
     case UnassignedActionType.playGame:
       print("ACTION: ${action.soldier.name} plays a game with ${action.targetSoldierId}.");
       break;
     case UnassignedActionType.responsiveAction:
       print("ACTION: ${action.soldier.name} performs a responsive action (e.g., mourning).");
       break;
     case UnassignedActionType.spreadDisease:
       print("ACTION: ${action.soldier.name} (sick) spreads their disease...");
       break;
     case UnassignedActionType.divulgeInfoToPlayer:
       print("ACTION: ${action.soldier.name} tells the player a piece of information.");
       break;
     case UnassignedActionType.idle:
     default:
       print("ACTION: ${action.soldier.name} does nothing in particular.");
       break;
   }
 }


 // --- STUBS FOR ACTION GENERATION ---
 // Each of these will return a (potentially empty) list of proposals


 List<SoldierActionProposal> _generateBarterActions(
     Soldier soldier, GameState gameState) {
   // 4: Check if soldier wants something.
   // Return List<SoldierActionProposal(actionType: UnassignedActionType.barter, ...)>
   return [];
 }


 List<SoldierActionProposal> _generateHostileActions(
     Soldier soldier, GameState gameState) {
   // 4.a: Loop relationships. If admiration <= 1, add fight/murder proposals.
   // Likelihood increases closer to 0. No murder until turn 8.
   return [];
 }


 List<SoldierActionProposal> _generateRequestActions(
     Soldier soldier, GameState gameState) {
   // 4.b: Check for grievances.
   return [];
 }


 List<SoldierActionProposal> _generateSocialActions(
     Soldier soldier, GameState gameState) {
   // 4.c & 4.c.1: 1-2% chance of random social interaction.
   // Check Zodiac animosity/camaraderie.
   return [];
 }


 List<SoldierActionProposal> _generateResponsiveActions(
     Soldier soldier, GameState gameState) {
   // 4.d: Check for recent events (e.g., death of yurt-mate).
   return [];
 }


 List<SoldierActionProposal> _generateTraitActions(
     Soldier soldier, GameState gameState) {
   // 4.e, 4.f, 4.g, 4.h: Check traits.
   List<SoldierActionProposal> actions = [];
   if (soldier.specialSkills.contains(SpecialSkill.surgeon)) {
     // actions.add(...)
   }
   if (soldier.specialSkills.contains(SpecialSkill.falconer)) {
     // actions.add(...)
   }
   // 4.g: All soldiers have a chance to tend horses.
   // actions.add(SoldierActionProposal(
   //   actionType: UnassignedActionType.tendHorses,
   //   soldier: soldier,
   //   probability: 0.5 + (soldier.animalHandling * 0.1)
   // ));
   // 4.h: All soldiers can play games.
   return actions;
 }


 List<SoldierActionProposal> _generateProselytizeActions(
     Soldier soldier, GameState gameState) {
   // 4.i: Check for fervor.
   return [];
 }


 List<SoldierActionProposal> _generateGossipActions(
     Soldier soldier, GameState gameState) {
   // 4.j: Check for 'Gossip' trait.
   return [];
 }


 List<SoldierActionProposal> _generateAdviceActions(
     Soldier soldier, GameState gameState) {
   // 4.k: Check for 'Mentor' trait or high stats.
   return [];
 }


 List<SoldierActionProposal> _generateDiseaseActions(
     Soldier soldier, GameState gameState) {
   // 4.m: Check if soldier is contagious.
   return [];
 }


 List<SoldierActionProposal> _generateGiftingActions(
     Soldier soldier, GameState gameState) {
   // 4.n: Check for birthdays or high admiration.
   return [];
 }


 List<SoldierActionProposal> _generateDivulgeInfoActions(
     Soldier soldier, GameState gameState) {
   // 4.o: Check if soldier is in player's aravt or a captain.
   // Calculate probability based on horde size.
   return [];
 }
}



