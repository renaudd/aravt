// screens/new_game_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:aravt/models/soldier_data.dart'; // For SoldierRole
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/widgets/narrative_screen.dart';
import 'package:aravt/screens/camp_screen.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  // --- MODIFIED: Set default to MEDIUM and updated Omniscience logic ---
  String _selectedDifficulty = 'MEDIUM'; // Default difficulty
  bool _allowOmniscience = false; // Controls if the button is available in-game
  bool _isYoloMode = false;
  // --- END MODIFIED ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Choose Your Path',
                      style: GoogleFonts.cinzel(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                              blurRadius: 10.0,
                              color: Colors.black,
                              offset: Offset(2, 2)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                    Wrap(
                      spacing: 40,
                      runSpacing: 40,
                      alignment: WrapAlignment.center,
                      children: [
                        _DifficultyBanner(
                          title: 'EASY',
                          imagePath: 'assets/images/easy_difficulty.png',
                          isSelected: _selectedDifficulty == 'EASY',
                          onPressed: () =>
                              setState(() => _selectedDifficulty = 'EASY'),
                        ),
                        _DifficultyBanner(
                          title: 'MEDIUM',
                          imagePath: 'assets/images/medium_difficulty.png',
                          isSelected: _selectedDifficulty == 'MEDIUM',
                          onPressed: () =>
                              setState(() => _selectedDifficulty = 'MEDIUM'),
                        ),
                        _DifficultyBanner(
                          title: 'HARD',
                          imagePath: 'assets/images/hard_difficulty.png',
                          isSelected: _selectedDifficulty == 'HARD',
                          onPressed: () =>
                              setState(() => _selectedDifficulty = 'HARD'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    _buildGameOptions(),
                    const SizedBox(height: 40),
                    _buildStartButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOptions() {
    return Container(
      width: 600,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // --- MODIFIED: Logic and text for Omniscience ---
          CheckboxListTile(
            title: Text('Allow Omniscient Mode',
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
            subtitle: Text('Allows toggling omniscience from the in-game menu.',
                style: GoogleFonts.cinzel(color: Colors.white70)),
            value: _allowOmniscience,
            onChanged: (bool? value) {
              setState(() {
                _allowOmniscience = value ?? false;
              });
            },
            activeColor: const Color(0xFFE0D5C1),
            checkColor: Colors.black,
          ),
          // --- END MODIFIED ---
          CheckboxListTile(
            title: Text('YOLO Mode',
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
            subtitle: Text(
                'Every turn auto-saves, overwriting the only game save.',
                style: GoogleFonts.cinzel(color: Colors.white70)),
            value: _isYoloMode,
            onChanged: (bool? value) {
              setState(() {
                _isYoloMode = value ?? false;
              });
            },
            activeColor: const Color(0xFFE0D5C1),
            checkColor: Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: () {
        final gameState = context.read<GameState>();

        // --- MODIFIED: Pass the new `allowOmniscience` flag ---
        gameState.initializeNewGame(
            difficulty: _selectedDifficulty,
            enableAutoSave: _isYoloMode,
            allowOmniscience: _allowOmniscience);
        // --- END MODIFIED ---

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NarrativeScreen(
              title: "A Troubling Dream",
              bodyText:
                  "You dream of a cold blade... a hand you recognize... one of your own men. You wake in a cold sweat. Why did it look like he was gripping the blade like that? Dreams are weird sometimes.",
              imagePath: 'assets/images/opening_1.png',
              onContinue: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      String leaderName = "The Chief";
                      try {
                        final leader = gameState.horde.firstWhere(
                            (s) => s.role == SoldierRole.hordeLeader,
                            orElse: () => gameState.horde.first);
                        leaderName = leader.name;
                      } catch (e) {
                        print("Error finding leader for intro: $e");
                      }

                      return NarrativeScreen(
                        title: "Summoned by the Chief",
                        bodyText:
                            "You are summoned by the Horde Leader, $leaderName. 'I'm sick and tired of you guys dropping bow strings. Seriously, I've had enough. Discipline around here is no good. You're all gonna be tested in one week's time... If your aravt fails, we're taking your horses and leaving you here. I mean it this time.'",
                        imagePath: 'assets/images/opening_2.png',
                        onContinue: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CampScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        width: 280,
        height: 55,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/button_background.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Center(
          child: Text(
            'START GAME',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFE0D5C1),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyBanner extends StatefulWidget {
  final String title;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onPressed;

  const _DifficultyBanner({
    required this.title,
    required this.imagePath,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  State<_DifficultyBanner> createState() => _DifficultyBannerState();
}

class _DifficultyBannerState extends State<_DifficultyBanner> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: (_isHovering || widget.isSelected)
              ? (Matrix4.identity()..scale(1.05))
              : Matrix4.identity(),
          width: 250,
          height: 400,
          decoration: BoxDecoration(
            boxShadow: [
              if (widget.isSelected)
                BoxShadow(
                  color: const Color(0xFFE0D5C1).withOpacity(0.7),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.asset(
                    widget.imagePath,
                    fit: BoxFit.cover,
                    color:
                        Colors.black.withOpacity(widget.isSelected ? 0.0 : 0.4),
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
              ),
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE0D5C1),
                    shadows: const [
                      Shadow(
                          blurRadius: 6.0,
                          color: Colors.black,
                          offset: Offset(2, 2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
