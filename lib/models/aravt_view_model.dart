import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/location_data.dart'; // --- NEW: Import ---
import 'package:aravt/models/settlement_data.dart'; // --- NEW: Import ---
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:flutter/material.dart'; // For Icons

/// A view model to provide clean, display-ready data for an Aravt.
class AravtViewModel {
  final Aravt aravt;
  final GameState gameState;
  final DateTime _currentTime;

  AravtViewModel({
    required this.aravt,
    required this.gameState,
  }) : _currentTime = gameState.currentDate?.toDateTime() ?? DateTime.now();

  /// The Aravt's unique ID.
  String get id => aravt.id;

  /// The name of the Aravt's captain.
  String get captainName {
    final captain = gameState.findSoldierById(aravt.captainId);
    return captain?.name ?? 'No Captain';
  }

  /// The number of soldiers in the Aravt.
  int get soldierCount => aravt.soldierIds.length;

  /// --- UPDATED: Gets the name of the Aravt's current physical location ---
  String get currentLocationName {
    if (aravt.currentLocationType == LocationType.poi) {
      final poi =
          gameState.currentArea?.findPoiById(aravt.currentLocationId);
      return poi?.name ?? 'Unknown Area';
    } else if (aravt.currentLocationType == LocationType.settlement) {
      final settlement = gameState.findSettlementById(aravt.currentLocationId);
      return settlement?.name ?? 'Unknown Settlement';
    }
    return 'Lost';
  }

  /// --- UPDATED: Gets the display name for the current task/assignment ---
  String get taskDisplayName {
    final task = aravt.task;
    if (task is MovingTask) {
      return 'Traveling';
    }
    if (task is AssignedTask) {
      // You can customize this as needed
      return task.assignment.name;
    }
    // No task
    return 'Resting';
  }

  /// --- UPDATED: Gets the name of the task's target location, if any ---
  String? get taskLocationName {
    final task = aravt.task;
    if (task is MovingTask) {
      if (task.destination.type == LocationType.poi) {
        return gameState.currentArea?.findPoiById(task.destination.id)?.name;
      } else {
        return gameState.findSettlementById(task.destination.id)?.name;
      }
    }
    if (task is AssignedTask) {
      final String? poiId = task.poiId;
      if (poiId != null) {
      return gameState.currentArea?.findPoiById(poiId)?.name;
      }
    }
    // Resting or other tasks have no separate target location
    return null;
  }

  /// --- UPDATED: Gets the icon for the current task ---
  IconData get taskIcon {
    final task = aravt.task;
    if (task is MovingTask) {
      return Icons.directions_walk; // Example icon
    }
    if (task is AssignedTask) {
      return getIconForAssignment(task.assignment);
    }
    return Icons.bed; // Resting
  }

  /// --- NEW: Gets a simple description string for the UI ---
  String get statusDescription {
    final task = aravt.task;
    if (task is MovingTask) {
      final locName = taskLocationName ?? 'destination';
      return 'En route to $locName';
    }
    if (task is AssignedTask) {
      final locName = taskLocationName ?? 'location';
      return '${task.assignment.name} at $locName';
    }
    return 'Resting at $currentLocationName';
  }

  /// --- NEW: Returns true if the Aravt is not Resting ---
  bool get isBusy {
    return aravt.task != null;
  }

  /// --- UPDATED: Calculates task progress percentage ---
  /// This now works for both MovingTask and AssignedTask.
  double get taskProgressPercent {
    final task = aravt.task;
    if (task == null) {
      return 0.0;
    }

    final double duration = task.durationInSeconds;
    if (duration <= 0) {
      return 0.0;
    }

    final double elapsed =
        _currentTime.difference(task.startTime).inSeconds.toDouble();
    
    // Clamp between 0.0 and 1.0
    return (elapsed / duration).clamp(0.0, 1.0);
  }

  /// --- NEW: Helper to get a progress string, e.g., "45% Complete" ---
  String get taskProgressString {
    return '${(taskProgressPercent * 100).toStringAsFixed(0)}% Complete';
  }

  /// --- NEW: Returns true if the aravt is currently moving ---
  bool get isMoving {
    return aravt.task is MovingTask;
  }

  // Example helper function (you may already have this)
  static IconData getIconForAssignment(AravtAssignment assignment) {
    switch (assignment) {
      case AravtAssignment.Rest:
        return Icons.bed;
      case AravtAssignment.Patrol:
        return Icons.security;
      case AravtAssignment.Scout:
        return Icons.visibility;
      case AravtAssignment.Hunt:
        return Icons.pets;
      case AravtAssignment.Forage:
        return Icons.grass;
      case AravtAssignment.Travel:
        return Icons.directions_walk;
      // ... add all other assignments
      default:
        return Icons.question_mark;
    }
  }
}

