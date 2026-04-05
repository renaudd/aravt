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
import 'package:aravt/screens/timelines_screen.dart';
import 'package:aravt/screens/global_inventory_screen.dart';

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
    'Logistics',
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
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 16),
              NotificationBadge(count: badgeCount),
            ],
          ),
          const SizedBox(width: 5),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return Scaffold(
      // No AppBar — we build our own compact header row inside the body
      body: Column(
        children: [
          // ── Compact header: [←] [Tab] [Tab] [Tab] [Tab] [Tab] ──
          Container(
            color: Colors.black.withOpacity(0.85),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 2,
              left: 0,
              right: 0,
              bottom: 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back arrow — same visual weight as a tab
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Tab bar fills the rest of the row
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Colors.amber,
                    indicatorWeight: 2,
                    labelStyle: GoogleFonts.cinzel(
                        fontSize: 11, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.cinzel(fontSize: 11),
                    labelColor: Colors.amber,
                    unselectedLabelColor: Colors.white70,
                    dividerColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    tabs: [
                      _buildTab("Chronicle", Icons.book,
                          gameState.getBadgeCountForTab("Chronicle")),
                      _buildTab("Logistics", Icons.warehouse,
                          gameState.getBadgeCountForTab("Logistics")),
                      _buildTab("Provisions", Icons.savings,
                          gameState.getBadgeCountForTab("Provisions")),
                      _buildTab("Military", Icons.military_tech,
                          gameState.getBadgeCountForTab("Military")),
                      _buildTab("World", Icons.public,
                          gameState.getBadgeCountForTab("World")),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Tab content fills the rest of the screen ──
          Expanded(
            child: Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. Chronicle: Event Log, Combat, Timelines
                    NestedReportCategory(
                      categoryName: 'Chronicle',
                      tabNames: const ["Event Log", "Combat", "Timeline"],
                      icons: const [
                        Icons.list_alt,
                        Icons.sports_kabaddi,
                        Icons.timeline
                      ],
                      children: [
                        EventLogTab(
                            isOmniscient: gameState.isOmniscientMode,
                            soldierId: null),
                        const CombatReportTab(soldierId: null),
                        const TimelinesView(),
                      ],
                    ),
                    // 2. Logistics: Finance, Industry, Khan, Horde, Global
                    NestedReportCategory(
                      categoryName: 'Logistics',
                      tabNames: const [
                        "Finance",
                        "Industry",
                        "Khan",
                        "Communal",
                        "Global"
                      ],
                      icons: const [
                        Icons.account_balance_wallet,
                        Icons.build,
                        Icons.person_outline,
                        Icons.groups_outlined,
                        Icons.public_outlined
                      ],
                      children: [
                        const FinanceReportTab(),
                        const IndustryReportTab(),
                        const PersonalInventoryTab(),
                        const CommunalInventoryTab(),
                        GlobalInventoryTab(
                            isOmniscient: gameState.isOmniscientMode),
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
          ),
        ],
      ),
    );
  }
}
