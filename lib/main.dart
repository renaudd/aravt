// lib/main.dart
import 'dart:io'; //For exit(0) on desktop
import 'package:flutter/foundation.dart' show kIsWeb; // For platform check
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aravt/game_data/item_templates.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/services/tutorial_service.dart'; // [GEMINI-NEW]
import 'package:aravt/screens/area_screen.dart';
import 'package:aravt/screens/region_screen.dart';
import 'package:aravt/screens/combat_screen.dart';
import 'package:aravt/screens/load_game_screen.dart';
import 'package:aravt/screens/save_game_screen.dart';
import 'package:aravt/screens/new_game_screen.dart';
import 'package:aravt/screens/world_map_screen.dart';
import 'package:aravt/screens/camp_screen.dart';
import 'package:aravt/screens/horde_screen.dart';
import 'package:aravt/screens/global_reports_screen.dart';
import 'package:aravt/screens/global_inventory_screen.dart';
import 'package:aravt/screens/settings_screen.dart'; // [GEMINI-NEW]
import 'package:aravt/screens/game_over_screen.dart'; // [GEMINI-NEW]
import 'package:aravt/screens/pre_combat_screen.dart';
import 'package:aravt/screens/post_combat_report_screen.dart';
import 'package:aravt/models/combat_flow_state.dart';
import 'package:aravt/widgets/tutorial_overlay_widget.dart';
import 'package:aravt/widgets/narrative_overlay_widget.dart';

void main() {
  ItemDatabase.initialize();
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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

    // Use postFrameCallback to ensure we don't try to navigate while building
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;

      // --- HANDLE GAME OVER ---
      if (isGameOver && !_wasGameOver) {
        _wasGameOver = true;
        // Push game over and remove everything but main menu to prevent going back
        navigator.pushNamedAndRemoveUntil(
            '/gameOver', ModalRoute.withName('/mainMenu'));
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aravt',
      navigatorKey: _navigatorKey,
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
      initialRoute: '/mainMenu',
      routes: {
        '/mainMenu': (context) => const MainMenuScreen(),
        '/newGame': (context) => const NewGameScreen(),
        '/save_game': (context) => const SaveGameScreen(),
        '/load_game': (context) => const LoadGameScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/gameOver': (context) => const GameOverScreen(),
        // --- IN-GAME ROUTES (Wrapped with Overlays) ---
        '/camp': (context) => const _GameScreenWrapper(child: CampScreen()),
        '/horde': (context) => const _GameScreenWrapper(child: HordeScreen()),
        '/area': (context) => const _GameScreenWrapper(child: AreaScreen()),
        '/region': (context) => const _GameScreenWrapper(child: RegionScreen()),
        '/world': (context) =>
            const _GameScreenWrapper(child: WorldMapScreen()),
        '/reports': (context) =>
            const _GameScreenWrapper(child: GlobalReportsScreen()),
        '/inventory': (context) =>
            const _GameScreenWrapper(child: GlobalInventoryScreen()),
        // --- COMBAT ROUTES (Typically don't need standard overlays) ---
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

// --- WRAPPER FOR IN-GAME SCREENS ---
// This ensures the Tutorial and Narrative overlays are present
// AND have access to the correct Navigator context.
class _GameScreenWrapper extends StatelessWidget {
  final Widget child;
  const _GameScreenWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // The order here matters: Narrative on top of Tutorial on top of Game
        const TutorialOverlayWidget(),
        const NarrativeOverlayWidget(),
      ],
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
