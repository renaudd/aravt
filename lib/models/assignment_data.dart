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

// import 'area_data.dart'; // --- REMOVED: No longer need HexCoordinates
import 'inventory_item.dart'; // For TradeTask cargo
import 'location_data.dart';


enum DiplomaticTerm {
  RequestAid,
  OfferTradingAlliance,
  RecruitSoldiers,
  RecruitAdvisors,
  LearnAboutArea,
  LearnNewTechnology,
  OfferProtection,
  RequestProtection,
  OfferTruce,
  DemandSubmission,
  LearnRelations,
  OfferAggressiveAlliance,
  OfferDefensiveAlliance,
  ProposeUnification,
  Surrender,
  OfferTribute,
  ProvideAid,
  PresentGifts,
  DemandTribute, // --- MOVED HERE ---
}


/// This enum defines all possible external tasks an Aravt group can be assigned to.
enum AravtAssignment {
  // --- Core & Camp Assignments ---
  Rest,
  Train,
  RepairGear,
  FletchArrows,
  GuardPrisoners,
  CareForWounded,
  Defend, // Defend Camp / POI
  Pack, // Pack up camp to move


  // --- Gathering Assignments ---
  Shepherd, // Was GrazingHerd
  Fish,
  Hunt,
  GatherWater,
  Forage,
  ChopWood,
  Harvest,
  Mine,

  // --- Diplomatic & Economic Assignments ---
  Trade,
  Emissary,
  Escort,
  // --- REMOVED: DemandTribute (now a DiplomaticTerm) ---

  // --- Intel & Clandestine Assignments ---
  Scout,
  Patrol,
  Ambush,
  Pillage,
  Raid,
  Raze,
  Assassinate,
  Kidnap,
  RescuePrisoners,

  // --- Military Assignments ---
  Attack,
  Siege,


  Travel, // Represents the state of being in a MovingTask
}

/// Represents the state of an Aravt group's current task or movement.
abstract class AravtTask {
  final DateTime startTime;
  final double durationInSeconds; // --- MOVED: Now in base class ---


  DateTime get expectedEndTime =>
      startTime.add(Duration(seconds: durationInSeconds.toInt()));
  String get description;

  AravtTask({
    DateTime? startTime,
    required this.durationInSeconds, // --- MOVED: Now in base class ---
  }) : startTime = startTime ?? DateTime.now();

  bool isCompleted(DateTime currentTime) {
    return !currentTime.isBefore(expectedEndTime);
  }

  Map<String, dynamic> toJson();
  factory AravtTask.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'moving':
        return MovingTask.fromJson(json);
      case 'assigned':
        return AssignedTask.fromJson(json);

      case 'trade':
        return TradeTask.fromJson(json);
      case 'emissary':
        return EmissaryTask.fromJson(json);
      case 'escort':
        return EscortTask.fromJson(json);

      default:
        throw ArgumentError('Unknown task type: ${json['type']}');
    }
  }
}

/// A task for moving an Aravt group from one location to another.
class MovingTask extends AravtTask {
  final GameLocation destination;


  final AravtAssignment? followUpAssignment;
  final String? followUpAreaId; // For area-level follow-ups (Scout, Patrol)
  final String? followUpPoiId; // For POI-level follow-ups (Hunt, etc.)
  final String? option;


  @override
  String get description {
    if (followUpAssignment != null) {
      return 'Traveling to ${destination.id}, then ${followUpAssignment!.name}';
    }
    return 'Traveling to ${destination.id}';
  }

  MovingTask({
    required this.destination,
    required double durationInSeconds, // Now passed directly
    DateTime? startTime,

    this.followUpAssignment,
    this.followUpAreaId,
    this.followUpPoiId,
    this.option,
  }) : super(
          startTime: startTime,
          durationInSeconds: durationInSeconds, // Pass to super
        );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'moving',
        'destinationType': destination.type.name,
        'destinationId': destination.id,
        'durationInSeconds': durationInSeconds,
        'startTime': startTime.toIso8601String(),

        'followUpAssignment': followUpAssignment?.name,
        'followUpAreaId': followUpAreaId,
        'followUpPoiId': followUpPoiId,
        'option': option,
      };

  factory MovingTask.fromJson(Map<String, dynamic> json) {
    return MovingTask(
      destination: GameLocation(
        type: LocationType.values
            .firstWhere((e) => e.name == json['destinationType']),
        id: json['destinationId'],
      ),
      durationInSeconds: json['durationInSeconds'] as double,
      startTime: DateTime.parse(json['startTime']),

      followUpAssignment: json['followUpAssignment'] != null
          ? assignmentFromName(json['followUpAssignment'])
          : null,
      followUpAreaId: json['followUpAreaId'] as String?,
      followUpPoiId: json['followUpPoiId'] as String?,
      option: json['option'] as String?,
    );
  }
}

/// A task for an Aravt group assigned to a Point of Interest.
class AssignedTask extends AravtTask {
  final String? areaId;
  final String? poiId;

  final AravtAssignment assignment;
  final String? option;

  @override
  String get description {
    if (poiId != null) {
      return '$assignment at POI $poiId';
    }
    if (areaId != null) {
      return '$assignment in Area $areaId';
    }
    return '$assignment (unknown location)';
  }

  AssignedTask({
    this.areaId,
    this.poiId,
    required this.assignment,
    this.option,
    required double durationInSeconds,
    DateTime? startTime,
  }) : super(
          startTime: startTime,
          durationInSeconds: durationInSeconds, // Pass to super
        );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'assigned',

        'areaId': areaId,
        'poiId': poiId,

        'assignment': assignment.name,
        'option': option,
        'durationInSeconds': durationInSeconds,
        'startTime': startTime.toIso8601String(),
      };

  factory AssignedTask.fromJson(Map<String, dynamic> json) {

    final String? loadedPoiId = json['poiId'] as String?;
    final String? loadedAreaId = json['areaId'] as String?;

    return AssignedTask(
      // If areaId is null (old save), we'll rely on poiId.
      // If poiId is also null (new area-level task), that's fine.
      areaId: loadedAreaId,
      poiId: loadedPoiId,

      assignment: AravtAssignment.values.firstWhere(
        (e) => e.name == json['assignment'],
        orElse: () => AravtAssignment.Rest, // Default to Rest if not found
      ),
      option: json['option'] as String?,
      durationInSeconds: json['durationInSeconds'] as double,
      startTime: DateTime.parse(json['startTime']), // Pass as named parameter
    );
  }
}


class TradeTask extends AravtTask {
  final String targetPoiId;
  final List<InventoryItem> cargo; // Items being carried for trade
  final List<Mount> horses; // Horses carrying the cargo
  final MovingTask movement; // The path to get there
  final Map<String, double> resources; // Fungible resources (scrap, meat, etc.)

  TradeTask({
    required this.targetPoiId,
    required this.cargo,
    this.horses = const [],
    this.resources = const {},
    required this.movement,
    DateTime? startTime,
  }) : super(
          startTime: startTime ?? movement.startTime,
          durationInSeconds:
              movement.durationInSeconds, // Pass movement's duration
        );

  @override
  DateTime get expectedEndTime => movement.expectedEndTime;
  @override
  String get description => 'Trading at $targetPoiId';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'trade',
        'targetPoiId': targetPoiId,
        'cargo': cargo.map((item) => item.toJson()).toList(),
        'horses': horses.map((h) => h.toJson()).toList(),
        'resources': resources,
        'movement': movement.toJson(),
        'startTime': startTime.toIso8601String(),
        // durationInSeconds is implicitly saved inside 'movement'
      };

  factory TradeTask.fromJson(Map<String, dynamic> json) {
    final movement = MovingTask.fromJson(json['movement']);
    return TradeTask(
      targetPoiId: json['targetPoiId'] as String,
      cargo: (json['cargo'] as List)
          .map((item) => InventoryItem.fromJson(item))
          .toList(),
      horses:
          (json['horses'] as List?)?.map((h) => Mount.fromJson(h)).toList() ??
              [],
      resources: (json['resources'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          ) ??
          {},
      movement: movement,
      startTime: DateTime.parse(json['startTime']),
    );
  }
}



class EmissaryTask extends AravtTask {
  final String targetPoiId;
  final List<DiplomaticTerm> terms;
  final MovingTask movement;


  EmissaryTask({
    required this.targetPoiId,
    required this.terms,
    required this.movement,
    DateTime? startTime,
  }) : super(
          startTime: startTime ?? movement.startTime,
          durationInSeconds:
              movement.durationInSeconds, // Pass movement's duration
        );

  @override
  DateTime get expectedEndTime => movement.expectedEndTime;
  @override
  String get description => 'Conducting diplomacy at $targetPoiId';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'emissary',
        'targetPoiId': targetPoiId,
        'terms': terms.map((term) => term.name).toList(),
        'movement': movement.toJson(),
        'startTime': startTime.toIso8601String(),
      };

  factory EmissaryTask.fromJson(Map<String, dynamic> json) {
    final movement = MovingTask.fromJson(json['movement']);
    return EmissaryTask(
      targetPoiId: json['targetPoiId'] as String,
      terms: (json['terms'] as List)
          .map(
              (name) => DiplomaticTerm.values.firstWhere((e) => e.name == name))
          .toList(),
      movement: movement,
      startTime: DateTime.parse(json['startTime']),
    );
  }
}



class EscortTask extends AravtTask {
  final String targetAravtGroupId; // The ID of the group being escorted
  // An escort's path and end time are dictated by their target

  EscortTask({
    required this.targetAravtGroupId,
    DateTime? startTime,
  }) : super(
          startTime: startTime,
          durationInSeconds: double.maxFinite, // Escorts don't end on their own
        );

  @override
  DateTime get expectedEndTime => DateTime.now().add(const Duration(days: 999));
  @override
  String get description => 'Escorting group $targetAravtGroupId';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'escort',
        'targetAravtGroupId': targetAravtGroupId,
        'startTime': startTime.toIso8601String(),
        // durationInSeconds is not saved, it's always max
      };

  factory EscortTask.fromJson(Map<String, dynamic> json) {
    return EscortTask(
      targetAravtGroupId: json['targetAravtGroupId'] as String,
      startTime: DateTime.parse(json['startTime']),
    );
  }
}


/// Finds an AravtAssignment by its string name, or returns a fallback.
AravtAssignment assignmentFromName(String? name,
    [AravtAssignment fallback = AravtAssignment.Rest]) {
  if (name == null) return fallback;
  for (final value in AravtAssignment.values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}
