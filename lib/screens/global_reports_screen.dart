import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/widgets/persistent_menu_widget.dart';
import 'package:aravt/widgets/report_tabs.dart';
import 'package:aravt/widgets/notification_badge.dart';

class GlobalReportsScreen extends StatefulWidget {
  const GlobalReportsScreen({super.key});

  @override
  State<GlobalReportsScreen> createState() => _GlobalReportsScreenState();
}

class _GlobalReportsScreenState extends State<GlobalReportsScreen>
    with SingleTickerProviderStateMixin {
  final int _tabCount = 9;
  late TabController _tabController;

  // [GEMINI-NEW] Tab names matching the helper method in GameState
  final List<String> _tabNames = [
    'Event Log',
    'Combat',
    'Health',
    'Commerce',
    'Herds',
    'Food',
    'Fishing',
    'Hunting',
    'Games',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);

    // [GEMINI-NEW] Listen for tab changes and mark as viewed
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final gameState = context.read<GameState>();
        final tabName = _tabNames[_tabController.index];
        gameState.markReportTabViewed(tabName);
      }
    });

    // [GEMINI-NEW] Mark initial tab as viewed
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
          controller: _tabController, // [GEMINI-NEW] Use our controller
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
            _buildTab("Fishing", Icons.tsunami,
                gameState.getBadgeCountForTab("Fishing")),
            _buildTab("Hunting", Icons.explore_outlined,
                gameState.getBadgeCountForTab("Hunting")),
            _buildTab("Games", Icons.emoji_events_outlined,
                gameState.getBadgeCountForTab("Games")),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController, // [GEMINI-NEW] Use our controller
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
          const PersistentMenuWidget(),
        ],
      ),
      // bottomNavigationBar removed as PersistentMenuWidget is now in Stack
    );
  }
}
