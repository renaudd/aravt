// lib/screens/pre_combat_screen.dart

import 'package:aravt/models/combat_flow_state.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'combat_screen.dart'; // Keep this import, it's not ambiguous here

class PreCombatScreen extends StatelessWidget {
  const PreCombatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This Consumer handles UI building
    return Consumer<GameState>(
      builder: (context, gameState, child) {
        
        // --- UI LOGIC ---
        final pendingCombat = gameState.pendingCombat;

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

        // --- This is your original UI, now returned inside a Scaffold ---
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image:
                    AssetImage('assets/images/background.png'), // Use your main background
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
                      _buildForceDisplay(
                          "Enemy Forces",
                          pendingCombat.opponentSoldiers.length,
                          Colors.red),
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
                      style: GoogleFonts.cinzel(fontSize: 24, color: Colors.white),
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
                      style:
                          GoogleFonts.cinzel(fontSize: 16, color: Colors.grey[300]),
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
          style: GoogleFonts.cinzel(fontSize: 18, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }
}

