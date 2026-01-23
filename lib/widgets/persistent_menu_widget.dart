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
import 'package:aravt/widgets/paper_panel.dart';
// Removed unused screen imports

class PersistentMenuWidget extends StatefulWidget {
  const PersistentMenuWidget({super.key});

  @override
  State<PersistentMenuWidget> createState() => _PersistentMenuWidgetState();
}

class _PersistentMenuWidgetState extends State<PersistentMenuWidget> {
  bool _isMenuOpen = false;
  bool _isNavHidden = false;
  // _isHordePanelOpen is now in GameState

  Widget _buildMenuButton(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      bool enabled = true,
      bool isActive = false,
      int badgeCount = 0}) {
    //  Added badge count parameter
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Tooltip(
        message: enabled ? tooltip : "$tooltip (Current Screen)",
        child: Stack(
          //  Wrap in Stack for badge
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(20),
              child: PaperPanel(
                padding: const EdgeInsets.all(6),
                irregularity: 1.2,
                segmentsPerSide: 8,
                seed: icon.hashCode + tooltip.hashCode,
                backgroundColor: isActive
                    ? Colors.amber.withValues(alpha: 0.9)
                    : (enabled
                        ? const Color(0xFFEADBBE).withValues(alpha: 0.9)
                        : const Color(0xFFD4C5A8).withValues(alpha: 0.5)),
                borderColor: isActive
                    ? Colors.amber.shade800
                    : (enabled
                        ? const Color(0xFFA68B5B)
                        : const Color(0xFF8C734B)),
                borderWidth: 1.5,
                elevation: enabled ? 2.0 : 0.0,
                child: Icon(icon,
                    color: isActive
                        ? Colors.black
                        : (enabled
                            ? const Color(0xFF4A3F35)
                            : const Color(0xFF7D6E5D)),
                    size: 22),
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
          backgroundColor: const Color(0xFFEADBBE),
          foregroundColor: const Color(0xFF4A3F35),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
            side: const BorderSide(color: Color(0xFFA68B5B), width: 1.5),
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
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallHeight = screenSize.height < 500;

    // Apply scale factor for small heights (landscape mobile)
    final double scaleFactor = isSmallHeight ? 0.85 : 1.0;

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
                            color: Colors.black.withValues(alpha: 0.5),
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
            bottom: isSmallHeight ? 5 : 15,
            right: isSmallHeight ? 5 : 15,
            child: Transform.scale(
              scale: scaleFactor,
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_isMenuOpen)
                    PaperPanel(
                      width: 250,
                      padding: const EdgeInsets.all(12),
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
                          _buildSubMenuButton('Combat Simulator', () {
                            setState(() => _isMenuOpen = false);
                            Navigator.pushNamed(context, '/combat_simulator');
                          }),
                          const Divider(color: Colors.brown, height: 20),
                          _buildSubMenuButton('Quit to Main Menu',
                              () => _showQuitConfirmationDialog(context)),
                        ],
                      ),
                    ),
                  PaperPanel(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    elevation: 4,
                    irregularity: 2.0,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isNavHidden) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                gameState.currentDate?.toString() ??
                                    "Loading...",
                                style: GoogleFonts.cinzel(
                                    color: const Color(0xFFEADBBE),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 4),
                            TutorialHighlighter(
                              highlightKey: 'open_horde_panel',
                              shape: BoxShape.circle,
                              child: _buildMenuButton(
                                  icon: Icons.group,
                                  tooltip: "Horde",
                                  isActive: gameState.isHordePanelOpen,
                                  onPressed: () {
                                    //  Advance tutorial if highlighted
                                    context
                                        .read<TutorialService>()
                                        .advanceIfHighlighted(context,
                                            gameState, 'open_horde_panel');

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
                                  badgeCount: gameState.getReportsBadgeCount(),
                                  onPressed: () {
                                    context
                                        .read<TutorialService>()
                                        .advanceIfHighlighted(context,
                                            gameState, 'open_reports_tab');
                                    Navigator.pushNamed(context, '/reports');
                                  }),
                            ),
                            _buildMenuButton(
                                icon: Icons.flag_outlined,
                                tooltip: "Camp",
                                enabled: canNavigateToCamp,
                                badgeCount: gameState.getCampBadgeCount(),
                                onPressed: () => Navigator.pushReplacementNamed(
                                    context, '/camp')),
                            _buildMenuButton(
                                icon: Icons.ssid_chart, // Graph icon
                                tooltip: "Timelines",
                                enabled: true,
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/timelines')),
                            _buildMenuButton(
                                icon: Icons.map_outlined,
                                tooltip: "Area Map",
                                enabled: canNavigateToArea,
                                onPressed: () => Navigator.pushReplacementNamed(
                                    context, '/area')),
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
                          ],
                          _buildMenuButton(
                              icon: _isMenuOpen ? Icons.close : Icons.menu,
                              tooltip: _isMenuOpen ? "Close Menu" : "Menu",
                              onPressed: () {
                                setState(() {
                                  _isMenuOpen = !_isMenuOpen;
                                });
                              }),
                          if (!_isNavHidden) ...[
                            if (gameState.isLoading)
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Tooltip(
                                  message: "Processing turn...",
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white24, width: 1),
                                    ),
                                    child: const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                                          .advanceIfHighlighted(context,
                                              gameState, 'next_turn_button');
                                      gameNotifier.advanceToNextTurn();
                                    }),
                              ),
                          ],
                          // Nav concealment toggle
                          _buildMenuButton(
                            icon: _isNavHidden
                                ? Icons.chevron_left
                                : Icons.chevron_right,
                            tooltip: _isNavHidden
                                ? "Show Navigation"
                                : "Hide Navigation",
                            onPressed: () =>
                                setState(() => _isNavHidden = !_isNavHidden),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
