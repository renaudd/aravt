/// Defines the data structures for representing an Aravt's location.
library;

/// Represents the type of location an Aravt can be at.
enum LocationType {
  /// The Aravt is at a specific Point of Interest (e.g., "Northern Pastures").
  poi,

  /// The Aravt is at a Settlement (e.g., "Ger").
  settlement,
}

/// A data class to hold a specific location, combining a type and an ID.
class GameLocation {
  final LocationType type;
  final String id;

  GameLocation({
    required this.type,
    required this.id,
  });

  /// Creates a location pointing to a Point of Interest.
  factory GameLocation.poi(String poiId) {
    return GameLocation(type: LocationType.poi, id: poiId);
  }

  /// Creates a location pointing to a Settlement.
  factory GameLocation.settlement(String settlementId) {
    return GameLocation(type: LocationType.settlement, id: settlementId);
  }

  @override
  String toString() {
    return 'GameLocation(type: $type, id: $id)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameLocation && other.type == type && other.id == id;
  }

  @override
  int get hashCode => type.hashCode ^ id.hashCode;
}

