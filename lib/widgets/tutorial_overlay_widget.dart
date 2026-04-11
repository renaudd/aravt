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

/// Width of the captain bust portrait shown in the bottom-left.
const double _kPortraitSize = 110.0;

/// SHORTER & WIDER DIALOGUE: 420px satisfies the '20% wider' request.
/// Adjusted padding and font to satisfy the '10% shorter' request.
const double _kBubbleMaxWidth = 504.0;

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
    _arrowAnimation = Tween<double>(begin: 0, end: 12).animate(
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
        final isActive = tutorial.isActive;
        final currentStepIndex = gameState.tutorialStepIndex;
        final currentStep = tutorial.currentStep; // Only use active step — never fall back to getStep()
        final currentRoute = tutorial.currentRoute;

        // When the service is inactive or currentStep is null
        if (!isActive || currentStep == null) {
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

        return Material(
          type: MaterialType.transparency,
          child: SizedBox.expand(
            child: Builder(builder: (context) {
              try {
                return Stack(
              children: [
                // isActive && currentStep != null guaranteed by early-return guard above.
                ...[
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    clipBehavior: Clip.none,
                    children: [
                       SizedBox(
                         width: _kPortraitSize,
                         child: GridPortraitWidget(
                           key: ValueKey('bust_${tutorial.captainPortraitIndex}_${tutorial.isShowingAngryPortrait}'),
                           imagePath: tutorial.getCaptainPortraitPath(),
                           gridIndex: tutorial.captainPortraitIndex,
                           size: _kPortraitSize,
                         ),
                       ),

                       Positioned(
                         left: _kPortraitSize - 10,
                         bottom: 8,
                         child: ConstrainedBox(
                           constraints: const BoxConstraints(maxWidth: _kBubbleMaxWidth),
                           child: PaperPanel(
                             backgroundColor: gameState.tutorialDismissalCount > 0
                                 ? const Color(0xFF241414).withValues(alpha: 0.98)
                                 : const Color(0xFF141414).withValues(alpha: 0.98),
                             borderColor: gameState.tutorialDismissalCount > 0
                                 ? Colors.red.shade900
                                 : const Color(0xFFE0D5C1).withValues(alpha: 0.3),
                             borderWidth: 1.5,
                             elevation: 10,
                             padding: const EdgeInsets.fromLTRB(14, 4, 14, 2), // Shorter padding
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Text(
                                   tutorial.getTutorialCaptain(gameState)?.name.toUpperCase() ?? "CAPTAIN",
                                   style: GoogleFonts.cinzel(
                                       color: gameState.tutorialDismissalCount > 0
                                           ? Colors.red.shade400
                                           : const Color(0xFFE0D5C1),
                                       letterSpacing: 1.2,
                                       fontWeight: FontWeight.bold,
                                       fontSize: 8.5), // Slightly smaller
                                 ),
                                 const SizedBox(height: 1),
                                 Text(
                                   currentStep.text,
                                   style: GoogleFonts.inter(
                                       color: Colors.white.withValues(alpha: 0.95),
                                       fontSize: 9.8, // Slightly smaller
                                       height: 1.15), // Tighter line height
                                   maxLines: 2, // Prefer 2 lines for 'shorter' look
                                   overflow: TextOverflow.ellipsis,
                                 ),
                                   const SizedBox(height: 4),
                                    // ── Action buttons ──────────────────────
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // DISMISS — always available, plain text, no box.
                                        // Applies a reputation penalty and switches to
                                        // angry portraits. After 3 dismissals the tutorial
                                        // is permanently dismissed.
                                        if (!currentStep.isConclude)
                                          TextButton(
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 0),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () => tutorial.dismiss(context, gameState),
                                          child: Text("Dismiss",
                                              style: GoogleFonts.cinzel(
                                                  color: Colors.white38, fontSize: 10)),
                                        ),
                                        const Spacer(),
                                        // CONCLUDE — final step only. Calls complete()
                                        // directly (not advance()) so the reputation reward
                                        // fires correctly.
                                        if (currentStep.isConclude)
                                          ElevatedButton(
                                            onPressed: () {
                                              tutorial.complete(gameState, success: true);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amber[700],
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              elevation: 3,
                                              minimumSize: const Size(0, 0),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text('CONCLUDE TUTORIAL',
                                                style: GoogleFonts.cinzel(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11)),
                                          )
                                        // CONTINUE — static/screen-anchor steps where
                                        // there is no interactive UI element to tap.
                                        else if (currentStep.highlightKey == null)
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFE0D5C1),
                                                foregroundColor: Colors.black,
                                                elevation: 3,
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 6),
                                                minimumSize: const Size(0, 0),
                                                tapTargetSize:
                                                    MaterialTapTargetSize.shrinkWrap),
                                            onPressed: () =>
                                                tutorial.advance(context, gameState),
                                            child: Text("Continue",
                                                style: GoogleFonts.cinzel(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11)),
                                          ),
                                      ],
                                    ),
                               ],
                             ),
                           ),
                         ),
                       ),
                    ],
                  ),
                ),

                // Arrow System
                Builder(builder: (arrowCtx) {
                  final arrowStep = currentStep;
                  final screenSize = MediaQuery.of(arrowCtx).size;
                  Offset? target;
                  
                  if (arrowStep.screenAnchor != null) {
                    final anchor = arrowStep.screenAnchor!;
                    target = Offset(
                      (anchor.x + 1) / 2 * screenSize.width,
                      (anchor.y + 1) / 2 * screenSize.height,
                    );
                  } else if (tutorial.highlightPosition != null) {
                    target = Offset(
                      tutorial.highlightPosition!.center.dx,
                      tutorial.highlightPosition!.top,
                    );
                  }

                  if (target == null) return const SizedBox.shrink();

                  final bool pointingUp = arrowStep.arrowRotation > 2.0;
                  final double arrowL = (target.dx - 20).clamp(0.0, screenSize.width - 40);
                  final double arrowT = pointingUp 
                      ? (target.dy + 10).clamp(0.0, screenSize.height - 40)
                      : (target.dy - 60).clamp(0.0, screenSize.height - 40);

                  return Positioned(
                    left: arrowL,
                    top: arrowT,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _arrowAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, pointingUp ? -_arrowAnimation.value : _arrowAnimation.value),
                            child: Transform.rotate(
                              angle: arrowStep.arrowRotation,
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: CustomPaint(painter: _RedArrowPainter()),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ],
            ],
            );
            } catch (e, stack) {
              print("[TUTORIAL ERROR] $e\n$stack");
              return Container(
                 color: Colors.red.withOpacity(0.5),
                 child: Text("TUTORIAL CRASH: $e"),
              );
            }
          }),
          ),
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

    final path = Path();
    path.moveTo(size.width * 0.5, size.height);
    path.lineTo(size.width * 0.1, size.height * 0.5);
    path.lineTo(size.width * 0.35, size.height * 0.5);
    path.lineTo(size.width * 0.35, 0);
    path.lineTo(size.width * 0.65, 0);
    path.lineTo(size.width * 0.65, size.height * 0.5);
    path.lineTo(size.width * 0.9, size.height * 0.5);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
