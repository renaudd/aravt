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
  TutorialStepData(this.text,
      {this.requiredRoute, this.highlightKey, this.isConclude = false});
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

  void resetTutorialNavigation() {
    _tutorialSoldierId = null;
    _tutorialTabIndex = null;
    _shouldOpenHordePanel = false;
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
        "Captain. I am the leader of the Second Aravt. We must organize. Access the Horde Panel to review our forces.",
        requiredRoute: '/camp',
        highlightKey: 'open_horde_panel'),
    // 1. Profile (Horde) -> Direct to Player Profile
    TutorialStepData(
        "You are the captain of the Third Aravt. Press your profile icon to inspect your own status.",
        requiredRoute: '/camp', // Horde panel is in camp
        highlightKey: 'open_player_profile'),
    // 2. Navigation (Profile) -> Direct to Next
    TutorialStepData(
        "Good. Now, press the navigate next button to cycle through the members of your aravt.",
        requiredRoute: null,
        highlightKey: 'navigate_next_soldier'),
    // 3. Inquire (Profile) -> Direct to Inquire
    TutorialStepData(
        "You must know your men. Use the 'Inquire' button to learn of their traits and history.",
        requiredRoute: null,
        highlightKey: 'inquire_soldier'),
    // 4. Aravt Tab (Profile) -> Direct to Aravt Tab
    TutorialStepData(
        "Go up to the Aravt tab. You won't want to keep all these responsibilities to yourself.",
        requiredRoute: null,
        highlightKey: 'open_aravt_tab'),
    // 5. Next Turn
    TutorialStepData(
        "When you’re done divvying up responsibilities and getting to know your soldiers, hit the Next Turn button to advance to the next day.",
        requiredRoute: null,
        highlightKey: 'next_turn_button'),
    // 6. Open Horde Panel Again
    TutorialStepData("Open the horde panel again.",
        requiredRoute: '/camp', highlightKey: 'open_horde_panel'),
    // 7. Reports Tab
    TutorialStepData(
        "Now you can see what each aravt has been assigned to do. If you ever become horde leader, it will be your job to assign these tasks. Click on the Reports Tab.",
        requiredRoute: null,
        highlightKey: 'open_reports_tab'),
    // 8. Conclude
    TutorialStepData(
        "Every assignment will produce a report upon completion. Study them to identify who deserves to be praised or scolded. You'll need to make the other captains respect you if you expect them to call you Khan some day.",
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

  void advance(BuildContext context, GameState gameState) {
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
    gameState.tutorialDismissalCount++;
    cyclePortrait(angry: true); // Cycle to next angry portrait

    // Apply penalty based on dismissal count
    double penalty = -0.2; // Default
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
      // Stay on Camp Screen for Horde Panel
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
        print(
            "[TUTORIAL] Navigating to Player Profile: ${gameState.player!.id}");
        navigatorKey.currentState
            ?.pushNamed('/soldier_profile', arguments: gameState.player!.id);
      }
      return;
    } else if (gameState.tutorialStepIndex == 3 ||
        gameState.tutorialStepIndex == 4) {
      // Only perform automatic navigation if resuming.
      // If advancing, we want the user to manually click.
      if (!isResume) {
        print(
            "[TUTORIAL] Skipping auto-navigation for step ${gameState.tutorialStepIndex} (advance)");
        return;
      }

      // Navigate to Second Soldier Profile
      if (gameState.player != null) {
        final aravt = gameState.findAravtById(gameState.player!.aravt);
        if (aravt != null && aravt.soldierIds.length > 1) {
          // Find a soldier that isn't the player
          final secondSoldierId =
              aravt.soldierIds.firstWhere((id) => id != gameState.player!.id);
          _tutorialSoldierId = secondSoldierId;

          // if (gameState.tutorialStepIndex == 4) {
          //   _tutorialTabIndex = 1; // Aravt Tab
          // }
          notifyListeners();
          print(
              "[TUTORIAL] Navigating to Second Soldier Profile: $secondSoldierId, Tab: $_tutorialTabIndex");
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
