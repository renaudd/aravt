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
  final int _tabCount = 5;
  late TabController _tabController;

  // Tab names (Categories)
  final List<String> _tabNames = [
    'Chronicle',
    'Treasury',
    'Provisions',
    'Military',
    'World',
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
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amber,
          labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.cinzel(),
          tabs: [
            _buildTab("Chronicle", Icons.book,
                gameState.getBadgeCountForTab("Chronicle")),
            _buildTab("Treasury", Icons.monetization_on,
                gameState.getBadgeCountForTab("Treasury")),
            _buildTab("Provisions", Icons.savings,
                gameState.getBadgeCountForTab("Provisions")),
            _buildTab("Military", Icons.military_tech,
                gameState.getBadgeCountForTab("Military")),
            _buildTab(
                "World", Icons.public, gameState.getBadgeCountForTab("World")),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // 1. Chronicle: Event Log & Combat
              NestedReportCategory(
                categoryName: 'Chronicle',
                tabNames: const ["Event Log", "Combat"],
                icons: const [Icons.list_alt, Icons.sports_kabaddi],
                children: [
                  EventLogTab(
                      isOmniscient: gameState.isOmniscientMode,
                      soldierId: null),
                  const CombatReportTab(soldierId: null),
                ],
              ),
              // 2. Treasury: Finance & Industry
              const NestedReportCategory(
                categoryName: 'Treasury',
                tabNames: ["Finance", "Industry"],
                icons: [Icons.account_balance_wallet, Icons.build],
                children: [
                  FinanceReportTab(),
                  IndustryReportTab(),
                ],
              ),
              // 3. Provisions: Herds, Food, Hunting, Fishing
              const NestedReportCategory(
                categoryName: 'Provisions',
                tabNames: ["Herds", "Food", "Hunting", "Fishing"],
                icons: [
                  Icons.cruelty_free,
                  Icons.restaurant,
                  Icons.search,
                  Icons.water
                ],
                children: [
                  HerdsReportTab(soldierId: null),
                  FoodReportTab(soldierId: null),
                  HuntingReportTab(soldierId: null),
                  FishingReportTab(soldierId: null),
                ],
              ),
              // 4. Military: Health, Training, Games
              const NestedReportCategory(
                categoryName: 'Military',
                tabNames: ["Health", "Training", "Games"],
                icons: [
                  Icons.local_hospital,
                  Icons.fitness_center,
                  Icons.emoji_events
                ],
                children: [
                  HealthReportTab(soldierId: null),
                  TrainingReportTab(soldierId: null),
                  GamesReportTab(soldierId: null),
                ],
              ),
              // 5. The World: Diplomacy
              const DiplomacyReportTab(soldierId: null),
            ],
          ),
          const PersistentMenuWidget(),
        ],
      ),
    );
  }
}
