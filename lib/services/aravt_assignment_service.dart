import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/settlement_data.dart';
import 'package:aravt/models/location_data.dart';
import 'package:aravt/models/combat_flow_state.dart';
// Services
import 'package:aravt/services/auto_resolve_service.dart';
import 'package:aravt/services/combat_service.dart';
import 'package:aravt/services/hunting_service.dart';
import 'package:aravt/services/fishing_service.dart';
import 'package:aravt/services/shepherding_service.dart';
import 'package:aravt/services/resource_service.dart';
import 'package:aravt/services/crafting_service.dart';
// Models
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/combat_models.dart';

class AravtAssignmentService {
  final Random _random = Random();
  final AutoResolveService _autoResolveService = AutoResolveService();
  final HuntingService _huntingService = HuntingService();
  final FishingService _fishingService = FishingService();
  final ShepherdingService _shepherdingService = ShepherdingService();
  final ResourceService _resourceService = ResourceService();
  final CraftingService _craftingService = CraftingService();

  Future<void> resolveAravtAssignments(GameState gameState) async {
    final DateTime currentTime =
        gameState.currentDate?.toDateTime() ?? DateTime.now();

    PointOfInterest? playerCamp;
    for (final area in gameState.worldMap.values) {
      try {
        playerCamp =
            area.pointsOfInterest.firstWhere((p) => p.id == 'camp-player');
        break;
      } catch (e) {}
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
        }
      }
    }
    // Small delay to allow UI to breathe between turn processing steps
    await Future.delayed(const Duration(milliseconds: 50));
  }

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
        // print("Player aravts found patrolling Northern Pastures. Triggering combat...");
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

    switch (currentTask.assignment) {
      case AravtAssignment.Scout:
        await _resolveScouting(aravt, soldiers, poi, gameState);
        break;
      case AravtAssignment.Patrol:
        await _resolvePatrolling(aravt, soldiers, poi, gameState);
        break;
      case AravtAssignment.Attack:
        await _resolveAttack(aravt, soldiers, poi, gameState);
        break;
      case AravtAssignment.Mine:
        await _resolveMining(aravt, soldiers, poi, gameState);
        break;
      case AravtAssignment.Hunt:
        await _resolveHunting(aravt, soldiers, poi, gameState);
        break;
      case AravtAssignment.Fish:
        await _resolveFishing(aravt, soldiers, poi, gameState);
        break;
      case AravtAssignment.Shepherd:
        await _resolveShepherding(aravt, soldiers, poi, gameState);
        break;
      case AravtAssignment.ChopWood:
        await _resolveWoodcutting(aravt, soldiers, poi, gameState);
        break;
      case AravtAssignment.FletchArrows:
        await _resolveFletching(aravt, soldiers, gameState);
        break;
      case AravtAssignment.Travel:
        break;
      default:
        break;
    }

    if (gameState.combatFlowState != CombatFlowState.none) return;

    bool isContinuous = currentTask.assignment == AravtAssignment.Defend ||
        currentTask.assignment == AravtAssignment.GuardPrisoners ||
        currentTask.assignment == AravtAssignment.Ambush ||
        currentTask.assignment == AravtAssignment.Patrol ||
        currentTask.assignment == AravtAssignment.Shepherd ||
        currentTask.assignment == AravtAssignment.FletchArrows;

    if (!isContinuous) {
      if (poi != null) {
        poi.assignedAravtIds.remove(aravt.id);
      }
      // Auto-return to camp if it's a player aravt finishing a non-continuous task
      if (gameState.aravts.contains(aravt) && playerCamp != null) {
        aravt.currentLocationType = LocationType.poi;
        aravt.currentLocationId = playerCamp.id;
        aravt.hexCoords = playerCamp.position;
        gameState.logEvent("${aravt.id} has returned to camp.",
            category: EventCategory.travel,
            aravtId: aravt.id,
            severity: EventSeverity.low);
      }
      aravt.task = null;
    } else {
      // Repeat continuous task
      aravt.task = AssignedTask(
        areaId: currentTask.areaId,
        poiId: currentTask.poiId,
        assignment: currentTask.assignment,
        durationInSeconds: currentTask.durationInSeconds,
        startTime: currentTime,
      );
    }
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

    if (gameState.aravts.contains(aravt)) {
      gameState.logEvent("Your aravt has arrived at their destination.",
          category: EventCategory.travel,
          severity: EventSeverity.low,
          aravtId: aravt.id);
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
        followUpArea = gameState.worldMap[aravt.hexCoords.toString()];
      }

      if (followUpArea != null) {
        aravt.hexCoords = followUpArea.coordinates;
        aravt.task = AssignedTask(
          areaId: followUpArea.id,
          poiId: currentTask.followUpPoiId,
          assignment: currentTask.followUpAssignment!,
          durationInSeconds: 7200, // Default 2 hour duration for new tasks
          startTime: currentTime,
        );

        if (gameState.aravts.contains(aravt)) {
          gameState.logEvent(
            "Your aravt has begun to ${currentTask.followUpAssignment!.name} in ${followUpArea.name}.",
            category: EventCategory.general,
            aravtId: aravt.id,
          );
        }
      } else {
        aravt.task = null;
      }
    } else {
      aravt.task = null;
    }
  }

  // --- Resting ---
  Future<void> _resolveResting(
      Aravt aravt, List<Soldier> soldiers, GameState gameState) async {
    int currentTurn = gameState.turn.turnNumber;
    for (var soldier in soldiers) {
      if (soldier.status != SoldierStatus.alive) continue;
      double restQuality = 1.0;
      restQuality -= (soldier.stress / 10.0) * 0.5;
      restQuality += (soldier.temperament - 5) * 0.05;
      restQuality += (_random.nextDouble() * 0.4 - 0.2);

      if (restQuality > 1.2) {
        soldier.exhaustion = (soldier.exhaustion - 3).clamp(0, 10);
        soldier.stress = (soldier.stress - 2).clamp(0, 10);
        if (soldier.bodyHealthCurrent < soldier.bodyHealthMax) {
          soldier.bodyHealthCurrent =
              min(soldier.bodyHealthMax, soldier.bodyHealthCurrent + 1);
        }
        soldier.performanceLog.add(PerformanceEvent(
            turnNumber: currentTurn,
            description: "Restful and rejuvenating sleep.",
            isPositive: true,
            magnitude: 1.5));
      } else if (restQuality < 0.6) {
        soldier.exhaustion = (soldier.exhaustion - 1).clamp(0, 10);
        if (_random.nextBool()) {
          soldier.stress = (soldier.stress + 0.5).clamp(0, 10);
        }
        soldier.performanceLog.add(PerformanceEvent(
            turnNumber: currentTurn,
            description: "Tossed and turned all night.",
            isPositive: false,
            magnitude: 1.0));
      } else {
        soldier.exhaustion = (soldier.exhaustion - 2).clamp(0, 10);
        soldier.stress = (soldier.stress - 1).clamp(0, 10);
      }
      soldier.experience = (soldier.experience - 0.005).clamp(0, 100);
    }
  }

  // --- ATTACK LOGIC ---
  Future<void> _resolveAttack(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameState gameState) async {
    if (poi == null) return;

    // 1. Identify Faction & Allies
    bool isPlayer = gameState.aravts.contains(aravt);
    List<Aravt> factionAravts = isPlayer
        ? gameState.aravts
        : (gameState.npcAravts1.contains(aravt)
            ? gameState.npcAravts1
            : gameState.npcAravts2);

    // 2. Find fellow attackers ALREADY HERE
    List<Aravt> readyAttackers = factionAravts
        .where((a) =>
            a.hexCoords == poi.position &&
            a.task is AssignedTask &&
            (a.task as AssignedTask).assignment == AravtAssignment.Attack &&
            (a.task as AssignedTask).poiId == poi.id)
        .toList();

    // Ensure current aravt is counted even if state lagged slightly
    if (!readyAttackers.contains(aravt)) readyAttackers.add(aravt);

    // Minimum 2 Aravts required to launch the attack
    if (readyAttackers.length < 2) {
      if (isPlayer && readyAttackers.length == 1) {
        gameState.logEvent(
            "${aravt.id} is waiting for reinforcements at ${poi.name} before attacking.",
            category: EventCategory.general, // [GEMINI-FIX] Not actual combat
            aravtId: aravt.id);
      }
      // They wait for the next turn resolution cycle
      return;
    }

    // 3. Identify Defenders
    List<Aravt> defenders = [];
    List<Soldier> defenderPool = [];

    // Check for Settlement Garrison
    Settlement? settlement = _findSettlementAtPoi(poi, gameState);
    if (settlement != null) {
      for (String gId in settlement.garrisonAravtIds) {
        Aravt? g = gameState.findAravtById(gId);
        if (g != null && g.soldierIds.isNotEmpty) {
          defenders.add(g);
        }
      }
      defenderPool = gameState.garrisonSoldiers;
    }

    // Check for NPC Camps (if it's a camp POI and not ours)
    if (poi.type == PoiType.camp && poi.id != 'camp-player') {
      bool isNpc1 = poi.id == 'camp-npc1';
      defenders.addAll(isNpc1 ? gameState.npcAravts1 : gameState.npcAravts2);
      defenderPool = isNpc1 ? gameState.npcHorde1 : gameState.npcHorde2;
      // Only defenders CURRENTLY AT THE CAMP can fight
      defenders = defenders.where((a) => a.hexCoords == poi.position).toList();
    }

    // 4. Execute Battle or Loot
    if (defenders.isEmpty) {
      _handleUncontestedVictory(readyAttackers, poi, gameState);
    } else {
      // If PLAYER is involved (either attacking or defending), use full combat
      bool playerInvolved =
          isPlayer || defenders.any((d) => gameState.aravts.contains(d));

      if (playerInvolved) {
        gameState.initiateCombat(
            playerAravts: isPlayer ? readyAttackers : defenders,
            opponentAravts: isPlayer ? defenders : readyAttackers,
            allPlayerSoldiers: gameState.horde,
            allOpponentSoldiers: defenderPool);
      } else {
        // NPC vs NPC auto-resolve
        _autoResolveService.resolveCombat(
          gameState: gameState,
          attackerAravts: readyAttackers,
          allAttackerSoldiers: _findHordeForAravt(aravt, gameState),
          defenderAravts: defenders,
          allDefenderSoldiers: defenderPool,
        );
      }
    }
  }

  void _handleUncontestedVictory(
      List<Aravt> attackers, PointOfInterest poi, GameState gameState) {
    gameState.logEvent(
        "${poi.name} was undefended! ${attackers.length} aravts pillage the location.",
        category: EventCategory.general,
        severity: EventSeverity.high);

    // Loot logic: Drain resources as generic "Scrap"
    if (poi.currentResources != null && poi.currentResources! > 0) {
      double loot = poi.currentResources!.toDouble();
      // If player was attacking, give them the loot
      if (gameState.aravts.contains(attackers.first)) {
        gameState.addCommunalScrap(loot);
        gameState.logEvent("Looted $loot scrap from ${poi.name}.",
            category: EventCategory.finance);
      }
    }

    // Mark location depleted/destroyed
    gameState.updateLocationResourceLevel(poi.id, 0.0);

    // Return attackers home
    for (var a in attackers) {
      a.task = null;
    }
  }

  Future<void> _resolveHunting(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameState gameState) async {
    String locationName = poi?.name ?? "Wilds";
    TerrainType terrain = TerrainType.plains; // Default

    // Simple terrain inference based on name
    String lowerName = locationName.toLowerCase();
    if (lowerName.contains("wood") || lowerName.contains("forest")) {
      terrain = TerrainType.trees;
    } else if (lowerName.contains("hill") || lowerName.contains("mountain")) {
      terrain = TerrainType.hills;
    } else if (lowerName.contains("river") || lowerName.contains("lake")) {
      terrain = TerrainType.waterShallow;
    }

    final report = await _huntingService.resolveHuntingTrip(
      aravt: aravt,
      terrain: terrain,
      locationName: locationName,
      date: gameState.gameDate,
      gameState: gameState,
    );

    gameState.addHuntingReport(report);

    // Log global event
    bool isPlayerAravt = aravt.soldierIds.contains(gameState.player?.id);
    if (report.totalMeat > 0) {
      gameState.logEvent(
        "${aravt.id} returned from hunting with ${report.totalMeat.toStringAsFixed(1)} kg of meat.",
        category: EventCategory.food,
        severity: isPlayerAravt ? EventSeverity.high : EventSeverity.normal,
        aravtId: aravt.id,
      );
    } else {
      gameState.logEvent(
        "${aravt.id} returned from hunting empty-handed.",
        category: EventCategory.food,
        severity: isPlayerAravt ? EventSeverity.high : EventSeverity.low,
        aravtId: aravt.id,
      );
    }

    // Update individual performance
    int currentTurn = gameState.turn.turnNumber;
    bool wasSuccessful = report.totalMeat > 0;
    double avgHaul = report.totalMeat / max(1, soldiers.length);

    for (var s in soldiers) {
      s.exhaustion = (s.exhaustion + 1.5).clamp(0, 10);
      s.stress = (s.stress - (wasSuccessful ? 0.5 : -0.2)).clamp(0, 10);

      s.performanceLog.add(PerformanceEvent(
          turnNumber: currentTurn,
          description: "Hunted at $locationName.",
          isPositive: wasSuccessful,
          magnitude: avgHaul > 10.0 ? 1.5 : 1.0));
    }
  }

  Future<void> _resolveFishing(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameState gameState) async {
    String locationName = poi?.name ?? "Waters";
    TerrainType terrain = TerrainType.waterShallow;
    if (locationName.toLowerCase().contains("deep") ||
        locationName.toLowerCase().contains("lake")) {
      terrain = TerrainType.waterDeep;
    }

    final report = await _fishingService.resolveFishingTrip(
      aravt: aravt,
      terrain: terrain,
      locationName: locationName,
      date: gameState.gameDate,
      gameState: gameState,
    );

    gameState.addFishingReport(report);

    bool isPlayerAravt = aravt.soldierIds.contains(gameState.player?.id);
    if (report.totalMeat > 0) {
      gameState.logEvent(
        "${aravt.id} caught ${report.totalFishCaught} fish (${report.totalMeat.toStringAsFixed(1)} kg).",
        category: EventCategory.food,
        severity: isPlayerAravt ? EventSeverity.high : EventSeverity.normal,
        aravtId: aravt.id,
      );
    } else {
      gameState.logEvent(
        "${aravt.id} caught nothing while fishing.",
        category: EventCategory.food,
        severity: isPlayerAravt ? EventSeverity.high : EventSeverity.low,
        aravtId: aravt.id,
      );
    }

    int currentTurn = gameState.turn.turnNumber;
    bool wasSuccessful = report.totalMeat > 0;
    double avgHaul = report.totalMeat / max(1, soldiers.length);

    for (var s in soldiers) {
      s.exhaustion = (s.exhaustion + 1.0).clamp(0, 10);
      s.stress = (s.stress - 0.5).clamp(0, 10); // Fishing is relaxing

      s.performanceLog.add(PerformanceEvent(
          turnNumber: currentTurn,
          description: "Fished at $locationName.",
          isPositive: wasSuccessful,
          magnitude: avgHaul > 5.0 ? 1.2 : 1.0));
    }
  }

  Future<void> _resolveWoodcutting(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameState gameState) async {
    if (poi == null) return;

    // Calls resolveWoodcuttingDetailed and handles the report
    final report = await _resourceService.resolveWoodcuttingDetailed(
      aravt: aravt,
      poi: poi,
      gameState: gameState,
    );

    gameState.addResourceReport(report);
    gameState.addCommunalWood(report.totalGathered);

    if (report.totalGathered > 0) {
      bool isPlayerAravt = aravt.soldierIds.contains(gameState.player?.id);
      gameState.logEvent(
        "${aravt.id} chopped ${report.totalGathered.toStringAsFixed(1)} kg of wood at ${poi.name}.",
        category: EventCategory.finance,
        severity: isPlayerAravt ? EventSeverity.high : EventSeverity.normal,
        aravtId: aravt.id,
      );
    }

    int currentTurn = gameState.turn.turnNumber;

    for (var result in report.individualResults) {
      final soldier = gameState.findSoldierById(result.soldierId);
      if (soldier != null) {
        soldier.exhaustion = (soldier.exhaustion + 2.0).clamp(0, 10);

        // Interaction Hooks
        // Praiseworthy: High output -> isPositive: true, magnitude 1.5
        // Scoldable: Low output -> isPositive: false, magnitude 1.5
        // Average: Normal output -> isPositive: true, magnitude 1.0
        bool isPraiseworthy = result.amountGathered > 30.0;
        bool isScoldable = result.amountGathered < 5.0;

        soldier.performanceLog.add(PerformanceEvent(
            turnNumber: currentTurn,
            description:
                "Chopped ${result.amountGathered.toStringAsFixed(1)}kg wood at ${poi.name}.",
            isPositive: !isScoldable, // False if scoldable, true otherwise
            magnitude: (isPraiseworthy || isScoldable) ? 1.5 : 1.0));
      }
    }
  }

  Future<void> _resolveMining(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameState gameState) async {
    if (poi == null) return;

    // Calls resolveMiningDetailed and handles the report
    final report = await _resourceService.resolveMiningDetailed(
      aravt: aravt,
      poi: poi,
      gameState: gameState,
    );

    gameState.addResourceReport(report);
    gameState.addCommunalIronOre(report.totalGathered);

    if (report.totalGathered > 0) {
      bool isPlayerAravt = aravt.soldierIds.contains(gameState.player?.id);
      gameState.logEvent(
        "${aravt.id} mined ${report.totalGathered.toStringAsFixed(1)} kg of iron ore at ${poi.name}.",
        category: EventCategory.finance,
        severity: isPlayerAravt ? EventSeverity.high : EventSeverity.normal,
        aravtId: aravt.id,
      );
    }

    int currentTurn = gameState.turn.turnNumber;

    for (var result in report.individualResults) {
      final soldier = gameState.findSoldierById(result.soldierId);
      if (soldier != null) {
        soldier.exhaustion = (soldier.exhaustion + 2.5).clamp(0, 10);
        soldier.stress = (soldier.stress + 0.1).clamp(0, 10);

        // Interaction Hooks
        // Mining is harder, so lower thresholds logic apply
        bool isPraiseworthy = result.amountGathered > 20.0;
        bool isScoldable = result.amountGathered < 3.0;

        soldier.performanceLog.add(PerformanceEvent(
            turnNumber: currentTurn,
            description:
                "Mined ${result.amountGathered.toStringAsFixed(1)}kg ore at ${poi.name}.",
            isPositive: !isScoldable,
            magnitude: (isPraiseworthy || isScoldable) ? 1.5 : 1.0));
      }
    }
  }

  // --- Other Tasks ---

  Future<void> _resolveShepherding(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameState gameState) async {
    await _shepherdingService.resolveShepherding(
      aravt: aravt,
      herd: gameState.communalCattle,
      gameState: gameState,
    );

    int currentTurn = gameState.turn.turnNumber;
    for (var s in soldiers) {
      s.exhaustion = (s.exhaustion + 0.5).clamp(0, 10);
      s.performanceLog.add(PerformanceEvent(
          turnNumber: currentTurn,
          description: "Shepherded the communal herd.",
          isPositive: true,
          magnitude: 1.0));
    }
  }

  Future<void> _resolveFletching(
      Aravt aravt, List<Soldier> soldiers, GameState gameState) async {
    await _craftingService.resolveFletching(aravt: aravt, gameState: gameState);
    int currentTurn = gameState.turn.turnNumber;
    for (var s in soldiers) {
      s.performanceLog.add(PerformanceEvent(
          turnNumber: currentTurn,
          description: "Fletched arrows.",
          isPositive: true,
          magnitude: 1.0));
    }
  }

  Future<void> _resolveScouting(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameState gameState) async {
    GameArea? areaToScout;
    if (poi != null) {
      for (var area in gameState.worldMap.values) {
        if (area.pointsOfInterest.any((p) => p.id == poi.id)) {
          areaToScout = area;
          break;
        }
      }
    } else if (aravt.task is AssignedTask &&
        (aravt.task as AssignedTask).areaId != null) {
      areaToScout = gameState.worldMap[(aravt.task as AssignedTask).areaId];
    }
    if (areaToScout == null) {
      areaToScout = gameState.worldMap[aravt.hexCoords.toString()];
    }

    if (areaToScout == null) {
      aravt.task = null;
      return;
    }

    if (!areaToScout.isExplored) {
      areaToScout.isExplored = true;
      gameState.logEvent("Your scouts have explored ${areaToScout.name}.",
          category: EventCategory.travel, aravtId: aravt.id);
      for (var s in soldiers) {
        if (s.status == SoldierStatus.alive) {
          s.performanceLog.add(PerformanceEvent(
              turnNumber: gameState.turn.turnNumber,
              description: "Explored new territory: ${areaToScout.name}",
              isPositive: true,
              magnitude: 1.5));
        }
      }
    }

    for (var areaPoi in areaToScout.pointsOfInterest) {
      if (!areaPoi.isDiscovered && areaPoi.type != PoiType.camp) {
        areaPoi.isDiscovered = true;
        gameState.logEvent("Scouts have discovered ${areaPoi.name}!",
            category: EventCategory.general,
            severity: EventSeverity.high,
            aravtId: aravt.id);
      }
    }

    if (_checkForHostileEncounters(areaToScout, aravt, gameState, 0.5)) return;

    for (var s in soldiers) s.experience = (s.experience + 0.1).clamp(0, 100);
  }

  Future<void> _resolvePatrolling(Aravt aravt, List<Soldier> soldiers,
      PointOfInterest? poi, GameState gameState) async {
    GameArea? areaToPatrol;
    if (poi != null) {
      for (var area in gameState.worldMap.values) {
        if (area.pointsOfInterest.any((p) => p.id == poi.id)) {
          areaToPatrol = area;
          break;
        }
      }
    } else if (aravt.task is AssignedTask &&
        (aravt.task as AssignedTask).areaId != null) {
      areaToPatrol = gameState.worldMap[(aravt.task as AssignedTask).areaId];
    }
    if (areaToPatrol == null) {
      areaToPatrol = gameState.worldMap[aravt.hexCoords.toString()];
    }

    if (areaToPatrol == null) {
      aravt.task = null;
      return;
    }

    if (!areaToPatrol.isExplored) {
      areaToPatrol.isExplored = true;
      gameState.logEvent("Your patrol has explored ${areaToPatrol.name}.",
          category: EventCategory.travel, aravtId: aravt.id);
      for (var s in soldiers) {
        if (s.status == SoldierStatus.alive) {
          s.performanceLog.add(PerformanceEvent(
              turnNumber: gameState.turn.turnNumber,
              description: "Discovered new territory while on patrol.",
              isPositive: true,
              magnitude: 1.0));
        }
      }
    }

    if (_checkForHostileEncounters(areaToPatrol, aravt, gameState, 0.75))
      return;

    for (var s in soldiers) {
      s.exhaustion = (s.exhaustion - 0.5).clamp(0, 10);
      s.experience = (s.experience + 0.05).clamp(0, 100);
    }
  }

  bool _checkForHostileEncounters(GameArea area, Aravt playerAravt,
      GameState gameState, double combatChance) {
    for (var areaPoi in area.pointsOfInterest) {
      if (areaPoi.type == PoiType.camp && areaPoi.id != 'camp-player') {
        if (!areaPoi.isDiscovered && _random.nextDouble() < 0.8) {
          areaPoi.isDiscovered = true;
          area.type = AreaType.NpcCamp;
          area.icon = Icons.fort;
          area.backgroundImagePath = 'assets/backgrounds/npc_camp_bg.jpg';
          gameState.logEvent("Your aravt has discovered the ${areaPoi.name}!",
              category: EventCategory.general,
              severity: EventSeverity.high,
              aravtId: playerAravt.id);
        }
        if (areaPoi.isDiscovered && _random.nextDouble() < combatChance) {
          List<Aravt> defenders = (areaPoi.id == 'camp-npc1')
              ? gameState.npcAravts1.take(3).toList()
              : gameState.npcAravts2.take(3).toList();
          List<Soldier> pool = (areaPoi.id == 'camp-npc1')
              ? gameState.npcHorde1
              : gameState.npcHorde2;
          defenders = defenders.where((a) => a.soldierIds.isNotEmpty).toList();

          if (defenders.isNotEmpty) {
            List<Aravt> playerForces = [playerAravt];
            for (var other in gameState.aravts) {
              if (other.id != playerAravt.id &&
                  other.hexCoords == area.coordinates &&
                  other.task is AssignedTask) {
                playerForces.add(other);
              }
            }

            gameState.logEvent(
                "Hostiles encountered near ${areaPoi.name}! ${playerForces.length} player aravt(s) engage.",
                category: EventCategory.general,
                severity: EventSeverity.high,
                aravtId: playerAravt.id);
            gameState.initiateCombat(
                playerAravts: playerForces,
                opponentAravts: defenders,
                allPlayerSoldiers: gameState.horde,
                allOpponentSoldiers: pool);
            return true;
          }
        }
      }
    }
    return false;
  }

  // --- Helpers ---
  Settlement? _findSettlementAtPoi(PointOfInterest poi, GameState gameState) {
    try {
      return gameState.settlements.firstWhere((s) => s.poiId == poi.id);
    } catch (e) {
      return null;
    }
  }

  List<Soldier> _findHordeForAravt(Aravt aravt, GameState gameState) {
    if (gameState.aravts.contains(aravt)) return gameState.horde;
    if (gameState.npcAravts1.contains(aravt)) return gameState.npcHorde1;
    if (gameState.npcAravts2.contains(aravt)) return gameState.npcHorde2;
    if (gameState.garrisonAravts.contains(aravt))
      return gameState.garrisonSoldiers;
    return [];
  }
}
