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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/game_state.dart';
import '../../models/narrative_models.dart';
import '../../models/soldier_data.dart';
import '../soldier_portrait_widget.dart';

class HordeLeaderTransitionDialog extends StatefulWidget {
  final NarrativeEvent event;
  const HordeLeaderTransitionDialog({super.key, required this.event});

  @override
  State<HordeLeaderTransitionDialog> createState() =>
      _HordeLeaderTransitionDialogState();
}

class _HordeLeaderTransitionDialogState
    extends State<HordeLeaderTransitionDialog> {
  int _currentPage = 0;
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    try {
      _data = jsonDecode(widget.event.description ?? '{}');
    } catch (e) {
      _data = {
        'leaderName': 'The Leader',
        'deathReason': 'unknown causes',
        'successorName': 'You',
        'splinteringCaptains': [],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.read<GameState>();
    final splinteringCaptains = _data['splinteringCaptains'] as List;
    final bool hasSplinters = splinteringCaptains.isNotEmpty;

    // Determine total pages based on splinters
    int totalPages = 2; // Page 1: Death, Page 2: Guidance
    if (hasSplinters)
      totalPages = 3; // Page 1: Death, Page 2: Splinters, Page 3: Guidance

    return Container(
      color: Colors.black87,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a1a),
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, blurRadius: 20, spreadRadius: 5)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPageContent(gameState, splinteringCaptains),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Page ${_currentPage + 1} of $totalPages",
                      style: GoogleFonts.cinzel(color: Colors.white54),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[800],
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_currentPage < totalPages - 1) {
                            _currentPage++;
                          } else {
                            gameState.dismissNarrativeEvent();
                          }
                        });
                      },
                      child: Text(
                        _currentPage < totalPages - 1
                            ? "Next"
                            : "Accept Command",
                        style: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(GameState gameState, List splinteringCaptains) {
    final bool hasSplinters = splinteringCaptains.isNotEmpty;
    int actualPage = _currentPage;
    if (!hasSplinters && _currentPage == 1) {
      actualPage = 2; // Skip splinters page if none
    }

    switch (actualPage) {
      case 0:
        return _buildDeathPage();
      case 1:
        return _buildSplintersPage(splinteringCaptains);
      case 2:
        return _buildGuidancePage(gameState);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDeathPage() {
    return Column(
      children: [
        Text(
          "A New Era Begins",
          style: GoogleFonts.cinzel(
            color: Colors.amber,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "${_data['leaderName']} has died of ${_data['deathReason']}.",
          style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(
          "As is tradition, you have taken command of the horde.",
          style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSplintersPage(List captains) {
    return Column(
      children: [
        Text(
          "A Split in the Ranks",
          style: GoogleFonts.cinzel(
            color: Colors.red[300],
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "However, not all captains are willing to follow you. The following have splintered off to form their own horde:",
          style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...captains.map((c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SoldierPortrait(
                    index: c['portraitIndex'],
                    size: 40,
                    backgroundColor: Color(c['backgroundColor']),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${c['name']} (Aravt ${c['aravtId']})",
                    style:
                        GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildGuidancePage(GameState gameState) {
    // Find a remaining captain to give advice
    final remainingCaptains = gameState.horde
        .where((s) =>
            s.role == SoldierRole.aravtCaptain && s.id != gameState.player?.id)
        .toList();

    String captainName = "A Captain";
    int portraitIndex = 0;
    Color bgColor = Colors.grey;

    if (remainingCaptains.isNotEmpty) {
      final c = remainingCaptains.first;
      captainName = c.name;
      portraitIndex = c.portraitIndex;
      bgColor = c.backgroundColor;
    }

    return Column(
      children: [
        Row(
          children: [
            SoldierPortrait(
              index: portraitIndex,
              size: 60,
              backgroundColor: bgColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "Guidance from $captainName",
                style: GoogleFonts.cinzel(
                  color: Colors.amber[200],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          "\"My Lord, you now command the horde. You must decide our path.\"",
          style: GoogleFonts.cinzel(
            color: Colors.white,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        _buildGuidanceItem("Assignments",
            "You can now assign Aravts from the Horde Panel, or by selecting areas on the Region Map."),
        _buildGuidanceItem("Policies",
            "Check the Camp Screen to set horde-wide policies on food and discipline."),
        _buildGuidanceItem("Expansion",
            "Use the Region Map to scout new territories and find resources."),
      ],
    );
  }

  Widget _buildGuidanceItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "• $title",
            style: GoogleFonts.cinzel(
                color: Colors.amber[100], fontWeight: FontWeight.bold),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(
              description,
              style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
