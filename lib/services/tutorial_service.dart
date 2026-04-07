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

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/main.dart'; //  Import main for navigatorKey

class TutorialStepData {
  final String text;
  final String? requiredRoute;
  final String? highlightKey; //  Key for UI highlighting
  final bool isConclude; //  Whether this is the final step
  /// When set, the overlay draws the red arrow at this fractional screen
  /// position (Alignment coords: -1,-1 = top-left, 1,1 = bottom-right)
  /// instead of tracking the widget's render-box position.  Use this for
  /// buttons that live inside Transform.scale widgets whose coordinates are
  /// Unreliable via localToGlobal.
  final Alignment? screenAnchor;
  /// Direction the arrow should point. 0 = down (default), pi/2 = left, -pi/2 = right, pi = up.
  final double arrowRotation;
  TutorialStepData(this.text,
      {this.requiredRoute,
      this.highlightKey,
      this.isConclude = false,
      this.screenAnchor,
      this.arrowRotation = 0.0});
}

class TutorialService extends ChangeNotifier {
  bool _isActive = false;
  int _currentIndex = 0;

  // Portrait cycling state
  int _captainPortraitIndex = 0; // 0-8 for grid position
  bool _isShowingAngryPortrait = false;
  int _lastTurnStarted = -1; // Track last turn tutorial was active

  // Complex Navigation State
  int? _tutorialSoldierId;
  int? _tutorialTabIndex;
  bool _shouldOpenHordePanel = false;

  bool get isActive => _isActive;
  int get captainPortraitIndex => _captainPortraitIndex;
  bool get isShowingAngryPortrait => _isShowingAngryPortrait;
  int get lastTurnStarted => _lastTurnStarted;
  int? get tutorialSoldierId => _tutorialSoldierId;
  int? get tutorialTabIndex => _tutorialTabIndex;
  bool get shouldOpenHordePanel => _shouldOpenHordePanel;
  Rect? _highlightPosition;
  Rect? get highlightPosition => _highlightPosition;

  void updateHighlightPosition(Rect? rect) {
    if (_highlightPosition != rect) {
      _highlightPosition = rect;
      notifyListeners();
    }
  }

  void resetTutorialNavigation() {
    _tutorialSoldierId = null;
    _tutorialTabIndex = null;
    _shouldOpenHordePanel = false;
    _highlightPosition = null;
    notifyListeners();
  }

  String getCaptainPortraitPath() {
    return _isShowingAngryPortrait
        ? 'assets/images/angry_captain.png'
        : 'assets/images/happy_captain.png';
  }

  // --- THE TUTORIAL SCRIPT ---
  final List<TutorialStepData> _steps = [
    // 0. Intro (Camp) -> Direct to Horde
    TutorialStepData(
        "Congratulations on your promotion, Captain. I am the leader of the Second Aravt. Let me show you around. Access the Horde Panel to review our forces.",
        requiredRoute: '/camp',
        highlightKey: 'open_horde_panel'),
    // 1. Profile (Horde) -> Direct to Player Profile
    TutorialStepData(
        "You are the captain of the Third Aravt. Press your profile icon to inspect your own file.",
        requiredRoute: '/camp',
        highlightKey: 'open_player_profile'),
    TutorialStepData(
        "Now, press the navigate next button to cycle through the members of your aravt.",
        requiredRoute: null,
        highlightKey: 'navigate_next_soldier',
        screenAnchor: const Alignment(0.8, -0.9),
        arrowRotation: -pi / 2),
    // 3. Inquire (Profile) -> Highlight only the Inquire button
    TutorialStepData(
        "Get to know your men. Use the 'Inquire' button to uncover a soldier's traits and history. Each interaction costs a token.",
        requiredRoute: null,
        highlightKey: 'inquire_soldier'),
    // 4. Aravt Tab (Profile) -> Direct to Aravt Tab
    TutorialStepData("Go up to the Aravt tab.",
        requiredRoute: null,
        highlightKey: 'open_aravt_tab',
        screenAnchor: const Alignment(-0.4, -0.465)),
    // 5. Next Turn
    TutorialStepData(
        "This is where you can assign duties to your men. You won't want to keep all these responsibilities to yourself. When you're done, hit the Next Turn button to advance to the next day.",
        requiredRoute: null,
        highlightKey: 'next_turn_button',
        // Bottom-right corner: the play button is the rightmost item in the nav bar
        screenAnchor: const Alignment(0.98, 0.92)),
    // 6. Open Horde Panel Again
    TutorialStepData("Open the horde panel again.",
        requiredRoute: '/camp',
        highlightKey: 'open_horde_panel',
        // Horde button is the first icon in the nav bar, near bottom-right
        screenAnchor: const Alignment(0.60, 0.92)),
    // 7. Reports Tab
    TutorialStepData(
        "Now you can see what our leader has assigned each aravt to do. Click on the Reports Tab.",
        requiredRoute: null,
        highlightKey: 'open_reports_tab',
        // Reports button is the second icon in the nav bar
        screenAnchor: const Alignment(0.68, 0.92)),
    // 8. Conclude
    TutorialStepData(
        "Every assignment will produce a report upon completion. Study them to identify who deserves to be praised or scolded. You'll want to make the other captains respect you if you expect them to call you Khan some day.",
        requiredRoute: null,
        highlightKey: null,
        isConclude: true),
  ];

  void startTutorial(BuildContext context, GameState gameState) {
    if (gameState.tutorialPermanentlyDismissed || gameState.tutorialCompleted)
      return;

    _isActive = true;
    _currentIndex = gameState.tutorialStepIndex;

    // _captainPortraitIndex = 0;

    _isShowingAngryPortrait = gameState.tutorialDismissalCount > 0;
    _lastTurnStarted = gameState.turn.turnNumber;

    print(
        "[TUTORIAL] Starting tutorial - portrait index: $_captainPortraitIndex, angry: $_isShowingAngryPortrait, path: ${getCaptainPortraitPath()}");

    // Ensure we start at the right place physically and visually
    if (_currentIndex < _steps.length) {
      _checkAndNavigate(context, _steps[_currentIndex].requiredRoute,
          isResume: true);
    }
    notifyListeners();
  }

  TutorialStepData? get currentStep =>
      _isActive && _currentIndex < _steps.length ? _steps[_currentIndex] : null;

  void cyclePortrait({bool angry = false}) {
    // If already angry, stay angry. Otherwise, set to requested state.
    if (_isShowingAngryPortrait) {
      _isShowingAngryPortrait = true;
    } else {
      _isShowingAngryPortrait = angry;
    }
    // Randomize portrait index (0-8)
    _captainPortraitIndex = Random().nextInt(9);
    notifyListeners();
  }

  bool _isAdvancing = false;

  void advance(BuildContext context, GameState gameState) {
    if (_isAdvancing) return;
    _isAdvancing = true;

    _highlightPosition = null;
    cyclePortrait(
        angry:
            false); // Cycle to next portrait, will stay angry if already angry
    gameState.tutorialStepIndex++;
    _currentIndex = gameState.tutorialStepIndex;

    if (_currentIndex >= _steps.length) {
      complete(gameState, success: true);
    } else {
      if (_steps[_currentIndex].requiredRoute != null) {
        _checkAndNavigate(context, _steps[_currentIndex].requiredRoute,
            isResume: false);
      } else {
        // If no required route, still check for complex navigation
        _checkAndNavigate(context, null, isResume: false);
      }
      notifyListeners();
    }

    // Reset advancing flag after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _isAdvancing = false;
    });
  }

  void advanceIfHighlighted(
      BuildContext context, GameState gameState, String key) {
    if (_isActive &&
        _currentIndex < _steps.length &&
        _steps[_currentIndex].highlightKey == key) {
      advance(context, gameState);
    }
  }

  void dismiss(BuildContext context, GameState gameState) {
    _highlightPosition = null;
    gameState.tutorialDismissalCount++;
    cyclePortrait(angry: true);

    // Remember the current turn — the tutorial won't re-activate until the
    // player advances at least one turn.
    _lastTurnStarted = gameState.turn.turnNumber;

    double penalty = -0.2;
    if (gameState.tutorialDismissalCount == 1)
      penalty = -0.35;
    else if (gameState.tutorialDismissalCount == 2)
      penalty = -0.3;
    else if (gameState.tutorialDismissalCount >= 3) penalty = -0.25;

    _applyReputationChange(gameState, penalty, penalty);

    if (gameState.tutorialDismissalCount >= 3) {
      gameState.tutorialPermanentlyDismissed = true;
      _isActive = false;
      notifyListeners();
    } else {
      // Advance past the current step so the same dialogue doesn't reappear.
      gameState.tutorialStepIndex++;
      _currentIndex = gameState.tutorialStepIndex;
      _isActive = false;
      notifyListeners();
    }
  }

  /// Silently deactivates the tutorial without any game-state side effects.
  /// Call this when the player quits to the main menu so the dialogue
  /// doesn't bleed into a new session.
  void deactivateForQuit() {
    _isActive = false;
    _highlightPosition = null;
    _tutorialSoldierId = null;
    _tutorialTabIndex = null;
    _shouldOpenHordePanel = false;
    notifyListeners();
  }

  void complete(GameState gameState, {required bool success}) {
    print(
        "[TUTORIAL] Completing tutorial. Success: $success, Dismissal Count: ${gameState.tutorialDismissalCount}, Current Index: $_currentIndex");
    _isActive = false;
    gameState.tutorialCompleted = true;

    if (success && gameState.tutorialDismissalCount == 0) {
      // Apply bonus only if never dismissed
      _applyReputationChange(gameState, 0.5, 0.5); // Gain respect/admiration
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
      final oldRespect = rel.respect;
      final oldAdmiration = rel.admiration;

      rel.respect = (rel.respect + respectChange).clamp(0.0, 5.0);
      rel.admiration = (rel.admiration + admirationChange).clamp(0.0, 5.0);

      print(
          "[TUTORIAL] Reputation Change: Respect ${oldRespect.toStringAsFixed(2)} -> ${rel.respect.toStringAsFixed(2)} (${respectChange > 0 ? '+' : ''}${respectChange.toStringAsFixed(2)}), Admiration ${oldAdmiration.toStringAsFixed(2)} -> ${rel.admiration.toStringAsFixed(2)} (${admirationChange > 0 ? '+' : ''}${admirationChange.toStringAsFixed(2)})");

      gameState.logEvent(
          admirationChange > 0
              ? "${captain.name} is impressed by your attentiveness."
              : "${captain.name} is annoyed by your dismissal.",
          category: EventCategory.general,
          severity:
              admirationChange > 0 ? EventSeverity.low : EventSeverity.normal);
    }
  }

  void _checkAndNavigate(BuildContext context, String? routeName,
      {bool isResume = false}) {
    // Reset previous navigation state
    _tutorialSoldierId = null;
    _tutorialTabIndex = null;
    _shouldOpenHordePanel = false;

    final gameState = context.read<GameState>();

    // Handle specific steps
    print(
        "[TUTORIAL] Navigating for step ${gameState.tutorialStepIndex}, isResume: $isResume");
    if (gameState.tutorialStepIndex == 1) {
      _shouldOpenHordePanel = true;
      notifyListeners();
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute != '/camp') {
        if (navigatorKey.currentState?.canPop() ?? false) {
          navigatorKey.currentState?.popUntil(ModalRoute.withName('/camp'));
        } else {
          navigatorKey.currentState?.pushReplacementNamed('/camp');
        }
      }
      return;
    } else if (gameState.tutorialStepIndex == 2) {
      // Navigate to Player Profile
      if (gameState.player != null) {
        _tutorialSoldierId = gameState.player!.id;
        notifyListeners();
        navigatorKey.currentState
            ?.pushNamed('/soldier_profile', arguments: gameState.player!.id);
      }
      return;
    } else if (gameState.tutorialStepIndex == 3 ||
        gameState.tutorialStepIndex == 4) {
      // Steps 3–4 take place on a soldier profile; on resume navigate there.
      if (!isResume) return;

      if (gameState.player != null) {
        final aravt = gameState.findAravtById(gameState.player!.aravt);
        if (aravt != null && aravt.soldierIds.length > 1) {
          final secondSoldierId =
              aravt.soldierIds.firstWhere((id) => id != gameState.player!.id);
          _tutorialSoldierId = secondSoldierId;
          notifyListeners();
          navigatorKey.currentState
              ?.pushNamed('/soldier_profile', arguments: secondSoldierId);
        }
      }
      return;
    }

    if (routeName == null) return;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == routeName) {
      print(
          "[TUTORIAL] Already on required route: $routeName. Skipping navigation.");
      return;
    }

    try {
      navigatorKey.currentState?.pushReplacementNamed(routeName);
    } catch (e) {
      print("[TUTORIAL] Navigation error: $e");
    }
  }

  //  Helper to find the tutorial captain, with fallback
  Soldier? getTutorialCaptain(GameState gameState) {
    // 1. Try ID from state
    if (gameState.tutorialCaptainId != null) {
      final s = gameState.findSoldierById(gameState.tutorialCaptainId!);
      if (s != null) return s;
    }

    // 2. Fallback: Find captain of Second Aravt (aravt_2)
    try {
      final secondAravt = gameState.aravts.firstWhere(
          (a) => a.id == 'aravt_2' || a.id.toLowerCase().contains('second'),
          orElse: () => gameState.aravts[1] // Fallback to index 1
          );

      final captain = gameState.findSoldierById(secondAravt.captainId);
      if (captain != null) {
        // Auto-fix the state ID
        gameState.tutorialCaptainId = captain.id;
        return captain;
      }
    } catch (e) {
      // print("Error finding fallback tutorial captain: $e");
    }

    return null;
  }
}
