import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/widgets/persistent_menu_widget.dart';
import 'package:aravt/widgets/report_tabs.dart'; // Import the split tabs

class GlobalReportsScreen extends StatelessWidget {
  const GlobalReportsScreen({super.key});

  final int _tabCount = 9;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return DefaultTabController(
      length: _tabCount,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Global Reports", style: GoogleFonts.cinzel()),
          backgroundColor: Colors.black.withOpacity(0.5),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.amber,
            labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.cinzel(),
            tabs: const [
              Tab(icon: Icon(Icons.book), text: "Event Log"),
              Tab(icon: Icon(Icons.sports_kabaddi), text: "Combat"),
              Tab(icon: Icon(Icons.local_hospital_outlined), text: "Health"),
              // [GEMINI-UPDATED] Renamed to Commerce, merged Finance & Industry
              Tab(icon: Icon(Icons.storefront), text: "Commerce"),
              // [GEMINI-UPDATED] Combined Horses into Herds
              Tab(icon: Icon(Icons.savings), text: "Herds"),
              Tab(icon: Icon(Icons.local_dining_outlined), text: "Food"),
              Tab(icon: Icon(Icons.tsunami), text: "Fishing"),
              Tab(icon: Icon(Icons.explore_outlined), text: "Hunting"),
              Tab(icon: Icon(Icons.emoji_events_outlined), text: "Games"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            EventLogTab(
                isOmniscient: gameState.isOmniscientMode, soldierId: null),
            const CombatReportTab(soldierId: null),
            const HealthReportTab(soldierId: null),
            // [GEMINI-UPDATED] New merged Commerce tab
            CommerceReportTab(
                isOmniscient: gameState.isOmniscientMode, soldierId: null),
            // [GEMINI-UPDATED] Combined Herds tab
            const HerdsReportTab(soldierId: null),
            const FoodReportTab(soldierId: null),
            const FishingReportTab(soldierId: null),
            const HuntingReportTab(soldierId: null),
            const GamesReportTab(soldierId: null),
          ],
        ),
        bottomNavigationBar: const PersistentMenuWidget(),
      ),
    );
  }
}

