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
import 'package:aravt/services/logger_service.dart';
import 'package:aravt/screens/unified_map_screen.dart';

import 'screens/timelines_screen.dart';
import 'package:aravt/screens/combat_screen.dart';
import 'package:aravt/screens/load_game_screen.dart';
import 'package:aravt/screens/save_game_screen.dart';
import 'package:aravt/screens/new_game_screen.dart';
import 'package:aravt/screens/soldier_profile_screen.dart';
import 'package:aravt/screens/camp_screen.dart';
import 'package:aravt/screens/combat_simulator_screen.dart';
import 'package:aravt/screens/global_reports_screen.dart';
import 'package:aravt/screens/global_inventory_screen.dart';
import 'package:aravt/screens/settings_screen.dart';
import 'package:aravt/screens/game_over_screen.dart';
import 'package:aravt/screens/pre_combat_screen.dart';
import 'package:aravt/screens/post_combat_report_screen.dart';
import 'package:aravt/screens/about_screen.dart';
import 'package:aravt/screens/loading_screen.dart';
import 'package:aravt/screens/privacy_policy_screen.dart';
import 'package:aravt/screens/contact_screen.dart';
import 'package:aravt/models/combat_flow_state.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aravt/widgets/tutorial_overlay_widget.dart';
import 'package:aravt/widgets/narrative_overlay_widget.dart';
import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required or window_manager
  await CrashLogger.init();
  ItemDatabase.initialize();

  // Window Manager setup for Desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(1024, 768),
      center: true,
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
    // Hide status bar for immersive feel and lock orientation on mobile
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Lock to landscape only on mobile devices
    // Allow both left/right landscape so physically flipping the device 180°
    // (upside-down landscape) still works, but 90° portrait turns do nothing.
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

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
    final wasSimulator = gameState.isSimulatorCombat;

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
          // Check if this was a simulator combat
          if (wasSimulator) {
            navigator.pushNamedAndRemoveUntil(
                '/mainMenu', (Route<dynamic> route) => false);
          } else {
            navigator.pop();
          }
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
        primaryColor: const Color(0xFFEADBBE), // Brighter Parchment
        scaffoldBackgroundColor: const Color(0xFF1a1a1a),
        textTheme:
            GoogleFonts.cinzelTextTheme(ThemeData.light().textTheme).apply(
          bodyColor: const Color(0xFF2D241E), // Deep Espresso
          displayColor: const Color(0xFF1A1A1A), // Charcoal
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4C5A8),
          brightness: Brightness.dark,
          surface: const Color(0xFF242424),
          onSurface: const Color(0xFFD4C5A8),
          primary: const Color(0xFFEADBBE),
          secondary: const Color(0xFFA68B5B), // Aged Parchment detail
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
      initialRoute: '/loading',
      routes: {
        '/loading': (context) => const LoadingScreen(),
        '/mainMenu': (context) => const MainMenuScreen(),
        '/newGame': (context) => const NewGameScreen(),
        '/save_game': (context) => const SaveGameScreen(),
        '/load_game': (context) => const LoadGameScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/about': (context) => const AboutScreen(),
        '/privacy': (context) => const PrivacyPolicyScreen(),
        '/contact': (context) => const ContactScreen(),

        '/timelines': (context) => const TimelinesScreen(),
        '/gameOver': (context) => const GameOverScreen(),
        // --- IN-GAME ROUTES ---
        '/camp': (context) => const CampScreen(),
        '/map': (context) => const UnifiedMapScreen(),
        '/area': (context) => const UnifiedMapScreen(),
        '/region': (context) => const UnifiedMapScreen(),
        '/world': (context) => const UnifiedMapScreen(),
        '/reports': (context) => const GlobalReportsScreen(),
        '/combat_simulator': (context) =>
            const CombatSimulatorScreen(), // Added route
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
              Provider.of<GameState>(context, listen: false).latestCombatReport;
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
    final bool isCompact = screenHeight < 500; // Landscape iPhone

    // Adaptive sizing for compact (landscape phone) vs large screens
    final double titleHeight = isCompact ? screenHeight * 0.18 : screenHeight * 0.15;
    final double bigGap = isCompact ? 12.0 : 48.0;
    final double smallGap = isCompact ? 10.0 : 20.0;
    final double buttonWidth = isCompact ? 240.0 : 280.0;
    final double buttonHeight = isCompact ? 42.0 : 55.0;
    final double buttonFontSize = isCompact ? 16.0 : 20.0;
    final double verticalPadding = isCompact ? 8.0 : 24.0;

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
                color: Colors.black.withValues(alpha: 0.3),
                colorBlendMode: BlendMode.darken,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: verticalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/title.png',
                          height: titleHeight,
                        ),
                        SizedBox(height: bigGap),
                        _MenuButton(
                            text: 'NEW GAME',
                            width: buttonWidth,
                            height: buttonHeight,
                            fontSize: buttonFontSize,
                            onPressed: () {
                              Navigator.pushNamed(context, '/newGame');
                            }),
                        SizedBox(height: smallGap),
                        _MenuButton(
                            text: 'COMBAT SIMULATOR',
                            width: buttonWidth,
                            height: buttonHeight,
                            fontSize: buttonFontSize,
                            onPressed: () {
                              Navigator.pushNamed(context, '/combat_simulator');
                            }),
                        SizedBox(height: smallGap),
                        _MenuButton(
                            text: 'LOAD GAME',
                            width: buttonWidth,
                            height: buttonHeight,
                            fontSize: buttonFontSize,
                            onPressed: () {
                              Navigator.pushNamed(context, '/load_game');
                            }),
                        SizedBox(height: smallGap),
                        _MenuButton(
                            text: 'SETTINGS',
                            width: buttonWidth,
                            height: buttonHeight,
                            fontSize: buttonFontSize,
                            onPressed: () {
                              Navigator.pushNamed(context, '/settings');
                            }),
                        SizedBox(height: smallGap),
                        _MenuButton(
                            text: 'ABOUT',
                            width: buttonWidth,
                            height: buttonHeight,
                            fontSize: buttonFontSize,
                            onPressed: () {
                              Navigator.pushNamed(context, '/about');
                            }),
                        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) ...[
                          SizedBox(height: smallGap),
                          _MenuButton(
                              text: 'EXIT',
                              width: buttonWidth,
                              height: buttonHeight,
                              fontSize: buttonFontSize,
                              onPressed: () {
                                exit(0);
                              }),
                        ],
                        // Hide the alpha section on very compact screens to avoid crowding
                        if (!isCompact) ...[
                          SizedBox(height: bigGap),
                          // State of Development Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'ALPHA DEVELOPMENT',
                                  style: GoogleFonts.cinzel(
                                      color: Colors.amber[100],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Active development in progress. Roadmap includes deeper social systems, trade routes, and expanded map content.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cinzel(
                                      color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () async {
                                    final Uri url =
                                        Uri.parse('https://github.com/renaudd/aravt');
                                    if (!await launchUrl(url)) {
                                      debugPrint('Could not launch $url');
                                    }
                                  },
                                  child: Text(
                                    'VIEW ON GITHUB',
                                    style: GoogleFonts.cinzel(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                        fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
  final double width;
  final double height;
  final double fontSize;

  const _MenuButton({
    required this.text,
    required this.onPressed,
    this.width = 280.0,
    this.height = 55.0,
    this.fontSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
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
              fontSize: fontSize,
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
