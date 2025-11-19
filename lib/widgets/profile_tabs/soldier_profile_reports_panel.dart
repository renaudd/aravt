// widgets/profile_tabs/soldier_profile_reports_panel.dart


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/soldier_data.dart';
// [GEMINI-FIX] Import the new dedicated widgets file, NOT the screen file
import 'package:aravt/widgets/report_tabs.dart';


class SoldierProfileReportsPanel extends StatelessWidget {
 final Soldier soldier;
 const SoldierProfileReportsPanel({super.key, required this.soldier});


 final int _tabCount = 9;


 @override
 Widget build(BuildContext context) {
   final gameState = context.watch<GameState>();


   return DefaultTabController(
     length: _tabCount,
     child: Column(
       children: [
         // This is the nested TabBar
         TabBar(
           isScrollable: true,
           indicatorColor: Colors.amber,
           labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
           unselectedLabelStyle: GoogleFonts.cinzel(),
           tabs: const [
             Tab(icon: Icon(Icons.book), text: "Event Log"),
             Tab(icon: Icon(Icons.sports_kabaddi), text: "Combat"),
             Tab(icon: Icon(Icons.local_hospital_outlined), text: "Health"),
             Tab(icon: Icon(Icons.money), text: "Finance"),
             Tab(icon: Icon(Icons.cruelty_free_outlined), text: "Horses"),
             Tab(icon: Icon(Icons.savings), text: "Herds"),
             Tab(icon: Icon(Icons.local_dining_outlined), text: "Food"),
             Tab(icon: Icon(Icons.explore_outlined), text: "Hunting"),
             Tab(icon: Icon(Icons.emoji_events_outlined), text: "Games"),
           ],
         ),
         // This is the nested TabBarView
         Expanded(
           child: TabBarView(
             children: [
               // --- Pass the soldier.id to each tab so it filters correctly ---
               EventLogTab(
                   isOmniscient: gameState.isOmniscientMode,
                   soldierId: soldier.id),
               CombatReportTab(soldierId: soldier.id),
               HealthReportTab(soldierId: soldier.id),
               CommerceReportTab(
                   isOmniscient: gameState.isOmniscientMode,
                   soldierId: soldier.id),
               HerdsReportTab(soldierId: soldier.id),
               FoodReportTab(soldierId: soldier.id),
               HuntingReportTab(soldierId: soldier.id),
               GamesReportTab(soldierId: soldier.id),
             ],
           ),
         ),
       ],
     ),
   );
 }
}

