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

/// Defines the data structures for representing an Aravt's location.
library;

/// Represents the type of location an Aravt can be at.
enum LocationType {
  /// The Aravt is at a specific Point of Interest (e.g., "Northern Pastures").
  poi,

  /// The Aravt is at a Settlement (e.g., "Ger").
  settlement,

  /// The Aravt is at a Game Area (e.g., "Green Steppe").
  area,
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

  /// Creates a location pointing to a Game Area.
  factory GameLocation.area(String areaId) {
    return GameLocation(type: LocationType.area, id: areaId);
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
