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
import '../../providers/game_state.dart';
import '../../models/narrative_models.dart';

/// Dialog shown when the tournament concludes, displaying final results.
class TournamentConclusionDialog extends StatelessWidget {
  final NarrativeEvent event;

  const TournamentConclusionDialog({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final gameState = context.read<GameState>();
    final description = event.description ?? "The tournament has concluded.";

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                border: Border.all(color: const Color(0xFF8B4513), width: 4),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black87, blurRadius: 20, spreadRadius: 5)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Text("TOURNAMENT CONCLUDED",
                      style: GoogleFonts.cinzel(
                          color: Colors.amber[200],
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const Divider(color: Color(0xFF8B4513), height: 30),

                  // --- RESULTS ---
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        description,
                        style: GoogleFonts.cinzel(
                            color: Colors.white, fontSize: 16, height: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- ACCEPT FATE BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[900],
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () {
                        gameState.dismissNarrativeEvent();
                        gameState.triggerGameOver(
                            "Your Aravt finished last in the tournament and has been exiled.");
                      },
                      child: Text("Accept Fate",
                          style: GoogleFonts.cinzel(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
