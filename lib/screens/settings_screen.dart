import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';


class SettingsScreen extends StatelessWidget {
 const SettingsScreen({super.key});


 @override
 Widget build(BuildContext context) {
   return Scaffold(
     extendBodyBehindAppBar: true,
     appBar: AppBar(
       title: Text("Settings",
           style: GoogleFonts.cinzel(
               color: Colors.white, fontWeight: FontWeight.bold)),
       backgroundColor: Colors.black.withOpacity(0.5),
       elevation: 0,
       leading: IconButton(
         icon: const Icon(Icons.arrow_back, color: Colors.white),
         onPressed: () => Navigator.of(context).pop(),
       ),
     ),
     body: Container(
       decoration: const BoxDecoration(
         image: DecorationImage(
           image: AssetImage('assets/images/background.png'),
           fit: BoxFit.cover,
         ),
       ),
       child: Container(
         color: Colors.black.withOpacity(0.7), // Dark overlay for readability
         child: Consumer<GameState>(
           builder: (context, gameState, child) {
             return ListView(
               padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
               children: [
                 _buildSectionTitle("Audio"),
                 _buildToggle(
                   "Music",
                   "Enable background music",
                   gameState.musicEnabled,
                   (val) => gameState.setMusicEnabled(val),
                 ),
                 if (gameState.musicEnabled)
                   _buildVolumeSlider(
                     gameState.musicVolume,
                     (val) => gameState.setMusicVolume(val),
                   ),
                 const Divider(color: Colors.white24),
                 _buildToggle(
                   "Sound Effects",
                   "Enable combat and interaction sounds",
                   gameState.sfxEnabled,
                   (val) => gameState.setSfxEnabled(val),
                 ),
                 if (gameState.sfxEnabled)
                   _buildVolumeSlider(
                     gameState.sfxVolume,
                     (val) => gameState.setSfxVolume(val),
                   ),
                 _buildSectionTitle("Gameplay"),
                 _buildToggle(
                   "Auto-Save",
                   "Save game automatically at the end of every turn",
                   gameState.autoSaveEnabled,
                   (val) => gameState.setAutoSaveEnabled(val),
                 ),
                 // You could add difficulty display here (read-only mid-game)
                 ListTile(
                   title: Text("Difficulty",
                       style: GoogleFonts.cinzel(
                           color: Colors.white, fontSize: 18)),
                   subtitle: Text(
                       gameState.difficulty[0].toUpperCase() +
                           gameState.difficulty.substring(1),
                       style: const TextStyle(color: Colors.white70)),
                   trailing: const Icon(Icons.lock, color: Colors.white24),
                 ),
               ],
             );
           },
         ),
       ),
     ),
   );
 }


 Widget _buildSectionTitle(String title) {
   return Padding(
     padding: const EdgeInsets.symmetric(vertical: 20.0),
     child: Text(
       title,
       style: GoogleFonts.cinzel(
         color: Colors.amber,
         fontSize: 24,
         fontWeight: FontWeight.bold,
       ),
     ),
   );
 }


 Widget _buildToggle(
     String title, String subtitle, bool value, Function(bool) onChanged) {
   return SwitchListTile(
     activeColor: Colors.amber,
     inactiveTrackColor: Colors.grey[800],
     title: Text(title,
         style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
     subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
     value: value,
     onChanged: onChanged,
   );
 }


 Widget _buildVolumeSlider(double value, Function(double) onChanged) {
   return Padding(
     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
     child: Row(
       children: [
         const Icon(Icons.volume_mute, color: Colors.white54),
         Expanded(
           child: Slider(
             value: value,
             min: 0.0,
             max: 1.0,
             activeColor: Colors.amber,
             inactiveColor: Colors.grey[800],
             onChanged: onChanged,
           ),
         ),
         const Icon(Icons.volume_up, color: Colors.white),
       ],
     ),
   );
 }
}

