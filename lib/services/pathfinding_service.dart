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
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/horde_data.dart'; // Correct import for Aravt

/// Represents a node in the pathfinding grid
class _HexNode {
  final HexCoordinates coordinates;
  double gCost; // Cost from start to this node
  double hCost; // Heuristic cost from this node to end
  _HexNode? parent; // Node we came from

  _HexNode(this.coordinates,
      {this.gCost = double.infinity,
      this.hCost = double.infinity,
      this.parent});

  double get fCost => gCost + hCost; // Total cost

  @override
  bool operator ==(Object other) =>
      other is _HexNode && coordinates == other.coordinates;
  @override
  int get hashCode => coordinates.hashCode;
}

class PathfindingService {
  /// Calculates the "cost" in days to cross a single hex.
  /// This is the base cost, not accounting for weather or Aravt speed.
  double _getMovementCost(GameArea area) {
    switch (area.type) {
      case AreaType.Mountain:
        return 5.0; // 5 days
      case AreaType.Forest:
        return 3.0; // 3 days
      case AreaType.Lake:
        return 2.0; // 2 days (circumnavigate)
      case AreaType.River:
        return 1.5; // 1 day + 0.5 for crossing

      // Grassland, Plains, Steppe, etc.
      case AreaType.Plains:
      case AreaType.Settlement:
      case AreaType.PlayerCamp:
      case AreaType.NpcCamp:
      case AreaType.Neutral:
        return 1.0; // 1 day

      // Other difficult terrains
      case AreaType.Desert:
      case AreaType.Swamp:
      case AreaType.Tundra:
        return 2.0; // 2 days for other difficult terrain

      default:
        return 1.0;
    }
  }

  /// Calculates the final travel cost per hex, modified by Aravt stats.
  /// Returns a value in "days per hex".
  double calculateTravelCost(
      Aravt aravt, List<Soldier> soldiers, GameArea area) {

    double baseCost = _getMovementCost(area);

    // --- TODO: Implement modifier logic ---
    // 1. Get average soldier health, exhaustion, stats
    // 2. Check mount status (encumbrance, health)
    // 3. Check weather

    // Example placeholder:
    // double soldierModifier = 1.0; // 1.0 = no effect
    // double encumbranceModifier = aravt.cargo.isNotEmpty ? 1.5 : 1.0; // 50% slower if carrying cargo
    // double weatherModifier = 1.0; // 1.0 = clear skies

    // return baseCost * soldierModifier * encumbranceModifier * weatherModifier;

    return baseCost; // Return base cost for now
  }

  /// Finds the optimal path from start to destination using A* algorithm.
  /// Returns a list of HexCoordinates representing the route, or an empty list if no path is found.
  List<HexCoordinates> findPath(HexCoordinates start,
      HexCoordinates destination, Map<String, GameArea> worldMap) {
    final GameArea? startArea = worldMap[start.toString()];
    final GameArea? endArea = worldMap[destination.toString()];

    if (startArea == null || endArea == null) {
      print("Pathfinding Error: Start or End area is null.");
      return []; // No path if start/end doesn't exist
    }

    final _HexNode startNode = _HexNode(start,
        gCost: 0, hCost: start.distanceTo(destination).toDouble());

    // Use a List and sort it to act as a Priority Queue
    final List<_HexNode> openList = [startNode];
    final Set<HexCoordinates> closedList = {};

    while (openList.isNotEmpty) {
      // 1. Find the node with the lowest fCost in the open list
      openList.sort((a, b) => a.fCost.compareTo(b.fCost));
      _HexNode currentNode = openList.removeAt(0);

      // 2. Move current node to closed list
      closedList.add(currentNode.coordinates);

      // 3. Check if we reached the destination
      if (currentNode.coordinates == destination) {
        return _reconstructPath(currentNode);
      }

      // 4. Process neighbors
      final List<HexCoordinates> neighbors =
          currentNode.coordinates.getNeighbors();

      for (final neighborCoords in neighbors) {
        // A. Check if neighbor is in closed list
        if (closedList.contains(neighborCoords)) {
          continue;
        }

        // B. Check if neighbor is walkable (i.e., exists in the world map)
        final GameArea? neighborArea = worldMap[neighborCoords.toString()];
        if (neighborArea == null) {
          continue; // Not a valid map hex
        }

        // C. Calculate costs
        // Using a simple movement cost for now. This can be expanded with Aravt speed.
        double tentativeGCost =
            currentNode.gCost + _getMovementCost(neighborArea);

        // D. Check if this path is better
        _HexNode neighborNode = openList.firstWhere(
            (node) => node.coordinates == neighborCoords,
            orElse: () =>
                _HexNode(neighborCoords) // Create new node if not in open list
            );

        if (tentativeGCost < neighborNode.gCost) {
          // This is a better path. Record it.
          neighborNode.parent = currentNode;
          neighborNode.gCost = tentativeGCost;
          neighborNode.hCost =
              neighborCoords.distanceTo(destination).toDouble();

          if (!openList.contains(neighborNode)) {
            openList.add(neighborNode);
          }
        }
      }
    }

    // No path found
    print("Pathfinding Error: No path found from $start to $destination.");
    return [];
  }

  /// Reconstructs the path from the end node back to the start.
  List<HexCoordinates> _reconstructPath(_HexNode endNode) {
    final List<HexCoordinates> path = [];
    _HexNode? currentNode = endNode;
    while (currentNode != null) {
      path.add(currentNode.coordinates);
      currentNode = currentNode.parent;
    }
    return path.reversed.toList();
  }
}
