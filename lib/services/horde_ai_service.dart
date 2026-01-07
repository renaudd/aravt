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
import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/location_data.dart';

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
    if (leader == null || leader.status != SoldierStatus.alive) return;

    // If player is leader, they manage assignments manually
    if (gameState.player != null && leader.id == gameState.player!.id) {
      return;
    }

    // 1. Assess Needs
    final needs = _assessHordeNeeds(horde, gameState);

    // 2. Determine Goals based on Needs & Personality
    final goals = _determineGoals(leader, needs, gameState, horde);

    // 3. Get Available Aravts
    final availableAravts = _getAvailableAravts(horde, gameState);

    if (availableAravts.isEmpty) {
      return;
    }

    // 4. Execute Assignments
    _executeAssignments(leader, horde, availableAravts, goals, gameState);

    // 5. Assign Intra-Aravt Duties (Lieutenant, Tuulch)
    _assignIntraAravtDuties(horde, gameState);
  }

  void resolveGarrisonAssignments(
      List<Aravt> garrisonAravts, GameState gameState) async {
    for (var aravt in garrisonAravts) {
      if (aravt.task != null) continue;

      // Simple AI for garrisons: alternate between Patrol and Rest, or Guard if prisoners exist
      final imprisonedSoldiers =
          gameState.horde.where((s) => s.isImprisoned).toList();

      if (imprisonedSoldiers.isNotEmpty && _random.nextDouble() < 0.5) {
        aravt.task = AssignedTask(
          areaId: null, // At settlement
          poiId: aravt.currentLocationId,
          assignment: AravtAssignment.GuardPrisoners,
          durationInSeconds: 86400,
          startTime: gameState.currentDate?.toDateTime() ?? DateTime.now(),
        );
      } else if (_random.nextDouble() < 0.7) {
        aravt.task = AssignedTask(
          areaId: null, // At settlement
          poiId: aravt.currentLocationId,
          assignment: AravtAssignment.Patrol,
          durationInSeconds: 86400,
          startTime: gameState.currentDate?.toDateTime() ?? DateTime.now(),
        );
      } else {
        // Rest
        aravt.task = null;
      }
    }
  }

  void _assignIntraAravtDuties(HordeData horde, GameState gameState) {
    List<Aravt> allAravts = (horde.id == 'player_horde')
        ? gameState.aravts
        : (horde.id == 'npc_horde_1'
            ? gameState.npcAravts1
            : gameState.npcAravts2);

    for (var aravt in allAravts) {
      // Captain is already set.

      // 1. Collect potential candidates (excluding captain)
      final candidates = aravt.soldierIds
          .where((id) => id != aravt.captainId)
          .map((id) => gameState.findSoldierById(id))
          .whereType<Soldier>()
          .toList();

      if (candidates.isEmpty) continue;

      // 2. Assign Lieutenant (Best Leadership/Courage)
      if (aravt.dutyAssignments[AravtDuty.lieutenant] == null) {
        candidates.sort((a, b) {
          int scoreA = a.leadership * 2 + a.courage;
          int scoreB = b.leadership * 2 + b.courage;
          return scoreB.compareTo(scoreA);
        });
        aravt.dutyAssignments[AravtDuty.lieutenant] = candidates.first.id;
      }

      // 3. Assign Tuulch (Best Charisma/Storyteller)
      if (aravt.dutyAssignments[AravtDuty.tuulch] == null) {
        final remainingCandidates = candidates
            .where((c) => c.id != aravt.dutyAssignments[AravtDuty.lieutenant])
            .toList();
        if (remainingCandidates.isNotEmpty) {
          remainingCandidates.sort((a, b) {
            int scoreA = a.charisma * 2 +
                (a.attributes.contains(SoldierAttribute.storyTeller) ? 10 : 0);
            int scoreB = b.charisma * 2 +
                (b.attributes.contains(SoldierAttribute.storyTeller) ? 10 : 0);
            return scoreB.compareTo(scoreA);
          });
          aravt.dutyAssignments[AravtDuty.tuulch] =
              remainingCandidates.first.id;
        }
      }
    }
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
    int currentTurn = gameState.turn.turnNumber;
    if (horde.id == 'player_horde') {
      int daysSinceGrazed =
          currentTurn - gameState.communalCattle.lastGrazedTurn;
      if (daysSinceGrazed >= 7) {
        needs[HordeNeedLevel.desperate]!.add("Grazing");
      } else if (daysSinceGrazed >= 3) {
        needs[HordeNeedLevel.low]!.add("Grazing");
      }
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
    } else if (needs[HordeNeedLevel.low]!.contains("Grazing") &&
        _random.nextDouble() < 0.5) {
      // Benefit from grazing twice a week
      goals.add(AIGoal.maintenance);
      print("AI (${leader.name}): Goal: MAINTENANCE (Cattle want grazing)");
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

    bool shepherdAssignedToday = false;
    int fletchersAssignedToday = 0;

    bool assign(AravtAssignment assignment, String? poiId, String? areaId) {
      if (aravtIndex >= availableAravts.length) return false;
      final aravt = availableAravts[aravtIndex];

      if (_needsRest(aravt, gameState) &&
          assignment != AravtAssignment.Rest &&
          assignment != AravtAssignment.Shepherd) {
        return false;
      }

      // Check distance for travel
      HexCoordinates? startCoords = aravt.hexCoords;
      HexCoordinates? endCoords;
      if (poiId != null) {
        endCoords = gameState.findPoiByIdWorld(poiId)?.position;
      } else if (areaId != null) {
        endCoords = gameState.worldMap[areaId]?.coordinates;
      }

      if (startCoords != null &&
          endCoords != null &&
          startCoords != endCoords) {
        // Need to travel
        int distance = startCoords.distanceTo(endCoords);
        double travelSeconds = max(86400.0, distance * 86400.0);
        aravt.task = MovingTask(
          destination: poiId != null
              ? GameLocation.poi(poiId)
              : GameLocation.area(areaId!),
          durationInSeconds: travelSeconds,
          startTime: now,
          followUpAssignment: assignment,
          followUpPoiId: poiId,
          followUpAreaId: areaId,
        );
      } else {
        aravt.task = AssignedTask(
          poiId: poiId,
          areaId: areaId,
          assignment: assignment,
          durationInSeconds: 86400,
          startTime: now,
        );
      }
      aravtIndex++;
      print("AI (${leader.name}): Assigned ${aravt.id} to ${assignment.name}.");
      return true;
    }

    // 1. Execute Critical Goals First
    if (goals.contains(AIGoal.maintenance)) {
      bool alreadyShepherding = availableAravts
              .any((a) => a.currentAssignment == AravtAssignment.Shepherd) ||
          (horde.id == 'player_horde'
                  ? gameState.aravts
                  : (horde.id == 'npc_horde_1'
                      ? gameState.npcAravts1
                      : gameState.npcAravts2))
              .any((a) => a.currentAssignment == AravtAssignment.Shepherd);

      if (!shepherdAssignedToday && !alreadyShepherding) {
        var pasture = _findBestPoiForAssignment(
            horde, AravtAssignment.Shepherd, gameState);
        if (pasture != null) {
          if (assign(
              AravtAssignment.Shepherd, pasture.poi.id, pasture.area.id)) {
            shepherdAssignedToday = true;
          }
        }
      }
    }
    if (goals.contains(AIGoal.getFood)) {
      var hunt =
          _findBestPoiForAssignment(horde, AravtAssignment.Hunt, gameState);
      if (hunt != null) {
        assign(AravtAssignment.Hunt, hunt.poi.id, hunt.area.id);
      }
    }

    // 2. FILLER LOGIC
    while (aravtIndex < availableAravts.length) {
      if (_tryAssignFillerTask(leader.name, horde, availableAravts[aravtIndex],
          gameState, now, shepherdAssignedToday, fletchersAssignedToday)) {
        final task = availableAravts[aravtIndex].task;
        if (task is AssignedTask) {
          if (task.assignment == AravtAssignment.Shepherd) {
            shepherdAssignedToday = true;
          } else if (task.assignment == AravtAssignment.FletchArrows) {
            fletchersAssignedToday++;
          }
        } else if (task is MovingTask) {
          if (task.followUpAssignment == AravtAssignment.Shepherd) {
            shepherdAssignedToday = true;
          } else if (task.followUpAssignment == AravtAssignment.FletchArrows) {
            fletchersAssignedToday++;
          }
        }
        aravtIndex++;
        continue;
      }
      availableAravts[aravtIndex++].task = null;
    }
  }

  bool _tryAssignFillerTask(
      String leaderName,
      HordeData horde,
      Aravt aravt,
      GameState gameState,
      DateTime now,
      bool shepherdAssignedToday,
      int fletchersAssignedToday) {
    if (_needsRest(aravt, gameState)) {
      var camp = _findHordeCamp(horde, gameState);
      if (camp != null) {
        HexCoordinates? startCoords = aravt.hexCoords;
        HexCoordinates? endCoords = camp.poi.position;

        if (startCoords != null &&
            endCoords != null &&
            startCoords != endCoords) {
          // Travel to camp
          int distance = startCoords.distanceTo(endCoords);
          double travelSeconds = max(86400.0, distance * 86400.0);
          aravt.task = MovingTask(
            destination: GameLocation.poi(camp.poi.id),
            durationInSeconds: travelSeconds,
            startTime: now,
            followUpAssignment: AravtAssignment.Rest,
            followUpPoiId: camp.poi.id,
            followUpAreaId: camp.area.id,
          );
          print(
              "AI Filler ($leaderName): Assigned ${aravt.id} to Travel to Camp for Rest");
          return true;
        } else {
          // Already at camp, just rest (null task or explicit Rest)
          // Explicit Rest is better for UI feedback
          aravt.task = AssignedTask(
            poiId: camp.poi.id,
            areaId: camp.area.id,
            assignment: AravtAssignment.Rest,
            durationInSeconds: 86400,
            startTime: now,
          );
          print(
              "AI Filler ($leaderName): Assigned ${aravt.id} to Rest at Camp");
          return true;
        }
      }
      // If no camp found (rare), just idle
      aravt.task = null;
      return true;
    }

    bool tryAssign(AravtAssignment type, {String? option}) {
      _PoiLocation? loc = _findBestPoiForAssignment(horde, type, gameState);
      if (type == AravtAssignment.FletchArrows) {
        // Allow up to 2 fletchers if resources are available
        if (fletchersAssignedToday >= 2) return false;

        double requiredWood = 50.0; // Require 50 wood for ~200 arrows
        double requiredScrap = 200.0; // Require 200 scrap for ~200 arrows
        if (gameState.communalWood < requiredWood ||
            gameState.communalScrap < requiredScrap) return false;
        loc = _findHordeCamp(horde, gameState);
      }

      if (loc != null) {
        // Check distance for travel
        HexCoordinates? startCoords = aravt.hexCoords;
        HexCoordinates? endCoords = loc.poi.position;

        if (startCoords != null &&
            endCoords != null &&
            startCoords != endCoords) {
          // Need to travel
          int distance = startCoords.distanceTo(endCoords);
          double travelSeconds = max(86400.0, distance * 86400.0);
          aravt.task = MovingTask(
            destination: GameLocation.poi(loc.poi.id),
            durationInSeconds: travelSeconds,
            startTime: now,
            followUpAssignment: type,
            followUpPoiId: loc.poi.id,
            followUpAreaId: loc.area.id,
            option: option,
          );
        } else {
          aravt.task = AssignedTask(
              poiId: loc.poi.id,
              areaId: loc.area.id,
              assignment: type,
              option: option,
              durationInSeconds: 86400,
              startTime: now);
        }
        print("AI Filler ($leaderName): Assigned ${aravt.id} to ${type.name}");
        return true;
      }
      return false;
    }

    int turn = gameState.turn.turnNumber;

    if (turn <= 11 && horde.id == 'player_horde') {
      // Shepherding: Max twice in first 7 turns (approx turns 2 and 5)
      bool isShepherdingDay = (turn == 1 || turn == 2 || turn == 5);
      bool alreadyShepherding = (horde.id == 'player_horde'
              ? gameState.aravts
              : (horde.id == 'npc_horde_1'
                  ? gameState.npcAravts1
                  : gameState.npcAravts2))
          .any((a) => a.currentAssignment == AravtAssignment.Shepherd);

      if (isShepherdingDay &&
          !shepherdAssignedToday &&
          !alreadyShepherding &&
          (gameState.communalCattle.lastGrazedTurn < 0 ||
              gameState.communalCattle.lastGrazedTurn < turn - 1)) {
        if (tryAssign(AravtAssignment.Shepherd)) return true;
      }

      List<AravtAssignment> ecoTasks = [
        AravtAssignment.Hunt,
        AravtAssignment.Fish,
        AravtAssignment.ChopWood,
        AravtAssignment.Mine,
        AravtAssignment.FletchArrows,
        AravtAssignment.Train,
        AravtAssignment.Train,
      ];
      ecoTasks.shuffle(_random);

      for (var task in ecoTasks) {
        String? option;
        if (task == AravtAssignment.FletchArrows) {
          option = _random.nextBool() ? 'short' : 'long';
        } else if (task == AravtAssignment.Train) {
          final captain = gameState.findSoldierById(aravt.captainId);
          if (captain != null) {
            int bestSkill = 0; // Default
            // Simple logic to pick skill based on attributes or random
            // For now, just pick random or default
            option = "Archery"; // Default
            if (captain.strength > 6) option = "Swordplay";
            if (captain.horsemanship > 6) option = "Horsemanship";
          }
        }
        if (tryAssign(task, option: option)) return true;
      }

      var scoutArea = _findNearestUnexploredArea(horde, gameState);
      if (scoutArea != null) {
        // Find a POI in that area to travel to, or just travel to area center if supported
        PointOfInterest? entryPoi;
        try {
          entryPoi =
              scoutArea.pointsOfInterest.firstWhere((p) => p.isDiscovered);
        } catch (e) {
          if (scoutArea.pointsOfInterest.isNotEmpty) {
            entryPoi = scoutArea.pointsOfInterest.first;
          }
        }

        HexCoordinates? startCoords = aravt.hexCoords;
        HexCoordinates? endCoords = entryPoi?.position ?? scoutArea.coordinates;

        if (startCoords != null && startCoords != endCoords) {
          int distance = startCoords.distanceTo(endCoords);
          double travelSeconds = max(86400.0, distance * 86400.0);
          aravt.task = MovingTask(
            destination: entryPoi != null
                ? GameLocation.poi(entryPoi.id)
                : GameLocation.area(scoutArea.id),
            durationInSeconds: travelSeconds,
            startTime: now,
            followUpAssignment: AravtAssignment.Scout,
            followUpAreaId: scoutArea.id,
            followUpPoiId: entryPoi?.id,
          );
        } else {
          aravt.task = AssignedTask(
              areaId: scoutArea.id,
              assignment: AravtAssignment.Scout,
              durationInSeconds: 7200,
              startTime: now);
        }
        print(
            "AI Filler ($leaderName): Week 1 fallback -> Scout ${scoutArea.name}");
        return true;
      }

      // Fallback 2: Patrol Camp
      var camp = _findHordeCamp(horde, gameState);
      if (camp != null) {
        aravt.task = AssignedTask(
            areaId: camp.area.id,
            assignment: AravtAssignment.Patrol,
            durationInSeconds: 7200,
            startTime: now);
        print("AI Filler ($leaderName): Week 1 fallback -> Patrol Camp Area");
        return true;
      }
    } else {
      if (turn > 11) {
        var scoutArea = _findNearestUnexploredArea(horde, gameState);
        if (scoutArea != null && _random.nextDouble() < 0.5) {
          // Handle travel for Scout
          PointOfInterest? entryPoi;
          try {
            entryPoi =
                scoutArea.pointsOfInterest.firstWhere((p) => p.isDiscovered);
          } catch (e) {
            if (scoutArea.pointsOfInterest.isNotEmpty) {
              entryPoi = scoutArea.pointsOfInterest.first;
            }
          }

          HexCoordinates? startCoords = aravt.hexCoords;
          HexCoordinates? endCoords =
              entryPoi?.position ?? scoutArea.coordinates;

          if (startCoords != null && startCoords != endCoords) {
            int distance = startCoords.distanceTo(endCoords);
            double travelSeconds = max(86400.0, distance * 86400.0);
            aravt.task = MovingTask(
              destination: entryPoi != null
                  ? GameLocation.poi(entryPoi.id)
                  : GameLocation.area(scoutArea.id),
              durationInSeconds: travelSeconds,
              startTime: now,
              followUpAssignment: AravtAssignment.Scout,
              followUpAreaId: scoutArea.id,
              followUpPoiId: entryPoi?.id,
            );
          } else {
            aravt.task = AssignedTask(
                areaId: scoutArea.id,
                assignment: AravtAssignment.Scout,
                durationInSeconds: 7200,
                startTime: now);
          }
          return true;
        }
      }

      List<AravtAssignment> otherTasks = [
        AravtAssignment.Patrol,
        AravtAssignment.Hunt,
        AravtAssignment.Train,
        AravtAssignment.FletchArrows,
      ];
      otherTasks.shuffle(_random);
      for (var task in otherTasks) {
        String? option;
        if (task == AravtAssignment.FletchArrows) {
          option = _random.nextBool() ? 'short' : 'long';
        } else if (task == AravtAssignment.Train) {
          final captain = gameState.findSoldierById(aravt.captainId);
          if (captain != null) {
            option = "Archery"; // Default
            if (captain.strength > 6) option = "Swordplay";
            if (captain.horsemanship > 6) option = "Horsemanship";
          }
        }
        if (tryAssign(task, option: option)) return true;
      }
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
        if (s.exhaustion > 7 || s.bodyHealthCurrent < s.bodyHealthMax * 0.5) {
          print(
              "AI DEBUG: ${aravt.id} needs rest due to soldier ${s.name} (Exh: ${s.exhaustion}, HP: ${s.bodyHealthCurrent}/${s.bodyHealthMax})");
          return true;
        }
      }
    }
    bool needs = memberCount > 0 && (totalExhaustion / memberCount) > 6.0;
    if (needs) {
      print(
          "AI DEBUG: ${aravt.id} needs rest due to average exhaustion ${totalExhaustion / memberCount}");
    }
    return needs;
  }

  List<Aravt> _getAvailableAravts(HordeData horde, GameState gameState) {
    List<Aravt> all = (horde.id == 'player_horde')
        ? gameState.aravts
        : (horde.id == 'npc_horde_1'
            ? gameState.npcAravts1
            : gameState.npcAravts2);

    final active = gameState.activeTournament;

    if (horde.id == 'player_horde') {
      int total = all.length;
      int available = 0;
      int excludedByTournament = 0;
      int excludedByTask = 0;

      for (var a in all) {
        if (active != null && active.participatingAravts.contains(a)) {
          excludedByTournament++;
        } else if (a.task != null &&
            (a.task is! AssignedTask ||
                (a.task as AssignedTask).assignment != AravtAssignment.Rest)) {
          excludedByTask++;
        } else {
          available++;
        }
      }
      print(
          "AI DEBUG: Player Horde Availability - Total: $total, Available: $available, ExcludedByTournament: $excludedByTournament, ExcludedByTask: $excludedByTask");
    }

    return all.where((a) {
      // 1. Check for active tournament participation
      if (active != null && active.participatingAravts.contains(a)) {
        return false;
      }
      // 2. Check if already assigned (but allow Rest)
      if (a.task == null) return true;
      if (a.task is AssignedTask &&
          (a.task as AssignedTask).assignment == AravtAssignment.Rest)
        return true;
      return false;
    }).toList()
      ..shuffle(_random);
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
    if (assignment == AravtAssignment.Train) {
      return _findHordeCamp(horde, gameState);
    }

    List<_PoiLocation> candidates = [];
    // bool isNpc = horde.id != 'player_horde'; // Unused

    for (var area in gameState.worldMap.values) {
      // Check exploration for this specific horde
      bool isAreaExplored = area.exploredByHordeIds.contains(horde.id);
      if (!isAreaExplored && !gameState.isOmniscientMode) continue;

      for (var poi in area.pointsOfInterest) {
        if (!poi.isDiscovered && !gameState.isOmniscientMode) {
          continue;
        }

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

    final exploredCoords = gameState.worldMap.values
        .where((a) => a.exploredByHordeIds.contains(horde.id))
        .map((a) => a.coordinates)
        .toSet();

    List<GameArea> unexplored = gameState.worldMap.values
        .where((a) => !a.exploredByHordeIds.contains(horde.id))
        .toList();

    if (unexplored.isEmpty) return null;

    // Filter for adjacency to explored space
    List<GameArea> frontier = unexplored.where((u) {
      for (var neighbor in u.coordinates.getNeighbors()) {
        if (exploredCoords.contains(neighbor)) return true;
      }
      return false;
    }).toList();

    // If we have a frontier, only consider those. Otherwise (e.g. start of game or island), consider all.
    final candidates = frontier.isNotEmpty ? frontier : unexplored;

    candidates.sort((a, b) => a.coordinates
        .distanceTo(camp.area.coordinates)
        .compareTo(b.coordinates.distanceTo(camp.area.coordinates)));

    return candidates.first;
  }
}

class _PoiLocation {
  final PointOfInterest poi;
  final GameArea area;
  _PoiLocation(this.poi, this.area);
}
