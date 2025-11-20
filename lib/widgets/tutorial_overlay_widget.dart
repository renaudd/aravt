import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../services/tutorial_service.dart';
import 'soldier_portrait_widget.dart';

class TutorialOverlayWidget extends StatelessWidget {
  const TutorialOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TutorialService, GameState>(
      builder: (context, tutorial, gameState, child) {
        // If tutorial is not active or no step is defined, show nothing.
        if (!tutorial.isActive || tutorial.currentStep == null) {
          return const SizedBox.shrink();
        }

        final captainId = gameState.tutorialCaptainId;
        final captain =
            captainId != null ? gameState.findSoldierById(captainId) : null;
        final step = tutorial.currentStep!;

        // Visual cue if they are annoyed (dismissal count > 0).
        // The service increments this count when 'Dismiss' is clicked.
        final isAnnoyed = gameState.tutorialDismissalCount > 0;

        return Positioned(
          // Position it near the top, but below standard app bars so it doesn't block navigation completely
          top: 80,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            // High elevation ensures it sits over almost everything else on screen
            elevation: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // Use a slightly redder/darker background if the captain is annoyed
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Captain Portrait ---
                  if (captain != null)
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: isAnnoyed
                                  ? Colors.red.shade800
                                  : const Color(0xFFE0D5C1),
                              width: 2),
                          boxShadow: const [
                            BoxShadow(blurRadius: 4, color: Colors.black54)
                          ]),
                      child: SoldierPortrait(
                          index: captain.portraitIndex,
                          size: 80,
                          // Darken their background color slightly if they are annoyed
                          backgroundColor: isAnnoyed
                              ? Color.lerp(
                                  captain.backgroundColor, Colors.black, 0.5)!
                              : captain.backgroundColor),
                    ),

                  // --- Text and Buttons ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(captain?.name ?? "Unknown Captain",
                            style: GoogleFonts.cinzel(
                                color: isAnnoyed
                                    ? Colors.red.shade300
                                    : const Color(0xFFE0D5C1),
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        const SizedBox(height: 10),
                        Text(step.text,
                            style: GoogleFonts.inter(
                                // Inter is often better for body text readability than Cinzel
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                                height: 1.4)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => tutorial.dismiss(gameState),
                              child: Text("Dismiss",
                                  style: GoogleFonts.cinzel(
                                      color: Colors.white38)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE0D5C1),
                                  foregroundColor: Colors.black,
                                  elevation: 5,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12)),
                              onPressed: () =>
                                  tutorial.advance(context, gameState),
                              child: Text("Continue",
                                  style: GoogleFonts.cinzel(
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
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
}
