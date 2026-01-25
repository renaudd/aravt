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

// lib/widgets/hex_map_tile.dart

import '../models/area_data.dart'; // For GameArea and HexCoordinates

/// Helper to map AreaType to its new tile image path.
/// Assumes tiles are in 'assets/tiles/'
String getTileImagePath(GameArea area, {bool isExplored = true}) {
  if (!isExplored) {
    // You will need to create a 'fog_tile.png' image in your assets/tiles/ folder
    return 'assets/tiles/fog_tile.png';
  }

  // Handle special cases first
  if (area.type == AreaType.Settlement) {
    return 'assets/tiles/grassland_with_settlement_tile.png';
  }
  if (area.type == AreaType.PlayerCamp || area.type == AreaType.NpcCamp) {
    // TODO: Create a "camp" tile. Using grassland for now.
    return 'assets/tiles/grassland_tile.png';
  }

  // Handle terrain types
  switch (area.type) {
    case AreaType.Forest:
      return 'assets/tiles/forest_tile.png';
    case AreaType.Mountain:
      return 'assets/tiles/mountain_tile.png'; // Corrected path
    case AreaType.River:
      return 'assets/tiles/river_tile.png';
    case AreaType.Lake:
      return 'assets/tiles/lake_tile.png';

    // TODO: Add tiles for these as well
    case AreaType.Steppe:
    case AreaType.Plains:
    case AreaType.Neutral:
    case AreaType.Desert:
    case AreaType.Swamp:
    case AreaType.Tundra:
    default:
      // Default to grassland tile
      return 'assets/tiles/grassland_tile.png';
  }
}
