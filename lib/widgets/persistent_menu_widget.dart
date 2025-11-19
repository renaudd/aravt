// lib/widgets/persistent_menu_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import 'horde_panel.dart'; // [GEMINI-FIX] Import the new panel
// Removed unused screen imports

class PersistentMenuWidget extends StatefulWidget {
  const PersistentMenuWidget({super.key});

  @override
  State<PersistentMenuWidget> createState() => _PersistentMenuWidgetState();
}

class _PersistentMenuWidgetState extends State<PersistentMenuWidget> {
  bool _isMenuOpen = false;

  Widget _buildMenuButton(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Tooltip(
        message: enabled ? tooltip : "$tooltip (Current Screen)",
        child: InkWell(
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
                  color: enabled ? Colors.white54 : Colors.white24, width: 1),
            ),
            child: Icon(icon,
                color: enabled ? Colors.white : Colors.white54, size: 24),
          ),
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
      // [GEMINI-FIX] Clean stack reset
      Navigator.pushNamedAndRemoveUntil(context, '/mainMenu', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final gameNotifier = context.read<GameState>();

    final currentRouteName = ModalRoute.of(context)?.settings.name;
    final bool canNavigateToCamp = currentRouteName != '/camp';
    final bool canNavigateToArea = currentRouteName != '/area';
    final bool canNavigateToRegion = currentRouteName != '/region';
    final bool canNavigateToWorldMap = currentRouteName != '/world';

    return Positioned(
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white54, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                
// [GEMINI-FIX] Horde Button -> Bottom Sheet with Padding
                _buildMenuButton(
                    icon: Icons.group,
                    tooltip: "Horde",
                    onPressed: () {
                        showModalBottomSheet(
                           context: context,
                           backgroundColor: Colors.transparent,
                           isScrollControlled: true,
                           builder: (context) => Padding(
                               // Add 80px padding to the bottom so it sits above the menu
                               padding: const EdgeInsets.only(bottom: 80.0),
                               child: const HordePanel(),
                           ),
                       );
                    }),


                _buildMenuButton(
                    icon: Icons.inventory_2_outlined,
                    tooltip: "Inventory",
                    onPressed: () => Navigator.pushNamed(context, '/inventory')),
                _buildMenuButton(
                    icon: Icons.assessment_outlined,
                    tooltip: "Reports",
                    onPressed: () => Navigator.pushNamed(context, '/reports')),
                // Advisor button placeholder if needed
                // _buildMenuButton(icon: Icons.people_outline, tooltip: "Advisors", onPressed: () => Navigator.pushNamed(context, '/advisors')),
                
                // [GEMINI-FIX] Use pushReplacement for main tabs to keep stack clean
                _buildMenuButton(
                    icon: Icons.flag_outlined,
                    tooltip: "Camp",
                    enabled: canNavigateToCamp,
                    onPressed: () => Navigator.pushReplacementNamed(context, '/camp')),
                _buildMenuButton(
                    icon: Icons.map_outlined,
                    tooltip: "Area Map",
                    enabled: canNavigateToArea,
                    onPressed: () => Navigator.pushReplacementNamed(context, '/area')),
                _buildMenuButton(
                    icon: Icons.travel_explore,
                    tooltip: "Region Map",
                    enabled: canNavigateToRegion,
                    onPressed: () => Navigator.pushReplacementNamed(context, '/region')),
                _buildMenuButton(
                    icon: Icons.public,
                    tooltip: "World Map",
                    enabled: canNavigateToWorldMap,
                    onPressed: () => Navigator.pushReplacementNamed(context, '/world')),

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
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white54),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  _buildMenuButton(
                      icon: Icons.play_arrow,
                      tooltip: "Next Turn",
                      onPressed: gameNotifier.advanceToNextTurn),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

