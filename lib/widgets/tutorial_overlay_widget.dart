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
import '../widgets/paper_panel.dart';

class TutorialOverlayWidget extends StatefulWidget {
  const TutorialOverlayWidget({super.key});

  @override
  State<TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<TutorialOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _arrowAnimation = Tween<double>(begin: 0, end: 15).animate(
        CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TutorialService, GameState>(
      builder: (context, tutorial, gameState, child) {
        if (!tutorial.isActive || tutorial.currentStep == null) {
          final currentTurn = gameState.turn.turnNumber;
          if (!gameState.tutorialCompleted &&
              !gameState.tutorialPermanentlyDismissed &&
              gameState.player != null &&
              gameState.tutorialStepIndex > 0 &&
              currentTurn > tutorial.lastTurnStarted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              tutorial.startTutorial(context, gameState);
            });
          }
          return const SizedBox.shrink();
        }

        final captain = tutorial.getTutorialCaptain(gameState);
        final step = tutorial.currentStep!;
        final isAnnoyed = gameState.tutorialDismissalCount > 0;

        return Stack(
          children: [
            // --- Global Bobbing Red Arrow ---
            // This is rendered above everything else
            if (tutorial.highlightPosition != null)
              Positioned(
                left: tutorial.highlightPosition!.center.dx - 25,
                top: tutorial.highlightPosition!.top - 65,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _arrowAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _arrowAnimation.value),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: CustomPaint(
                            painter: _RedArrowPainter(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // --- Floating Captain Portrait (Bottom Left) ---
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                child: GridPortraitWidget(
                    key: ValueKey(
                        'portrait_${tutorial.captainPortraitIndex}_${tutorial.isShowingAngryPortrait}'),
                    imagePath: tutorial.getCaptainPortraitPath(),
                    gridIndex: tutorial.captainPortraitIndex,
                    size: 150),
              ),
            ),

            // --- Dialogue Box (Bottom Right) ---
            Positioned(
              bottom: 80,
              right: 16,
              left: 170, // Consistent space for portrait
              child: PaperPanel(
                backgroundColor: isAnnoyed
                    ? const Color(0xFF2D1A1A).withValues(alpha: 0.95)
                    : const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                borderColor: isAnnoyed
                    ? Colors.red.shade900
                    : const Color(0xFFE0D5C1).withValues(alpha: 0.4),
                borderWidth: 2.0,
                irregularity: 3.5,
                elevation: 12,
                padding: const EdgeInsets.all(12),
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
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(step.text,
                        style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
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
                                    fontWeight: FontWeight.bold, fontSize: 10)),
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
                                    fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.shade900
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    path.moveTo(size.width * 0.5, size.height);
    path.lineTo(size.width * 0.05, size.height * 0.45);
    path.lineTo(size.width * 0.3, size.height * 0.45);
    path.lineTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.7, 0);
    path.lineTo(size.width * 0.7, size.height * 0.45);
    path.lineTo(size.width * 0.95, size.height * 0.45);
    path.close();

    canvas.drawPath(path.shift(const Offset(2, 3)), shadowPaint);
    canvas.drawPath(path, paint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
