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

  bool get isActive => _isActive;

  // --- THE TUTORIAL SCRIPT ---
  final List<TutorialStepData> _steps = [
    // 0. Intro (Camp)
    TutorialStepData(
        "Captain. A word, if you will. Those dreams you've been having... bad omens. The spirits are restless.",
        requiredRoute: '/camp'),
    // 1. The Threat (Camp)
    TutorialStepData(
        "And now the Khan's threat to 'cut an Aravt loose' at the end of the week? The eyes of the horde are upon us."),
    // 2. Call to Action (Camp)
    TutorialStepData(
        "We must ensure it is not *our* aravt that falls. The tournament is in seven days. We need to be prepared."),
    // 3. Yurts/Roster Info (Camp)
    TutorialStepData(
        "See these yurts? Click on them to know your soldiers. Their strengths, their weaknesses... their loyalties. Lives depend on it."),
    // 4. Horde Screen Guidance (Navigate to Horde/Roster)
    TutorialStepData(
        "Here is where we manage our ranks. Keep them busy with tasks, or they will get restless... or worse.",
        requiredRoute:
            '/roster'), // Assuming '/roster' or '/horde' is your roster screen route
    // 5. Inventory Guidance (Navigate to Inventory)
    TutorialStepData(
        "Check our supplies often. We cannot fight—or win tournaments—on empty stomachs.",
        requiredRoute: '/inventory'),
    // 6. Wrap up (Return to Camp)
    TutorialStepData(
        "Stay sharp, Captain. Review the upcoming tournament events in the Reports screen, and ready your men.",
        requiredRoute: '/camp'),
  ];

  void startTutorial(BuildContext context, GameState gameState) {
    if (gameState.tutorialPermanentlyDismissed || gameState.tutorialCompleted)
      return;

    _isActive = true;
    // [GEMINI-FIX] Resume from persistent step index
    _currentIndex = gameState.tutorialStepIndex;

    // Ensure we start at the right place physically and visually
    if (_currentIndex < _steps.length) {
      _checkAndNavigate(context, _steps[_currentIndex].requiredRoute);
    }
    notifyListeners();
  }

  TutorialStepData? get currentStep =>
      _isActive && _currentIndex < _steps.length ? _steps[_currentIndex] : null;

  void advance(BuildContext context, GameState gameState) {
    // [GEMINI-FIX] Update persistent step index
    gameState.tutorialStepIndex++;
    _currentIndex = gameState.tutorialStepIndex;

    if (_currentIndex >= _steps.length) {
      complete(gameState, success: true);
    } else {
      // Handle forced navigation for the next step
      _checkAndNavigate(context, _steps[_currentIndex].requiredRoute);
      notifyListeners();
    }
  }

  void _checkAndNavigate(BuildContext context, String? routeName) {
    if (routeName != null) {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      // Only navigate if we aren't already there
      if (currentRoute != routeName) {
        // Using pushReplacement to avoid building a massive back stack during tutorial
        Navigator.of(context).pushReplacementNamed(routeName);
      }
    }
  }

  void dismiss(GameState gameState) {
    if (!_isActive) return;

    gameState.tutorialDismissalCount++;
    _isActive = false;

    // [GEMINI-FIX] Advance to next major section instead of restarting
    // Tutorial sections: 0-3 (Camp), 4 (Horde), 5 (Inventory), 6 (Wrap-up)
    if (_currentIndex <= 3) {
      // Dismissed during Camp intro → jump to Horde section
      gameState.tutorialStepIndex = 4;
    } else if (_currentIndex == 4) {
      // Dismissed during Horde → jump to Inventory
      gameState.tutorialStepIndex = 5;
    } else if (_currentIndex == 5) {
      // Dismissed during Inventory → jump to wrap-up
      gameState.tutorialStepIndex = 6;
    } else {
      // Dismissed during wrap-up → mark as completed
      gameState.tutorialCompleted = true;
    }

    final captain = _getTutorialCaptain(gameState);
    if (captain != null) {
      // 1. Apply Penalty (-0.4 Adm, -0.2 Res per dismissal)
      captain
          .getRelationship(gameState.player?.id ?? -1)
          .updateAdmiration(-0.4);
      captain.getRelationship(gameState.player?.id ?? -1).updateRespect(-0.2);

      // 2. Check for permanent dismissal (3 strikes)
      if (gameState.tutorialDismissalCount >= 3) {
        gameState.tutorialPermanentlyDismissed = true;
        gameState.logEvent(
            "${captain.name} is disgusted by your arrogance and will offer no further guidance.",
            category: EventCategory.general,
            severity: EventSeverity.high,
            soldierId: captain.id);
      } else {
        gameState.logEvent(
            "${captain.name} seems annoyed you dismissed their advice.",
            category: EventCategory.general,
            soldierId: captain.id);
      }
    }
    notifyListeners();
  }

  void complete(GameState gameState, {bool success = false}) {
    _isActive = false;
    if (success) {
      gameState.tutorialCompleted = true;
      final captain = _getTutorialCaptain(gameState);
      if (captain != null) {
        // Reward: +0.5 Adm, +0.2 Res
        captain
            .getRelationship(gameState.player?.id ?? -1)
            .updateAdmiration(0.5);
        captain.getRelationship(gameState.player?.id ?? -1).updateRespect(0.2);

        gameState.logEvent(
            "${captain.name} appreciates your attention to their counsel.",
            category: EventCategory.general,
            soldierId: captain.id);
      }
    }
    notifyListeners();
  }

  Soldier? _getTutorialCaptain(GameState gameState) {
    if (gameState.tutorialCaptainId != null) {
      return gameState.findSoldierById(gameState.tutorialCaptainId!);
    }
    return null;
  }
}
