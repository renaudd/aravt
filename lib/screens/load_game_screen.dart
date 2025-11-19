// screens/load_game_screen.dart
import 'package:aravt/models/save_file_info.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class LoadGameScreen extends StatefulWidget {
  const LoadGameScreen({super.key});

  @override
  State<LoadGameScreen> createState() => _LoadGameScreenState();
}

class _LoadGameScreenState extends State<LoadGameScreen> {
  late Future<List<SaveFileInfo>> _saveFilesFuture;

  @override
  void initState() {
    super.initState();
    // Fetch the save files immediately when the screen loads
    _fetchSaveFiles();
  }

  void _fetchSaveFiles() {
    // We use context.read inside initState (or a function called by it)
    _saveFilesFuture = context.read<GameState>().getSaveFiles();
  }

  Future<void> _onLoadGamePressed(SaveFileInfo save) async {
    // Show a confirmation dialog
    final bool? shouldLoad = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Load Game?',
            style: GoogleFonts.cinzel(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to load this game?\n"${save.displayName}"\n\nYour current unsaved progress will be lost.',
            style: GoogleFonts.cinzel(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: GoogleFonts.cinzel(color: Colors.white70)),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // Do not load
              },
            ),
            TextButton(
              child: Text('Load', style: GoogleFonts.cinzel(color: Colors.amber)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Yes, load
              },
            ),
          ],
        );
      },
    );

    // If the user confirmed
    if (shouldLoad == true) {
      // Use 'mounted' check for async operations in stateful widgets
      if (!mounted) return;
      
      final gameState = context.read<GameState>();
      final bool loadSuccess = await gameState.loadGame(save.fullFileName);

      if (!mounted) return;

      if (loadSuccess) {
        // Navigate to the main game screen and remove all other routes
        Navigator.pushNamedAndRemoveUntil(context, '/camp', (route) => false);
      } else {
        // Show an error if loading failed (e.g., file corrupt)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to load save file. It may be corrupt.",
              style: GoogleFonts.cinzel(color: Colors.white),
            ),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Load Game', style: GoogleFonts.cinzel()),
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
        child: FutureBuilder<List<SaveFileInfo>>(
          future: _saveFilesFuture,
          builder: (context, snapshot) {
            // Case 1: Still loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Case 2: Error
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading save files:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(color: Colors.red[300], fontSize: 16),
                ),
              );
            }

            // Case 3: No data or empty list
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  'No save files found.',
                  style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18),
                ),
              );
            }

            // Case 4: Success, show the list
            final saveFiles = snapshot.data!;
            return ListView.builder(
              itemCount: saveFiles.length,
              itemBuilder: (context, index) {
                final save = saveFiles[index];
                return Card(
                  color: Colors.black.withOpacity(0.6),
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ListTile(
                    leading: const Icon(Icons.save, color: Colors.white70),
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
                    onTap: () => _onLoadGamePressed(save),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

