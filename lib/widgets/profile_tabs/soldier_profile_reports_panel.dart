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

// widgets/profile_tabs/soldier_profile_reports_panel.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/soldier_data.dart';

import 'package:aravt/widgets/report_tabs.dart';
import 'package:aravt/widgets/notification_badge.dart';

class SoldierProfileReportsPanel extends StatefulWidget {
  final Soldier soldier;
  const SoldierProfileReportsPanel({super.key, required this.soldier});

  @override
  State<SoldierProfileReportsPanel> createState() =>
      _SoldierProfileReportsPanelState();
}

class _SoldierProfileReportsPanelState extends State<SoldierProfileReportsPanel>
    with SingleTickerProviderStateMixin {
  final int _tabCount = 9;
  late TabController _tabController;

  // Tab names matching the helper method in GameState
  final List<String> _tabNames = [
    'Event Log',
    'Combat',
    'Health',
    'Commerce',
    'Herds',
    'Food',
    'Hunting',
    'Games',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);

    // Listen for tab changes and mark as viewed
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final gameState = context.read<GameState>();
        final tabName = _tabNames[_tabController.index];
        gameState.markReportTabViewedForSoldier(tabName, widget.soldier.id);
      }
    });

    // Mark initial tab as viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameState = context.read<GameState>();
      gameState.markReportTabViewedForSoldier(_tabNames[0], widget.soldier.id);
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

    return Column(
      children: [
        // This is the nested TabBar
        TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amber,
          labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cinzel(),
          tabs: [
            _buildTab(
                "Event Log",
                Icons.book,
                gameState.getBadgeCountForTabAndSoldier(
                    "Event Log", widget.soldier.id)),
            _buildTab(
                "Combat",
                Icons.sports_kabaddi,
                gameState.getBadgeCountForTabAndSoldier(
                    "Combat", widget.soldier.id)),
            _buildTab(
                "Health",
                Icons.local_hospital_outlined,
                gameState.getBadgeCountForTabAndSoldier(
                    "Health", widget.soldier.id)),
            _buildTab(
                "Finance",
                Icons.money,
                gameState.getBadgeCountForTabAndSoldier(
                    "Commerce", widget.soldier.id)),
            _buildTab(
                "Horses",
                Icons.cruelty_free_outlined,
                gameState.getBadgeCountForTabAndSoldier(
                    "Herds", widget.soldier.id)),
            _buildTab(
                "Herds",
                Icons.savings,
                gameState.getBadgeCountForTabAndSoldier(
                    "Herds", widget.soldier.id)),
            _buildTab(
                "Food",
                Icons.local_dining_outlined,
                gameState.getBadgeCountForTabAndSoldier(
                    "Food", widget.soldier.id)),
            _buildTab(
                "Hunting",
                Icons.explore_outlined,
                gameState.getBadgeCountForTabAndSoldier(
                    "Hunting", widget.soldier.id)),
            _buildTab(
                "Games",
                Icons.emoji_events_outlined,
                gameState.getBadgeCountForTabAndSoldier(
                    "Games", widget.soldier.id)),
          ],
        ),
        // This is the nested TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // --- Pass the soldier.id to each tab so it filters correctly ---
              EventLogTab(
                  isOmniscient: gameState.isOmniscientMode,
                  soldierId: widget.soldier.id),
              CombatReportTab(soldierId: widget.soldier.id),
              HealthReportTab(soldierId: widget.soldier.id),
              CommerceReportTab(
                  isOmniscient: gameState.isOmniscientMode,
                  soldierId: widget.soldier.id),
              HerdsReportTab(soldierId: widget.soldier.id),
              HerdsReportTab(
                  soldierId: widget.soldier.id), // Duplicate for Horses tab
              FoodReportTab(soldierId: widget.soldier.id),
              HuntingReportTab(soldierId: widget.soldier.id),
              GamesReportTab(soldierId: widget.soldier.id),
            ],
          ),
        ),
      ],
    );
  }
}
