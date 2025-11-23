import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' as math;

import '../providers/game_state.dart';
import '../models/soldier_data.dart';
import '../models/horde_data.dart';
import '../models/assignment_data.dart';
import '../models/location_data.dart';
import '../models/area_data.dart';
import '../screens/soldier_profile_screen.dart';
import 'soldier_portrait_widget.dart';
import 'tutorial_highlighter.dart';

class HordePanel extends StatefulWidget {
  const HordePanel({super.key});

  @override
  State<HordePanel> createState() => _HordePanelState();
}

class _HordePanelState extends State<HordePanel> with TickerProviderStateMixin {
  final Map<String, ui.Image> _sprites = {};
  bool _assetsLoaded = false;

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
      if (mounted) setState(() => _assetsLoaded = true);
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

    return Container(
      height: 400, // Fixed reasonable height
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0xFFE0D5C1), width: 2),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Drag handle
          Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
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
    if (captain == null) return const SizedBox.shrink();

    final bool isLeader = captain.role == SoldierRole.hordeLeader;
    final bool isPlayer = captain.isPlayer;

    // [GEMINI-NEW] Check if player has authority to assign tasks
    final bool canAssign =
        widget.gameState.player?.role == SoldierRole.hordeLeader;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isLeader
                  ? Colors.amber
                  : (isPlayer ? const Color(0xFFE0D5C1) : Colors.white24))),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SoldierProfileScreen(soldierId: captain.id))),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: isPlayer
                        ? TutorialHighlighter(
                            highlightKey: 'open_player_profile',
                            child: SoldierPortrait(
                                index: captain.portraitIndex,
                                size: 52,
                                backgroundColor: captain.backgroundColor),
                          )
                        : SoldierPortrait(
                            index: captain.portraitIndex,
                            size: 52,
                            backgroundColor: captain.backgroundColor),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(captain.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cinzel(
                              color: isPlayer
                                  ? const Color(0xFFE0D5C1)
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      GestureDetector(
                        // [GEMINI-FIX] Only allow tap if player is Horde Leader
                        onTap: canAssign
                            ? () => _showReassignmentDialog(
                                context, widget.aravt, widget.gameState)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          // [GEMINI-FIX] Pass editable state to text builder
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
                  icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white54),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.black87,
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
                                  color: s.isPlayer
                                      ? const Color(0xFFE0D5C1)
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: s.isPlayer
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
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
    if (task is MovingTask) {
      text = "Traveling...";
      color = Colors.blue[300]!;
    } else if (task is AssignedTask) {
      text = task.assignment.name;
      color = Colors.green[300]!;
    } else if (widget.aravt.currentAssignment != AravtAssignment.Rest) {
      text = widget.aravt.currentAssignment.name;
    }
    return Text(text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.cinzel(
            color: color,
            fontSize: 11,
            // [GEMINI-FIX] Only show underline if editable
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
                    ] else
                      const Text("Camp not found.",
                          style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ));
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
        vsync: widget.vsync, duration: const Duration(milliseconds: 600))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Real distance calculation
    HexCoordinates? campCoords;
    for (var area in widget.gameState.worldMap.values) {
      if (area.pointsOfInterest.any((p) => p.id == 'camp-player')) {
        campCoords = area.pointsOfInterest
            .firstWhere((p) => p.id == 'camp-player')
            .position;
        break;
      }
    }

    double distance = 0.0;
    if (campCoords != null) {
      // Axial distance formula
      int dq = widget.aravt.hexCoords.q - campCoords.q;
      int dr = widget.aravt.hexCoords.r - campCoords.r;
      int dist = (dq.abs() + (dq + dr).abs() + dr.abs()) ~/ 2;

      // 3 tiles = 100% progress bar
      distance = (dist / 3.0).clamp(0.0, 1.0);
    }

    // If they have a task but are still at camp (distance 0), show them just starting out (10%)
    if (distance == 0.0 && widget.aravt.task != null) distance = 0.1;

    bool isMoving = widget.aravt.task != null;
    // TODO: Detect if returning home for sprite flip. For now assume outbound.
    ui.Image? sprite = widget.sprites['red_right'];

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
          FractionallySizedBox(
            widthFactor: math.max(0.01, distance),
            child: Container(
                decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(18))),
          ),
          if (sprite != null && distance > 0)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                int frame =
                    isMoving ? (_controller.value * 16).floor() % 17 : 0;
                return Align(
                  alignment: Alignment(distance * 2 - 1.0, 0.0),
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
