import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/combat_models.dart';


class GameOverScreen extends StatelessWidget {
 const GameOverScreen({super.key});


 @override
 Widget build(BuildContext context) {
   // Read state once on entry to capture final stats before any reset happens
   final gameState = context.read<GameState>();


   final reason = gameState.gameOverReason ?? "Your journey has ended.";
   final daysSurvived = gameState.turn.turnNumber;


   // Calculate total kills from all combat reports
   final int totalKills = gameState.combatReports.fold(0, (sum, report) {
     // Count how many enemies did NOT survive (killed or fled, we'll count both as 'defeats' for scoring for now, or strictly killed)
     final enemyLosses = report.enemySoldiers
         .where((s) => s.finalStatus == SoldierStatus.killed)
         .length;
     return sum + enemyLosses;
   });


   final double finalWealth = gameState.player?.treasureWealth ?? 0;


   // Simple composite score formula
   final int score =
       (daysSurvived * 100) + (totalKills * 50) + finalWealth.toInt();


   return Scaffold(
     body: Container(
       decoration: const BoxDecoration(
         image: DecorationImage(
           // Use a grim background if you have one, or reuse the main one with heavy filtering
           image: AssetImage('assets/images/background.png'),
           fit: BoxFit.cover,
           colorFilter: ColorFilter.mode(Colors.black87, BlendMode.darken),
         ),
       ),
       child: Center(
         child: SingleChildScrollView(
           child: Container(
             constraints: const BoxConstraints(maxWidth: 600),
             padding: const EdgeInsets.all(32),
             decoration: BoxDecoration(
               color: Colors.black.withOpacity(0.8),
               border: Border.all(color: Colors.red.shade900, width: 2),
               boxShadow: [
                 BoxShadow(
                     color: Colors.red.shade900.withOpacity(0.3),
                     blurRadius: 30,
                     spreadRadius: 5)
               ],
             ),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text("GAME OVER",
                     style: GoogleFonts.cinzel(
                         fontSize: 48,
                         color: Colors.red.shade700,
                         fontWeight: FontWeight.bold,
                         shadows: [
                           const Shadow(blurRadius: 10, color: Colors.black)
                         ])),
                 const SizedBox(height: 24),
                 Text(
                   reason,
                   textAlign: TextAlign.center,
                   style: GoogleFonts.cinzel(
                       fontSize: 20,
                       color: Colors.white.withOpacity(0.9),
                       height: 1.4),
                 ),
                 const Divider(color: Colors.red, height: 60, thickness: 1),
                 _buildStatRow("Days Survived", daysSurvived.toString()),
                 _buildStatRow("Enemies Slain", totalKills.toString()),
                 _buildStatRow(
                     "Final Wealth", "${finalWealth.toStringAsFixed(0)} silver"),
                 const SizedBox(height: 30),
                 Container(
                   padding: const EdgeInsets.symmetric(
                       vertical: 12, horizontal: 30),
                   decoration: BoxDecoration(
                       color: Colors.red.shade900.withOpacity(0.3),
                       border:
                           Border.all(color: Colors.red.shade700, width: 2)),
                   child: Column(
                     children: [
                       Text("FINAL SCORE",
                           style: GoogleFonts.cinzel(
                               color: Colors.red.shade200, fontSize: 16)),
                       Text(score.toString(),
                           style: GoogleFonts.cinzel(
                               color: Colors.amber,
                               fontSize: 40,
                               fontWeight: FontWeight.bold)),
                     ],
                   ),
                 ),
                 const SizedBox(height: 60),
                 SizedBox(
                   width: double.infinity,
                   height: 60,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.grey[900],
                       side: const BorderSide(color: Colors.white24),
                     ),
                     onPressed: () {
                       // Pop everything until we are back at the Main Menu
                       Navigator.of(context)
                           .popUntil(ModalRoute.withName('/mainMenu'));
                     },
                     child: Text("RETURN TO MAIN MENU",
                         style: GoogleFonts.cinzel(
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                             color: Colors.white70)),
                   ),
                 ),
               ],
             ),
           ),
         ),
       ),
     ),
   );
 }


 Widget _buildStatRow(String label, String value) {
   return Padding(
     padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
     child: Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Text(label,
             style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18)),
         Text(value,
             style: GoogleFonts.cinzel(
                 color: Colors.white,
                 fontSize: 20,
                 fontWeight: FontWeight.bold)),
       ],
     ),
   );
 }
}

