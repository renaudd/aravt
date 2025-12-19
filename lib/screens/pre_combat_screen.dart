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

// lib/screens/pre_combat_screen.dart

import 'package:aravt/providers/game_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class PreCombatScreen extends StatelessWidget {
  const PreCombatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This Consumer handles UI building
    return Consumer<GameState>(
      builder: (context, gameState, child) {
        // --- UI LOGIC ---
        final pendingCombat = gameState.pendingCombatState;

        if (pendingCombat == null) {
          // This state is now valid (e.g., after clicking a button but
          // before the navigation callback fires). Show a loading indicator.
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/background.png'),
                  fit: BoxFit.cover,
                  opacity: 0.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text("Loading...",
                        style: GoogleFonts.cinzel(color: Colors.white)),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/background.png'), // Use your main background
                fit: BoxFit.cover,
                opacity: 0.5,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Enemies Sighted!",
                    style: GoogleFonts.cinzel(
                        fontSize: 40,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),

                  // Simple "Vs" layout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildForceDisplay("Your Forces",
                          pendingCombat.playerSoldiers.length, Colors.blue),
                      Text("VS",
                          style: GoogleFonts.cinzel(
                              fontSize: 30, color: Colors.white)),
                      _buildForceDisplay("Enemy Forces",
                          pendingCombat.opponentSoldiers.length, Colors.red),
                    ],
                  ),

                  const SizedBox(height: 60),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 20),
                    ),
                    onPressed: () {
                      // This just changes the state.
                      // GameStateNavigator will handle navigation.
                      context.read<GameState>().beginCombatFromPreScreen();
                    },
                    child: Text(
                      "Begin Battle!",
                      style:
                          GoogleFonts.cinzel(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      // This just changes the state.
                      // GameStateNavigator will handle navigation.
                      print("Attempting to retreat...");
                      context.read<GameState>().dismissPostCombatReport();
                    },
                    child: Text(
                      "Attempt to Retreat",
                      style: GoogleFonts.cinzel(
                          fontSize: 16, color: Colors.grey[300]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widget (moved outside build method) ---
  Widget _buildForceDisplay(String title, int count, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.cinzel(fontSize: 22, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: GoogleFonts.cinzel(
              fontSize: 48, color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          "Soldiers",
          style:
              GoogleFonts.cinzel(fontSize: 18, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }
}
