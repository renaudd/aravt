// lib/models/horde_data.dart

import 'dart:math';
import 'soldier_data.dart';
import 'location_data.dart';
import 'package:aravt/models/aravt_models.dart';
import 'package:aravt/models/assignment_data.dart' as assign;
import 'area_data.dart'; // --- NEW: Import for HexCoordinates

// --- (locationTypeFromName function is unchanged) ---
LocationType locationTypeFromName(String name) {
  return LocationType.values.firstWhere(
    (e) => e.name == name,
    orElse: () => LocationType.poi, 
  );
}

class Aravt {
  final String id;
  final int captainId;
  List<int> soldierIds;

  assign.AravtTask? task;

  Map<AravtDuty, int> dutyAssignments;

  LocationType currentLocationType;
  String currentLocationId; 

  // --- NEW: Aravt's current world map hex position ---
  HexCoordinates hexCoords;
  // --- END NEW ---

  // --- (Getters: currentAssignment, assignmentLocationId are unchanged) ---
  assign.AravtAssignment get currentAssignment {
    if (task is assign.AssignedTask) {
      return (task as assign.AssignedTask).assignment;
    }
    if (task is assign.MovingTask) {
      return assign.AravtAssignment.Travel;
    }
    return assign.AravtAssignment.Rest;
  }

    set currentAssignment(assign.AravtAssignment newAssignment) {
      if (newAssignment == assign.AravtAssignment.Rest) {
          task = null; // Resting means no task
      } else {
          // For other assignments, we need more info (location, etc.), 
          // so we can't easily set them here. 
          // But we CAN support setting it to 'Rest' to cancel tasks, 
          // which is what the UI wants to do.
          print("Warning: Cannot set complex assignment $newAssignment directly via setter. Use AssignmentService.");
      }
  }


  String? get assignmentLocationId {
    if (task is assign.AssignedTask) {
      return (task as assign.AssignedTask).poiId;
    }
    return null; 
  }

  Aravt({
    required this.id,
    required this.captainId,
    this.soldierIds = const [],
    this.task,
    Map<AravtDuty, int>? dutyAssignments,
    required this.currentLocationType,
    required this.currentLocationId,
    required this.hexCoords, // --- NEW ---
  }) : this.dutyAssignments = dutyAssignments ??
            {
              for (var duty in AravtDuty.values) duty: captainId,
            };

  Map<String, dynamic> toJson() => {
        'id': id,
        'captainId': captainId,
        'soldierIds': soldierIds,
        'task': task?.toJson(),
        'dutyAssignments':
            dutyAssignments.map((key, value) => MapEntry(key.name, value)),
        'currentLocationType': currentLocationType.name,
        'currentLocationId': currentLocationId,
        'hexCoords': hexCoords.toJson(), // --- NEW ---
      };

  factory Aravt.fromJson(Map<String, dynamic> json) {
    assign.AravtTask? loadedTask;
    if (json.containsKey('task') && json['task'] != null) {
      loadedTask = assign.AravtTask.fromJson(json['task']);
    } else if (json.containsKey('currentAssignment')) {
      var assignment = assign.assignmentFromName(json['currentAssignment']);
      if (assignment != assign.AravtAssignment.Rest &&
          json['assignmentLocationId'] != null) {
        loadedTask = assign.AssignedTask(
          poiId: json['assignmentLocationId'],
          areaId: null, 
          assignment: assignment,
          durationInSeconds: 3600,
          startTime: DateTime.now(),
        );
      }
    }

    LocationType locType;
    String locId;

    if (json.containsKey('currentLocationId')) {
      locId = json['currentLocationId'];
      locType = locationTypeFromName(json['currentLocationType'] ?? 'poi');
    } else if (loadedTask is assign.AssignedTask) {
      locType = LocationType.poi;
      locId = loadedTask.poiId ?? "DEFAULT_CAMP_POI_ID";
    } else {
      locType = LocationType.poi;
      locId = "DEFAULT_CAMP_POI_ID";
      print(
          "Warning: Aravt ${json['id']} has no location. Defaulting to $locId.");
    }
    
    // --- NEW: Load hexCoords, with fallback for old saves ---
    HexCoordinates coords;
    if (json.containsKey('hexCoords')) {
      coords = HexCoordinates.fromJson(json['hexCoords']);
    } else {
      // Fallback for old saves: Assume (0,0)
      coords = const HexCoordinates(0, 0); 
      print("Warning: Aravt ${json['id']} has no hexCoords. Defaulting to (0,0).");
    }
    // --- END NEW ---

    return Aravt(
      id: json['id'],
      captainId: json['captainId'],
      soldierIds: List<int>.from(json['soldierIds']),
      task: loadedTask,
      dutyAssignments: (json['dutyAssignments'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(aravtDutyFromName(key), value as int)),
      currentLocationType: locType,
      currentLocationId: locId,
      hexCoords: coords, // --- NEW ---
    );
  }
}

// --- (Horde, HordeGenerator, HordeData classes are unchanged) ---
class Horde {
  final Soldier leader;
  final List<Soldier> members;
  final Map<String, List<Soldier>> aravts = {};

  Horde({required this.leader, required this.members}) {
    // Organize members into aravts for easy access
    for (var member in members) {
      if (!aravts.containsKey(member.aravt)) {
        aravts[member.aravt] = [];
      }
      aravts[member.aravt]!.add(member);
    }
  }
}
class HordeGenerator {
  static final Random _random = Random();

  // Generates a complete horde with relationships
  static Horde generateHorde() {
    // 1. Use your detailed generator to create all the soldiers first.
    final List<Soldier> members = List.generate(50, // Create 50 soldiers for the horde
        (index) {
      final aravtNumber = _random.nextInt(5) + 1; // Generates 1 to 5
      return SoldierGenerator.generateNewSoldier(
        id: index + 1,
        aravt: 'Aravt $aravtNumber',
      );
    });

    final Soldier leader = members.first;

    // 2. Now, loop through the fully generated soldiers to create relationships.
    for (var soldier in members) {
      // Generate relationships with every other member
      for (var other in members) {
        if (soldier.id == other.id) continue; // No relationship with self
        soldier.hordeRelationships[other.id] =
            _generateRelationship(soldier, other);
      }
      // Ensure a specific relationship with the leader is generated
      if (soldier.id != leader.id) {
        soldier.hordeRelationships[leader.id] =
            _generateRelationship(soldier, leader, isLeader: true);
      }

      // Generate a few external relationships for variety
      soldier.externalRelationships['Rival Tribe'] =
          _generateRelationship(soldier, null, external: true);
      soldier.externalRelationships['Nearby Settlement'] =
          _generateRelationship(soldier, null, external: true);
    }

    return Horde(leader: leader, members: members);
  }

  // This function now uses the detailed Soldier objects to influence relationship values
  static RelationshipValues _generateRelationship(Soldier from, Soldier? to,
      {bool isLeader = false, bool external = false}) {
    if (external) {
      // Simplified logic for external factions
      return RelationshipValues(
        admiration: _random.nextDouble() * 2, // 0-2
        respect: _random.nextDouble() * 2, // 0-2
        fear: _random.nextDouble() * 3 + 1, // 1-4
        loyalty: 0,
      );
    }

    // Baseline values for internal horde relationships
    double admiration = 2.5;
    double respect = 2.5;
    double fear = 2.0;
    double loyalty = 2.5;

    // --- Add Your Complex Logic Here ---
    if (isLeader) {
      respect += from.leadership > 7 ? 1.5 : 0.5;
      loyalty += from.leadership > 7 ? 1.5 : 0.5;
      fear += from.temperament < 3 ? 1.0 : 0.0;
    }

    if (from.aravt == to?.aravt) {
      loyalty += 0.5;
      admiration += 0.2;
    }

    if (from.temperament < 3 && to!.temperament > 7) {
      respect -= 0.5;
    }

    // Return clamped values
    return RelationshipValues(
      admiration: (admiration + (_random.nextDouble() - 0.5)).clamp(0, 5),
      respect: (respect + (_random.nextDouble() - 0.5)).clamp(0, 5),
      fear: (fear + (_random.nextDouble() - 0.5)).clamp(0, 5),
      loyalty: (loyalty + (_random.nextDouble() - 0.5)).clamp(0, 5),
    );
  }
}
class HordeData {
  final String id;
  final int leaderId;
  final List<int> memberIds;
  final List<String> aravtIds;

  // Communal Resources
  double communalKilosOfMeat;
  double communalKilosOfRice;
  double communalSuppliesWealth;
  double communalTreasureWealth;

  // Horde-level relationships
  Map<String, RelationshipValues> diplomacy;

  HordeData({
    required this.id,
    required this.leaderId,
    required this.memberIds,
    required this.aravtIds,
    this.communalKilosOfMeat = 100.0,
    this.communalKilosOfRice = 50.0,
    this.communalSuppliesWealth = 100.0,
    this.communalTreasureWealth = 20.0,
    Map<String, RelationshipValues>? diplomacy,
  }) : this.diplomacy = diplomacy ?? {};

  // --- NEW: JSON Serialization ---
  Map<String, dynamic> toJson() => {
        'id': id,
        'leaderId': leaderId,
        'memberIds': memberIds,
        'aravtIds': aravtIds,
        'communalKilosOfMeat': communalKilosOfMeat,
        'communalKilosOfRice': communalKilosOfRice,
        'communalSuppliesWealth': communalSuppliesWealth,
        'communalTreasureWealth': communalTreasureWealth,
        'diplomacy':
            diplomacy.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory HordeData.fromJson(Map<String, dynamic> json) {
    return HordeData(
      id: json['id'],
      leaderId: json['leaderId'],
      memberIds: List<int>.from(json['memberIds']),
      aravtIds: List<String>.from(json['aravtIds']),
      communalKilosOfMeat: json['communalKilosOfMeat'] ?? 100.0,
      communalKilosOfRice: json['communalKilosOfRice'] ?? 50.0,
      communalSuppliesWealth: json['communalSuppliesWealth'] ?? 100.0,
      communalTreasureWealth: json['communalTreasureWealth'] ?? 20.0,
      diplomacy: (json['diplomacy'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, RelationshipValues.fromJson(value))),
    );
  }

  // --- HELPER GETTERS ---
  double get totalCommunalFood => communalKilosOfMeat + communalKilosOfRice;
  double get estimatedFoodConsumptionPerTurn => memberIds.length * 0.5;
}

