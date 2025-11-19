// lib/models/area_data.dart

import 'package:aravt/models/assignment_data.dart';
import 'package:flutter/material.dart'; // For IconData
import 'package:uuid/uuid.dart'; // For generating unique IDs
import 'dart:math';

// ... (AreaType enum is unchanged) ...
enum AreaType {
  Plains,
  Forest,
  Mountain,
  Lake,
  River,
  Desert,
  Steppe,
  Swamp,
  Tundra,
  Settlement,
  PlayerCamp,
  NpcCamp,
  Neutral,
}

/// Represents a point of interest within a GameArea.
class PointOfInterest {
  final String id;
  final String name;
  final String description;
  final PoiType type;
  final List<String> assignedAravtIds;
  final IconData? icon;

  final double relativeX;
  final double relativeY;

  final HexCoordinates position;
  final List<AravtAssignment> availableAssignments;
  
  // --- UPDATED FOR FOG OF WAR ---
  bool isDiscovered; 

  // --- NEW FOR DESTRUCTIBLE POIS (Your Request) ---
  final int? maxResources; // e.g., 1000 wood
  int? currentResources;   // e.g., 450 wood remaining
  final bool isSeasonal;      // True for hunting, fishing, grazing
  // --- END NEW ---

  PointOfInterest({
    String? id,
    required this.name,
    this.description = '',
    required this.type,
    List<String>? assignedAravtIds,
    this.icon,
    this.relativeX = 0.5,
    this.relativeY = 0.5,
    required this.position,
    List<AravtAssignment>? availableAssignments,
    this.isDiscovered = false, // Default to hidden for Fog of War
    // --- NEW: Add to constructor ---
    this.maxResources,
    this.currentResources,
    this.isSeasonal = false,
  }) : this.id = id ?? const Uuid().v4(),
       this.assignedAravtIds = assignedAravtIds ?? [],
       this.availableAssignments = availableAssignments ?? [];

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: PoiType.values.firstWhere(
            (e) => e.toString() == 'PoiType.${json['type']}',
        orElse: () => PoiType.resourceNode,
      ),
      assignedAravtIds: List<String>.from(json['assignedAravtIds'] ?? []),
      icon: json['iconCodePoint'] != null
          ? IconData(json['iconCodePoint'] as int, fontFamily: 'MaterialIcons')
          : null,
      position: HexCoordinates.fromJson(json['position']),
      availableAssignments: (json['availableAssignments'] as List? ?? [])
          .map((name) => AravtAssignment.values.firstWhere(
                (e) => e.name == name,
                orElse: () => AravtAssignment.Rest,
              ))
          .toList(),
      // --- UPDATED: Load new fields ---
      // Default to true so old saves don't break
      isDiscovered: json['isDiscovered'] as bool? ?? true, 
      maxResources: json['maxResources'] as int?,
      currentResources: json['currentResources'] as int?,
      isSeasonal: json['isSeasonal'] as bool? ?? false,
      // --- END UPDATED ---
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'assignedAravtIds': assignedAravtIds,
      'iconCodePoint': icon?.codePoint,
      'position': position.toJson(),
      'availableAssignments': availableAssignments.map((e) => e.name).toList(),
      // --- UPDATED: Save new fields ---
      'isDiscovered': isDiscovered,
      'maxResources': maxResources,
      'currentResources': currentResources,
      'isSeasonal': isSeasonal,
      // --- END UPDATED ---
    };
  }

  PointOfInterest copyWith({
    String? id,
    String? name,
    String? description,
    PoiType? type,
    List<String>? assignedAravtIds,
    IconData? icon,
    // --- NEW: Add relativeX and relativeY ---
    double? relativeX,
    double? relativeY,
    // --- END NEW ---
    HexCoordinates? position,
    List<AravtAssignment>? availableAssignments,
    bool? isDiscovered,
    // --- NEW: Add to copyWith ---
    int? maxResources,
    int? currentResources,
    bool? isSeasonal,
  }) {
    return PointOfInterest(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      assignedAravtIds: assignedAravtIds ?? List.from(this.assignedAravtIds),
      icon: icon ?? this.icon,
      // --- NEW: Pass them to the constructor ---
      relativeX: relativeX ?? this.relativeX,
      relativeY: relativeY ?? this.relativeY,
      // --- END NEW ---
      position: position ?? this.position,
      availableAssignments: availableAssignments ?? List.from(this.availableAssignments),
      isDiscovered: isDiscovered ?? this.isDiscovered,
      // --- NEW ---
      maxResources: maxResources ?? this.maxResources,
      currentResources: currentResources ?? this.currentResources,
      isSeasonal: isSeasonal ?? this.isSeasonal,
    );
  }
}

// ... (PoiType, HexCoordinates, and GameArea classes are unchanged) ...
// ... (Your existing code for PoiType, HexCoordinates, and GameArea) ...
enum PoiType {
  resourceNode,
  camp,
  enemyCamp,
  settlement,
  questGiver,
  landmark,
  specialEncounter,
}

@immutable
class HexCoordinates {
  final int q; // column
  final int r; // row
  const HexCoordinates(this.q, this.r);
  // ... (rest of HexCoordinates is unchanged) ...
  static const List<HexCoordinates> directions = [
    HexCoordinates(1, 0),
    HexCoordinates(0, 1),
    HexCoordinates(-1, 1),
    HexCoordinates(-1, 0),
    HexCoordinates(0, -1),
    HexCoordinates(1, -1),
  ];
  List<HexCoordinates> getNeighbors() {
    return directions.map((dir) => HexCoordinates(q + dir.q, r + dir.r)).toList();
  }
  int get s => -q - r;
  int get length => (q.abs() + r.abs() + s.abs()) ~/ 2;
  int distanceTo(HexCoordinates other) {
    final dq = (q - other.q).abs();
    final dr = (r - other.r).abs();
    final ds = ((q - other.q) + (r - other.r) + (s - other.s)).abs(); // s component
    return (dq + dr + ds) ~/ 2;
  }
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HexCoordinates &&
              runtimeType == other.runtimeType &&
              q == other.q &&
              r == other.r;
  @override
  int get hashCode => q.hashCode ^ r.hashCode;
  @override
  String toString() => 'Hex(q:$q, r:$r)';
  factory HexCoordinates.fromJson(Map<String, dynamic> json) {
    return HexCoordinates(
      json['q'] as int,
      json['r'] as int,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'q': q,
      'r': r,
    };
  }
}

class GameArea {
  final String id;
  String terrain;
  String backgroundImagePath;
  final HexCoordinates coordinates;
  AreaType type;
  String name;
  String description;
  List<PointOfInterest> pointsOfInterest;
  bool isExplored;
  IconData? icon;
  GameArea({
    required this.id,
    required this.coordinates,
    this.type = AreaType.Neutral,
    String? name,
    this.description = '',
    List<PointOfInterest>? pointsOfInterest,
    this.isExplored = false,
    this.icon,
    this.terrain = 'Plains',
    this.backgroundImagePath = 'assets/backgrounds/default_bg.jpg',
  }) : this.name = name ?? _generateDefaultName(type),
       this.pointsOfInterest = pointsOfInterest ?? [];
  static String _generateDefaultName(AreaType type) {
    switch (type) {
      case AreaType.Plains: return "Grassy Plains";
      case AreaType.Forest: return "Dense Forest";
      case AreaType.Mountain: return "Rugged Mountain";
      case AreaType.Lake: return "Crystal Lake";
      case AreaType.River: return "Winding River";
      case AreaType.Desert: return "Scorched Desert";
      case AreaType.Swamp: return "Murky Swamp";
      case AreaType.Tundra: return "Frozen Tundra";
      case AreaType.Settlement: return "Settlement";
      case AreaType.PlayerCamp: return "Player Camp";
      case AreaType.NpcCamp: return "Nomad Camp";
      case AreaType.Neutral:
      default: return "Wilderness";
    }
  }
  PointOfInterest? findPoiById(String id) {
    try {
      return pointsOfInterest.firstWhere((poi) => poi.id == id);
    } catch (e) {
      return null;
    }
  }
  factory GameArea.fromJson(Map<String, dynamic> json) {
    return GameArea(
      id: json['id'] as String,
      coordinates: HexCoordinates.fromJson(json['coordinates']),
      type: AreaType.values.firstWhere(
            (e) => e.toString() == 'AreaType.${json['type']}',
        orElse: () => AreaType.Neutral,
      ),
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      pointsOfInterest: (json['pointsOfInterest'] as List? ?? [])
          .map((e) => PointOfInterest.fromJson(e as Map<String, dynamic>))
          .toList(),
      isExplored: json['isExplored'] as bool? ?? false,
      icon: json['iconCodePoint'] != null
          ? IconData(json['iconCodePoint'] as int, fontFamily: 'MaterialIcons')
          : null,
      terrain: json['terrain'] as String? ?? 'Plains',
      backgroundImagePath: json['backgroundImagePath'] as String? ?? 'assets/backgrounds/default_bg.jpg',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coordinates': coordinates.toJson(),
      'type': type.name,
      'name': name,
      'description': description,
      'pointsOfInterest': pointsOfInterest.map((e) => e.toJson()).toList(),
      'isExplored': isExplored,
      'iconCodePoint': icon?.codePoint,
      'terrain': terrain,
      'backgroundImagePath': backgroundImagePath,
    };
  }
  GameArea copyWith({
    String? id,
    HexCoordinates? coordinates,
    AreaType? type,
    String? name,
    String? description,
    List<PointOfInterest>? pointsOfInterest,
    bool? isExplored,
    IconData? icon,
    String? terrain,
    String? backgroundImagePath,
  }) {
    return GameArea(
      id: id ?? this.id,
      coordinates: coordinates ?? this.coordinates,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      pointsOfInterest: pointsOfInterest ?? List.from(this.pointsOfInterest),
      isExplored: isExplored ?? this.isExplored,
      icon: icon ?? this.icon,
      terrain: terrain ?? this.terrain,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
    );
  }
}

