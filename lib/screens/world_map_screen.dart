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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import '../providers/game_state.dart';
import '../models/area_data.dart'; // For GameArea and HexCoordinates
import '../widgets/persistent_menu_widget.dart';


import '../widgets/aravt_map_icon.dart';
import '../widgets/hex_map_tile.dart';
import '../models/soldier_data.dart';
import '../models/horde_data.dart';
import '../models/assignment_data.dart';
import '../widgets/aravt_assignment_dialog.dart';
import '../services/ui_assignment_service.dart';

class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: Text('World Map', style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black.withAlpha((255 * 0.5).round()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.pushReplacementNamed(context, '/region');
            }
          },
        ),
      ),
      body: Stack(
        children: [
          _buildWorldMap(context),
          const PersistentMenuWidget(),
        ],
      ),
    );
  }

  IconData _getPoiIcon(PoiType type) {
    switch (type) {
      case PoiType.settlement:
        return Icons.fort;
      case PoiType.camp:
        return Icons.fireplace;
      case PoiType.resourceNode:
        return Icons.circle_outlined;
      case PoiType.landmark:
        return Icons.star_border;
      case PoiType.enemyCamp:
        return Icons.priority_high;
      case PoiType.questGiver:
        return Icons.person_pin;
      case PoiType.specialEncounter:
        return Icons.help_outline;
    }
  }

  List<Widget> _buildPoiIcons(
      GameArea hexArea, double hexRadius, GameState gameState) {
    List<Widget> poiWidgets = [];

    final bool canSeePois = gameState.isOmniscientMode || hexArea.isExplored;
    if (!canSeePois) return [];

    final poiList = hexArea.pointsOfInterest
        .where((p) => p.isDiscovered || gameState.isOmniscientMode);

    for (var poi in poiList) {

      if (poi.type == PoiType.camp) {
        if (hexArea.type == AreaType.PlayerCamp)
          continue; // Player camp is handled differently or not shown here
        if (hexArea.type == AreaType.NpcCamp &&
            !hexArea.isExplored &&
            !gameState.isOmniscientMode) {
          continue; // Hide NPC camp if not explored
        }
      }

      // Pointy-top POI offset math
      final double poiX = (poi.relativeX - 0.5) * (hexRadius * sqrt(3));
      final double poiY = (poi.relativeY - 0.5) * (hexRadius * 1.5);

      poiWidgets.add(
        Transform.translate(
          offset: Offset(poiX, poiY),
          child: Tooltip(
            message: poi.name,
            child: Icon(
              _getPoiIcon(poi.type),
              color: Colors.white,
              size: hexRadius * 0.3, // Small icon
              shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
            ),
          ),
        ),
      );
    }
    return poiWidgets;
  }

  //  Helper to build animated Aravt icons
  List<Widget> _buildAravtIcons(
      GameArea hexArea, double hexRadius, GameState gameState) {
    List<Widget> aravtWidgets = [];

    // Find all player aravts in this specific hex
    final aravtsInHex = gameState.aravts
        .where((aravt) => aravt.hexCoords == hexArea.coordinates)
        .toList();

    int i = 0;
    for (var aravt in aravtsInHex) {
      // Simple offset logic to prevent stacking
      final double aravtX = (i * 0.1 - 0.2) * (hexRadius * sqrt(3));
      final double aravtY = (0.2) * (hexRadius * 1.5);
      i++;

      aravtWidgets.add(
        Transform.translate(
          offset: Offset(aravtX, aravtY),
          child: Tooltip(
            message:
                "Aravt: ${gameState.findSoldierById(aravt.captainId)?.name ?? 'Unknown'}",
            child: AravtMapIcon(
              color: 'blue', // TODO: randomize this based on captain/horde
              scale:
                  0.75,
            ),
          ),
        ),
      );
    }
    return aravtWidgets;
  }

  Widget _buildWorldMap(BuildContext context) {
    final gameState = context.watch<GameState>();
    final allAreas = gameState.worldMap.values.toList();

    if (allAreas.isEmpty) {
      return Center(
        child: Text('World Map is empty.', style: GoogleFonts.cinzel()),
      );
    }

    int minQ = 0, maxQ = 0, minR = 0, maxR = 0;
    for (var area in allAreas) {
      minQ = min(minQ, area.coordinates.q);
      maxQ = max(maxQ, area.coordinates.q);
      minR = min(minR, area.coordinates.r);
      maxR = max(maxR, area.coordinates.r);
    }
    final int qRange = (maxQ - minQ).abs() + 1;
    final int rRange = (maxR - minR).abs() + 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Pointy-top layout math
        final double mapHexWidth = qRange + (rRange / 2);
        final double mapHexHeight = rRange * 0.75;

        final double radiusFromWidth =
            constraints.maxWidth / (mapHexWidth * sqrt(3));
        final double radiusFromHeight =
            constraints.maxHeight / (mapHexHeight * 2);

        final double hexRadius = min(radiusFromWidth, radiusFromHeight);

        final double hexWidth = sqrt(3) * hexRadius;
        final double hexHeight = 2 * hexRadius;
        final Offset centerOffset =
            Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            ...allAreas.map((hexArea) {
            final HexCoordinates coords = hexArea.coordinates;

            // Pointy-top layout positions
            final double x =
                centerOffset.dx + hexWidth * (coords.q + coords.r / 2);
            final double y = centerOffset.dy + hexHeight * 3 / 4 * (coords.r);

            final bool isExplored =
                hexArea.isExplored || gameState.isOmniscientMode;

              // Determine if this is a neighbor of the caravan (for movement)
              bool isCaravanNeighbor = false;
              if (gameState.isCaravanMode &&
                  gameState.caravanPosition != null) {
                isCaravanNeighbor =
                    gameState.caravanPosition!.distanceTo(coords) == 1;
              }

            return Positioned(
              left: x - (hexWidth / 2),
              top: y - (hexHeight / 2),
              width: hexWidth,
              height: hexHeight,
              child: GestureDetector(

                onTap: () {
                    if (gameState.isCaravanMode &&
                        gameState.caravanPosition != null) {
                      if (coords == gameState.caravanPosition) {
                        // Establish Camp
                        _showEstablishCampDialog(context, gameState, coords);
                        return;
                      }
                      if (isCaravanNeighbor) {
                        // Move Caravan
                        _showMoveCaravanDialog(context, gameState, coords);
                        return;
                      }
                    }

                  if (!isExplored) {
                    // For unexplored, just select it (maybe show a tooltip)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unexplored Area. Long press to Scout.',
                            style: GoogleFonts.cinzel(color: Colors.amber)),
                        backgroundColor: Colors.blueGrey[900],
                      ),
                    );
                    return;
                  }
                  gameState.setCurrentArea(hexArea.coordinates);
                  Navigator.pushReplacementNamed(context, '/region');
                },

                onLongPress: () {
                  _showAreaAssignmentDialog(context, hexArea, gameState);
                },
                onSecondaryTap: () {
                  _showAreaAssignmentDialog(context, hexArea, gameState);
                },
                child: Tooltip(
                  message: isExplored
                      ? '${hexArea.name} (${hexArea.type.name})'
                      : 'Unexplored Area',
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        getTileImagePath(hexArea, isExplored: isExplored),
                        width: hexWidth,
                        height: hexHeight,
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: hexWidth,
                            height: hexHeight,
                            color: Colors.red.shade900,
                            child:
                                const Center(child: Icon(Icons.error_outline)),
                          );
                        },
                      ),
                      if (isExplored)
                        FittedBox(
                          fit: BoxFit.contain,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                hexArea.name,
                                style: GoogleFonts.cinzel(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: hexRadius * 0.3,
                                  shadows: [
                                    const Shadow(
                                        blurRadius: 4, color: Colors.black)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      // POI Icons
                      ..._buildPoiIcons(hexArea, hexRadius, gameState),
                        // Aravt Icons (Hide if Caravan Mode and at Caravan Pos)
                        if (!gameState.isCaravanMode ||
                            gameState.caravanPosition != coords)
                          ..._buildAravtIcons(hexArea, hexRadius, gameState),
                      
                        // Highlight Caravan Neighbors
                        if (isCaravanNeighbor)
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.5),
                                  width: 2),
                            ),
                          ),

                      // Border
                      CustomPaint(
                        painter: HexBorderPainter(
                          color: (gameState.currentArea?.coordinates ==
                                  hexArea.coordinates)
                              ? Colors.yellowAccent
                              : Colors.white10,
                        ),
                        child: Container(),
                      ),
                    ],
                  ),
                ),
              ),
            );
            }),

            // Render Caravan Icon on top?
            // Actually, rendering it INSIDE the Stack above (per tile) is easier if we want it clipped/positioned correctly.
            // But "The horde IS represented as a moving caravan".
            // It should ideally be ON the tile.
            // I can add it to the generic tile stack above if coords match.
            if (gameState.isCaravanMode && gameState.caravanPosition != null)
              ...allAreas
                  .where((a) => a.coordinates == gameState.caravanPosition)
                  .map((hexArea) {
                final HexCoordinates coords = hexArea.coordinates;
                final double x =
                    centerOffset.dx + hexWidth * (coords.q + coords.r / 2);
                final double y =
                    centerOffset.dy + hexHeight * 3 / 4 * (coords.r);
                return Positioned(
                  left: x - (hexWidth / 2),
                  top: y - (hexHeight / 2),
                  width: hexWidth,
                  height: hexHeight,
                  child: IgnorePointer(
                    // Taps are handled by the tile underneath
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, 0), // Centered
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 32),
                            Text("Horde",
                                style: GoogleFonts.cinzel(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  void _showAreaAssignmentDialog(
      BuildContext context, GameArea area, GameState gameState) {
    if (gameState.player?.role != SoldierRole.hordeLeader) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only the Horde Leader can assign missions.',
              style: GoogleFonts.cinzel()),
          backgroundColor: Colors.red[900],
        ),
      );
      return;
    }

    // For now, only allow Scouting on unexplored areas from World Map
    // and maybe Patrol on explored areas.
    final List<Aravt> assignedAravts = gameState.aravts.where((aravt) {
      final task = aravt.task;
      if (task is AssignedTask) {
        return task.areaId == area.id &&
            (task.assignment == AravtAssignment.Scout ||
                task.assignment == AravtAssignment.Patrol);
      }
      return false;
    }).toList();
    final List<Aravt> availableAravts = gameState.aravts
        .where((aravt) =>
            aravt.soldierIds.isNotEmpty &&
            (aravt.task == null ||
                (aravt.task is AssignedTask &&
                    (aravt.task as AssignedTask).assignment ==
                        AravtAssignment.Rest)) &&
            !assignedAravts.contains(aravt))
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AravtAssignmentDialog(
          title: "Mission to ${area.name}",
          description: "Assign Aravts to scout or patrol this area.",
          availableAssignments: area.isExplored
              ? const [AravtAssignment.Scout, AravtAssignment.Patrol]
              : const [AravtAssignment.Scout],
          assignedAravts: assignedAravts,
          availableAravts: availableAravts,
          onConfirm: (selectedAssignment, selectedAravtIds, option) {
            final uiService = UiAssignmentService();
            for (final aravtId in selectedAravtIds) {
              final aravt = gameState.findAravtById(aravtId);
              if (aravt != null) {
                uiService.assignAreaTask(
                  aravt: aravt,
                  area: area,
                  assignment: selectedAssignment,
                  gameState: gameState,
                  option: option,
                );
              }
            }
          },
        );
      },
    );
  }
  void _showEstablishCampDialog(
      BuildContext context, GameState gameState, HexCoordinates coords) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Establish Camp",
            style: GoogleFonts.cinzel(color: Colors.white)),
        content: Text("Do you want to unpack and establish your camp here?",
            style: GoogleFonts.cinzel(color: Colors.white70)),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            child: Text("Cancel", style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text("Establish", style: TextStyle(color: Colors.amber)),
            onPressed: () {
              gameState.establishCamp(coords);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showMoveCaravanDialog(
      BuildContext context, GameState gameState, HexCoordinates coords) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Move Caravan",
            style: GoogleFonts.cinzel(color: Colors.white)),
        content: Text("Move the horde to this location? This will take 1 day.",
            style: GoogleFonts.cinzel(color: Colors.white70)),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            child: Text("Cancel", style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text("Move", style: TextStyle(color: Colors.amber)),
            onPressed: () {
              gameState.moveCaravan(coords);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}

class HexBorderPainter extends CustomPainter {
  final Color color;
  HexBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    final double w = size.width;
    final double h = size.height;

    // Pointy-top hex path
    path.moveTo(w / 2, 0);
    path.lineTo(w, h / 4);
    path.lineTo(w, 3 * h / 4);
    path.lineTo(w / 2, h);
    path.lineTo(0, 3 * h / 4);
    path.lineTo(0, h / 4);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
