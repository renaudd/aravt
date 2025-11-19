// lib/screens/horde_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/soldier_data.dart';
import '../models/horde_data.dart';
import '../models/assignment_data.dart';
import '../models/area_data.dart'; // For POI lookup
import '../models/location_data.dart';
import '../widgets/soldier_portrait_widget.dart';
import '../widgets/persistent_menu_widget.dart';
import 'soldier_profile_screen.dart';
import 'dart:math' as math;

class HordeScreen extends StatefulWidget {
  const HordeScreen({super.key});

  @override
  State<HordeScreen> createState() => _HordeScreenState();
}

class _HordeScreenState extends State<HordeScreen> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    
    // 1. Sort Aravts: Leader -> Player -> Others
    List<Aravt> sortedAravts = List.from(gameState.aravts);
    sortedAravts.sort((a, b) {
        final capA = gameState.findSoldierById(a.captainId);
        final capB = gameState.findSoldierById(b.captainId);
        if (capA?.role == SoldierRole.hordeLeader) return -1;
        if (capB?.role == SoldierRole.hordeLeader) return 1;
        if (capA?.isPlayer ?? false) return -1;
        if (capB?.isPlayer ?? false) return 1;
        return a.id.compareTo(b.id);
    });

    return Scaffold(
      backgroundColor: Colors.grey[900],
      // Make AppBar compact to feel more like a widget
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40.0),
        child: AppBar(
          title: Text('Horde Status', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.black,
          automaticallyImplyLeading: false,
          centerTitle: true,
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 80.0),
        itemCount: sortedAravts.length,
        itemBuilder: (context, index) {
          return _buildCompactAravtRow(context, sortedAravts[index], gameState);
        },
      ),
      bottomNavigationBar: const PersistentMenuWidget(),
    );
  }

  Widget _buildCompactAravtRow(BuildContext context, Aravt aravt, GameState gameState) {
      final captain = gameState.findSoldierById(aravt.captainId);
      if (captain == null) return const SizedBox.shrink();

      final bool isLeader = captain.role == SoldierRole.hordeLeader;
      final bool isPlayer = captain.isPlayer;

      return Container(
          height: 60, // Compact fixed height
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          decoration: BoxDecoration(
              color: Colors.grey[850],
              border: Border(
                  left: BorderSide(
                      color: isLeader ? Colors.amber : (isPlayer ? const Color(0xFFE0D5C1) : Colors.transparent),
                      width: 3.0
                  )
              )
          ),
          child: Row(
              children: [
                  // 1. Captain Portrait (Clickable)
                  GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SoldierProfileScreen(soldierId: captain.id))),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: SoldierPortrait(index: captain.portraitIndex, size: 50, backgroundColor: captain.backgroundColor),
                      ),
                  ),
                  
                  // 2. Name & Assignment Details
                  Expanded(
                      flex: 3,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(captain.name, 
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cinzel(
                                      color: isPlayer ? const Color(0xFFE0D5C1) : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                  )
                              ),
                              // Clickable Assignment Text
                              GestureDetector(
                                  onTap: () => _showAssignmentDialog(context, aravt, gameState),
                                  child: _buildAssignmentText(aravt, gameState),
                              ),
                          ],
                      ),
                  ),

                  // 3. Animated Progress Bar (Takes up remaining space)
                  Expanded(
                      flex: 4,
                      child: _AravtProgressBar(aravt: aravt, gameState: gameState, vsync: this),
                  ),

                  // 4. Expand Button (Placeholder for now, can open detailed view later)
                  IconButton(
                      icon: const Icon(Icons.expand_more, color: Colors.white30, size: 20),
                      onPressed: () {
                          // TODO: Implement expansion to see individual soldiers if needed
                      },
                  )
              ],
          ),
      );
  }

  Widget _buildAssignmentText(Aravt aravt, GameState gameState) {
      String text = "Resting";
      Color color = Colors.white54;

      if (aravt.task is MovingTask) {
          text = "Traveling...";
          color = Colors.blue[200]!;
      } else if (aravt.task is AssignedTask) {
          final task = aravt.task as AssignedTask;
          String locName = "";
          if (task.poiId != null) {
               locName = gameState.findPoiByIdWorld(task.poiId!)?.name ?? "Unknown";
          }
          text = "${task.assignment.name} at $locName";
          color = Colors.green[200]!;
      } else if (aravt.currentAssignment != AravtAssignment.Rest) {
           text = aravt.currentAssignment.name;
      }

      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cinzel(color: color, fontSize: 11));
  }

  void _showAssignmentDialog(BuildContext context, Aravt aravt, GameState gameState) {
      // Re-implementing the dialog here since we removed it from the other file's view model
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text("Assign ${aravt.id}", style: GoogleFonts.cinzel(color: Colors.white)),
              content: Container(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView(
                      children: [
                          ListTile(
                              title: Text("Rest (Cancel Task)", style: GoogleFonts.cinzel(color: Colors.white)),
                              onTap: () {
                                  // Simple clear for now, can use service later
                                  aravt.task = null;
                                  aravt.currentAssignment = AravtAssignment.Rest;
                                  Navigator.pop(context);
                              },
                          ),
                          // TODO: Add full assignment list here (requires access to AssignmentService or similar)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Available assignments depend on current location (Go to Area screen to assign specific POI tasks).", 
                                style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                          )
                      ],
                  ),
              ),
          )
      );
  }
}

class _AravtProgressBar extends StatefulWidget {
    final Aravt aravt;
    final GameState gameState;
    final TickerProvider vsync;
    const _AravtProgressBar({required this.aravt, required this.gameState, required this.vsync});

    @override
    State<_AravtProgressBar> createState() => _AravtProgressBarState();
}

class _AravtProgressBarState extends State<_AravtProgressBar> with SingleTickerProviderStateMixin {
    late AnimationController _controller;

    @override
    void initState() {
        super.initState();
        _controller = AnimationController(vsync: widget.vsync, duration: const Duration(seconds: 2))..repeat();
    }

    @override
    void dispose() {
        _controller.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        // 1. Determine State
        bool isMoving = widget.aravt.task is MovingTask;
        bool isReturning = false; // TODO: Real pathfinding check. For now assume outbound if moving.
        
        // Simple distance check: assume Camp is at 0,0,0 for now, need real camp coords
        // Using a placeholder distance since we don't have easy access to 'Camp' coords here without search
        double distance = 0.0; 
        if (widget.aravt.currentLocationType != LocationType.poi || widget.aravt.task != null) {
             // If they have a task or aren't at a POI (assumed camp), they are 'away'
             distance = 1.0; // simplified 'away' state
             if (isMoving) distance = 1.5;
             // If we had real hex distance:
             // distance = widget.aravt.hexCoords.distanceTo(campCoords) / 3.0;
        }
        double progress = distance.clamp(0.0, 1.0);

        return Container(
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24)
            ),
            child: Stack(
                children: [
                    // Background track
                    FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(12))),
                    ),
                    // Animated Icon
                    AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                            // Animate position slightly if moving
                            double bounce = isMoving ? math.sin(_controller.value * math.pi * 2) * 2.0 : 0;
                            return Align(
                                alignment: Alignment(progress * 2 - 1.0, 0.0), // Map 0..1 to -1..1 for Align
                                child: Transform.translate(
                                    offset: Offset(0, -bounce.abs()), // Little bounce while riding
                                    child: Icon(
                                        Icons.pets, // Placeholder for your sprite
                                        color: isReturning ? Colors.grey : Colors.white, 
                                        size: 18
                                    ),
                                ),
                            );
                        }
                    )
                ],
            ),
        );
    }
}

