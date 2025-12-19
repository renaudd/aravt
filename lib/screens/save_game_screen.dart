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

// lib/screens/save_game_screen.dart
import 'package:aravt/models/save_file_info.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SaveGameScreen extends StatefulWidget {
  const SaveGameScreen({super.key});

  @override
  State<SaveGameScreen> createState() => _SaveGameScreenState();
}

class _SaveGameScreenState extends State<SaveGameScreen> {
  late Future<List<SaveFileInfo>> _saveFilesFuture;

  @override
  void initState() {
    super.initState();
    _refreshSaveList();
  }

  /// Refreshes the list of save files
  void _refreshSaveList() {
    _saveFilesFuture = context.read<GameState>().getSaveFiles();
    if (mounted) {
      setState(() {});
    }
  }

  /// Handles the save game logic
  Future<void> _onSavePressed() async {
    final gameState = context.read<GameState>();
    if (gameState.isLoading) return;

    await gameState.saveGame();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Game Saved!', style: GoogleFonts.cinzel()),
          backgroundColor: Colors.green[800],
        ),
      );
    }
    // Refresh the list to show the new save
    _refreshSaveList();
  }

  // (We can add an "Overwrite" confirmation here later if needed)

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final headerStyle = GoogleFonts.cinzel(
        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold);
    final buttonStyle = GoogleFonts.cinzel(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        title: Text('Save Game', style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black.withOpacity(0.5),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/steppe_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: Center(
          child: Container(
            width: 600,
            constraints: const BoxConstraints(minHeight: 500, maxHeight: 700),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("SAVE GAME", style: headerStyle),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    onPressed: gameState.isLoading ? null : _onSavePressed,
                    child: Text(
                      gameState.isLoading ? 'Processing...' : 'Create New Save',
                      style: buttonStyle,
                    ),
                  ),
                ),
                const Divider(height: 40, color: Colors.white54),
                Text("EXISTING SAVES", style: headerStyle),
                const SizedBox(height: 20),
                Expanded(
                  child: FutureBuilder<List<SaveFileInfo>>(
                    future: _saveFilesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading save files:\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cinzel(
                                color: Colors.red[300], fontSize: 16),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Text(
                            'No save files found.',
                            style: GoogleFonts.cinzel(
                                color: Colors.white70, fontSize: 18),
                          ),
                        );
                      }
                      final saveFiles = snapshot.data!;
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: saveFiles.length,
                        itemBuilder: (context, index) {
                          final save = saveFiles[index];
                          return Card(
                            color: Colors.black.withOpacity(0.6),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: ListTile(
                              leading:
                                  const Icon(Icons.save, color: Colors.white70),
                              title: Text(
                                save.displayName,
                                style: GoogleFonts.cinzel(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Text(
                                "Saved: ${save.saveDate.toString()}\nReal Time: ${save.fileTimestamp.toLocal().toString().substring(0, 16)}",
                                style: const TextStyle(color: Colors.white60),
                              ),
                              isThreeLine: true,
                              onTap: null, // Tapping does nothing (for now)
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
