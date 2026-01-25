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
import 'dart:ui'; // For ImageFilter

import '../providers/game_state.dart';
import '../models/area_data.dart';
import '../models/horde_data.dart';
import '../widgets/persistent_menu_widget.dart';
import '../widgets/aravt_assignment_dialog.dart';
import '../models/assignment_data.dart';

class AreaScreen extends StatelessWidget {
  const AreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AreaMapView(showMenu: true),
    );
  }
}

class AreaMapView extends StatelessWidget {
  final bool showMenu;
  const AreaMapView({super.key, this.showMenu = false});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final GameArea? currentArea = gameState.currentArea;

    if (currentArea == null) {
      return Center(
        child: Text(
          'No area selected.',
          style: GoogleFonts.cinzel(fontSize: 20, color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        // 1. Background Image
        _buildBackgroundImage(currentArea.backgroundImagePath),

        // 2. POI Layout
        _buildPoiStack(context, currentArea, gameState),

        // 3. Persistent Menu (Optional)
        if (showMenu) const PersistentMenuWidget(),
      ],
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
            final double usableWidth = constraints.maxWidth * 0.7;
            final double usableHeight = constraints.maxHeight * 0.6;

            final double left =
                (constraints.maxWidth * 0.15) + (usableWidth * poi.relativeX);
            final double top =
                (constraints.maxHeight * 0.20) + (usableHeight * poi.relativeY);
            return Positioned(
              left: left - 50,
              top: top - 50,
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
      },
      child: Tooltip(
        message: poi.name,
        child: SizedBox(
          width: 100,
          height: 100,
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

    final List<Aravt> assignedAravts = gameState.aravts
        .where((aravt) => poi.assignedAravtIds.contains(aravt.id))
        .toList();
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
          title: poi.name,
          description: poi.description,
          availableAssignments: poi.availableAssignments,
          assignedAravts: assignedAravts,
          availableAravts: availableAravts,
          onConfirm: gameState.isPlayerLeader
              ? (assignment, selectedAravtIds, option) {
                  for (final aravtId in selectedAravtIds) {
                    final aravt = gameState.findAravtById(aravtId);
                    if (aravt != null) {
                      gameState.assignAravtToPoi(aravt, poi, assignment,
                          option: option);
                    }
                  }
                }
              : null,
        );
      },
    );
  }
}
