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
// --- Imports from your project ---
import '../providers/game_state.dart';
import '../models/yurt_data.dart';
import '../models/soldier_data.dart';
import '../widgets/soldier_portrait_widget.dart';
import '../screens/soldier_profile_screen.dart';

class YurtDetailScreen extends StatelessWidget {
  final String yurtId;

  const YurtDetailScreen({
    super.key,
    required this.yurtId,
  });

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final List<Soldier> allSoldiers = gameState.horde;
    final screenHeight = MediaQuery.of(context).size.height;

    final Yurt yurt;
    try {
      yurt = gameState.yurts.firstWhere((y) => y.id == yurtId);
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Text("Error: Yurt with ID $yurtId not found.",
              style: GoogleFonts.cinzel()),
        ),
      );
    }

    final List<Soldier> yurtOccupants = _getOccupants(yurt, allSoldiers);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset('assets/images/steppe_background.jpg',
                fit: BoxFit.cover),
          ),

          // Scrollable main content — avoids overflow on small screens.
          // Uses SingleChildScrollView + Column (mainAxisSize.min) instead of
          // Expanded + ListView so the panel shrinks to fit its content and
          // the whole thing scrolls when it doesn't fit.
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: UiPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title
                        Text(
                          '${yurt.quality.name} Yurt (${yurt.id})',
                          style: GoogleFonts.cinzel(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Yurt image — capped at 30% screen height so it
                        // never dominates on a small landscape phone.
                        Image.asset(
                          yurt.imagePath,
                          height: (screenHeight * 0.30).clamp(80.0, 180.0),
                          fit: BoxFit.contain,
                        ),
                        const Divider(color: Colors.white54, height: 28),

                        // Occupants header
                        Text(
                          'Occupants (${yurtOccupants.length})',
                          style: GoogleFonts.cinzel(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Occupant rows — no Expanded/ListView needed;
                        // Column expands naturally and the outer
                        // SingleChildScrollView handles overflow.
                        ...yurtOccupants.map(
                          (soldier) => ListTile(
                            leading: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SoldierProfileScreen(
                                      soldierId: soldier.id,
                                    ),
                                  ),
                                );
                              },
                              child: SoldierPortrait(
                                index: soldier.portraitIndex,
                                size: 46.0,
                                backgroundColor: soldier.backgroundColor,
                              ),
                            ),
                            title: Text(
                              soldier.name,
                              style: GoogleFonts.cinzel(
                                  color: soldier.isPlayer
                                      ? const Color(0xFFE0D5C1)
                                      : Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Role: ${soldier.role.name} | Aravt: ${soldier.aravt}',
                              style: GoogleFonts.cinzel(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back button pinned top-left, above scroll content
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Helper Functions ---

List<Soldier> _getOccupants(Yurt yurt, List<Soldier> allSoldiers) {
  return yurt.occupantIds
      .map((id) => allSoldiers.firstWhere((s) => s.id == id,
          orElse: () => _createUnknownSoldier(id, yurt.id)))
      .toList();
}

Soldier _createUnknownSoldier(int id, String yurtId) {
  DateTime defaultBirthDate =
      DateTime(SoldierGenerator.gameStartYear - 25, 1, 1);
  Soldier unknown = Soldier(
      id: id,
      aravt: 'Unknown',
      name: 'Unknown Soldier [$id]',
      firstName: 'Unknown',
      familyName: 'Soldier',
      placeOrTribeOfOrigin: '?',
      languages: ['?'],
      religionType: ReligionType.none,
      religionIntensity: ReligionIntensity.normal,
      dateOfBirth: defaultBirthDate,
      zodiac: Zodiac.dog,
      backgroundColor: Colors.grey,
      age: 25,
      yearsWithHorde: 0,
      height: 170,
      healthMax: 5,
      startingInjury: StartingInjuryType.none,
      exhaustion: 0,
      stress: 0,
      equippedItems: {},
      ambition: 3,
      courage: 3,
      strength: 3,
      longRangeArcherySkill: 3,
      mountedArcherySkill: 3,
      spearSkill: 3,
      swordSkill: 3,
      shieldSkill: 3,
      perception: 3,
      intelligence: 3,
      knowledge: 3,
      patience: 3,
      judgment: 3,
      horsemanship: 3,
      animalHandling: 3,
      honesty: 3,
      temperament: 3,
      stamina: 3,
      hygiene: 3,
      charisma: 3,
      leadership: 3,
      adaptability: 3,
      experience: 0,
      giftOriginPreference: GiftOriginPreference.unappreciative,
      giftTypePreference: GiftTypePreference.supplies,
      specialSkills: [],
      attributes: [],
      fungibleRupees: 20,
      fungibleScrap: 39,
      kilosOfMeat: 0,
      kilosOfRice: 0,
      portraitIndex: 0);
  print("Warning: Could not find soldier with ID $id for yurt $yurtId");
  return unknown;
}

// --- Reusable UiPanel ---
class UiPanel extends StatelessWidget {
  final Widget child;
  const UiPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.0),
      ),
      child: child,
    );
  }
}
