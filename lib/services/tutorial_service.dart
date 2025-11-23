import 'package:flutter/material.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/game_event.dart';

class TutorialStepData {
  final String text;

  /// The named route to navigate to when this step begins.
  /// If null, stays on the current screen.
  final String? requiredRoute;
  TutorialStepData(this.text, {this.requiredRoute});
}

class TutorialService extends ChangeNotifier {
  bool _isActive = false;
  int _currentIndex = 0;

  // Portrait cycling state
  int _captainPortraitIndex = 0; // 0-8 for grid position
  bool _isShowingAngryPortrait = false;

  bool get isActive => _isActive;
  int get captainPortraitIndex => _captainPortraitIndex;
  bool get isShowingAngryPortrait => _isShowingAngryPortrait;

  String getCaptainPortraitPath() {
    return _isShowingAngryPortrait
        ? 'assets/images/angry_captain.png'
        : 'assets/images/happy_captain.png';
  }

  // --- THE TUTORIAL SCRIPT ---
  final List<TutorialStepData> _steps = [
    // 0. Intro (Camp) -> Direct to Horde
    TutorialStepData(
        "Captain. I am the leader of the Second Aravt. We must organize. Access the Horde Panel to review our forces.",
        requiredRoute: '/camp'),
    // 1. Profile (Horde) -> Direct to Player Profile
    TutorialStepData(
        "You are the captain of the Third Aravt. Press your profile icon to inspect your own status.",
        requiredRoute: '/horde'),
    // 2. Navigation (Profile) -> Direct to Next
    TutorialStepData(
        "Good. Now, press the navigate next button to cycle through the members of your aravt.",
        requiredRoute: null), // User should be on profile screen
    // 3. Inquire (Profile) -> Direct to Inquire
    TutorialStepData(
        "You must know your men. Use the 'Inquire' button to learn of their traits and history.",
        requiredRoute: null),
    // 4. Aravt Tab (Profile) -> Direct to Aravt Tab
    TutorialStepData(
        "Finally, go to the Aravt tab. Here you must distribute responsibilities. Do not let them sit idle.",
        requiredRoute: null),
  ];

  void startTutorial(BuildContext context, GameState gameState) {
    if (gameState.tutorialPermanentlyDismissed || gameState.tutorialCompleted)
      return;

    _isActive = true;
    _currentIndex = gameState.tutorialStepIndex;
    _captainPortraitIndex = 0;
    // [GEMINI-FIX] Start angry if they've dismissed us before
    _isShowingAngryPortrait = gameState.tutorialDismissalCount > 0;

    print(
        "[TUTORIAL] Starting tutorial - portrait index: $_captainPortraitIndex, angry: $_isShowingAngryPortrait, path: ${getCaptainPortraitPath()}");

    // Ensure we start at the right place physically and visually
    if (_currentIndex < _steps.length) {
      _checkAndNavigate(context, _steps[_currentIndex].requiredRoute);
    }
    notifyListeners();
  }

  TutorialStepData? get currentStep =>
      _isActive && _currentIndex < _steps.length ? _steps[_currentIndex] : null;

  void cyclePortrait({bool angry = false}) {
    _isShowingAngryPortrait = angry;
    _captainPortraitIndex = (_captainPortraitIndex + 1) % 9;
    notifyListeners();
  }

  void advance(BuildContext context, GameState gameState) {
    cyclePortrait(angry: false); // Cycle to next happy portrait
    gameState.tutorialStepIndex++;
    _currentIndex = gameState.tutorialStepIndex;

    if (_currentIndex >= _steps.length) {
      complete(gameState, success: true);
    } else {
      if (_steps[_currentIndex].requiredRoute != null) {
        _checkAndNavigate(context, _steps[_currentIndex].requiredRoute);
      }
      notifyListeners();
    }
  }

  void dismiss(BuildContext context, GameState gameState) {
    gameState.tutorialDismissalCount++;
    _isShowingAngryPortrait = true; // Immediate feedback

    // Apply penalty
    _applyReputationChange(gameState, -1.0, -1.0); // Lose respect/admiration

    if (gameState.tutorialDismissalCount >= 3) {
      gameState.tutorialPermanentlyDismissed = true;
      _isActive = false;
      notifyListeners();
    } else {
      // Advance to next step so they don't see the same one again
      gameState.tutorialStepIndex++;
      _currentIndex = gameState.tutorialStepIndex;
      _isActive = false;
      notifyListeners();
    }
  }

  void complete(GameState gameState, {required bool success}) {
    _isActive = false;
    gameState.tutorialCompleted = true;

    if (success) {
      // Apply bonus
      _applyReputationChange(gameState, 1.0, 1.0); // Gain respect/admiration
    }
    notifyListeners();
  }

  void _applyReputationChange(
      GameState gameState, double admirationChange, double respectChange) {
    if (gameState.tutorialCaptainId == null || gameState.player == null) return;

    final captain = gameState.findSoldierById(gameState.tutorialCaptainId!);
    final player = gameState.player!;

    if (captain != null) {
      // Captain -> Player relationship
      final rel = captain.getRelationship(player.id);
      rel.admiration = (rel.admiration + admirationChange).clamp(0.0, 5.0);
      rel.respect = (rel.respect + respectChange).clamp(0.0, 5.0);

      print(
          "[TUTORIAL] Reputation update for ${captain.name}: Adm ${rel.admiration}, Res ${rel.respect}");

      gameState.logEvent(
          admirationChange > 0
              ? "${captain.name} is impressed by your attentiveness."
              : "${captain.name} is annoyed by your dismissal.",
          category: EventCategory.general,
          severity:
              admirationChange > 0 ? EventSeverity.low : EventSeverity.normal);
    }
  }

  void _checkAndNavigate(BuildContext context, String? routeName) {
    if (routeName == null) return;
    try {
      Navigator.of(context).pushReplacementNamed(routeName);
    } catch (e) {
      print("[TUTORIAL] Navigation error: $e");
    }
  }
}
