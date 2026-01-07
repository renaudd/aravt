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
import 'area_screen.dart'; // To navigate to the detailed area view

import '../widgets/hex_map_tile.dart';
import '../services/ui_assignment_service.dart';
import '../models/horde_data.dart';
import '../models/assignment_data.dart';
import '../widgets/aravt_assignment_dialog.dart';

import '../widgets/aravt_map_icon.dart';
import '../models/soldier_data.dart';

class RegionScreen extends StatefulWidget {
  const RegionScreen({super.key});

  @override
  State<RegionScreen> createState() => _RegionScreenState();
}

class _RegionScreenState extends State<RegionScreen> {
  GameArea? _selectedArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: Text('Current Region', style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black.withAlpha((255 * 0.5).round()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: "View World Map",
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/world_map');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildRegionMap(context),
          if (_selectedArea != null) _buildInfoPanel(context, _selectedArea!),
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
      if (poi.type == PoiType.camp &&
          (hexArea.type == AreaType.PlayerCamp ||
              hexArea.type == AreaType.NpcCamp)) {
        continue;
      }

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
              size: hexRadius * 0.2, // Small icon
              shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
            ),
          ),
        ),
      );
    }
    return poiWidgets;
  }

  List<Widget> _buildAravtIcons(
      GameArea hexArea, double hexRadius, GameState gameState) {
    List<Widget> aravtWidgets = [];

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
              color: 'blue', // TODO: randomize this or base on captain
              scale:
                  1.0,
            ),
          ),
        ),
      );
    }
    return aravtWidgets;
  }

  Widget _buildRegionMap(BuildContext context) {
    final gameState = context.watch<GameState>();
    final currentArea = gameState.currentArea;

    if (currentArea == null) {
      return Center(
        child: Text('No Current Area Selected', style: GoogleFonts.cinzel()),
      );
    }

    final List<HexCoordinates> currentNeighbors =
        currentArea.coordinates.getNeighbors();
    final Map<HexCoordinates, GameArea> displayHexes = {};

    displayHexes[const HexCoordinates(0, 0)] = currentArea;

    for (final HexCoordinates neighborActualCoords in currentNeighbors) {
      final GameArea? neighborArea =
          gameState.worldMap[neighborActualCoords.toString()];
      if (neighborArea != null) {
        final int relQ = neighborActualCoords.q - currentArea.coordinates.q;
        final int relR = neighborActualCoords.r - currentArea.coordinates.r;
        displayHexes[HexCoordinates(relQ, relR)] = neighborArea;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double radiusFromWidth = constraints.maxWidth / (3 * sqrt(3));
        final double radiusFromHeight = constraints.maxHeight / 4;

        final double hexRadius = min(radiusFromWidth, radiusFromHeight);

        final double hexWidth = sqrt(3) * hexRadius;
        final double hexHeight = 2 * hexRadius;

        final double usableHeight = constraints.maxHeight - 140;
        final Offset centerOffset = Offset(
          constraints.maxWidth / 2,
          (usableHeight / 2) + 60,
        );

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: displayHexes.entries.map((entry) {
            final HexCoordinates relativeCoords = entry.key;
            final GameArea hexArea = entry.value;

            final double x = centerOffset.dx +
                hexWidth * (relativeCoords.q + relativeCoords.r / 2);
            final double y =
                centerOffset.dy + hexHeight * 3 / 4 * (relativeCoords.r);

            final bool isExplored =
                hexArea.isExplored || gameState.isOmniscientMode;

            return Positioned(
              left: x - (hexWidth / 2),
              top: y - (hexHeight / 2),
              width: hexWidth,
              height: hexHeight,
              child: GestureDetector(
                onTap: () {
                  if (_selectedArea?.coordinates == hexArea.coordinates) {
                    // Second tap on same tile -> Navigate
                    if (!isExplored) return;
                    gameState.setCurrentArea(hexArea.coordinates);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (ctx) => const AreaScreen()),
                    );
                  } else {
                    // First tap -> Select
                    setState(() {
                      _selectedArea = hexArea;
                    });
                  }
                },
                onLongPress: () {
                  _showAreaAssignmentDialog(
                      context, hexArea, gameState, AravtAssignment.Scout);
                },
                onSecondaryTap: () {
                  _showAreaAssignmentDialog(
                      context, hexArea, gameState, AravtAssignment.Scout);
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
                        fit: BoxFit.contain,
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hexArea.icon != null)
                                Icon(hexArea.icon,
                                    color: Colors.white,
                                    size: hexRadius * 0.4,
                                    shadows: const [
                                      Shadow(blurRadius: 4, color: Colors.black)
                                    ])
                              else
                                Icon(Icons.terrain,
                                    color: Colors.white.withOpacity(0.7),
                                    size: hexRadius * 0.4,
                                    shadows: const [
                                      Shadow(blurRadius: 4, color: Colors.black)
                                    ]),
                              SizedBox(height: hexRadius * 0.05),
                              Text(
                                hexArea.name,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cinzel(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: hexRadius * 0.2,
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
                      // Aravt Icons
                      ..._buildAravtIcons(hexArea, hexRadius, gameState),
                      // Border
                      CustomPaint(
                        painter: HexBorderPainter(
                          color:
                              _selectedArea?.coordinates == hexArea.coordinates
                                  ? Colors.yellowAccent
                                  : (gameState.currentArea?.coordinates ==
                                          hexArea.coordinates
                                      ? Colors.white
                                      : Colors.white24),
                        ),
                        child: Container(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInfoPanel(BuildContext context, GameArea area) {
    final gameState = context.watch<GameState>();
    return Positioned(
      bottom: 70,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  area.name,
                  style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _selectedArea = null),
                ),
              ],
            ),
            Text(
              'Type: ${area.type.name}',
              style: GoogleFonts.cinzel(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              area.isExplored ? 'Explored' : 'Unexplored',
              style: GoogleFonts.cinzel(
                  color: area.isExplored ? Colors.green : Colors.red),
            ),
            if (area.isExplored) ...[
              const SizedBox(height: 8),
              Text(
                'Points of Interest: ${area.pointsOfInterest.length}',
                style: GoogleFonts.cinzel(color: Colors.white),
              ),
            ],
            const SizedBox(height: 12),
            // Scout & Patrol Buttons (Multi-Aravt) - Visible to all, but disabled if not leader
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: gameState.player?.role == SoldierRole.hordeLeader
                        ? 'Scout this area'
                        : 'Only the Horde Leader can assign Scouting',
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: Text('Scout', style: GoogleFonts.cinzel()),
                      onPressed: gameState.player?.role ==
                              SoldierRole.hordeLeader
                          ? () => _showAreaAssignmentDialog(
                              context, area, gameState, AravtAssignment.Scout)
                          : null, // Disabled if not leader
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[700],
                          foregroundColor: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: gameState.player?.role == SoldierRole.hordeLeader
                        ? 'Patrol this area'
                        : 'Only the Horde Leader can assign Patrols',
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.shield),
                      label: Text('Patrol', style: GoogleFonts.cinzel()),
                      onPressed: gameState.player?.role ==
                              SoldierRole.hordeLeader
                          ? () => _showAreaAssignmentDialog(
                              context, area, gameState, AravtAssignment.Patrol)
                          : null, // Disabled if not leader
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[700],
                          foregroundColor: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAreaAssignmentDialog(BuildContext context, GameArea area,
      GameState gameState, AravtAssignment assignment) {
    final List<Aravt> assignedAravts = gameState.aravts.where((aravt) {
      final task = aravt.task;
      if (task is AssignedTask) {
        return task.areaId == area.id && task.assignment == assignment;
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
