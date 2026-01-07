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

import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/location_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'dart:math';

/// This service is called by the UI to create and assign new tasks to Aravts.
/// It performs checks, handles travel logistics, and translates UI actions into model data changes.
class UiAssignmentService {
  /// Checks if an Aravt is free to receive a new task.
  bool canAssignNewTask(Aravt aravt) {
    if (aravt.task == null) return true;
    if (aravt.task is AssignedTask &&
        (aravt.task as AssignedTask).assignment == AravtAssignment.Rest) {
      return true;
    }
    return false;
  }

  /// Assigns a task at a specific POI (Hunt, Fish, Mine, etc.).
  /// Automatically handles travel if the Aravt is not currently at that POI.
  void assignPoiTask({
    required Aravt aravt,
    required PointOfInterest poi,
    required AravtAssignment assignment,
    required GameState gameState,
    String? option,
  }) {
    if (!canAssignNewTask(aravt)) {
      _logError(gameState, "Aravt ${aravt.id} is already busy.");
      return;
    }

    // Determine appropriate duration based on task type
    int duration = 86400; // Default 1 day
    switch (assignment) {
      case AravtAssignment.Hunt:
      case AravtAssignment.Fish:
      case AravtAssignment.Mine:
      case AravtAssignment.ChopWood:
        duration = 32400; // 9 hours
        break;
      case AravtAssignment.FletchArrows:
      case AravtAssignment.Train:
        duration = 32400; // Camp tasks resolve in 1 turn (9h)
        break;
      default:
        duration = 32400; // 9 hours
        break;
    }

    if (aravt.currentLocationType == LocationType.poi &&
        aravt.currentLocationId == poi.id) {
      // Already there, start immediately
      _assignImmediateTask(
        aravt: aravt,
        areaId: null, // POI task doesn't strictly need areaId if it has poiId
        poiId: poi.id,
        assignment: assignment,
        duration: duration,
        gameState: gameState,
        locationName: poi.name,
        option: option,
      );
    } else if (aravt.hexCoords == poi.position) {
      // Same hex, but different POI (or no POI). Still instant travel.
      _assignImmediateTask(
        aravt: aravt,
        areaId: null,
        poiId: poi.id,
        assignment: assignment,
        duration: duration,
        gameState: gameState,
        locationName: poi.name,
        option: option,
      );
    } else {
      // Need to travel first
      _assignTravelThenTask(
        aravt: aravt,
        destination: GameLocation.poi(poi.id),
        followUpAssignment: assignment,
        followUpPoiId: poi.id,
        duration: duration,
        gameState: gameState,
        destinationName: poi.name,
        option: option,
      );
    }
  }

  /// Assigns an Area-Level task (Scout, Patrol).
  /// Automatically handles travel if the Aravt is not in that Area.
  void assignAreaTask({
    required Aravt aravt,
    required GameArea area,
    required AravtAssignment assignment,
    required GameState gameState,
    String? option,
  }) {
    if (!canAssignNewTask(aravt)) {
      _logError(gameState, "Aravt ${aravt.id} is already busy.");
      return;
    }

    // Find a valid entry point for travel calculations if needed
    PointOfInterest? entryPoi;
    try {
      entryPoi = area.pointsOfInterest.firstWhere((p) => p.isDiscovered);
    } catch (e) {
      if (area.pointsOfInterest.isNotEmpty) {
        entryPoi = area.pointsOfInterest.first;
      }
    }

    // If we are already in the area (based on hex coords), we can start immediately
    // regardless of whether we are at a specific POI.
    bool isAlreadyInArea = aravt.hexCoords == area.coordinates;

    if (isAlreadyInArea) {
      if (assignment == AravtAssignment.Patrol && !area.isExplored) {
        _logError(gameState, "Cannot patrol an unexplored area: ${area.name}");
        return;
      }
      _assignImmediateTask(
        aravt: aravt,
        areaId: area.id,
        poiId: null,
        assignment: assignment,
        duration: 86400, // 1 day standard for area tasks
        gameState: gameState,
        locationName: area.name,
        option: option,
      );
    } else {
      // Need to travel. We need *some* destination ID for the moving task.
      if (entryPoi == null) {
        _logError(
            gameState, "Cannot travel to ${area.name}: No known entry points.");
        return;
      }

      _assignTravelThenTask(
        aravt: aravt,
        destination: GameLocation.poi(entryPoi.id),
        followUpAssignment: assignment,
        followUpAreaId: area.id,
        duration: 86400,
        gameState: gameState,
        destinationName: area.name,
        option: option,
      );
    }
  }

  /// Assigns a simple Travel task with no follow-up.
  void assignTravelTask({
    required Aravt aravt,
    required GameLocation destination,
    required GameState gameState,
  }) {
    if (!canAssignNewTask(aravt)) return;

    _createMovingTask(
      aravt: aravt,
      destination: destination,
      gameState: gameState,
    );

    String destName = "destination";
    if (destination.type == LocationType.poi) {
      destName =
          gameState.findPoiByIdWorld(destination.id)?.name ?? "unknown POI";
    }

    gameState.logEvent(
      "Your aravt begins traveling to $destName.",
      category: EventCategory.travel,
      aravtId: aravt.id,
    );
    gameState.triggerUpdate();
  }

  /// Assigns the Pack task.
  void assignPackTask({
    required Aravt aravt,
    required GameState gameState,
  }) {
    if (!canAssignNewTask(aravt)) {
      _logError(gameState, "Aravt ${aravt.id} is already busy.");
      return;
    }

    _assignImmediateTask(
      aravt: aravt,
      areaId: null, // Packing happens at current location (camp)
      poiId: null,
      assignment: AravtAssignment.Pack,
      duration: 86400, // 1 day cycle, progress tracked separately
      gameState: gameState,
      locationName: "Camp",
    );
  }

  // --- PRIVATE HELPERS ---

  void _assignImmediateTask({
    required Aravt aravt,
    required String? areaId,
    required String? poiId,
    required AravtAssignment assignment,
    required int duration,
    required GameState gameState,
    required String locationName,
    String? option,
  }) {
    // Register at POI if applicable
    if (poiId != null) {
      final poi = gameState.findPoiByIdWorld(poiId);
      if (poi != null && !poi.assignedAravtIds.contains(aravt.id)) {
        poi.assignedAravtIds.add(aravt.id);
      }
    }

    aravt.task = AssignedTask(
      areaId: areaId,
      poiId: poiId,
      assignment: assignment,
      option: option,
      durationInSeconds: duration.toDouble(),
      startTime: gameState.gameDate.toDateTime(),
    );
    // Only set persistent assignment for continuous tasks
    if (assignment != AravtAssignment.Scout &&
        assignment != AravtAssignment.Patrol &&
        assignment != AravtAssignment.Attack) {
      aravt.persistentAssignment = assignment;
      aravt.persistentAssignmentLocationId = poiId ?? areaId;
    } else {
      aravt.persistentAssignment = null;
      aravt.persistentAssignmentLocationId = null;
    }
    print(
        "DEBUG: Created AssignedTask for ${aravt.id}. Start: ${aravt.task!.startTime}, Duration: ${aravt.task!.durationInSeconds}, End: ${aravt.task!.expectedEndTime}");

    gameState.logEvent(
      "Your aravt begins to ${assignment.name} at $locationName.",
      category: EventCategory.general,
      aravtId: aravt.id,
    );
    gameState.triggerUpdate();
  }

  void _assignTravelThenTask({
    required Aravt aravt,
    required GameLocation destination,
    required AravtAssignment followUpAssignment,
    required int duration,
    required GameState gameState,
    required String destinationName,
    String? followUpAreaId,
    String? followUpPoiId,
    String? option,
  }) {
    // Deregister from current POI if any before leaving
    gameState.clearAravtAssignment(aravt);

    _createMovingTask(
      aravt: aravt,
      destination: destination,
      gameState: gameState,
      followUpAssignment: followUpAssignment,
      followUpAreaId: followUpAreaId,
      followUpPoiId: followUpPoiId,
      followUpDuration: duration,
      option: option,
    );

    gameState.logEvent(
      "Your aravt begins traveling to $destinationName to ${followUpAssignment.name}.",
      category: EventCategory.travel,
      aravtId: aravt.id,
    );
    gameState.triggerUpdate();
  }

  void _createMovingTask({
    required Aravt aravt,
    required GameLocation destination,
    required GameState gameState,
    AravtAssignment? followUpAssignment,
    String? followUpAreaId,
    String? followUpPoiId,
    int? followUpDuration,
    String? option,
  }) {
    // Calculate travel time based on distance
    double travelSeconds = 3600; // Default 1 hour if calculation fails

    HexCoordinates? startCoords = aravt.hexCoords;
    HexCoordinates? endCoords;

    if (destination.type == LocationType.poi) {
      endCoords = gameState.findPoiByIdWorld(destination.id)?.position;
    } else if (destination.type == LocationType.settlement) {
      final settlement = gameState.findSettlementById(destination.id);
      if (settlement != null) {
        endCoords = gameState.findPoiByIdWorld(settlement.poiId)?.position;
      }
    }

    if (endCoords != null) {
      int distance = startCoords.distanceTo(endCoords);
      if (distance > 0) {
        travelSeconds = distance * 86400.0; // 1 day per tile
      }
    }

    // Find area for startCoords
    String? startAreaId;
    for (var area in gameState.worldMap.values) {
      if (area.coordinates == startCoords) {
        startAreaId = area.id;
        break;
      }
    }

    if (startAreaId != null) {
      aravt.currentLocationType = LocationType.area;
      aravt.currentLocationId = startAreaId;
    }

    aravt.task = MovingTask(
      destination: destination,
      durationInSeconds: travelSeconds,
      startTime: gameState.gameDate.toDateTime(),
      followUpAssignment: followUpAssignment,
      followUpAreaId: followUpAreaId,
      followUpPoiId: followUpPoiId,
      option: option,
    );

    // Only set persistent assignment for continuous tasks
    if (followUpAssignment != AravtAssignment.Scout &&
        followUpAssignment != AravtAssignment.Patrol &&
        followUpAssignment != AravtAssignment.Attack) {
      aravt.persistentAssignment = followUpAssignment;
      aravt.persistentAssignmentLocationId = followUpPoiId ?? followUpAreaId;
    } else {
      aravt.persistentAssignment = null;
      aravt.persistentAssignmentLocationId = null;
    }

    print(
        "DEBUG: Created MovingTask for ${aravt.id}. Start: ${aravt.task!.startTime}, Duration: ${aravt.task!.durationInSeconds}, End: ${aravt.task!.expectedEndTime}");
  }

  void _logError(GameState gameState, String message) {
    print("UI ASSIGNMENT ERROR: $message");
    // Optionally push this to the in-game log too if it's relevant to the player
    // gameState.logEvent(message, category: EventCategory.system, severity: EventSeverity.high);
  }
}
