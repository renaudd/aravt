import 'dart:math';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/combat_models.dart'; // For SoldierStatus


/// Represents the horde's most urgent needs
enum HordeNeedLevel { desperate, low, stable, surplus }


/// Represents the primary goals the AI can choose
enum AIGoal {
 getFood,
 getSupplies, // Wood, Iron, Scrap
 security, // Patrol, Guard
 conquest, // Attack rivals
 diplomacy, // Trade, Emissary
 maintenance, // Shepherding, Fletching
 scout, // Explicit goal to find new resources
 rest, // Explicit rest for weary units
 none
}


class HordeAIService {
 final Random _random = Random();


 Future<void> resolveHordeLeaderTurn(
     HordeData horde, GameState gameState) async {
   final Soldier? leader = gameState.findSoldierById(horde.leaderId);
   if (leader == null) return;


   // 1. Assess Needs
   final needs = _assessHordeNeeds(horde, gameState);


   // 2. Determine Goals based on Needs & Personality
   final goals = _determineGoals(leader, needs, gameState, horde);


   // 3. Get Available Aravts
   final availableAravts = _getAvailableAravts(horde, gameState, needs);


   if (availableAravts.isEmpty) {
     return;
   }


   // 4. Execute Assignments
   _executeAssignments(leader, horde, availableAravts, goals, gameState);
 }


 Map<HordeNeedLevel, List<String>> _assessHordeNeeds(
     HordeData horde, GameState gameState) {
   final needs = <HordeNeedLevel, List<String>>{
     HordeNeedLevel.desperate: [],
     HordeNeedLevel.low: [],
     HordeNeedLevel.stable: [],
   };


   // --- FOOD ---
   double dailyConsumption = horde.memberIds.length * 1.0;
   double daysOfFood = (horde.totalCommunalFood) / max(1, dailyConsumption);


   if (daysOfFood < 2) {
     needs[HordeNeedLevel.desperate]!.add("Food");
   } else if (daysOfFood < 7) {
     needs[HordeNeedLevel.low]!.add("Food");
   }


   // --- CATTLE (Grazing) ---
   // [GEMINI-FIX] Only desperate if NOT grazed yesterday.
   // If grazed yesterday (lastGrazed == current - 1), they are fine for today.
   int currentTurn = gameState.turn.turnNumber;
   if (horde.id == 'player_horde') {
     if (gameState.communalCattle.lastGrazedTurn < currentTurn - 1) {
       needs[HordeNeedLevel.desperate]!.add("Grazing");
     }
     // Removed "stable" grazing need to enforce "every other day" explicitly.
   }


   // --- SECURITY ---
   if (needs[HordeNeedLevel.desperate]!.isEmpty) {
     needs[HordeNeedLevel.low]!.add("Security");
   }


   return needs;
 }


 List<AIGoal> _determineGoals(
     Soldier leader,
     Map<HordeNeedLevel, List<String>> needs,
     GameState gameState,
     HordeData horde) {
   List<AIGoal> goals = [];


   // 1. Critical Needs always come first
   if (needs[HordeNeedLevel.desperate]!.contains("Grazing")) {
     goals.add(AIGoal.maintenance);
     print("AI (${leader.name}): Goal: MAINTENANCE (Cattle starving)");
   }
   if (needs[HordeNeedLevel.desperate]!.contains("Food")) {
     goals.add(AIGoal.getFood);
     print("AI (${leader.name}): Goal: GET FOOD (Desperate)");
   }


   return goals;
 }


 void _executeAssignments(Soldier leader, HordeData horde,
     List<Aravt> availableAravts, List<AIGoal> goals, GameState gameState) {
   int aravtIndex = 0;
   DateTime now = gameState.gameDate.toDateTime();
   int currentTurn = gameState.turn.turnNumber;


   // [GEMINI-NEW] Track if we've already assigned a shepherd this turn
   bool shepherdAssignedToday = false;


   bool assign(AravtAssignment assignment, String? poiId, String? areaId) {
     if (aravtIndex >= availableAravts.length) return false;
     final aravt = availableAravts[aravtIndex];


     if (_needsRest(aravt, gameState) &&
         assignment != AravtAssignment.Rest &&
         assignment != AravtAssignment.Shepherd) {
       return false;
     }


     aravt.task = AssignedTask(
       poiId: poiId,
       areaId: areaId,
       assignment: assignment,
       durationInSeconds: 7200,
       startTime: now,
     );
     aravtIndex++;
     print("AI (${leader.name}): Assigned ${aravt.id} to ${assignment.name}.");
     return true;
   }


   // 1. Execute Critical Goals First
   if (goals.contains(AIGoal.maintenance)) {
     // [GEMINI-FIX] Check the daily flag AND the turn timer
     if (!shepherdAssignedToday &&
         gameState.communalCattle.lastGrazedTurn < currentTurn - 1) {
       var pasture = _findBestPoiForAssignment(
           horde, AravtAssignment.Shepherd, gameState);
       if (pasture != null) {
         if (assign(AravtAssignment.Shepherd, pasture.poi.id, pasture.area.id)) {
            shepherdAssignedToday = true;
         }
       }
     }
   }
   if (goals.contains(AIGoal.getFood)) {
     var hunt =
         _findBestPoiForAssignment(horde, AravtAssignment.Hunt, gameState);
     if (hunt != null)
       assign(AravtAssignment.Hunt, hunt.poi.id, hunt.area.id);
   }


   // 2. FILLER LOGIC
   while (aravtIndex < availableAravts.length) {
     // Pass the shepherd flag down so filler doesn't double-assign either
     if (_tryAssignFillerTask(leader.name, horde, availableAravts[aravtIndex],
         gameState, now, shepherdAssignedToday)) {
      
       // If filler assigned a shepherd, update the flag for next iteration
       if (availableAravts[aravtIndex].task is AssignedTask &&
           (availableAravts[aravtIndex].task as AssignedTask).assignment == AravtAssignment.Shepherd) {
           shepherdAssignedToday = true;
       }
       aravtIndex++;
       continue;
     }
     // Final fallback
     availableAravts[aravtIndex++].task = null;
   }
 }


 bool _tryAssignFillerTask(String leaderName, HordeData horde, Aravt aravt,
     GameState gameState, DateTime now, bool shepherdAssignedToday) {
  
   if (_needsRest(aravt, gameState)) {
     aravt.task = null;
     return true;
   }


   bool tryAssign(AravtAssignment type) {
     _PoiLocation? loc = _findBestPoiForAssignment(horde, type, gameState);
     // Special case for Fletching
     if (type == AravtAssignment.FletchArrows) {
       if (gameState.communalWood < 5 || gameState.communalScrap < 5)
         return false;
       loc = _findHordeCamp(horde, gameState);
     }


     if (loc != null) {
       aravt.task = AssignedTask(
           poiId: loc.poi.id,
           areaId: loc.area.id,
           assignment: type,
           durationInSeconds: 7200,
           startTime: now);
       print("AI Filler ($leaderName): Assigned ${aravt.id} to ${type.name}");
       return true;
     }
     return false;
   }


   int turn = gameState.turn.turnNumber;


   if (turn <= 7 && horde.id == 'player_horde') {
     // 1. Shepherd (only if NOT done today AND needed)
     if (!shepherdAssignedToday &&
         gameState.communalCattle.lastGrazedTurn < turn - 1) {
       if (tryAssign(AravtAssignment.Shepherd)) return true;
     }


     // [GEMINI-NEW] Randomized Economic Priority Queue
     // Shuffling this list ensures we don't just spam Hunting if Wood is also available.
     List<AravtAssignment> ecoTasks = [
         AravtAssignment.Hunt,
         AravtAssignment.Fish,
         AravtAssignment.ChopWood,
         AravtAssignment.Mine,
     ];
     ecoTasks.shuffle(_random);


     // Try the shuffled tasks
     for (var task in ecoTasks) {
         if (tryAssign(task)) return true;
     }


     // Try crafting specifically if we have materials
     if (tryAssign(AravtAssignment.FletchArrows)) return true;


     // Scout if nothing else possible
     var scoutArea = _findNearestUnexploredArea(horde, gameState);
     if (scoutArea != null) {
       aravt.task = AssignedTask(
           areaId: scoutArea.id,
           assignment: AravtAssignment.Scout,
           durationInSeconds: 7200,
           startTime: now);
       print(
           "AI Filler ($leaderName): Week 1 fallback -> Scout ${scoutArea.name}");
       return true;
     }
   } else {
     // Standard AI (Turns 8+)
     if (tryAssign(AravtAssignment.Hunt)) return true;
     if (tryAssign(AravtAssignment.Patrol)) return true;
   }


   return false;
 }


 bool _needsRest(Aravt aravt, GameState gameState) {
   double totalExhaustion = 0;
   int memberCount = 0;
   for (var id in aravt.soldierIds) {
     final s = gameState.findSoldierById(id);
     if (s != null && s.status == SoldierStatus.alive) {
       totalExhaustion += s.exhaustion;
       memberCount++;
       if (s.exhaustion > 7 || s.bodyHealthCurrent < s.bodyHealthMax * 0.5)
         return true;
     }
   }
   return memberCount > 0 && (totalExhaustion / memberCount) > 6.0;
 }


 List<Aravt> _getAvailableAravts(HordeData horde, GameState gameState,
     Map<HordeNeedLevel, List<String>> needs) {
   List<Aravt> all = (horde.id == 'player_horde')
       ? gameState.aravts
       : (horde.id == 'npc_horde_1'
           ? gameState.npcAravts1
           : gameState.npcAravts2);


   return all.where((a) => a.task == null).toList()..shuffle(_random);
 }


 _PoiLocation? _findHordeCamp(HordeData horde, GameState gameState) {
   String targetId = (horde.id == 'player_horde')
       ? 'camp-player'
       : (horde.id == 'npc_horde_1' ? 'camp-npc1' : 'camp-npc2');
   for (var area in gameState.worldMap.values) {
     for (var poi in area.pointsOfInterest) {
       if (poi.id == targetId) return _PoiLocation(poi, area);
     }
   }
   return null;
 }


 _PoiLocation? _findBestPoiForAssignment(
     HordeData horde, AravtAssignment assignment, GameState gameState) {
   List<_PoiLocation> candidates = [];
   bool isNpc = horde.id != 'player_horde';


   for (var area in gameState.worldMap.values) {
     if (!isNpc && !area.isExplored && !gameState.isOmniscientMode) continue;


     for (var poi in area.pointsOfInterest) {
       if (!isNpc && !poi.isDiscovered && !gameState.isOmniscientMode)
         continue;


       if (poi.availableAssignments.contains(assignment)) {
         candidates.add(_PoiLocation(poi, area));
       }
     }
   }
   if (candidates.isEmpty) return null;
   return candidates[_random.nextInt(candidates.length)];
 }


 GameArea? _findNearestUnexploredArea(HordeData horde, GameState gameState) {
   var camp = _findHordeCamp(horde, gameState);
   if (camp == null) return null;
   List<GameArea> unexplored =
       gameState.worldMap.values.where((a) => !a.isExplored).toList();
   if (unexplored.isEmpty) return null;
   unexplored.sort((a, b) => a.coordinates
       .distanceTo(camp.area.coordinates)
       .compareTo(b.coordinates.distanceTo(camp.area.coordinates)));
   return unexplored.first;
 }
}


class _PoiLocation {
 final PointOfInterest poi;
 final GameArea area;
 _PoiLocation(this.poi, this.area);
}

