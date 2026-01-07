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

// screens/in_game_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart'; // No longer needed here
import '../widgets/persistent_menu_widget.dart';
// import 'dart:io'; // No longer needed here
// import 'package:flutter/foundation.dart'; // No longer needed here

class InGameMenuScreen extends StatefulWidget {
  const InGameMenuScreen({super.key});

  @override
  State<InGameMenuScreen> createState() => _InGameMenuScreenState();
}

class _InGameMenuScreenState extends State<InGameMenuScreen> {
  // bool _dontAskAgain = false; // Removed as it wasn't fully implemented

  Future<void> _showQuitConfirmationDialog(BuildContext context) async {
    // final gameState = context.read<GameState>(); // Unused

    bool? shouldQuit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('Quit to Main Menu?',
                  style: GoogleFonts.cinzel(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Are you sure you want to quit?\nAny unsaved progress will be lost.',
                      style: GoogleFonts.cinzel(color: Colors.white70)),
                  // Removed "Don't ask again" checkbox
                ],
              ),
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
      },
    );

    if (shouldQuit == true) {

      // It *only* navigates to the main menu.
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/mainMenu', (route) => false); // Corrected route name
      }
    }
  }

  Widget _buildMenuButton(String label, VoidCallback onPressed) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.4),
      body: Stack(
        children: [
          const PersistentMenuWidget(),
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(), // Empty container to catch taps
            ),
          ),
          Positioned(
            bottom: 80, // Positioned just above the persistent menu
            right: 15, // Aligned to the right
            child: Container(
              width: 250, // Fixed width for the column
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white54, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMenuButton(
                    'Save Game',
                    () {
                      Navigator.of(context).pop(); // Close menu first
                      Navigator.pushNamed(context, '/save_game');
                    },
                  ),
                  _buildMenuButton(
                    'Load Game',
                    () {
                      Navigator.of(context).pop(); // Close menu first
                      Navigator.pushNamed(context, '/load_game');
                    },
                  ),
                  _buildMenuButton(
                    'Options',
                    () {
                      Navigator.of(context).pop(); // Close menu first
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  _buildMenuButton(
                    'Quit to Main Menu',
                    () => _showQuitConfirmationDialog(context),
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
