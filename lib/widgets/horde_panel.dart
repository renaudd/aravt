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
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:aravt/widgets/paper_panel.dart';

import '../providers/game_state.dart';
import '../models/soldier_data.dart';
import '../models/horde_data.dart';
import '../models/assignment_data.dart';
import '../models/area_data.dart';
import '../models/location_data.dart';
import '../screens/soldier_profile_screen.dart';
import 'soldier_portrait_widget.dart';
import 'notification_badge.dart'; // import notification badge
import 'tutorial_highlighter.dart';
import '../services/tutorial_service.dart'; //  Import tutorial service

class HordePanel extends StatefulWidget {
  const HordePanel({super.key});

  @override
  State<HordePanel> createState() => _HordePanelState();
}

class _HordePanelState extends State<HordePanel> with TickerProviderStateMixin {
  final Map<String, ui.Image> _sprites = {};

  double? _maxHeightPixels;

  @override
  void initState() {
    super.initState();
    _loadSprites();
  }

  Future<void> _loadSprites() async {
    try {
      for (String color in ['red', 'blue', 'green', 'kellygreen']) {
        _sprites['${color}_right'] = await _loadImage(
            'assets/images/sprites/${color}_horse_archer_spritesheet_right.png');
        _sprites['${color}_left'] = await _loadImage(
            'assets/images/sprites/${color}_horse_archer_spritesheet.png');
      }
      if (mounted) setState(() {});
    } catch (e) {
      // print("Error loading HordePanel sprites: $e");
    }
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    List<Aravt> sortedAravts = List.from(gameState.aravts);

    sortedAravts.sort((a, b) {
      final capA = gameState.findSoldierById(a.captainId);
      final capB = gameState.findSoldierById(b.captainId);

      // 1. Horde Leader always first
      if (capA?.role == SoldierRole.hordeLeader) return -1;
      if (capB?.role == SoldierRole.hordeLeader) return 1;

      // 2. Sort by numeric ID suffix (aravt_1, aravt_2, etc.)
      int idA = _parseId(a.id);
      int idB = _parseId(b.id);
      return idA.compareTo(idB);
    });

    return PaperPanel(
      irregularity: 3.0,
      elevation: 8.0,
      padding: EdgeInsets.zero,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: _maxHeightPixels ??
              MediaQuery.of(context).size.height * 0.6, // Default 60%
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle area
            GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  // Initialize if null
                  _maxHeightPixels ??= context.size?.height ??
                      (MediaQuery.of(context).size.height * 0.6);

                  // Invert delta because dragging UP increases height
                  _maxHeightPixels = (_maxHeightPixels! - details.delta.dy)
                      .clamp(150.0, MediaQuery.of(context).size.height * 0.9);
                });
              },
              behavior:
                  HitTestBehavior.translucent, // Catch taps on transparent area
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFFA68B5B).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2))),
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: sortedAravts.length,
                itemBuilder: (context, index) {
                  return _AravtRow(
                      aravt: sortedAravts[index],
                      gameState: gameState,
                      sprites: _sprites,
                      vsync: this);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _parseId(String id) {
    try {
      final match = RegExp(r'\d+').firstMatch(id);
      if (match != null) {
        return int.parse(match.group(0)!);
      }
    } catch (e) {
      // ignore
    }
    return 9999;
  }
}

class _AravtRow extends StatefulWidget {
  final Aravt aravt;
  final GameState gameState;
  final Map<String, ui.Image> sprites;
  final TickerProvider vsync;

  const _AravtRow(
      {required this.aravt,
      required this.gameState,
      required this.sprites,
      required this.vsync});

  @override
  State<_AravtRow> createState() => _AravtRowState();
}

class _AravtRowState extends State<_AravtRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final captain = widget.gameState.findSoldierById(widget.aravt.captainId);

    // if (captain == null) return const SizedBox.shrink();
    
    final bool isLeader = captain?.role == SoldierRole.hordeLeader;
    final bool isPlayer = captain?.isPlayer ?? false;

    //  Check if player has authority to assign tasks
    final bool canAssign =
        widget.gameState.player?.role == SoldierRole.hordeLeader;



    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
          color: const Color(0xFFEADBBE).withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: isLeader
                  ? Colors.amber[700]!
                  : (isPlayer ? const Color(0xFFA68B5B) : Colors.black12),
              width: isLeader || isPlayer ? 2.0 : 1.0)),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    //  Advance tutorial if highlighted
                    if (isPlayer) {
                      final tutorial = context.read<TutorialService>();
                      tutorial.advanceIfHighlighted(
                          context, widget.gameState, 'open_player_profile');

                      //  Close panel if tutorial is active (requested exception)
                      if (tutorial.isActive) {
                        widget.gameState.setHordePanelOpen(false);
                      }
                    }
                    if (captain != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  SoldierProfileScreen(soldierId: captain.id)));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        isPlayer
                            ? TutorialHighlighter(
                                highlightKey: 'open_player_profile',
                                child: SoldierPortrait(
                                    index: captain?.portraitIndex ?? 0,
                                    size: 52,
                                    backgroundColor: captain?.backgroundColor ??
                                        Colors.grey),
                              )
                            : SoldierPortrait(
                                index: captain?.portraitIndex ?? 0,
                                size: 52,
                                backgroundColor:
                                    captain?.backgroundColor ?? Colors.grey),
                        if (captain?.queuedListenItem != null)
                          const Positioned(
                            right: -5,
                            top: -5,
                            child: NotificationBadge(count: 1),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(captain?.name ?? "Unknown Captain",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cinzel(
                              color: const Color(0xFF2D241E), // Dark Espresso
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      GestureDetector(

                        onTap: canAssign
                            ? () => _showReassignmentDialog(
                                context, widget.aravt, widget.gameState)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),

                          child: _buildAssignmentText(isEditable: canAssign),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _AravtSpriteProgressBar(
                      aravt: widget.aravt,
                      gameState: widget.gameState,
                      sprites: widget.sprites,
                      vsync: widget.vsync),
                ),
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(_isExpanded ? Icons.expand_less : Icons.expand_more,
                          color:
                              const Color(0xFF4A3F35).withValues(alpha: 0.7)),
                      if (widget.aravt.soldierIds.any((id) {
                            final s = widget.gameState.findSoldierById(id);
                            return s != null &&
                                s.queuedListenItem != null &&
                                !s.isPlayer;
                          }) &&
                          !_isExpanded)
                        const Positioned(
                          right: -2,
                          top: -2,
                          child: NotificationBadge(count: 1, size: 10),
                        ),
                    ],
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: const Color(0xFFDCCFAD).withValues(alpha: 0.5),
              child: Column(
                children: widget.aravt.soldierIds.map((id) {
                  final s = widget.gameState.findSoldierById(id);
                  if (s == null) return const SizedBox.shrink();
                  String duty = "";
                  widget.aravt.dutyAssignments.forEach((k, v) {
                    if (v == s.id) duty = k.name;
                  });
                  return InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                SoldierProfileScreen(soldierId: s.id))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Text(s.name,
                              style: GoogleFonts.cinzel(
                                  color:
                                      const Color(0xFF2D241E), // Dark Espresso
                                  fontSize: 12,
                                  fontWeight: s.isPlayer
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                          if (s.queuedListenItem != null)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: NotificationBadge(count: 1, size: 14),
                            ),
                          const Spacer(),
                          if (duty.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.blueGrey[900],
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(duty,
                                  style: GoogleFonts.cinzel(
                                      color: const Color(0xFFE0D5C1),
                                      fontSize: 10)),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildAssignmentText({required bool isEditable}) {
    String text = "Resting";
    Color color = Colors.white38;
    final task = widget.aravt.task;

    // Check if at camp for resting color
    bool atCamp = false;
    // Find Camp Coordinates
    HexCoordinates? campCoords;
    for (var area in widget.gameState.worldMap.values) {
      if (area.pointsOfInterest.any((p) => p.id == 'camp-player')) {
        campCoords = area.pointsOfInterest
            .firstWhere((p) => p.id == 'camp-player')
            .position;
        break;
      }
    }
    if (campCoords != null && widget.aravt.hexCoords == campCoords) {
      atCamp = true;
    }

    if (task is MovingTask) {
      if (task.followUpAssignment != null) {
        text = task.followUpAssignment!.name;
      } else {
        text = "Traveling...";
      }
      color = Colors.blue[300]!;
    } else if (task is AssignedTask) {
      text = task.assignment.name;

      if (task.option != null && task.option!.isNotEmpty) {
        text += " (${task.option})";
      }
      color = Colors.green[300]!;
    } else if (widget.aravt.currentAssignment != AravtAssignment.Rest) {
      text = widget.aravt.currentAssignment.name;
    } else {
      // Resting
      if (atCamp) {
        color = Colors.green[300]!; // Available/Present
      } else {
        color = Colors.white38; // Resting away from camp (or unassigned)
      }
    }
    return Text(text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.cinzel(
            color: color,
            fontSize: 11,

            decoration:
                isEditable ? TextDecoration.underline : TextDecoration.none,
            decorationStyle: TextDecorationStyle.dotted));
  }

  void _showReassignmentDialog(
      BuildContext context, Aravt aravt, GameState gameState) {
    // Find Player Camp POI for camp duties
    PointOfInterest? camp;
    for (var area in gameState.worldMap.values) {
      try {
        camp = area.pointsOfInterest.firstWhere((p) => p.id == 'camp-player');
        break;
      } catch (e) {}
    }

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text("Assign ${aravt.id}",
                  style: GoogleFonts.cinzel(color: Colors.white)),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: ListView(
                  children: [
                    _buildCurrentStatus(aravt, gameState),
                    const Divider(color: Colors.white24),
                    _buildAssignOption(ctx, "Rest (Cancel Current Task)", () {
                      gameState.clearAravtAssignment(aravt);
                      Navigator.pop(ctx);
                    }),
                    const Divider(color: Colors.white24),
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text("Join Active Mission",
                            style: GoogleFonts.cinzel(color: Colors.white54))),

                    // Only show Trade/Emissary tasks as joinable escorts
                    ...gameState.aravts
                        .where((a) =>
                            a.id != aravt.id &&
                            a.task is AssignedTask &&
                            ((a.task as AssignedTask).assignment ==
                                    AravtAssignment.Trade ||
                                (a.task as AssignedTask).assignment ==
                                    AravtAssignment.Emissary))
                        .map((other) {
                      return _buildAssignOption(ctx,
                          "Escort ${other.id} (${other.currentAssignment.name})",
                          () {
                        // TODO: Implement actual escort logic linking
                        Navigator.pop(ctx);
                      });
                    }).toList(),
                    if (!gameState.aravts.any((a) =>
                        a.id != aravt.id &&
                        a.task is AssignedTask &&
                        ((a.task as AssignedTask).assignment ==
                                AravtAssignment.Trade ||
                            (a.task as AssignedTask).assignment ==
                                AravtAssignment.Emissary)))
                      const Padding(
                          padding: EdgeInsets.only(left: 16, bottom: 8),
                          child: Text("No eligible missions.",
                              style: TextStyle(
                                  color: Colors.white30,
                                  fontStyle: FontStyle.italic))),

                    const Divider(color: Colors.white24),
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text("General Duties",
                            style: GoogleFonts.cinzel(color: Colors.white54))),
                    _buildAssignOption(ctx, "Patrol Area", () {
                      // Find current area
                      String? areaId;
                      for (var area in gameState.worldMap.values) {
                        if (area.coordinates == aravt.hexCoords) {
                          areaId = area.id;
                          break;
                        }
                      }
                      // Fallback to camp area if at camp
                      if (areaId == null && camp != null) {
                        // Find area containing camp
                        for (var area in gameState.worldMap.values) {
                          if (area.pointsOfInterest.contains(camp)) {
                            areaId = area.id;
                            break;
                          }
                        }
                      }

                      if (areaId != null) {
                        gameState.assignAravtToArea(
                            aravt, areaId, AravtAssignment.Patrol);
                      }
                      Navigator.pop(ctx);
                    }),
                    _buildAssignOption(ctx, "Hunt for Food", () {
                      // Find current area
                      String? areaId;
                      for (var area in gameState.worldMap.values) {
                        if (area.coordinates == aravt.hexCoords) {
                          areaId = area.id;
                          break;
                        }
                      }
                      if (areaId != null) {
                        gameState.assignAravtToArea(
                            aravt, areaId, AravtAssignment.Hunt);
                      }
                      Navigator.pop(ctx);
                    }),
                    _buildAssignOption(ctx, "Forage for Food", () {
                      // Find current area
                      String? areaId;
                      for (var area in gameState.worldMap.values) {
                        if (area.coordinates == aravt.hexCoords) {
                          areaId = area.id;
                          break;
                        }
                      }
                      if (areaId != null) {
                        gameState.assignAravtToArea(
                            aravt, areaId, AravtAssignment.Forage);
                      }
                      Navigator.pop(ctx);
                    }),
                    _buildAssignOption(ctx, "Shepherd Herd", () {
                      if (camp != null) {
                        gameState.assignAravtToPoi(
                            aravt, camp!, AravtAssignment.Shepherd);
                      }
                      Navigator.pop(ctx);
                    }),
                    _buildAssignOption(ctx, "Fish in River", () {
                      // Find current area
                      String? areaId;
                      for (var area in gameState.worldMap.values) {
                        if (area.coordinates == aravt.hexCoords) {
                          areaId = area.id;
                          break;
                        }
                      }
                      if (areaId != null) {
                        gameState.assignAravtToArea(
                            aravt, areaId, AravtAssignment.Fish);
                      }
                      Navigator.pop(ctx);
                    }),

                    const Divider(color: Colors.white24),
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text("Camp Duties",
                            style: GoogleFonts.cinzel(color: Colors.white54))),
                    if (camp != null) ...[
                      _buildAssignOption(ctx, "Guard Camp", () {
                        gameState.assignAravtToPoi(
                            aravt, camp!, AravtAssignment.Defend);
                        Navigator.pop(ctx);
                      }),
                      _buildAssignOption(ctx, "Train Troops", () {
                        gameState.assignAravtToPoi(
                            aravt, camp!, AravtAssignment.Train);
                        Navigator.pop(ctx);
                      }),
                      _buildAssignOption(ctx, "Fletch Arrows...", () {
                        Navigator.pop(ctx); // Close main menu
                        _showArrowTypeDialog(context, gameState, aravt, camp!);
                      }),
                    ] else
                      const Text("Camp not found.",
                          style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ));
  }

  void _showArrowTypeDialog(BuildContext context, GameState gameState,
      Aravt aravt, PointOfInterest camp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text("Select Arrow Type",
            style: GoogleFonts.cinzel(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAssignOption(ctx, "Short Arrows", () {
              gameState.assignAravtToPoi(
                  aravt, camp, AravtAssignment.FletchArrows,
                  option: 'short');
              Navigator.pop(ctx);
            }),
            _buildAssignOption(ctx, "Long Arrows", () {
              Navigator.pop(ctx); // Close main menu
              // Call arrow fletching logic here if separate or handled above
              gameState.assignAravtToPoi(
                  aravt, camp, AravtAssignment.FletchArrows,
                  option: 'short_arrows');
            }),
            // Add other arrow types if needed
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatus(Aravt aravt, GameState gameState) {
    if (aravt.task == null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Current Status: Available",
          style: GoogleFonts.cinzel(color: Colors.white70),
        ),
      );
    }

    String status = "Unknown Activity";
    String details = "";
    String eta = "";

    // Helper to get location name
    String getLocationName(HexCoordinates? coords) {
      if (coords == null) return "Unknown Location";
      for (var area in gameState.worldMap.values) {
        if (area.coordinates == coords) return area.name;
        // Check POIs
        for (var _ in area.pointsOfInterest) {
          // Approximate or exact match if we had poi location
          // For now just area name is safe fallback
        }
      }
      return "(${coords.q}, ${coords.r})";
    }

    // Helper to get POI name
    String getPoiName(String poiId) {
      for (var area in gameState.worldMap.values) {
        try {
          final poi = area.pointsOfInterest.firstWhere((p) => p.id == poiId);
          return poi.name;
        } catch (_) {}
      }
      return poiId;
    }

    if (aravt.task is MovingTask) {
      final task = aravt.task as MovingTask;
      status = "Traveling";

      final origin = getLocationName(aravt.hexCoords);
      // destination is GameLocation, need to resolve name
      String dest = "Unknown";
      if (task.destination.type == LocationType.poi) {
        dest = getPoiName(task.destination.id);
      } else {
        // Could be area id
        final area = gameState.worldMap[task.destination.id];
        dest = area?.name ?? task.destination.id;
      }

      // Calculate remaining time
      final now = gameState.gameDate.toDateTime();
      final remaining = task.expectedEndTime?.difference(now) ?? Duration.zero;
      String timeString = remaining.inHours > 24
          ? "${(remaining.inHours / 24).toStringAsFixed(1)} days"
          : "${remaining.inHours}h ${remaining.inMinutes % 60}m";

      if (remaining.isNegative) timeString = "Arriving...";

      details = "From: $origin\nTo: $dest";
      eta = "ETA: $timeString";

      if (task.followUpAssignment != null) {
        details += "\nMission: ${task.followUpAssignment!.name}";
      }
    } else if (aravt.task is TradeTask) {
      final task = aravt.task as TradeTask;
      // Active Trade Task implies they might be AT the location or returning?
      // Actually TradeTask wraps MovingTask usually, but if top level task is TradeTask
      // it means logic handles it.
      // Wait, AravtTask polymorphism:
      // In assignment_data.dart: TradeTask extends AravtTask.
      // It HAS a 'movement' field.
      // If aravt.task IS TradeTask, are they moving?
      // Yes, 'movement' tracks the travel.

      final dest = getPoiName(task.targetPoiId);
      status = "Trade Caravan";
      details = "Target: $dest\nCargo: ${task.cargo.length} item types";

      final now = gameState.gameDate.toDateTime();
      final remaining =
          task.movement.expectedEndTime?.difference(now) ?? Duration.zero;

      String timeString = remaining.inHours > 24
          ? "${(remaining.inHours / 24).toStringAsFixed(1)} days"
          : "${remaining.inHours}h ${remaining.inMinutes % 60}m";

      if (remaining.isNegative) timeString = "Trading..."; // or returning
      eta = "ETA: $timeString";
    } else if (aravt.task is EmissaryTask) {
      final task = aravt.task as EmissaryTask;
      final dest = getPoiName(task.targetPoiId);
      status = "Diplomatic Mission";
      details = "Target: $dest\nTerms: ${task.terms.length} terms";

      final now = gameState.gameDate.toDateTime();
      final remaining =
          task.movement.expectedEndTime?.difference(now) ?? Duration.zero;
      String timeString = remaining.inHours > 24
          ? "${(remaining.inHours / 24).toStringAsFixed(1)} days"
          : "${remaining.inHours}h ${remaining.inMinutes % 60}m";
      eta = "ETA: $timeString";
    } else if (aravt.task is AssignedTask) {
      final task = aravt.task as AssignedTask;
      status = task.assignment.name;
      // Location?
      final loc = getLocationName(aravt.hexCoords);
      details = "Location: $loc";
      if (task.option != null) details += "\nFocus: ${task.option}";

      // Assigned tasks usually indefinite unless specific
      eta = "Ongoing";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CURRENT ORDER",
              style: GoogleFonts.cinzel(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(status,
              style: GoogleFonts.cinzel(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(details, style: const TextStyle(color: Colors.white70)),
          if (eta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(eta,
                style: TextStyle(
                    color: Colors.green[200], fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }

  Widget _buildAssignOption(BuildContext ctx, String text, VoidCallback onTap) {
    return ListTile(
      title: Text(text, style: GoogleFonts.cinzel(color: Colors.white)),
      onTap: onTap,
      dense: true,
      trailing:
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
    );
  }
}

class _AravtSpriteProgressBar extends StatefulWidget {
  final Aravt aravt;
  final GameState gameState;
  final Map<String, ui.Image> sprites;
  final TickerProvider vsync;
  const _AravtSpriteProgressBar(
      {required this.aravt,
      required this.gameState,
      required this.sprites,
      required this.vsync});
  @override
  State<_AravtSpriteProgressBar> createState() =>
      _AravtSpriteProgressBarState();
}

class _AravtSpriteProgressBarState extends State<_AravtSpriteProgressBar> {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: widget.vsync,
        duration: const Duration(
            milliseconds: 400))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Find Camp Coordinates
    HexCoordinates? campCoords;
    for (var area in widget.gameState.worldMap.values) {
      if (area.pointsOfInterest.any((p) => p.id == 'camp-player')) {
        campCoords = area.pointsOfInterest
            .firstWhere((p) => p.id == 'camp-player')
            .position;
        break;
      }
    }

    // 2. Determine State
    final task = widget.aravt.task;
    bool isMoving = task is MovingTask;
    bool isAssigned = task is AssignedTask;

    HexCoordinates? destPos;
    IconData? destIcon;
    String? destName;

    if (isMoving) {
      final mt = task as MovingTask;
      if (mt.destination.type == LocationType.poi) {
        final poi = widget.gameState.findPoiByIdWorld(mt.destination.id);
        destPos = poi?.position;
        destIcon = poi?.icon;
        destName = poi?.name;
      } else {
        final area = widget.gameState.worldMap[mt.destination.id];
        destPos = area?.coordinates;
        destIcon = area?.icon;
        destName = area?.name;
      }
    } else if (isAssigned) {
      final at = task as AssignedTask;
      if (at.poiId != null) {
        final poi = widget.gameState.findPoiByIdWorld(at.poiId!);
        destPos = poi?.position;
        destIcon = poi?.icon;
        destName = poi?.name;
      } else if (at.areaId != null) {
        final area = widget.gameState.worldMap[at.areaId!];
        destPos = area?.coordinates;
        destIcon = area?.icon;
        destName = area?.name;
      }
    }

    // 3. Check for Same Tile Assignment
    bool isSameTile = false;
    if (campCoords != null && destPos != null) {
      if (campCoords == destPos) {
        isSameTile = true;
      }
    } else if (destPos == null && !isMoving && !isAssigned) {
      // Resting at camp
      isSameTile = true;
    }

    if (isSameTile && isAssigned) {
      final at = task as AssignedTask;
      String assignmentName = at.assignment.name;
      if (at.option != null && at.option!.isNotEmpty) {
        assignmentName += " (${at.option})";
      }
      String detailText = assignmentName;
      // Only show location if it's not the camp (e.g. Patrol at Steppe)
      if (destName != null && !destName.toLowerCase().contains('camp')) {
        detailText += " at $destName";
      }

      return Container(
        height: 36,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          detailText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 10),
        ),
      );
    }

    // 4. Calculate Distance & Progress for Progress Bar
    double iconPosFactor = 0.0;
    if (campCoords != null && destPos != null) {
      int dist = campCoords.distanceTo(destPos);
      // 3 tiles = 100% progress bar
      iconPosFactor = (dist / 3.0).clamp(0.0, 1.0);
    } else if (isMoving || isAssigned) {
      // If we can't calculate distance but have a task, assume 1 tile for now
      iconPosFactor = 0.33;
    }

    double horsePosFactor = iconPosFactor;
    bool isReturning = false;

    if (isMoving) {
      final mt = task as MovingTask;
      DateTime now = widget.gameState.gameDate.toDateTime();
      double totalSec = mt.durationInSeconds;
      double elapsedSec = now.difference(mt.startTime).inSeconds.toDouble();
      double progress = (elapsedSec / totalSec).clamp(0.0, 1.0);

      // Check if returning (destination is camp)
      if (destPos != null && campCoords != null && destPos == campCoords) {
        isReturning = true;
        // Returning: Horse moves from iconPosFactor to 0.5 * iconPosFactor
        horsePosFactor = iconPosFactor - (iconPosFactor * 0.5 * progress);
      } else {
        // Outbound: Horse moves from 0 to 0.5 * iconPosFactor
        horsePosFactor = (iconPosFactor * 0.5) * progress;
      }
    } else if (isAssigned) {
      // At destination
      horsePosFactor = iconPosFactor;
    } else {
      // Resting at camp
      horsePosFactor = 0.0;
      iconPosFactor = 0.0;
    }

    // 5. Render Progress Bar
    String color = widget.aravt.color;
    ui.Image? sprite = isReturning
        ? (widget.sprites['${color}_left'] ?? widget.sprites['red_left'])
        : (widget.sprites['${color}_right'] ?? widget.sprites['red_right']);

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10)),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Progress Bar Fill (up to icon)
          if (iconPosFactor > 0)
            FractionallySizedBox(
              widthFactor: iconPosFactor,
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(18))),
            ),
          // Destination Icon
          if (iconPosFactor > 0)
            Align(
              alignment: Alignment(iconPosFactor * 2 - 1.0, 0.0),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(
                  destIcon ?? Icons.location_on,
                  size: 14,
                  color: Colors.amber,
                ),
              ),
            ),
          // Horse Sprite
          if (sprite != null && (isMoving || isAssigned || horsePosFactor > 0))
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                int frame =
                    (isMoving) ? (_controller.value * 16).floor() % 17 : 0;
                return Align(
                  alignment: Alignment(horsePosFactor * 2 - 1.0, 0.0),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CustomPaint(
                        painter: _SingleFrameSpritePainter(
                            sprite: sprite, frame: frame)),
                  ),
                );
              },
            )
        ],
      ),
    );
  }
}

class _SingleFrameSpritePainter extends CustomPainter {
  final ui.Image sprite;
  final int frame;
  _SingleFrameSpritePainter({required this.sprite, required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..filterQuality = FilterQuality.low;
    // Assume standard 250x250 frames
    final double srcX = (frame * 250).toDouble();
    final Rect srcRect = Rect.fromLTWH(srcX, 0, 250, 250);
    final Rect dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(sprite, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(_SingleFrameSpritePainter old) =>
      old.frame != frame || old.sprite != sprite;
}
