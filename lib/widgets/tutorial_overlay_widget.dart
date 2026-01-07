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
import '../providers/game_state.dart';
import '../services/tutorial_service.dart';
import '../widgets/grid_portrait_widget.dart';

class TutorialOverlayWidget extends StatelessWidget {
  const TutorialOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TutorialService, GameState>(
      builder: (context, tutorial, gameState, child) {
        // If tutorial is not active or no step is defined, show nothing.
        // If tutorial is not active or no step is defined, check for resumption
        if (!tutorial.isActive || tutorial.currentStep == null) {
          final currentTurn = gameState.turn.turnNumber;
          if (!gameState.tutorialCompleted &&
              !gameState.tutorialPermanentlyDismissed &&
              gameState.player != null && // Ensure game is active
              gameState.tutorialStepIndex >
                  0 && // Ensure tutorial has started (Step 0 handled by CampScreen)
              currentTurn > tutorial.lastTurnStarted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              tutorial.startTutorial(context, gameState);
            });
          }
          return const SizedBox.shrink();
        }


        final captain = tutorial.getTutorialCaptain(gameState);

        // [DEBUG] Check why portrait might be missing
        if (tutorial.isActive && tutorial.currentStep != null) {
          print("[TUTORIAL OVERLAY] Active. Captain Found: ${captain?.name}");
        }

        final step = tutorial.currentStep!;

        // Visual cue if they are annoyed (dismissal count > 0).
        // The service increments this count when 'Dismiss' is clicked.
        final isAnnoyed = gameState.tutorialDismissalCount > 0;

        return Stack(
          children: [
            // --- Floating Captain Portrait (Bottom Left) ---
            Positioned(
              bottom: 0,
              left: 0, // Hug the left edge
              child: Container(
                // No border or background as requested
                child: GridPortraitWidget(
                    key: ValueKey(
                        'portrait_${tutorial.captainPortraitIndex}_${tutorial.isShowingAngryPortrait}'),
                    imagePath: tutorial.getCaptainPortraitPath(),
                    gridIndex: tutorial.captainPortraitIndex,
                    size: 200), // Double size (from 100)
              ),
            ),

            // --- Dialogue Box (Bottom Right) ---
            Positioned(
              bottom: 80, // Above persistent menu
              right: 16,
              left:
                  220, // Leave even more space for portrait, making box narrower
              child: Material(
                color: Colors.transparent,
                elevation: 20,
                child: Container(
                  padding: const EdgeInsets.all(8), // Even less padding
                  decoration: BoxDecoration(
                    color: isAnnoyed
                        ? const Color(0xFF2a1a1a).withOpacity(0.95)
                        : const Color(0xFF1a1a1a).withOpacity(0.95),
                    border: Border.all(
                        color: isAnnoyed
                            ? Colors.red.shade800
                            : const Color(0xFFE0D5C1),
                        width: 2),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 15,
                          spreadRadius: 5,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(captain?.name ?? "Aravt Captain",
                          style: GoogleFonts.cinzel(
                              color: isAnnoyed
                                  ? Colors.red.shade300
                                  : const Color(0xFFE0D5C1),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)), // Further reduced font size
                      const SizedBox(height: 4),
                      Text(step.text,
                          style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12, // Further reduced font size
                              height: 1.1)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!step.isConclude)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () =>
                                  tutorial.dismiss(context, gameState),
                              child: Text("Dismiss",
                                  style: GoogleFonts.cinzel(
                                      color: Colors.white38, fontSize: 10)),
                            ),
                          if (step.isConclude) ...[
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE0D5C1),
                                  foregroundColor: Colors.black,
                                  elevation: 5,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap),
                              onPressed: () =>
                                  tutorial.complete(gameState, success: true),
                              child: Text("Conclude",
                                  style: GoogleFonts.cinzel(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            ),
                          ] else if (step.highlightKey == null) ...[
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE0D5C1),
                                  foregroundColor: Colors.black,
                                  elevation: 5,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap),
                              onPressed: () =>
                                  tutorial.advance(context, gameState),
                              child: Text("Continue",
                                  style: GoogleFonts.cinzel(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            ),
                          ],
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
