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
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/widgets/persistent_menu_widget.dart';
import 'package:aravt/widgets/report_tabs.dart';
import 'package:aravt/widgets/training_report_tab.dart';
import 'package:aravt/widgets/notification_badge.dart';
import 'package:aravt/widgets/diplomacy_report_tab.dart';

class GlobalReportsScreen extends StatefulWidget {
  const GlobalReportsScreen({super.key});

  @override
  State<GlobalReportsScreen> createState() => _GlobalReportsScreenState();
}

class _GlobalReportsScreenState extends State<GlobalReportsScreen>
    with SingleTickerProviderStateMixin {
  final int _tabCount = 9;
  late TabController _tabController;

  // Tab names
  final List<String> _tabNames = [
    'Event Log',
    'Combat',
    'Health',
    'Commerce',
    'Herds',
    'Food',
    'Games',
    'Training',
    'Diplomacy',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);

    //  Listen for tab changes and mark as viewed
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final gameState = context.read<GameState>();
        final tabName = _tabNames[_tabController.index];
        gameState.markReportTabViewed(tabName);
      }
    });

    //  Mark initial tab as viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameState = context.read<GameState>();
      gameState.markReportTabViewed(_tabNames[0]);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTab(String text, IconData icon, int badgeCount) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon),
              NotificationBadge(count: badgeCount),
            ],
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(
        title: Text("Global Reports", style: GoogleFonts.cinzel()),
        backgroundColor: Colors.black.withOpacity(0.5),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController, //  Use our controller
          isScrollable: true,
          indicatorColor: Colors.amber,
          labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cinzel(),
          tabs: [
            _buildTab("Event Log", Icons.book,
                gameState.getBadgeCountForTab("Event Log")),
            _buildTab("Combat", Icons.sports_kabaddi,
                gameState.getBadgeCountForTab("Combat")),
            _buildTab("Health", Icons.local_hospital_outlined,
                gameState.getBadgeCountForTab("Health")),
            _buildTab("Commerce", Icons.storefront,
                gameState.getBadgeCountForTab("Commerce")),
            _buildTab(
                "Herds", Icons.savings, gameState.getBadgeCountForTab("Herds")),
            _buildTab("Food", Icons.local_dining_outlined,
                gameState.getBadgeCountForTab("Food")),
            _buildTab("Games", Icons.emoji_events_outlined,
                gameState.getBadgeCountForTab("Games")),
            _buildTab("Training", Icons.fitness_center,
                gameState.getBadgeCountForTab("Training")),
            _buildTab("Diplomacy", Icons.handshake,
                gameState.getBadgeCountForTab("Diplomacy")),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController, //  Use our controller
            children: [
              EventLogTab(
                  isOmniscient: gameState.isOmniscientMode, soldierId: null),
              const CombatReportTab(soldierId: null),
              const HealthReportTab(soldierId: null),
              CommerceReportTab(
                  isOmniscient: gameState.isOmniscientMode, soldierId: null),
              const HerdsReportTab(soldierId: null),
              const FoodReportTab(soldierId: null),
              const GamesReportTab(soldierId: null),
              const TrainingReportTab(soldierId: null),
              const DiplomacyReportTab(soldierId: null),
            ],
          ),
          const PersistentMenuWidget(),
        ],
      ),
      // bottomNavigationBar removed as PersistentMenuWidget is now in Stack
    );
  }
}
