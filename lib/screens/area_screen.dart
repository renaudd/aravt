import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For ImageFilter

import '../providers/game_state.dart';
import '../models/area_data.dart';
import '../models/horde_data.dart';
import '../models/assignment_data.dart';
import '../widgets/persistent_menu_widget.dart';
import '../models/soldier_data.dart'; // Needed for SoldierRole

class AreaScreen extends StatelessWidget {
  const AreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final GameArea? currentArea = gameState.currentArea;

    if (currentArea == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'No area selected.',
            style: GoogleFonts.cinzel(fontSize: 20, color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(currentArea.name,
            style: GoogleFonts.cinzel(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // 1. Background Image
          _buildBackgroundImage(currentArea.backgroundImagePath),

          // 2. POI Layout
          _buildPoiStack(context, currentArea, gameState),

          // 3. Persistent Menu
          const PersistentMenuWidget(),
        ],
      ),
    );
  }

  Widget _buildBackgroundImage(String imagePath) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(imagePath), // Assumes imagePath is in assets
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5), // Darken the image
            BlendMode.darken,
          ),
        ),
      ),
    );
  }

  Widget _buildPoiStack(
      BuildContext context, GameArea currentArea, GameState gameState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visiblePois = currentArea.pointsOfInterest
            .where((poi) => poi.isDiscovered || gameState.isOmniscientMode)
            .toList();

        return Stack(
          children: visiblePois.map((poi) {
            // Calculate pixel position from relative coordinates
            // We give a padding of 15% on X and 20% on Y to avoid edges
            final double usableWidth = constraints.maxWidth * 0.7;
            final double usableHeight = constraints.maxHeight * 0.6;

            final double left =
                (constraints.maxWidth * 0.15) + (usableWidth * poi.relativeX);
            final double top =
                (constraints.maxHeight * 0.20) + (usableHeight * poi.relativeY);
            return Positioned(
              // Position the center of the widget at the calculated (left, top)
              left: left -
                  50, // Adjust by half of the widget's assumed width (100)
              top: top -
                  50, // Adjust by half of the widget's assumed height (100)
              child: _buildPoiWidget(context, poi),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPoiWidget(BuildContext context, PointOfInterest poi) {
    return GestureDetector(
      onTap: () {
        _showPoiDetailDialog(context, poi);
        print("Tapped on POI: ${poi.name}");
      },
      child: Tooltip(
        message: poi.name,
        child: SizedBox(
          width: 100, // Fixed width for the POI widget
          height: 100, // Fixed height for the POI widget
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(poi.icon ?? Icons.place, color: Colors.white, size: 40),
              const SizedBox(height: 4),
              Text(
                poi.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    const Shadow(blurRadius: 2, color: Colors.black),
                    const Shadow(blurRadius: 4, color: Colors.black),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPoiDetailDialog(BuildContext context, PointOfInterest poi) {
    final gameState = Provider.of<GameState>(context, listen: false);

    // [GEMINI-NEW] Check player role
    final bool isHordeLeader =
        gameState.player?.role == SoldierRole.hordeLeader;

    final List<Aravt> assignedAravts = gameState.aravts
        .where((aravt) => poi.assignedAravtIds.contains(aravt.id))
        .toList();
    final List<Aravt> availableAravts = gameState.aravts
        .where((aravt) => aravt.task == null && !assignedAravts.contains(aravt))
        .toList();

    AravtAssignment? _selectedAssignment;
    final Set<String> _selectedAravtIds = {};

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool canConfirm =
                _selectedAssignment != null && _selectedAravtIds.isNotEmpty;

            return AlertDialog(
              backgroundColor: Colors.grey[900]?.withOpacity(0.95),
              title: Text(
                  _selectedAssignment == null
                      ? poi.name
                      : "Assign to: ${_selectedAssignment!.name}",
                  style: GoogleFonts.cinzel(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedAssignment == null) ...[
                        Text(poi.description,
                            style: GoogleFonts.cinzel(color: Colors.white70)),
                        const Divider(color: Colors.white24, height: 20),
                        Text("Your Aravts Here:",
                            style: GoogleFonts.cinzel(
                                color: Colors.white, fontSize: 16)),
                        if (assignedAravts.isEmpty)
                          Text("None",
                              style: GoogleFonts.cinzel(
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic)),
                        ...assignedAravts.map((aravt) => Text(
                              "- ${aravt.id} (${aravt.currentAssignment.name})",
                              style:
                                  GoogleFonts.cinzel(color: Colors.amber[200]),
                            )),
                        const Divider(color: Colors.white24, height: 20),

                        // [GEMINI-FIX] Only show assignment controls if Horde Leader
                        if (isHordeLeader) ...[
                          Text("Available Assignments:",
                              style: GoogleFonts.cinzel(
                                  color: Colors.white, fontSize: 16)),
                          if (poi.availableAssignments.isEmpty)
                            Text("None",
                                style: GoogleFonts.cinzel(
                                    color: Colors.white54,
                                    fontStyle: FontStyle.italic)),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children:
                                poi.availableAssignments.map((assignment) {
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal[800],
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(assignment.name,
                                    style: GoogleFonts.cinzel()),
                                onPressed: availableAravts.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedAssignment = assignment;
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                          if (availableAravts.isEmpty &&
                              poi.availableAssignments.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text("No aravts available (all are busy).",
                                  style: GoogleFonts.cinzel(
                                      color: Colors.red[300],
                                      fontStyle: FontStyle.italic)),
                            ),
                        ] else ...[
                          // Not Horde Leader
                          Text("Only the Horde Leader can assign tasks here.",
                              style: GoogleFonts.cinzel(
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic)),
                        ]
                      ] else ...[
                        // Step 2 of assignment (only reachable if Horde Leader)
                        Text("Select Aravts to assign:",
                            style: GoogleFonts.cinzel(
                                color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 250,
                          child: ListView(
                            children: availableAravts.map((aravt) {
                              return CheckboxListTile(
                                title: Text(aravt.id,
                                    style: GoogleFonts.cinzel(
                                        color: Colors.white)),
                                subtitle: Text(
                                    "Soldiers: ${aravt.soldierIds.length}",
                                    style: GoogleFonts.cinzel(
                                        color: Colors.white70)),
                                value: _selectedAravtIds.contains(aravt.id),
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedAravtIds.add(aravt.id);
                                    } else {
                                      _selectedAravtIds.remove(aravt.id);
                                    }
                                  });
                                },
                                checkColor: Colors.black,
                                activeColor: Colors.amber,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            }).toList(),
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                if (_selectedAssignment != null)
                  TextButton(
                    child: Text("Back",
                        style: GoogleFonts.cinzel(color: Colors.white70)),
                    onPressed: () {
                      setState(() {
                        _selectedAssignment = null;
                        _selectedAravtIds.clear();
                      });
                    },
                  ),
                TextButton(
                  child: Text("Close",
                      style: GoogleFonts.cinzel(color: Colors.white70)),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                if (_selectedAssignment != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: !canConfirm
                        ? null
                        : () {
                            for (final aravtId in _selectedAravtIds) {
                              final aravt = gameState.findAravtById(aravtId);
                              if (aravt != null) {
                                gameState.assignAravtToPoi(
                                    aravt, poi, _selectedAssignment!);
                              }
                            }
                            Navigator.of(dialogContext).pop();
                          },
                    child: Text("Confirm (${_selectedAravtIds.length})",
                        style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
