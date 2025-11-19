// import 'area_data.dart'; // --- REMOVED: No longer need HexCoordinates
import 'inventory_item.dart'; // For TradeTask cargo
import 'location_data.dart'; // --- NEW: For GameLocation

// --- NEW: Enum for all Emissary actions ---
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
// --- END NEW ---

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

  // --- NEW: Internal Task Type ---
  Travel, // Represents the state of being in a MovingTask
}

/// Represents the state of an Aravt group's current task or movement.
abstract class AravtTask {
  final DateTime startTime;
  final double durationInSeconds; // --- MOVED: Now in base class ---

  // --- UPDATED: Now uses durationInSeconds from base class ---
  DateTime get expectedEndTime =>
      startTime.add(Duration(seconds: durationInSeconds.toInt()));
  String get description;

  AravtTask({
    DateTime? startTime,
    required this.durationInSeconds, // --- MOVED: Now in base class ---
  }) : startTime = startTime ?? DateTime.now();

  bool isCompleted(DateTime currentTime) {
    return currentTime.isAfter(expectedEndTime);
  }

  Map<String, dynamic> toJson();
  factory AravtTask.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'moving':
        return MovingTask.fromJson(json);
      case 'assigned':
        return AssignedTask.fromJson(json);
      // --- NEW TASK TYPES ---
      case 'trade':
        return TradeTask.fromJson(json);
      case 'emissary':
        return EmissaryTask.fromJson(json);
      case 'escort':
        return EscortTask.fromJson(json);
      // --- END NEW ---
      default:
        throw ArgumentError('Unknown task type: ${json['type']}');
    }
  }
}

/// A task for moving an Aravt group from one location to another.
class MovingTask extends AravtTask {
  final GameLocation destination;

  // --- NEW: For follow-up commands ---
  final AravtAssignment? followUpAssignment;
  final String? followUpAreaId; // For area-level follow-ups (Scout, Patrol)
  final String? followUpPoiId;  // For POI-level follow-ups (Hunt, etc.)
  // --- END NEW ---

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
    // --- NEW: Add follow-up fields to constructor ---
    this.followUpAssignment,
    this.followUpAreaId,
    this.followUpPoiId,
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
        // --- NEW: Save follow-up fields ---
        'followUpAssignment': followUpAssignment?.name,
        'followUpAreaId': followUpAreaId,
        'followUpPoiId': followUpPoiId,
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
      // --- NEW: Load follow-up fields ---
      followUpAssignment: json['followUpAssignment'] != null
          ? assignmentFromName(json['followUpAssignment'])
          : null,
      followUpAreaId: json['followUpAreaId'] as String?,
      followUpPoiId: json['followUpPoiId'] as String?,
    );
  }
}

/// A task for an Aravt group assigned to a Point of Interest.
class AssignedTask extends AravtTask {
  final String? areaId;
  final String? poiId;

  final AravtAssignment assignment;

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
    required double durationInSeconds, 
    DateTime? startTime,
  })  : 
        super(
          startTime: startTime,
          durationInSeconds: durationInSeconds, // Pass to super
        );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'assigned',
        // --- UPDATED ---
        'areaId': areaId,
        'poiId': poiId,
        // --- END UPDATED ---
        'assignment': assignment.name,
        'durationInSeconds': durationInSeconds,
        'startTime': startTime.toIso8601String(),
      };

  factory AssignedTask.fromJson(Map<String, dynamic> json) {
    // --- UPDATED: Handle new fields and backwards compatibility ---
    final String? loadedPoiId = json['poiId'] as String?;
    final String? loadedAreaId = json['areaId'] as String?;

    return AssignedTask(
      // If areaId is null (old save), we'll rely on poiId.
      // If poiId is also null (new area-level task), that's fine.
      areaId: loadedAreaId,
      poiId: loadedPoiId,
      // --- END UPDATED ---
      assignment: AravtAssignment.values.firstWhere(
        (e) => e.name == json['assignment'],
        orElse: () => AravtAssignment.Rest, // Default to Rest if not found
      ),
      durationInSeconds: json['durationInSeconds'] as double,
      startTime: DateTime.parse(json['startTime']), // Pass as named parameter
    );
  }
}

// --- NEW: Trade Task ---
class TradeTask extends AravtTask {
  final String targetPoiId;
  final List<InventoryItem> cargo; // Items being carried for trade
  final MovingTask movement; // The path to get there

  // --- UPDATED: duration is now inherited ---
  TradeTask({
    required this.targetPoiId,
    required this.cargo,
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
      movement: movement,
      startTime: DateTime.parse(json['startTime']),
    );
  }
}
// --- END NEW ---

// --- NEW: Emissary Task ---
class EmissaryTask extends AravtTask {
  final String targetPoiId;
  final List<DiplomaticTerm> terms;
  final MovingTask movement;

  // --- UPDATED: duration is now inherited ---
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
          .map((name) =>
              DiplomaticTerm.values.firstWhere((e) => e.name == name))
          .toList(),
      movement: movement,
      startTime: DateTime.parse(json['startTime']),
    );
  }
}
// --- END NEW ---

// --- NEW: Escort Task ---
class EscortTask extends AravtTask {
  final String targetAravtGroupId; // The ID of the group being escorted
  // An escort's path and end time are dictated by their target

  EscortTask({
    required this.targetAravtGroupId,
    DateTime? startTime,
  }) : super(
          startTime: startTime,
          durationInSeconds:
              double.maxFinite, // Escorts don't end on their own
        );

  @override
  DateTime get expectedEndTime =>
      DateTime.now().add(const Duration(days: 999));
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
// --- END NEW ---

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

