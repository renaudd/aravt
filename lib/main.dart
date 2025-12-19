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

// lib/main.dart
import 'dart:io'; //For exit(0) on desktop
import 'package:flutter/foundation.dart' show kIsWeb; // For platform check
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aravt/game_data/item_templates.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/services/tutorial_service.dart';
import 'package:aravt/screens/area_screen.dart';
import 'package:aravt/screens/region_screen.dart';
import 'package:aravt/screens/combat_screen.dart';
import 'package:aravt/screens/load_game_screen.dart';
import 'package:aravt/screens/save_game_screen.dart';
import 'package:aravt/screens/new_game_screen.dart';
import 'package:aravt/screens/world_map_screen.dart';
import 'package:aravt/screens/soldier_profile_screen.dart';
import 'package:aravt/screens/camp_screen.dart';
import 'package:aravt/screens/global_reports_screen.dart';
import 'package:aravt/screens/global_inventory_screen.dart';
import 'package:aravt/screens/settings_screen.dart';
import 'package:aravt/screens/game_over_screen.dart';
import 'package:aravt/screens/pre_combat_screen.dart';
import 'package:aravt/screens/post_combat_report_screen.dart';
import 'package:aravt/models/combat_flow_state.dart';
import 'package:aravt/widgets/tutorial_overlay_widget.dart';
import 'package:aravt/widgets/narrative_overlay_widget.dart';
import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required or window_manager
  ItemDatabase.initialize();

  // Window Manager setup for Desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(1024, 768), // Increased minimum size
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => GameState()),
        ChangeNotifierProvider(create: (context) => TutorialService()),
      ],
      child: const AravtGame(),
    ),
  );
}

class AravtGame extends StatefulWidget {
  const AravtGame({super.key});

  @override
  State<AravtGame> createState() => _AravtGameState();
}

class _AravtGameState extends State<AravtGame> {
  CombatFlowState? _previousCombatState;
  bool _wasGameOver = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Hide status bar for immersive feel
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final gameState = Provider.of<GameState>(context, listen: false);
    gameState.addListener(_onGameStateChanged);
    _previousCombatState = gameState.combatFlowState;
    _wasGameOver = gameState.isGameOver;
  }

  @override
  void dispose() {
    Provider.of<GameState>(context, listen: false)
        .removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    final gameState = Provider.of<GameState>(context, listen: false);
    final currentCombatState = gameState.combatFlowState;
    final isGameOver = gameState.isGameOver;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isNavigating) return;
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      _isNavigating = true;
      try {
        // --- HANDLE GAME OVER ---
        if (isGameOver) {
          if (!_wasGameOver) {
            _wasGameOver = true;
            // Push game over and remove everything but main menu to prevent going back
            navigator.pushNamedAndRemoveUntil(
                '/gameOver', ModalRoute.withName('/mainMenu'));
          }
          return; // Prioritize Game Over over combat navigation
        }
        // Reset flag if a new game started
        if (!isGameOver && _wasGameOver) {
          _wasGameOver = false;
        }

        // --- HANDLE COMBAT FLOW ---
        if (currentCombatState == _previousCombatState) return;

        if (currentCombatState == CombatFlowState.preCombat &&
            _previousCombatState != CombatFlowState.preCombat) {
          navigator.pushNamed('/preCombat');
        } else if (currentCombatState == CombatFlowState.inCombat &&
            _previousCombatState == CombatFlowState.preCombat) {
          navigator.popAndPushNamed('/combat');
        } else if (currentCombatState == CombatFlowState.postCombat &&
            _previousCombatState == CombatFlowState.inCombat) {
          navigator.popAndPushNamed('/postCombat');
        } else if (currentCombatState == CombatFlowState.none &&
            _previousCombatState == CombatFlowState.postCombat) {
          navigator.pop();
        } else if (currentCombatState == CombatFlowState.none &&
            _previousCombatState == CombatFlowState.preCombat) {
          navigator.pop(); // Player fled/avoided from Pre-Combat
        }

        _previousCombatState = currentCombatState;
      } finally {
        _isNavigating = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aravt',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE0D5C1), // Parchment-ish
        scaffoldBackgroundColor: const Color(0xFF1a1a1a),
        textTheme:
            GoogleFonts.cinzelTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: const Color(0xFFE0D5C1),
          displayColor: const Color(0xFFE0D5C1),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
          surface: const Color(0xFF2a2a2a),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            // Overlays now sit above EVERYTHING
            const TutorialOverlayWidget(),
            const NarrativeOverlayWidget(),
          ],
        );
      },
      initialRoute: '/mainMenu',
      routes: {
        '/mainMenu': (context) => const MainMenuScreen(),
        '/newGame': (context) => const NewGameScreen(),
        '/save_game': (context) => const SaveGameScreen(),
        '/load_game': (context) => const LoadGameScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/gameOver': (context) => const GameOverScreen(),
        // --- IN-GAME ROUTES ---
        '/camp': (context) => const CampScreen(),
        '/area': (context) => const AreaScreen(),
        '/region': (context) => const RegionScreen(),
        '/world': (context) => const WorldMapScreen(),
        '/reports': (context) => const GlobalReportsScreen(),
        '/inventory': (context) => const GlobalInventoryScreen(),
        '/soldier_profile': (context) {
          final soldierId = ModalRoute.of(context)!.settings.arguments as int;
          return SoldierProfileScreen(soldierId: soldierId);
        },
        // --- COMBAT ROUTES ---
        '/combat': (context) => const CombatScreen(),
        '/preCombat': (context) => const PreCombatScreen(),
        '/postCombat': (context) {
          final report =
              Provider.of<GameState>(context, listen: false).lastCombatReport;
          if (report == null) return const MainMenuScreen(); // Fallback
          return PostCombatReportScreen(report: report);
        },
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: -screenHeight * 0.05,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/foreground.png',
                fit: BoxFit.contain,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.darken,
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    Image.asset(
                      'assets/images/title.png',
                      height: screenHeight * 0.15,
                    ),
                    const Spacer(flex: 3),
                    _MenuButton(
                        text: 'NEW GAME',
                        onPressed: () {
                          Navigator.pushNamed(context, '/newGame');
                        }),
                    const SizedBox(height: 20),
                    _MenuButton(
                        text: 'LOAD GAME',
                        onPressed: () {
                          Navigator.pushNamed(context, '/load_game');
                        }),
                    const SizedBox(height: 20),
                    _MenuButton(
                        text: 'SETTINGS',
                        onPressed: () {
                          Navigator.pushNamed(context, '/settings');
                        }),
                    const SizedBox(height: 20),
                    _MenuButton(
                        text: 'EXIT',
                        onPressed: () {
                          if (!kIsWeb &&
                              (Platform.isWindows ||
                                  Platform.isLinux ||
                                  Platform.isMacOS)) {
                            exit(0);
                          } else {
                            SystemNavigator.pop();
                          }
                        }),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _MenuButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
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
            text,
            style: GoogleFonts.cinzel(
              color: const Color(0xFFE0D5C1),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              shadows: [
                const Shadow(
                  blurRadius: 4.0,
                  color: Colors.black,
                  offset: Offset(2.0, 2.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
