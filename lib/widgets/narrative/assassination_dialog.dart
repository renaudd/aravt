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

class AssassinationDialog extends StatelessWidget {
  final NarrativeEvent event;

  const AssassinationDialog({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context, listen: false);
    String imagePath;
    String title;

    switch (event.type) {
      case NarrativeEventType.assassinationPoison:
        imagePath = 'images/assassination_poison.png';
        title = 'Poisoning Attempt';
        break;
      case NarrativeEventType.assassinationAccident:
        imagePath = 'images/assassination_accident.png';
        title = 'Suspicious Accident';
        break;
      case NarrativeEventType.assassinationStrangle:
        imagePath = 'images/assassination_strangle.png';
        title = 'Strangulation Attempt';
        break;
      case NarrativeEventType.assassinationConfront:
        imagePath = 'images/assassination_confront.png';
        title = 'Direct Confrontation';
        break;
      default:
        imagePath = 'images/assassination_accident.png'; // Fallback
        title = 'Assassination Attempt';
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: Colors.red[900]!, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red[900]!.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image
                  Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 300,
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.cinzel(
                            color: Colors.red[100],
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          event.description ??
                              'An assassination attempt was made.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[900],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.white30),
                            ),
                            onPressed: () {
                              gameState.dismissNarrativeEvent();
                              if (event.success == true &&
                                  event.targetId == gameState.player?.id) {
                                gameState.triggerGameOver(
                                  "You were assassinated by ${gameState.findSoldierById(event.instigatorId)?.name ?? 'an unknown assailant'}",
                                );
                              }
                            },
                            child: Text(
                              'CONTINUE',
                              style: GoogleFonts.cinzel(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
