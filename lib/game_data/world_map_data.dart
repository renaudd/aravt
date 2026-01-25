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

import 'dart:math';
import 'package:flutter/material.dart'; // For IconData
import '../models/area_data.dart'; // Ensure this imports GameArea, HexCoordinates, AreaType, PoiType
import '../models/assignment_data.dart';
import 'dart:ui' show Offset;
import 'package:aravt/game_data/poi_names.dart';

class WorldMapDatabase {
  final Random _random = Random();
  int _poiIdCounter = 0;

  String _getUniquePoiId(String prefix) {
    _poiIdCounter++;
    return 'poi_${prefix}_$_poiIdCounter';
  }

  Map<String, GameArea> generateLakeBaikalRegion() {
    _poiIdCounter = 0;
    Map<String, GameArea> worldMap = {};
    const int radius = 3;

    Map<String, dynamic> _getAreaProperties(HexCoordinates coords) {
      final double distance = sqrt(coords.q * coords.q +
              coords.r * coords.r +
              (coords.q + coords.r) * (coords.q + coords.r)) /
          2;
      if (coords.q == 0 && coords.r == 0) {
        return {
          'type': AreaType.Plains,
          'terrain': 'Grassland',
          'name': 'Central Steppe'
        };
      }
      if (distance < 1.5) {
        if (_random.nextDouble() < 0.3)
          return {
            'type': AreaType.Forest,
            'terrain': 'Light Forest',
            'name': 'Forested Hills'
          };
        if (_random.nextDouble() < 0.6)
          return {
            'type': AreaType.Plains,
            'terrain': 'Open Steppe',
            'name': 'Rolling Steppe'
          };
        return {
          'type': AreaType.River,
          'terrain': 'Riverbend',
          'name': 'Riverbend Fields'
        };
      } else if (distance < 2.5) {
        if (_random.nextDouble() < 0.4)
          return {
            'type': AreaType.Mountain,
            'terrain': 'Rocky Foothills',
            'name': 'Mountain Foothills'
          };
        if (_random.nextDouble() < 0.7)
          return {
            'type': AreaType.Forest,
            'terrain': 'Dense Forest',
            'name': 'Deep Woods'
          };
        return {
          'type': AreaType.Plains,
          'terrain': 'Wide Plains',
          'name': 'Vast Plains'
        };
      } else {
        if (_random.nextDouble() < 0.2)
          return {
            'type': AreaType.Lake,
            'terrain': 'Lake Shore',
            'name': 'Baikal Shore'
          };
        if (_random.nextDouble() < 0.5)
          return {
            'type': AreaType.Mountain,
            'terrain': 'Rugged Mountains',
            'name': 'High Peaks'
          };
        if (_random.nextDouble() < 0.8)
          return {
            'type': AreaType.Tundra,
            'terrain': 'Frozen Tundra',
            'name': 'Cold Tundra'
          };
        return {
          'type': AreaType.Steppe,
          'terrain': 'Arid Steppe',
          'name': 'Dry Steppe'
        };
      }
    }

    List<Offset> _createPoiSlots() {
      final List<Offset> slots = [
        Offset(0.5, 0.5),
        Offset(0.3, 0.3),
        Offset(0.7, 0.3),
        Offset(0.3, 0.7),
        Offset(0.7, 0.7),
      ];
      slots.shuffle(_random);
      return slots;
    }

    Offset _getNextOffset(List<Offset> slots) {
      if (slots.isEmpty) {
        return Offset(
            _random.nextDouble() * 0.4 + 0.3, _random.nextDouble() * 0.4 + 0.3);
      }
      return slots.removeLast();
    }

    for (int q = -radius; q <= radius; q++) {
      int r1 = max(-radius, -q - radius);
      int r2 = min(radius, -q + radius);
      for (int r = r1; r <= r2; r++) {
        final coords = HexCoordinates(q, r);
        final properties = _getAreaProperties(coords);

        final String id = 'area_${coords.q}_${coords.r}';
        final String name = properties['name'];
        final AreaType type = properties['type'];
        final String terrain = properties['terrain'];

        String backgroundImagePath;
        IconData? icon;
        switch (type) {
          case AreaType.Forest:
            backgroundImagePath = 'assets/backgrounds/forest_bg.jpg';
            icon = Icons.forest;
            break;
          case AreaType.Mountain:
            backgroundImagePath = 'assets/backgrounds/mountain_bg.jpg';
            icon = Icons.landscape;
            break;
          case AreaType.Lake:
            backgroundImagePath = 'assets/backgrounds/lake_bg.jpg';
            icon = Icons.waves;
            break;
          case AreaType.River:
            backgroundImagePath = 'assets/backgrounds/river_bg.jpg';
            icon = Icons.waves;
            break;
          case AreaType.Plains:
            backgroundImagePath = 'assets/backgrounds/plains_bg.jpg';
            icon = Icons.grass;
            break;
          case AreaType.Steppe:
            backgroundImagePath = 'assets/backgrounds/steppe_bg.jpg';
            icon = Icons.grain;
            break;
          case AreaType.Desert:
            backgroundImagePath = 'assets/backgrounds/desert_bg.jpg';
            icon = Icons.filter_hdr;
            break;
          case AreaType.Swamp:
            backgroundImagePath = 'assets/backgrounds/swamp_bg.jpg';
            icon = Icons.water;
            break;
          case AreaType.Tundra:
            backgroundImagePath = 'assets/backgrounds/tundra_bg.jpg';
            icon = Icons.ac_unit;
            break;
          case AreaType.Settlement:
            backgroundImagePath = 'assets/backgrounds/settlement_bg.jpg';
            icon = Icons.location_city;
            break;
          case AreaType.PlayerCamp:
          case AreaType.NpcCamp:
            backgroundImagePath = 'assets/backgrounds/plains_bg.jpg';
            icon = Icons.house; // Or fort
            break;
          case AreaType.Neutral:
          default:
            backgroundImagePath = 'assets/backgrounds/default_bg.jpg';
            icon = Icons.help;
            break;
        }

        // --- PROCEDURAL POI GENERATION ---
        List<PointOfInterest> pois = [];
        List<Offset> poiOffsets = _createPoiSlots();
        int numPois = 1 + _random.nextInt(4);

        for (int i = 0; i < numPois; i++) {
          if (poiOffsets.isEmpty) break;
          var offset = _getNextOffset(poiOffsets);

          switch (type) {
            case AreaType.Forest:
              if (_random.nextBool()) {
                pois.add(PointOfInterest(
                    id: _getUniquePoiId('woods'),
                    name: PoiNames
                        .forests[_random.nextInt(PoiNames.forests.length)],
                    type: PoiType.resourceNode,
                    position: coords,
                    icon: Icons.forest,
                    relativeX: offset.dx,
                    relativeY: offset.dy,
                    isDiscovered: false,
                    availableAssignments: [
                      AravtAssignment.ChopWood,
                      AravtAssignment.Hunt,
                      AravtAssignment.Forage,
                      AravtAssignment.Scout
                    ]));
              } else {
                pois.add(PointOfInterest(
                    id: _getUniquePoiId('hunt'),
                    name: PoiNames
                        .forests[_random.nextInt(PoiNames.forests.length)],
                    type: PoiType.resourceNode,
                    position: coords,
                    icon: Icons.pets,
                    relativeX: offset.dx,
                    relativeY: offset.dy,
                    isDiscovered: false,
                    isSeasonal: true,
                    availableAssignments: [
                      AravtAssignment.Hunt,
                      AravtAssignment.Forage,
                      AravtAssignment.Patrol
                    ]));
              }
              break;
            case AreaType.Mountain:
              pois.add(PointOfInterest(
                  id: _getUniquePoiId('mine'),
                  name: PoiNames
                      .mountains[_random.nextInt(PoiNames.mountains.length)],
                  type: PoiType.resourceNode,
                  position: coords,
                  icon: Icons.filter_hdr,
                  relativeX: offset.dx,
                  relativeY: offset.dy,
                  isDiscovered: false,
                  availableAssignments: [
                    AravtAssignment.Mine,
                    AravtAssignment.Scout,
                    AravtAssignment.Patrol
                  ]));
              break;
            case AreaType.Lake:
            case AreaType.River:
              pois.add(PointOfInterest(
                  id: _getUniquePoiId('fish'),
                  name:
                      PoiNames.waters[_random.nextInt(PoiNames.waters.length)],
                  type: PoiType.resourceNode,
                  position: coords,
                  icon: Icons.waves,
                  relativeX: offset.dx,
                  relativeY: offset.dy,
                  isDiscovered: false,
                  isSeasonal: true,
                  availableAssignments: [
                    AravtAssignment.Fish,
                    AravtAssignment.GatherWater,
                    AravtAssignment.Forage
                  ]));
              break;
            case AreaType.Plains:
            case AreaType.Steppe:
              pois.add(PointOfInterest(
                  id: _getUniquePoiId('plains'),
                  name:
                      PoiNames.plains[_random.nextInt(PoiNames.plains.length)],
                  type: PoiType.resourceNode,
                  position: coords,
                  icon: Icons.grass,
                  relativeX: offset.dx,
                  relativeY: offset.dy,
                  isDiscovered: false,
                  isSeasonal: true,
                  availableAssignments: [
                    AravtAssignment.Shepherd,
                    AravtAssignment.Hunt,
                    AravtAssignment.Forage,
                    AravtAssignment.Patrol
                  ]));
              break;
            default:
              pois.add(PointOfInterest(
                  id: _getUniquePoiId('wilds'),
                  name: 'Wilderness',
                  type: PoiType.landmark,
                  position: coords,
                  icon: icon ?? Icons.landscape,
                  relativeX: offset.dx,
                  relativeY: offset.dy,
                  isDiscovered: false,
                  availableAssignments: [
                    AravtAssignment.Scout,
                    AravtAssignment.Patrol,
                    AravtAssignment.Forage
                  ]));
              break;
          }
        }

        if (pois.isEmpty) {
          var offset = _getNextOffset(poiOffsets);
          pois.add(PointOfInterest(
              id: _getUniquePoiId('wilds_fallback'),
              name: 'Wilderness',
              type: PoiType.landmark,
              position: coords,
              icon: Icons.landscape,
              relativeX: offset.dx,
              relativeY: offset.dy,
              isDiscovered: false,
              availableAssignments: [
                AravtAssignment.Scout,
                AravtAssignment.Patrol,
                AravtAssignment.Forage
              ]));
        }

        worldMap[coords.toString()] = GameArea(
          id: id,
          name: name,
          coordinates: coords,
          backgroundImagePath: backgroundImagePath,
          icon: icon,
          type: type,
          terrain: terrain,
          pointsOfInterest: pois,
        );
      }
    }

    // Settlement placement is handled in GameSetupService,
    // but we ensure the base map supports it.
    return worldMap;
  }
}
