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
import 'package:flutter/material.dart';
import 'package:aravt/services/auto_resolve_service.dart';
import 'package:aravt/services/combat_service.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/combat_flow_state.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/settlement_data.dart';
import 'package:aravt/models/location_data.dart';
import 'package:aravt/models/combat_models.dart'; // For TerrainType
import 'package:aravt/services/hunting_service.dart';
import 'package:aravt/services/fishing_service.dart';
import 'package:aravt/services/shepherding_service.dart';
import 'package:aravt/services/resource_service.dart';
import 'package:aravt/services/crafting_service.dart';
import 'package:aravt/services/training_service.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/trade_report.dart';

class AravtAssignmentService {
  final Random _random = Random();
  final AutoResolveService _autoResolveService = AutoResolveService();
  final HuntingService _huntingService = HuntingService();
  final FishingService _fishingService = FishingService();
  final ShepherdingService _shepherdingService = ShepherdingService();
  final ResourceService _resourceService = ResourceService();
  final CraftingService _craftingService = CraftingService();
  final TrainingService _trainingService = TrainingService();

  Future<void> resolveAravtAssignments(GameState gameState) async {
    DateTime currentTime = gameState.gameDate.toDateTime();

    // Migration: If time is midnight, move to 9pm of the same day (since we want turns to end at 9pm)
    if (currentTime.hour == 0 && currentTime.minute == 0) {
      currentTime =
          DateTime(currentTime.year, currentTime.month, currentTime.day, 21);
    }

    // Capture actual time for checks that shouldn't use the "next day" logic
    final DateTime actualCurrentTime = currentTime;

    // Advance time by 1 day for checking completion
    currentTime = currentTime.add(const Duration(days: 1));

    PointOfInterest? playerCamp;
    for (final area in gameState.worldMap.values) {
      try {
        playerCamp =
            area.pointsOfInterest.firstWhere((p) => p.id == 'camp-player');
        break;
      } catch (e) {
        // Ignore if not found in this area
      }
    }

    // --- Scripted Triggers ---
    if (gameState.combatFlowState == CombatFlowState.none) {
      _checkNorthernPasturesTrigger(gameState);
    }

    final List<Aravt> allAravts = [
      ...gameState.aravts,
      ...gameState.npcAravts1,
      ...gameState.npcAravts2,
    ];

    // This was duplicative and causing indefinite resting.
    // Tournament participation is now handled dynamically by HordeAIService and TournamentService.

    for (final aravt in allAravts) {
      final List<Soldier> soldiers = aravt.soldierIds
          .map((id) => gameState.findSoldierById(id))
          .whereType<Soldier>()
          .toList();

      final AravtTask? currentTask = aravt.task;

      // Cleanup empty aravts
      if (soldiers.isEmpty && currentTask != null) {
        aravt.task = null;
        continue;
      }

      // Idle aravts rest
      if (currentTask == null) {
        // Check if away from camp
        bool atCamp = false;
        if (playerCamp != null && aravt.hexCoords == playerCamp.position) {
          atCamp = true;
        }

        if (!atCamp && playerCamp != null && gameState.aravts.contains(aravt)) {
          // Auto-return to camp if player aravt is idle away from home
          int distance = aravt.hexCoords.distanceTo(playerCamp.position);
          double travelSeconds = distance * 86400.0;
          aravt.task = MovingTask(
            destination: GameLocation.poi(playerCamp.id),
            durationInSeconds: travelSeconds,
            startTime: actualCurrentTime,
            followUpAssignment: AravtAssignment.Rest,
          );
          continue;
        }

        if (soldiers.isNotEmpty) {
          await _resolveResting(aravt, soldiers, gameState);
        }
        continue;
      }

      // Process Active Tasks
      if (currentTask.isCompleted(currentTime)) {
        if (currentTask is AssignedTask) {
          await _processAssignedTask(
              aravt, soldiers, currentTask, gameState, currentTime, playerCamp);
        } else if (currentTask is MovingTask) {
          await _processMovingTask(aravt, currentTask, gameState, currentTime);
        } else if (currentTask is TradeTask) {
          // Trade Task IS a wrapper for movement + action.
          // It passes completion if start + duration < now
          // BUT we need to check if movement is actually done or if we just arrived?
          // 'expectedEndTime' of TradeTask delegates to movement.expectedEndTime.
          // So if checks passes, movement IS done.

          // Double check we are AT the location?
          if (currentTask.targetPoiId == aravt.currentLocationId ||
              (aravt.task as TradeTask).movement.isCompleted(currentTime)) {
            await _resolveTrade(aravt, currentTask, gameState);
          }
        } else if (currentTask is EmissaryTask) {
          if (currentTask.targetPoiId == aravt.currentLocationId ||
              (aravt.task as EmissaryTask).movement.isCompleted(currentTime)) {
            await _resolveEmissary(aravt, currentTask, gameState);
          }
        }
      } else {
        print(
            "DEBUG: Task NOT completed for ${aravt.id}. End: ${currentTask.expectedEndTime}, Now: $currentTime");
        if (currentTask is TradeTask) {
          await _processOngoingMovement(aravt, currentTask.movement, gameState);
        } else if (currentTask is EmissaryTask) {
          await _processOngoingMovement(aravt, currentTask.movement, gameState);
        } else if (currentTask is MovingTask) {
          await _processOngoingMovement(aravt, currentTask, gameState);
        }
      }
    }
    // Small delay to allow UI to breathe between turn processing steps
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // --- Task Processors ---

  Future<void> _processAssignedTask(
      Aravt aravt,
      List<Soldier> soldiers,
      AssignedTask currentTask,
      GameState gameState,
      DateTime currentTime,
      PointOfInterest? playerCamp) async {
    PointOfInterest? poi;
    if (currentTask.poiId != null) {
      poi = gameState.findPoiByIdWorld(currentTask.poiId!);
    }
    GameArea? area;
    if (currentTask.areaId != null) {
      area = gameState.worldMap[currentTask.areaId];
      // Fallback: Search by ID if key lookup fails
      if (area == null) {
        try {
          area = gameState.worldMap.values
              .firstWhere((a) => a.id == currentTask.areaId);
        } catch (e) {
          // Area not found
        }
      }
    }

    // Determine Terrain for Hunting/Fishing
    TerrainType terrain = TerrainType.plains; // Default
    if (poi != null) {
      // Find area containing POI to get terrain
      for (final area in gameState.worldMap.values) {
        if (area.pointsOfInterest.contains(poi)) {
          // Map string to enum
          final terrainString = area.terrain.toLowerCase();
          if (terrainString.contains('plain') ||
              terrainString.contains('steppe') ||
              terrainString.contains('tundra') ||
              terrainString.contains('desert')) {
            terrain = TerrainType.plains;
          } else if (terrainString.contains('forest') ||
              terrainString.contains('wood')) {
            terrain = TerrainType.trees;
          } else if (terrainString.contains('mountain') ||
              terrainString.contains('rock')) {
            terrain = TerrainType.rocks;
          } else if (terrainString.contains('lake') ||
              terrainString.contains('ocean')) {
            terrain = TerrainType.waterDeep;
          } else if (terrainString.contains('river') ||
              terrainString.contains('swamp') ||
              terrainString.contains('creek')) {
            terrain = TerrainType.waterShallow;
          } else if (terrainString.contains('hill')) {
            terrain = TerrainType.hills;
          } else {
            terrain = TerrainType.plains;
          }
          break;
        }
      }
    }

    switch (currentTask.assignment) {
      case AravtAssignment.Scout:
        try {
          await _resolveScouting(aravt, soldiers, poi, area, gameState);
        } catch (e) {
          // Error handling
        }
      // break;
      case AravtAssignment.Patrol:
        try {
          await _resolvePatrolling(aravt, soldiers, poi, area, gameState);
        } catch (e) {
          // Error handling
        }
      // break;
      case AravtAssignment.Attack:
        try {
          await _resolveAttack(aravt, soldiers, poi, gameState);
        } catch (e) {
          // Error handling
        }
      // break;
      case AravtAssignment.Mine:
        if (poi != null) {
          final report = await _resourceService.resolveMiningDetailed(
              aravt: aravt, poi: poi, gameState: gameState);
          gameState.resourceReports.add(report);
          gameState.addCommunalIronOre(report.totalGathered);
        }
      // break;
      case AravtAssignment.Hunt:
        final report = await _huntingService.resolveHuntingTrip(
          aravt: aravt,
          terrain: terrain,
          locationName: poi?.name ?? "Unknown",
          date: gameState.gameDate,
          gameState: gameState,
        );
        gameState.huntingReports.add(report);
      // break;
      case AravtAssignment.Fish:
        final report = await _fishingService.resolveFishingTrip(
          aravt: aravt,
          terrain: terrain,
          locationName: poi?.name ?? "Unknown",
          date: gameState.gameDate,
          gameState: gameState,
        );
        gameState.fishingReports.add(report);
      // break;
      case AravtAssignment.Shepherd:
        final report = await _shepherdingService.resolveShepherding(
          aravt: aravt,
          herd: gameState.communalCattle,
          gameState: gameState,
        );
        gameState.shepherdingReports.add(report);
      // break;
      case AravtAssignment.ChopWood:
        if (poi != null) {
          final report = await _resourceService.resolveWoodcuttingDetailed(
              aravt: aravt, poi: poi, gameState: gameState);
          gameState.resourceReports.add(report);
          gameState.addCommunalWood(report.totalGathered);
        }
      // break;
      case AravtAssignment.FletchArrows:
        final fletchReport = await _craftingService.resolveFletching(
          aravt: aravt,
          gameState: gameState,
          isLongArrows: currentTask.option == 'long',
        );
        gameState.addFletchingReport(fletchReport);
      // break;
      case AravtAssignment.Train:
        await _trainingService.resolveTraining(
            aravt: aravt, gameState: gameState);
      // break;
      case AravtAssignment.Defend:
        // Defend is now a 1-day at-camp task, similar to Fletch/Train
        break;
      case AravtAssignment.GuardPrisoners:
        await _resolveGuardingPrisoners(aravt, soldiers, gameState);
      // break;
      case AravtAssignment.CareForWounded:
        await _resolveCaringForWounded(aravt, soldiers, gameState);
      // break;
      case AravtAssignment.Travel:
        break;
      case AravtAssignment.Pack:
        await _resolvePack(aravt, gameState);
      default:
        break;
    }

    if (gameState.combatFlowState != CombatFlowState.none) return;

    if (currentTask.assignment == AravtAssignment.Rest) {
      // Ensure they stay resting if that's what they are doing
      return;
    }

    // All assignments now trigger return logic after completion.

    if (poi != null) {
      poi.assignedAravtIds.remove(aravt.id);
    }
    // Determine home camp based on horde
    String campId = 'camp-player';
    if (gameState.npcAravts1.any((a) => a.id == aravt.id)) {
      campId = 'camp-npc1';
    } else if (gameState.npcAravts2.any((a) => a.id == aravt.id)) {
      campId = 'camp-npc2';
    }

    PointOfInterest? homeCamp;
    // Try to find the camp POI
    for (final area in gameState.worldMap.values) {
      try {
        homeCamp = area.pointsOfInterest.firstWhere((p) => p.id == campId);
        break; // Found it
      } catch (e) {
        // Not in this area
      }
    }

    if (homeCamp != null) {
      // Create return task
      int distance = aravt.hexCoords.distanceTo(homeCamp.position);

      if (distance == 0) {
        if (aravt.persistentAssignment != null &&
            // Don't renew if we just finished a one-off task that happened to match persistent (edge case)
            // Actually, if persistent is set, we SHOULD renew.
            // Exception: If the task logic itself cleared it (like Pack did above).
            true) {
          aravt.task = AssignedTask(
            areaId: aravt.currentLocationType == LocationType.area
                ? aravt.currentLocationId
                : null,
            poiId: aravt.currentLocationType == LocationType.poi
                ? aravt.currentLocationId
                : null,
            assignment: aravt.persistentAssignment!,
            durationInSeconds: 86400,
            startTime: currentTime,
            option: currentTask.option,
          );

          // Log less frequently for continuous tasks? Or just log "continues to..."
          // Maybe omit log to reduce spam, or use debug log?
          // "Continues to X" is nice feedback.
          /*
            gameState.logEvent(
              "Your aravt continues to ${aravt.persistentAssignment!.name}.",
              category: EventCategory.general,
              aravtId: aravt.id,
              isPlayerKnown: false, // Too spammy if true?
            );
            */
        } else {
          aravt.task = null;
          gameState.logEvent(
            "Your aravt has finished ${currentTask.assignment.name} and is awaiting orders at camp.",
            category: EventCategory.general,
            aravtId: aravt.id,
            isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
          );
        }
      } else {
        double travelSeconds = distance * 86400.0;

        aravt.task = MovingTask(
          destination: GameLocation(id: homeCamp.id, type: LocationType.poi),
          durationInSeconds: travelSeconds,
          startTime: gameState.currentDate?.toDateTime() ?? DateTime.now(),
          followUpAssignment: aravt.persistentAssignment,
          option: currentTask.option,
        );

        gameState.logEvent(
          "Your aravt has finished ${aravt.persistentAssignment?.name ?? 'task'} and is returning to camp.",
          category: EventCategory.travel,
          aravtId: aravt.id,
          isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
        );
      }
    } else {
      // Fallback if camp not found
      aravt.task = null;
      gameState.logEvent(
        "Your aravt has finished ${aravt.persistentAssignment?.name ?? 'task'} but cannot find the way home.",
        category: EventCategory.general,
        aravtId: aravt.id,
        isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
      );
    }

    // Random Encounter during travel (Lower chance)
    // Random Encounter logic removed from here as it relies on travel context
    // and destPoi which is not available in AssignedTask processing.
  }

  Future<void> _processMovingTask(Aravt aravt, MovingTask currentTask,
      GameState gameState, DateTime currentTime) async {
    // Arrival Logic
    aravt.currentLocationType = currentTask.destination.type;
    aravt.currentLocationId = currentTask.destination.id;

    PointOfInterest? destPoi;
    if (currentTask.destination.type == LocationType.poi) {
      destPoi = gameState.findPoiByIdWorld(currentTask.destination.id);
      if (destPoi != null) aravt.hexCoords = destPoi.position;
    } else if (currentTask.destination.type == LocationType.settlement) {
      final settlement =
          gameState.findSettlementById(currentTask.destination.id);
      if (settlement != null) {
        final poi = gameState.findPoiByIdWorld(settlement.poiId);
        if (poi != null) aravt.hexCoords = poi.position;
      }
    }

    // Handle Follow-up Assignments
    if (currentTask.followUpAssignment != null) {
      GameArea? followUpArea;
      if (currentTask.followUpAreaId != null) {
        followUpArea = gameState.worldMap[currentTask.followUpAreaId!];
      }
      // Try to find area based on POI if area ID wasn't explicit
      if (followUpArea == null && destPoi != null) {
        for (var area in gameState.worldMap.values) {
          if (area.pointsOfInterest.contains(destPoi)) {
            followUpArea = area;
            break;
          }
        }
      }
      // Fallback to current hex
      if (followUpArea == null) {
        for (var area in gameState.worldMap.values) {
          if (area.coordinates == aravt.hexCoords) {
            followUpArea = area;
            break;
          }
        }
      }

      aravt.task = AssignedTask(
        areaId: followUpArea?.id,
        poiId: currentTask.followUpPoiId,
        assignment: currentTask.followUpAssignment!,
        durationInSeconds: 32400, // 9 hours for follow-up
        startTime: currentTime,
        option: currentTask.option,
      );

      // Register at POI if applicable
      if (currentTask.followUpPoiId != null) {
        final poi = gameState.findPoiByIdWorld(currentTask.followUpPoiId!);
        if (poi != null && !poi.assignedAravtIds.contains(aravt.id)) {
          poi.assignedAravtIds.add(aravt.id);
        }
      }

      gameState.logEvent(
        "Your aravt has arrived and begun to ${currentTask.followUpAssignment!.name}.",
        category: EventCategory.general,
        aravtId: aravt.id,
        isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
      );
    } else if (aravt.persistentAssignment != null &&
        aravt.persistentAssignment != AravtAssignment.Travel &&
        aravt.persistentAssignment != AravtAssignment.Rest) {
      // Fallback to persistent assignment
      GameArea? followUpArea;
      if (aravt.persistentAssignmentLocationId != null) {
        followUpArea =
            gameState.worldMap[aravt.persistentAssignmentLocationId!];
      }
      // Try to find area based on POI if area ID wasn't explicit
      if (followUpArea == null && destPoi != null) {
        for (var area in gameState.worldMap.values) {
          if (area.pointsOfInterest.contains(destPoi)) {
            followUpArea = area;
            break;
          }
        }
      }
      // Fallback to current hex
      if (followUpArea == null) {
        for (var area in gameState.worldMap.values) {
          if (area.coordinates == aravt.hexCoords) {
            followUpArea = area;
            break;
          }
        }
      }

      String? option;
      if (aravt.persistentAssignment == AravtAssignment.Train) {
        final captain = gameState.findSoldierById(aravt.captainId);
        if (captain != null) {
          int skillType = TrainingService.getTrainingSkillType(captain);
          option = TrainingService.getTrainingName(skillType);
        }
      }

      aravt.task = AssignedTask(
        areaId: followUpArea?.id,
        poiId: aravt.persistentAssignmentLocationId,
        assignment: aravt.persistentAssignment!,
        durationInSeconds: 32400, // 9 hours for follow-up
        startTime: currentTime,
        option: option,
      );

      // Register at POI if applicable
      if (aravt.persistentAssignmentLocationId != null) {
        final poi =
            gameState.findPoiByIdWorld(aravt.persistentAssignmentLocationId!);
        if (poi != null && !poi.assignedAravtIds.contains(aravt.id)) {
          poi.assignedAravtIds.add(aravt.id);
        }
      }

      gameState.logEvent(
        "Your aravt has arrived and begun to ${aravt.persistentAssignment!.name} (Fallback).",
        category: EventCategory.general,
        aravtId: aravt.id,
        isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
      );
    } else {
      aravt.task = null;
      gameState.logEvent(
        "Your aravt has arrived at its destination.",
        category: EventCategory.travel,
        aravtId: aravt.id,
        isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id),
      );
    }

    // Random Encounter during travel (Lower chance)
    if (_random.nextDouble() < 0.1) {
      // 10% chance per travel leg
      _triggerRandomEncounter(
          aravt,
          aravt.soldierIds
              .map((id) => gameState.findSoldierById(id))
              .whereType<Soldier>()
              .toList(),
          gameState,
          destPoi);
    }
  }

  Future<void> _processOngoingMovement(
      Aravt aravt, MovingTask task, GameState gameState) async {
    // if (aravt.hexCoords == null) return;

    // Calculate path if not already doing so (simple interpolation for now)
    // In a real pathfinding system, we'd follow a list of nodes.
    // Here, we'll just move 1 tile closer to destination if distance > 1.

    HexCoordinates? targetCoords;
    if (task.destination.type == LocationType.poi) {
      final poi = gameState.findPoiByIdWorld(task.destination.id);
      targetCoords = poi?.position;
    } else if (task.destination.type == LocationType.settlement) {
      final settlement = gameState.findSettlementById(task.destination.id);
      if (settlement != null) {
        final poi = gameState.findPoiByIdWorld(settlement.poiId);
        targetCoords = poi?.position;
      }
    }

    if (targetCoords != null && aravt.hexCoords != targetCoords) {
      final int distance = aravt.hexCoords.distanceTo(targetCoords);
      if (distance > 0) {
        // Move 1 step closer
        // Simple algorithm: Find neighbor with min distance to target
        HexCoordinates bestNeighbor = aravt.hexCoords;
        int minDist = distance;

        for (var neighbor in aravt.hexCoords.getNeighbors()) {
          final d = neighbor.distanceTo(targetCoords);
          if (d < minDist) {
            minDist = d;
            bestNeighbor = neighbor;
          }
        }

        if (bestNeighbor != aravt.hexCoords) {
          aravt.hexCoords = bestNeighbor;
        }
      }
    }
  }

  // --- Assignment Resolvers ---

  Future<void> _resolveScouting(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameArea? area, GameState gameState) async {
    // Scouting logic...
    if (poi == null && area == null) return;

    // 1. Mark Area as Explored
    GameArea? targetArea = area;
    if (targetArea == null && poi != null) {
      for (final a in gameState.worldMap.values) {
        if (a.pointsOfInterest.any((p) => p.id == poi.id)) {
          targetArea = a;
          break;
        }
      }
    }
    // Fallback to current location if still null
    if (targetArea == null) {
      for (final a in gameState.worldMap.values) {
        if (a.coordinates == aravt.hexCoords) {
          targetArea = a;
          break;
        }
      }
    }

    if (targetArea != null) {
      // Determine which horde this Aravt belongs to
      String hordeId = 'player_horde'; // Default
      if (gameState.npcAravts1.any((a) => a.id == aravt.id)) {
        hordeId = 'npc_horde_1';
      } else if (gameState.npcAravts2.any((a) => a.id == aravt.id)) {
        hordeId = 'npc_horde_2';
      }

      if (!targetArea.exploredByHordeIds.contains(hordeId)) {
        targetArea.exploredByHordeIds.add(hordeId);

        // Only log for player if it's the player's horde exploring
        if (hordeId == 'player_horde') {
          gameState.logEvent(
              "Area ${targetArea.name} has been explored by ${aravt.id}.",
              category: EventCategory.general,
              aravtId: aravt.id,
              isPlayerKnown: true);
        }
      }

      // 2. Check for NPC Camp Discovery & Combat
      if (hordeId == 'player_horde') {
        await _checkAndTriggerNpcCampDiscovery(aravt, targetArea, gameState);
      }
    }

    if (_random.nextDouble() < 0.3) {
      // 30% chance at destination
      _triggerRandomEncounter(aravt, soldiers, gameState, poi);
    } else {
      final targetName = poi?.name ?? targetArea?.name ?? "Unknown Area";
      gameState.logEvent("${aravt.id} is scouting $targetName.",
          category: EventCategory.general,
          aravtId: aravt.id,
          isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id));
    }
  }

  Future<void> _resolvePatrolling(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameArea? area, GameState gameState) async {
    // Patrolling logic...
    if (poi == null && area == null) return;
    final targetName = poi?.name ?? area?.name ?? "Unknown Area";

    // Check for NPC Camp Discovery & Combat
    GameArea? targetArea = area;
    if (targetArea == null && poi != null) {
      for (final a in gameState.worldMap.values) {
        if (a.pointsOfInterest.any((p) => p.id == poi.id)) {
          targetArea = a;
          break;
        }
      }
    }
    // Fallback to current location
    if (targetArea == null) {
      for (final a in gameState.worldMap.values) {
        if (a.coordinates == aravt.hexCoords) {
          targetArea = a;
          break;
        }
      }
    }

    if (targetArea != null) {
      // Determine horde (Patrol is usually player only, but good to be safe)
      String hordeId = 'player_horde';
      if (gameState.npcAravts1.any((a) => a.id == aravt.id)) {
        hordeId = 'npc_horde_1';
      } else if (gameState.npcAravts2.any((a) => a.id == aravt.id)) {
        hordeId = 'npc_horde_2';
      }

      if (hordeId == 'player_horde') {
        await _checkAndTriggerNpcCampDiscovery(aravt, targetArea, gameState);
      }
    }

    // Check for Planted Encounters
    bool combatTriggered = false;
    for (var soldier in soldiers) {
      final planted = soldier.plantedEncounters
          .where((e) => e.encounterType.startsWith('patrol'))
          .toList();
      if (planted.isNotEmpty) {
        // Trigger Encounter
        final encounter = planted.first;
        _triggerPlantedPatrolEncounter(aravt, encounter, gameState);
        soldier.plantedEncounters.remove(encounter);
        combatTriggered = true;
        break; // One per turn per aravt
      }
    }

    if (!combatTriggered) {
      gameState.logEvent("${aravt.id} is patrolling around $targetName.",
          category: EventCategory.general,
          aravtId: aravt.id,
          isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id));
    }
  }

  void _triggerPlantedPatrolEncounter(
      Aravt playerAravt, PlantedEncounter encounter, GameState gameState) {
    // Generate Bandit Captain first to get ID
    final captain = _createGarrisonSoldier(gameState, isCaptain: true);
    captain.name = "Bandit Leader";
    gameState.garrisonSoldiers.add(captain);

    // Generate Bandits Aravt
    final banditAravt = Aravt(
      id: 'bandits_${playerAravt.id}_${gameState.turn.turnNumber}',
      captainId: captain.id, // Now using int ID
      soldierIds: [captain.id],
      currentLocationType: playerAravt.currentLocationType,
      currentLocationId: playerAravt.currentLocationId,
      hexCoords: playerAravt.hexCoords,
      color: 'red',
    );
    captain.aravt = banditAravt.id;

    // Create remaining random soldiers for bandits
    List<Soldier> bandits = [captain];
    int count = (2 + _random.nextInt(4) * encounter.difficulty)
        .round(); // Reduced base by 1 since captain is separate
    for (int i = 0; i < count; i++) {
      final bandit = _createGarrisonSoldier(gameState, isCaptain: false);
      bandit.name = "Bandit";
      bandit.aravt = banditAravt.id;
      gameState.garrisonSoldiers.add(bandit);
      banditAravt.soldierIds.add(bandit.id);
      bandits.add(bandit);
    }

    gameState.logEvent(
        "While patrolling, ${playerAravt.id} was ambushed by bandits! (Quest Encounter)",
        category: EventCategory.combat,
        severity: EventSeverity.critical,
        aravtId: playerAravt.id);

    // Initiate Combat
    // Note: This relies on manual combat initiation or auto-resolve if flow state is handled
    // For now simple log and "combat" state setting if supported
    // Since initiateCombat expects full lists, and works best if interactive

    // Using initiateCombat if player is involved
    if (gameState.aravts.any((a) => a.id == playerAravt.id)) {
      gameState.initiateCombat(
        playerAravts: [playerAravt],
        opponentAravts: [banditAravt],
        allPlayerSoldiers: gameState.horde,
        allOpponentSoldiers: bandits,
      );
    } else {
      // Auto resolve for NPCs
      // ...
    }
  }

  Future<void> _resolvePack(Aravt aravt, GameState gameState) async {
    // 1. Calculate contribution
    int total = gameState.aravts.length;
    int packingCount = gameState.aravts
        .where((a) => a.currentAssignment == AravtAssignment.Pack)
        .length;

    double contribution;
    // Rule: "if at least half of all the player's aravts (rounded up) are assigned... it only takes one turn."
    // One turn = 1.0 progress total.
    if (packingCount >= (total / 2.0).ceil()) {
      contribution = 1.0 / packingCount;
    } else {
      // Otherwise proportional (e.g. 1/10th of aravts = 1/10th speed = 10 turns)
      contribution = 1.0 / total;
    }

    gameState.updatePackingProgress(gameState.packingProgress + contribution);

    if (gameState.isCaravanMode) {
      // Just finished!
      gameState.logEvent(
        "The camp has been packed! Your horde is now a caravan.",
        category: EventCategory.general,
        severity: EventSeverity.high,
      );

      // Stop all packing assignments
      for (var a in gameState.aravts) {
        if (a.persistentAssignment == AravtAssignment.Pack) {
          a.persistentAssignment = null;
        }
        if (a.task is AssignedTask &&
            (a.task as AssignedTask).assignment == AravtAssignment.Pack) {
          a.task = null; // Cancel current pack tasks
        }
      }
    }
  }

  Future<void> _resolveAttack(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameState gameState) async {
    if (poi == null) return;

    // 1. Check for Settlement
    final settlement = gameState.settlements.firstWhere(
      (s) => s.poiId == poi.id,
      orElse: () => Settlement(
        id: 'temp',
        poiId: poi.id,
        name: 'Unknown',
        leaderSoldierId: 'unknown', // Required field
      ),
    );

    if (settlement.id == 'temp') return; // Nothing to attack

    // 2. Generate Garrison if needed
    if (settlement.garrisonAravtIds.isEmpty &&
        !settlement.hasGeneratedGarrison) {
      _generateGarrison(settlement, gameState);
    }

    // 3. Identify Defenders
    List<Aravt> defenderAravts = [];
    List<Soldier> defenderSoldiers = [];

    // Check if we have garrison soldiers in GameState
    if (gameState.garrisonAravts.isNotEmpty) {
      // Filter for THIS settlement's garrison
      defenderAravts = gameState.garrisonAravts
          .where((a) => settlement.garrisonAravtIds.contains(a.id))
          .toList();

      for (var aravt in defenderAravts) {
        defenderSoldiers.addAll(gameState.garrisonSoldiers
            .where((s) => aravt.soldierIds.contains(s.id)));
      }
    }

    // 4. Trigger Combat
    // If player is attacking, we want interactive combat
    if (gameState.aravts.any((a) => a.id == aravt.id)) {
      if (defenderAravts.isNotEmpty) {
        // Check if combat already triggered for this settlement this turn
        // We can check if any of the defenders are already in combat
        // But better: Gather ALL player aravts attacking this settlement

        // If this aravt is already in combat (e.g. grouped by previous iteration), skip
        // But wait, we are iterating aravts. If we group them now, we need to make sure we don't re-trigger.
        // The loop in resolveAravtAssignments processes each aravt.
        // If we trigger combat now, we should include all other attackers.

        // Find other attackers
        List<Aravt> allAttackers = [aravt];
        for (var other in gameState.aravts) {
          if (other.id == aravt.id) continue;
          if (other.task is AssignedTask) {
            final task = other.task as AssignedTask;
            if (task.assignment == AravtAssignment.Attack &&
                task.poiId == poi.id) {
              allAttackers.add(other);
            }
          }
        }

        // Check if any of these are already in pending/active combat
        bool alreadyInCombat = false;
        if (gameState.combatFlowState != CombatFlowState.none) {
          // Check if any attacker is in the current combat
          // This is tricky because we might be in the middle of the loop.
          // If combat flow is active, we should probably just join it or skip?
          // But initiateCombat checks flow state.
          alreadyInCombat = true;
        }

        if (!alreadyInCombat) {
          gameState.logEvent(
              "You are attacking ${settlement.name}! The garrison sally out to meet you.",
              category: EventCategory.combat,
              severity: EventSeverity.critical,
              aravtId: aravt.id);

          gameState.initiateCombat(
            playerAravts: allAttackers,
            opponentAravts: defenderAravts,
            allPlayerSoldiers: gameState.horde,
            allOpponentSoldiers:
                gameState.garrisonSoldiers, // Pass all garrison soldiers
          );
        }
      } else {
        // Auto-win if no garrison? Or maybe just pillage?
        // If generation failed or population is 0.
        gameState.logEvent(
            "You attacked ${settlement.name} but found no resistance.",
            category: EventCategory.combat,
            severity: EventSeverity.high,
            aravtId: aravt.id);
        // Treat as victory
        gameState.addCommunalMeat(50.0);
        gameState.addCommunalScrap(20.0);

        //  Return to camp after auto-win
        PointOfInterest? playerCamp;
        for (final area in gameState.worldMap.values) {
          try {
            playerCamp =
                area.pointsOfInterest.firstWhere((p) => p.id == 'camp-player');
            break;
          } catch (_) {
            // Ignore
          }
        }

        if (playerCamp != null) {
          int distance = aravt.hexCoords.distanceTo(playerCamp.position);
          double travelSeconds = distance * 86400.0;
          aravt.task = MovingTask(
            destination: GameLocation.poi(playerCamp.id),
            durationInSeconds: travelSeconds,
            startTime: gameState.currentDate?.toDateTime() ?? DateTime.now(),
            followUpAssignment: AravtAssignment.Rest,
          );
        }
      }
    } else {
      // NPC vs NPC or NPC vs Settlement (Auto Resolve)
      final report = _autoResolveService.resolveCombat(
        gameState: gameState,
        attackerAravts: [aravt],
        allAttackerSoldiers: soldiers,
        defenderAravts: defenderAravts,
        allDefenderSoldiers: defenderSoldiers,
      );

      // Apply Results
      if (report.result == CombatResult.playerVictory) {
        // Attacker victory
        // Logic for NPC taking settlement?
      }
    }
  }

  Future<void> _resolveGuardingPrisoners(
      Aravt aravt, List<Soldier> soldiers, GameState gameState) async {
    // Placeholder
  }

  Future<void> _resolveCaringForWounded(
      Aravt aravt, List<Soldier> soldiers, GameState gameState) async {
    // Placeholder
  }

  Future<void> _resolveResting(
      Aravt aravt, List<Soldier> soldiers, GameState gameState) async {
    // Base recovery for resting
    for (var soldier in soldiers) {
      if (soldier.status == SoldierStatus.alive) {
        soldier.exhaustion = (soldier.exhaustion - 20.0).clamp(0.0, 100.0);
        soldier.stress = (soldier.stress - 5.0).clamp(0.0, 100.0);
      }
    }
  }

  // --- Helpers & Triggers ---

  void _checkNorthernPasturesTrigger(GameState gameState) {
    PointOfInterest? northernPastures;
    if (gameState.currentArea != null) {
      try {
        northernPastures = gameState.currentArea!.pointsOfInterest
            .firstWhere((poi) => poi.name == "Northern Pastures");
      } catch (e) {
        northernPastures = null;
      }
    }

    if (northernPastures != null) {
      final List<Aravt> playerPatrol = gameState.aravts
          .where((a) =>
              a.assignmentLocationId == northernPastures!.id &&
              a.currentAssignment == AravtAssignment.Patrol)
          .toList();

      if (playerPatrol.isNotEmpty) {
        final List<Aravt> availableNpcs = List.from(gameState.npcAravts1);
        if (availableNpcs.isNotEmpty) {
          availableNpcs.shuffle(_random);
          final List<Aravt> opponentAravts = availableNpcs.take(3).toList();

          gameState.initiateCombat(
            playerAravts: playerPatrol,
            opponentAravts: opponentAravts,
            allPlayerSoldiers: gameState.horde,
            allOpponentSoldiers: gameState.npcHorde1,
          );
        }
      }
    }
  }

  Future<void> _checkAndTriggerNpcCampDiscovery(
      Aravt aravt, GameArea area, GameState gameState) async {
    // Check if there is an undiscovered NPC camp here
    PointOfInterest? npcCamp;
    String? npcHordeId;
    List<Aravt>? npcAravts;
    List<Soldier>? npcSoldiers;

    for (var p in area.pointsOfInterest) {
      if (p.type == PoiType.camp && p.id != 'camp-player') {
        // Found a non-player camp
        if (p.id == 'camp-npc1') {
          npcHordeId = 'npc_horde_1';
          npcAravts = gameState.npcAravts1;
          npcSoldiers = gameState.npcHorde1;
          npcCamp = p;
        } else if (p.id == 'camp-npc2') {
          npcHordeId = 'npc_horde_2';
          npcAravts = gameState.npcAravts2;
          npcSoldiers = gameState.npcHorde2;
          npcCamp = p;
        }
        break;
      }
    }

    if (npcCamp != null && npcHordeId != null) {
      // Reveal it if not already discovered
      bool wasDiscovered = npcCamp.isDiscovered;
      if (!wasDiscovered) {
        npcCamp.isDiscovered = true;
        gameState.logEvent("You have discovered the ${npcCamp.name}!",
            category: EventCategory.general,
            severity: EventSeverity.high,
            aravtId: aravt.id);
      }

      // Trigger Combat ONLY if it was JUST discovered OR if the player is actively scouting/patrolling it
      if (npcCamp.hasTriggeredDiscoveryCombat) {
        return;
      }

      // Mark as triggered immediately
      npcCamp.hasTriggeredDiscoveryCombat = true;

      // Find ALL player aravts currently scouting/patrolling this area/POI to group them
      List<Aravt> involvedPlayerAravts = [aravt];

      // Look for others
      for (var otherAravt in gameState.aravts) {
        if (otherAravt.id == aravt.id) continue;
        if (otherAravt.task == null) continue;

        // Only consider AssignedTasks (active scouting/patrolling)
        if (otherAravt.task is! AssignedTask) continue;
        final task = otherAravt.task as AssignedTask;

        bool sameLocation = false;
        if (task.areaId == area.id) sameLocation = true;
        if (task.poiId != null &&
            area.pointsOfInterest.any((p) => p.id == task.poiId)) {
          sameLocation = true;
        }

        // Also check if they are physically there (or arriving this turn)
        if (sameLocation &&
            (task.assignment == AravtAssignment.Scout ||
                task.assignment == AravtAssignment.Patrol)) {
          involvedPlayerAravts.add(otherAravt);
        }
      }

      // Trigger Combat
      if (npcAravts != null && npcSoldiers != null && npcAravts.isNotEmpty) {
        // Pick 3 random aravts
        final opponents =
            (List<Aravt>.from(npcAravts)..shuffle(_random)).take(3).toList();

        if (opponents.isNotEmpty) {
          gameState.logEvent(
              "Your scouts have been intercepted by ${npcCamp.name} defenders!",
              category: EventCategory.combat,
              severity: EventSeverity.critical,
              aravtId: aravt.id);

          gameState.initiateCombat(
            playerAravts: involvedPlayerAravts,
            opponentAravts: opponents,
            allPlayerSoldiers: gameState.horde,
            allOpponentSoldiers: npcSoldiers,
          );

          // CRITICAL: Force return to camp for ALL involved aravts so they don't loop or get stuck
          PointOfInterest? playerCamp =
              gameState.findPoiByIdWorld('camp-player');
          if (playerCamp != null) {
            for (var involved in involvedPlayerAravts) {
              int distance = involved.hexCoords.distanceTo(playerCamp.position);
              double travelSeconds = distance * 86400.0;
              involved.task = MovingTask(
                destination: GameLocation.poi(playerCamp.id),
                durationInSeconds: travelSeconds,
                startTime:
                    gameState.currentDate?.toDateTime() ?? DateTime.now(),
                followUpAssignment: AravtAssignment.Rest,
              );
              involved.persistentAssignment = null; // Ensure no persistence
              print(
                  "[SABOTAGE DEBUG] Combat triggered. Forcing ${involved.id} to return to camp.");
            }
          }
        }
      }
    }
  }

  void _triggerRandomEncounter(Aravt aravt, List<Soldier> soldiers,
      GameState gameState, PointOfInterest? poi) {
    final roll = _random.nextDouble();
    if (roll < 0.4) {
      // Positive: Found something
      final items = ["Pelts", "Scrap", "Wild Herbs"];
      final item = items[_random.nextInt(items.length)];
      gameState.logEvent("${aravt.id} found some $item while scouting.",
          category: EventCategory.general,
          aravtId: aravt.id,
          isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id));
      if (item == "Scrap") gameState.addCommunalScrap(5.0);
    } else if (roll < 0.7) {
      // Neutral: Saw something
      gameState.logEvent(
          "${aravt.id} spotted some wild animals in the distance.",
          category: EventCategory.general,
          aravtId: aravt.id,
          isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id));
    } else {
      // Negative: Minor setback
      gameState.logEvent(
          "${aravt.id} encountered some rough terrain, delaying them slightly.",
          category: EventCategory.general,
          aravtId: aravt.id,
          isPlayerKnown: gameState.aravts.any((a) => a.id == aravt.id));
      for (var s in soldiers) {
        s.exhaustion += 10.0;
      }
    }
  }

  // --- Garrison Logic ---

  void _generateGarrison(Settlement settlement, GameState gameState) {
    // print("Generating garrison for ${settlement.name}...");

    int garrisonSize =
        (settlement.peasantPopulation * 0.25).round().clamp(10, 100);
    int numAravts = (garrisonSize / 10).ceil();

    // Find settlement location
    final poi = gameState.findPoiByIdWorld(settlement.poiId);
    final hexCoords = poi?.position ?? HexCoordinates(0, 0);

    for (int i = 0; i < numAravts; i++) {
      String aravtId = "garrison_${settlement.id}_$i";
      List<int> soldierIds = [];

      // Create Captain
      Soldier captain = _createGarrisonSoldier(gameState, isCaptain: true);
      captain.aravt = aravtId;
      gameState.garrisonSoldiers.add(captain);
      soldierIds.add(captain.id);

      // Create Soldiers
      int soldiersInUnit = min(10, garrisonSize - (i * 10));
      for (int j = 0; j < soldiersInUnit - 1; j++) {
        // -1 for captain
        Soldier s = _createGarrisonSoldier(gameState);
        s.aravt = aravtId;
        gameState.garrisonSoldiers.add(s);
        soldierIds.add(s.id);
      }

      Aravt garrisonAravt = Aravt(
        id: aravtId,
        captainId: captain.id,
        soldierIds: soldierIds,
        currentLocationType: LocationType.settlement,
        currentLocationId: settlement.id,
        hexCoords: hexCoords,
        color:
            'purple', // Ensure they use the purple sprite (Spearman supported)
      );

      gameState.garrisonAravts.add(garrisonAravt);
      settlement.garrisonAravtIds.add(aravtId);
    }
    settlement.hasGeneratedGarrison = true; //  Mark as generated
  }

  Soldier _createGarrisonSoldier(GameState gameState,
      {bool isCaptain = false}) {
    int id = gameState.getNextSoldierId();
    int baseStat = isCaptain ? 6 : 3;

    return Soldier(
      id: id,
      name: isCaptain ? "Garrison Captain" : "Garrison Soldier",
      firstName: isCaptain ? "Captain" : "Soldier",
      familyName: "Garrison",
      isPlayer: false,
      role: isCaptain ? SoldierRole.aravtCaptain : SoldierRole.soldier,
      aravt: 'unassigned',
      strength: baseStat + _random.nextInt(4),
      intelligence: baseStat + _random.nextInt(4),
      ambition: baseStat + _random.nextInt(4),
      perception: baseStat + _random.nextInt(4),
      temperament: baseStat + _random.nextInt(4),
      knowledge: baseStat + _random.nextInt(4),
      patience: baseStat + _random.nextInt(4),
      leadership: isCaptain ? 5 + _random.nextInt(5) : 1 + _random.nextInt(3),
      age: 20 + _random.nextInt(20),
      dateOfBirth: DateTime(1120, 1, 1),
      longRangeArcherySkill: (baseStat + _random.nextInt(3)).toDouble(),
      mountedArcherySkill: (baseStat + _random.nextInt(3)).toDouble(),
      spearSkill: (baseStat + _random.nextInt(3)).toDouble(),
      swordSkill: (baseStat + _random.nextInt(3)).toDouble(),
      shieldSkill: (baseStat + _random.nextInt(3)).toDouble(),
      equippedItems: {
        // Ensure they have a spear and NO mount
        EquipmentSlot.spear: Weapon(
          id: 'garrison_spear_$id',
          templateId: 'wep_spear_garrison',
          name: 'Garrison Spear',
          description: 'A standard issue spear for garrison troops.',
          itemType: ItemType.spear,
          valueType: ValueType.Supply,
          baseValue: 10,
          weight: 2.0,
          quality: 'Common',
          iconAssetPath: 'assets/images/items/spear.png',
          spriteIndex: 0,
          slot: EquipmentSlot.spear,
          condition: 100.0,
          maxCondition: 100.0,
          damageType: DamageType.Piercing,
          baseDamage: 5.0,
          effectiveRange: 2.0,
        ),
      },

      // Required fields
      portraitIndex: _random.nextInt(20),
      placeOrTribeOfOrigin: "Local Settlement",
      languages: ["Common"],
      religionType: ReligionType.tengri,
      religionIntensity: ReligionIntensity.normal,
      zodiac: Zodiac.rat,
      backgroundColor: Colors.grey,
      yearsWithHorde: 0,
      height: (170 + _random.nextInt(20)).toDouble(),
      startingInjury: StartingInjuryType.none,
      healthMax: 10,
      exhaustion: 0.0,
      stress: 0.0,
      courage: baseStat + _random.nextInt(4),
      judgment: baseStat + _random.nextInt(4),
      horsemanship: baseStat + _random.nextInt(4),
      animalHandling: baseStat + _random.nextInt(4),
      honesty: baseStat + _random.nextInt(4),
      stamina: baseStat + _random.nextInt(4),
      hygiene: 5.0,
      charisma: baseStat + _random.nextInt(4),
      adaptability: baseStat + _random.nextInt(4),
      experience: isCaptain ? 100 : 10,
      giftOriginPreference: GiftOriginPreference.fromHome,
      giftTypePreference: GiftTypePreference.supplies,
      specialSkills: [],
      attributes: [],
      fungibleScrap: 0.0,
      fungibleRupees: 0.0,
      kilosOfMeat: 0.0,
      kilosOfRice: 0.0,
    );
  }

  // --- Trade & Emissary Resolvers ---

  Future<void> _resolveTrade(
      Aravt aravt, TradeTask task, GameState gameState) async {
    // 1. Move Aravt to destination
    await _processMovingTask(
        aravt, task.movement, gameState, task.expectedEndTime);

    // 2. Execute Trade Logic
    // Calculate Value of Cargo
    double totalValue = 0;
    List<ItemExchange> itemsGiven = [];

    // Items Value
    if (aravt.task is! TradeTask) return; // Safety check
    final TradeTask tradeTask = aravt.task as TradeTask;

    // Group cargo by templateId to create consolidated report items
    final Map<String, List<InventoryItem>> groupedCargo = {};
    for (var item in tradeTask.cargo) {
      groupedCargo.putIfAbsent(item.templateId, () => []).add(item);
    }

    for (var entry in groupedCargo.entries) {
      final items = entry.value;
      final int qty = items.length;
      final firstItem = items.first;

      double valPerItem = 0;
      if (firstItem.valueType == ValueType.Treasure) {
        valPerItem = firstItem.baseValue;
      } else if (firstItem.valueType == ValueType.Supply) {
        valPerItem = firstItem.baseValue * 0.5;
      } else {
        valPerItem = firstItem.baseValue * 0.8;
      }

      final double totalItemVal = valPerItem * qty;
      totalValue += totalItemVal;

      itemsGiven.add(ItemExchange(
          itemTemplateId: firstItem.templateId,
          itemName: firstItem.name,
          quantity: qty,
          value: totalItemVal));
    }

    // Resources Value
    task.resources.forEach((key, amount) {
      double resVal = 0;
      double unitVal = 1.0;
      switch (key) {
        case 'rupees':
          unitVal = 1.0;
        case 'scrap':
          unitVal = 0.5;
        case 'meat':
          unitVal = 2.0;
        case 'wood':
          unitVal = 1.0;
        case 'iron':
          unitVal = 5.0;
        default:
          unitVal = 1.0;
      }
      resVal = amount * unitVal;
      totalValue += resVal;
      itemsGiven.add(ItemExchange(
          itemTemplateId: key,
          itemName: key[0].toUpperCase() + key.substring(1),
          quantity: amount.toInt(),
          value: resVal));
    });

    // Apply Captain's Charisma Bonus
    final captain = gameState.findSoldierById(aravt.captainId);
    double bonus = 0.0;
    if (captain != null) {
      bonus = captain.charisma * 0.05; // 5% per charisma point
      totalValue *= (1.0 + bonus);
    }

    gameState.addCommunalRupees(totalValue);

    // Create Report
    final report = TradeReport(
      date: gameState.gameDate.copy(),
      partnerName:
          "POI ${task.targetPoiId}", // TODO: Get Settlement name if specific
      itemsGiven: itemsGiven,
      itemsReceived: [
        ItemExchange(
          itemTemplateId: 'rupees',
          itemName: 'Rupees',
          quantity: totalValue.toInt(),
          value: totalValue,
        )
      ],
      outcome: TradeOutcome.success,
      notes: bonus > 0 ? "Charisma bonus: +${(bonus * 100).toInt()}%" : "",
    );
    gameState.tradeReports.add(report);
    // Sort reports by date (optional, but good for display)
    // gameState.tradeReports.sort((a, b) => b.date.compareTo(a.date));

    gameState.logEvent(
      "Trade completed at ${task.targetPoiId}. Traded goods for ${totalValue.toInt()} Rupees.",
      category: EventCategory.finance,
      aravtId: aravt.id,
      isPlayerKnown: true,
    );

    // 3. Trigger Return
    _triggerReturnTrip(aravt, gameState);
  }

  Future<void> _resolveEmissary(
      Aravt aravt, EmissaryTask task, GameState gameState) async {
    // 1. Move Aravt
    await _processMovingTask(
        aravt, task.movement, gameState, task.expectedEndTime);

    // 2. Execute Diplomacy
    final termsCount = task.terms.length;

    // Find Settlement
    Settlement? settlement;
    try {
      settlement =
          gameState.settlements.firstWhere((s) => s.poiId == task.targetPoiId);
    } catch (_) {
      // Not a settlement POI or settlement not found
    }

    if (settlement != null) {
      final rel = settlement.getRelationship('Player');
      for (var term in task.terms) {
        switch (term) {
          case DiplomaticTerm.PresentGifts: // (Assuming this matches enum)
            rel.admiration = (rel.admiration + 1.0).clamp(0.0, 10.0);
            rel.respect = (rel.respect + 0.5).clamp(0.0, 10.0);
          case DiplomaticTerm.OfferTradingAlliance:
            rel.respect = (rel.respect + 1.0).clamp(0.0, 10.0);
          case DiplomaticTerm.DemandTribute:
            rel.fear = (rel.fear + 1.0).clamp(0.0, 10.0);
            rel.admiration = (rel.admiration - 2.0).clamp(0.0, 10.0);
          case DiplomaticTerm.OfferTruce:
            rel.respect = (rel.respect + 0.5).clamp(0.0, 10.0);
          default:
            // Small interaction boost
            rel.respect = (rel.respect + 0.1).clamp(0.0, 10.0);
        }
      }
    }

    gameState.logEvent(
      "Emissary mission completed at ${task.targetPoiId}. Presented $termsCount diplomatic terms.",
      category: EventCategory.diplomacy,
      aravtId: aravt.id,
      isPlayerKnown: true,
    );

    // 3. Return
    _triggerReturnTrip(aravt, gameState);
  }

  void _triggerReturnTrip(Aravt aravt, GameState gameState) {
    // Determine home camp
    String campId = 'camp-player';
    if (gameState.npcAravts1.any((a) => a.id == aravt.id)) {
      campId = 'camp-npc1';
    } else if (gameState.npcAravts2.any((a) => a.id == aravt.id)) {
      campId = 'camp-npc2';
    }

    PointOfInterest? homeCamp;
    for (final area in gameState.worldMap.values) {
      try {
        homeCamp = area.pointsOfInterest.firstWhere((p) => p.id == campId);
        break;
      } catch (_) {}
    }

    if (homeCamp != null) {
      int distance = aravt.hexCoords.distanceTo(homeCamp.position);
      if (distance > 0) {
        double travelSeconds = distance * 86400.0;
        aravt.task = MovingTask(
          destination: GameLocation(id: homeCamp.id, type: LocationType.poi),
          durationInSeconds: travelSeconds,
          startTime: gameState.gameDate.toDateTime(),
          followUpAssignment: AravtAssignment.Rest,
        );
      } else {
        aravt.task = null; // Already home
      }
    } else {
      aravt.task = null;
    }
  }
}
