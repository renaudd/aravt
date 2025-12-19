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
import '../providers/game_state.dart';
import 'horde_panel.dart';
import 'notification_badge.dart'; //  Import notification badge
import 'tutorial_highlighter.dart'; //  Import highlighter
import '../services/tutorial_service.dart'; //  Import tutorial service
// Removed unused screen imports

class PersistentMenuWidget extends StatefulWidget {
  const PersistentMenuWidget({super.key});

  @override
  State<PersistentMenuWidget> createState() => _PersistentMenuWidgetState();
}

class _PersistentMenuWidgetState extends State<PersistentMenuWidget> {
  bool _isMenuOpen = false;
  // _isHordePanelOpen is now in GameState

  Widget _buildMenuButton(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      bool enabled = true,
      int badgeCount = 0}) {
    //  Added badge count parameter
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Tooltip(
        message: enabled ? tooltip : "$tooltip (Current Screen)",
        child: Stack(
          //  Wrap in Stack for badge
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: enabled
                      ? Colors.black.withOpacity(0.6)
                      : Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: enabled ? Colors.white54 : Colors.white24,
                      width: 1),
                ),
                child: Icon(icon,
                    color: enabled ? Colors.white : Colors.white54, size: 24),
              ),
            ),
            //  Add badge if count > 0
            NotificationBadge(count: badgeCount),
          ],
        ),
      ),
    );
  }

  Widget _buildSubMenuButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.black.withOpacity(0.7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: Colors.white54, width: 1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _showQuitConfirmationDialog(BuildContext context) async {
    bool? shouldQuit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Quit to Main Menu?',
              style: GoogleFonts.cinzel(color: Colors.white)),
          content: Text(
              'Are you sure you want to quit?\nAny unsaved progress will be lost.',
              style: GoogleFonts.cinzel(color: Colors.white70)),
          actions: [
            TextButton(
              child: Text('Cancel',
                  style: GoogleFonts.cinzel(color: Colors.white70)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text('Quit',
                  style: GoogleFonts.cinzel(color: Colors.redAccent)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldQuit == true && mounted) {

      Navigator.pushNamedAndRemoveUntil(context, '/mainMenu', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final gameNotifier = context.read<GameState>();
    final tutorial = context.watch<TutorialService>();

    //  Auto-open Horde Panel for tutorial
    //  Auto-open Horde Panel for tutorial
    if (tutorial.shouldOpenHordePanel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && tutorial.shouldOpenHordePanel) {
          tutorial.resetTutorialNavigation(); // Reset flag immediately
          tutorial.resetTutorialNavigation(); // Reset flag immediately
          gameNotifier.setHordePanelOpen(true);
        }
      });
    }

    final currentRouteName = ModalRoute.of(context)?.settings.name;
    final bool canNavigateToCamp = currentRouteName != '/camp';
    final bool canNavigateToArea = currentRouteName != '/area';
    final bool canNavigateToRegion = currentRouteName != '/region';
    final bool canNavigateToWorldMap = currentRouteName != '/world';

    return Positioned.fill(
      child: Stack(
        children: [
          //  Horde Panel Overlay
          //  Horde Panel Overlay (Non-blocking, positioned above menu)
          if (gameState.isHordePanelOpen)
            Positioned(
              bottom: 78,
              left: 0,
              right: 0,

              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 600, // Fixed width as requested
                  child: Stack(
                    children: [
                      const HordePanel(),
                      // Close button for the panel
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                            onPressed: () =>
                                gameNotifier.setHordePanelOpen(false),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          //  Menu Buttons (Always on top)
          Positioned(
            bottom: 15,
            right: 15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isMenuOpen)
                  Container(
                    width: 250,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white54, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSubMenuButton('Save Game', () {
                          setState(() => _isMenuOpen = false);
                          Navigator.pushNamed(context, '/save_game');
                        }),
                        _buildSubMenuButton('Load Game', () {
                          setState(() => _isMenuOpen = false);
                          Navigator.pushNamed(context, '/load_game');
                        }),
                        _buildSubMenuButton('Options', () {
                          setState(() => _isMenuOpen = false);
                          Navigator.pushNamed(context, '/settings');
                        }),
                        const Divider(color: Colors.white24, height: 20),
                        _buildSubMenuButton('Quit to Main Menu',
                            () => _showQuitConfirmationDialog(context)),
                      ],
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white54, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          gameState.currentDate?.toString() ?? "Loading...",
                          style: GoogleFonts.cinzel(
                              color: Colors.amber[100],
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),


                      TutorialHighlighter(
                        highlightKey: 'open_horde_panel',
                        shape: BoxShape.circle,
                        child: _buildMenuButton(
                            icon: Icons.group,
                            tooltip: "Horde",
                            onPressed: () {
                              //  Advance tutorial if highlighted
                              context
                                  .read<TutorialService>()
                                  .advanceIfHighlighted(
                                      context, gameState, 'open_horde_panel');

                              context
                                  .read<TutorialService>()
                                  .resetTutorialNavigation();

                              gameNotifier.toggleHordePanel();
                            },
                            badgeCount: gameState.totalListenCount),
                      ),

                      _buildMenuButton(
                          icon: Icons.inventory_2_outlined,
                          tooltip: "Inventory",
                          onPressed: () =>
                              Navigator.pushNamed(context, '/inventory')),
                      TutorialHighlighter(
                        highlightKey: 'open_reports_tab',
                        shape: BoxShape.circle,
                        child: _buildMenuButton(
                            icon: Icons.assessment_outlined,
                            tooltip: "Reports",
                            badgeCount: gameState
                                .getReportsBadgeCount(),
                            onPressed: () {
                              context
                                  .read<TutorialService>()
                                  .advanceIfHighlighted(
                                      context, gameState, 'open_reports_tab');
                              Navigator.pushNamed(context, '/reports');
                            }),
                      ),
                      // Advisor button placeholder if needed
                      // _buildMenuButton(icon: Icons.people_outline, tooltip: "Advisors", onPressed: () => Navigator.pushNamed(context, '/advisors')),


                      _buildMenuButton(
                          icon: Icons.flag_outlined,
                          tooltip: "Camp",
                          enabled: canNavigateToCamp,
                          badgeCount:
                              gameState.getCampBadgeCount(),
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/camp')),
                      _buildMenuButton(
                          icon: Icons.map_outlined,
                          tooltip: "Area Map",
                          enabled: canNavigateToArea,
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/area')),
                      _buildMenuButton(
                          icon: Icons.travel_explore,
                          tooltip: "Region Map",
                          enabled: canNavigateToRegion,
                          onPressed: () => Navigator.pushReplacementNamed(
                              context, '/region')),
                      _buildMenuButton(
                          icon: Icons.public,
                          tooltip: "World Map",
                          enabled: canNavigateToWorldMap,
                          onPressed: () => Navigator.pushReplacementNamed(
                              context, '/world')),

                      if (gameState.isOmniscienceAllowed)
                        _buildMenuButton(
                            icon: Icons.auto_stories,
                            tooltip: gameState.isOmniscientMode
                                ? "Omniscience ON"
                                : "Omniscience OFF",
                            onPressed: gameNotifier.toggleOmniscientMode),

                      _buildMenuButton(
                          icon: _isMenuOpen ? Icons.close : Icons.menu,
                          tooltip: _isMenuOpen ? "Close Menu" : "Menu",
                          onPressed: () {
                            setState(() {
                              _isMenuOpen = !_isMenuOpen;
                            });
                          }),
                      if (gameState.isLoading)
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Tooltip(
                            message: "Processing turn...",
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white24, width: 1),
                              ),
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white54),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        TutorialHighlighter(
                          highlightKey: 'next_turn_button',
                          shape: BoxShape.circle,
                          child: _buildMenuButton(
                              icon: Icons.play_arrow,
                              tooltip: "Next Turn",
                              onPressed: () {
                                context
                                    .read<TutorialService>()
                                    .advanceIfHighlighted(
                                        context, gameState, 'next_turn_button');
                                gameNotifier.advanceToNextTurn();
                              }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
