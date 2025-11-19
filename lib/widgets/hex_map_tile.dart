// lib/widgets/hex_map_tile.dart

import 'package:flutter/material.dart';
import 'dart:math';

import '../models/area_data.dart'; // For GameArea and HexCoordinates

/// Helper to map AreaType to its new tile image path.
/// Assumes tiles are in 'assets/tiles/'
String getTileImagePath(GameArea area, {bool isExplored = true}) {
  // --- NEW: Handle fog of war ---
  if (!isExplored) {
    // You will need to create a 'fog_tile.png' image in your assets/tiles/ folder
    return 'assets/tiles/fog_tile.png';
  }
  // --- END NEW ---

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


/// --- REMOVED: HexagonClipper ---
/// We will not use clipping, as your images are already transparent.
/// The border is now handled by the CustomPaint in the map screens.

