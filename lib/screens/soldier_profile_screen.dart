// screens/soldier_profile_screen.dart

import 'package:aravt/models/inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/widgets/soldier_portrait_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aravt/providers/game_state.dart';

import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/services/interaction_service.dart';
import 'package:aravt/widgets/persistent_menu_widget.dart';
import 'package:aravt/widgets/profile_tabs/soldier_profile_aravt_panel.dart';
import 'package:aravt/widgets/profile_tabs/soldier_profile_inventory_panel.dart';
import 'package:aravt/widgets/profile_tabs/soldier_profile_relationships_panel.dart';
import 'package:aravt/widgets/profile_tabs/soldier_profile_reports_panel.dart';
import 'package:aravt/widgets/profile_tabs/soldier_profile_yurt_panel.dart';
import 'package:aravt/widgets/gifting_dialog.dart';
import 'package:aravt/widgets/tutorial_highlighter.dart';

const Map<EquipmentSlot, IconData> _placeholderIconMap = {
  EquipmentSlot.helmet: Icons.headset,
  EquipmentSlot.armor: Icons.shield,
  EquipmentSlot.shield: Icons.shield,
  EquipmentSlot.gauntlets: Icons.pan_tool,
  EquipmentSlot.boots: Icons.ice_skating,
  EquipmentSlot.longBow: Icons.arrow_back_rounded,
  EquipmentSlot.shortBow: Icons.arrow_back_sharp,
  EquipmentSlot.spear: Icons.chevron_right,
  EquipmentSlot.melee: Icons.gavel,
  EquipmentSlot.mount: Icons.pets,
  EquipmentSlot.necklace: Icons.watch,
  EquipmentSlot.ring: Icons.circle,
  EquipmentSlot.undergarments: Icons.checkroom,
  EquipmentSlot.trophy: Icons.emoji_events,
};

class SoldierProfileScreen extends StatefulWidget {
  final int soldierId;

  const SoldierProfileScreen({
    super.key,
    required this.soldierId,
  });

  @override
  State<SoldierProfileScreen> createState() => _SoldierProfileScreenState();
}

class _SoldierProfileScreenState extends State<SoldierProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _logScrollController = ScrollController();

  final List<Widget> _tabs = [
    const Tab(text: 'Profile'),
    const TutorialHighlighter(
        highlightKey: 'open_aravt_tab', child: Tab(text: 'Aravt')),
    const Tab(text: 'Yurt'),
    const Tab(text: 'Inventory'),
    const Tab(text: 'Reports'),
    const Tab(text: 'Relationships'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  List<Soldier> _aravtMembers = [];
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAravtMembers();
  }

  void _loadAravtMembers() {
    final gameState = Provider.of<GameState>(context, listen: false);
    try {
      final soldier =
          gameState.horde.firstWhere((s) => s.id == widget.soldierId);
      // Check if soldier is in an aravt (not None)
      if (soldier.aravt != 'None') {
        _aravtMembers =
            gameState.horde.where((s) => s.aravt == soldier.aravt).toList();
        // Sort by role (Captain first) then name
        _aravtMembers.sort((a, b) {
          if (a.role == SoldierRole.aravtCaptain) return -1;
          if (b.role == SoldierRole.aravtCaptain) return 1;
          return a.name.compareTo(b.name);
        });
        _currentIndex = _aravtMembers.indexWhere((s) => s.id == soldier.id);
      } else {
        _aravtMembers = [];
      }
    } catch (e) {
      _aravtMembers = [];
    }
  }

  void _navigateToSoldier(int index) {
    if (_aravtMembers.isEmpty) return;

    // Handle wrapping
    int targetIndex = index;
    if (targetIndex < 0) targetIndex = _aravtMembers.length - 1;
    if (targetIndex >= _aravtMembers.length) targetIndex = 0;

    final targetSoldier = _aravtMembers[targetIndex];

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SoldierProfileScreen(soldierId: targetSoldier.id),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final Soldier soldier;
    try {
      soldier = gameState.horde.firstWhere((s) => s.id == widget.soldierId);
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Text("Error: Soldier with ID ${widget.soldierId} not found.",
              style: GoogleFonts.cinzel()),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/steppe_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Image.asset('assets/images/soldier_render.png'),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: 20,
            left: 60,
            right: 20,
            child: _buildTopTabBar(),
          ),
          Positioned(
            top: 70, // Slightly lower to avoid tab bar
            left: 0,
            right: 0,
            bottom: 60, // Make space for persistent menu
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                // 1. Profile Tab
                _buildProfileTabContent(context, soldier, gameState),
                // 2. Aravt Tab
                SoldierProfileAravtPanel(soldier: soldier),
                // 3. Yurt Tab
                SoldierProfileYurtPanel(soldier: soldier),
                // 4. Inventory Tab
                SoldierProfileInventoryPanel(soldier: soldier),
                // 5. Reports Tab
                SoldierProfileReportsPanel(soldier: soldier),
                // 6. Relationships Tab
                SoldierProfileRelationshipsPanel(soldier: soldier),
              ],
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: PersistentMenuWidget(),
          ),
          Positioned(
            bottom: 70, // Above persistent menu
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: _buildInteractionTokenDisplay(
                    gameState.interactionTokensRemaining),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: _tabs,
      isScrollable: true,
      labelStyle:
          GoogleFonts.cinzel(color: Colors.yellow, fontWeight: FontWeight.bold),
      unselectedLabelStyle: GoogleFonts.cinzel(color: Colors.white),
      indicatorColor: Colors.yellow,
      dividerColor: Colors.transparent,
    );
  }

  Widget _buildProfileTabContent(
      BuildContext context, Soldier soldier, GameState gameState) {
    final bool isOmniscient = gameState.isOmniscientMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Profile, Interaction, and Hidden Stats panels
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfilePanel(soldier),
                const SizedBox(height: 16),
                _buildInteractionPanel(context, soldier, gameState),
                if (isOmniscient) ...[
                  const SizedBox(height: 16),
                  _buildHiddenStatsPanel(soldier),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Right column: Gear and Actions panel
          Expanded(
            flex: 1,
            child: _buildGearAndActionsPanel(soldier, gameState),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePanel(Soldier soldier) {
    final textStyle = GoogleFonts.cinzel(color: Colors.white);

    return UiPanel(
      width: 335,
      height: 255,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(soldier),
          const SizedBox(height: 10),
          Row(
            children: [
              SoldierPortrait(
                index: soldier.portraitIndex,
                backgroundColor: soldier.backgroundColor,
                size: 80.0,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Age: ${soldier.age}', style: textStyle),
                  Text('Aravt: ${soldier.aravt}', style: textStyle),
                  Text('Years with horde: ${soldier.yearsWithHorde}',
                      style: textStyle),
                ],
              )
            ],
          ),
          const Divider(color: Colors.white54),
          _buildProfileRow('Ailments:', soldier.ailments ?? 'None'),
          _buildProfileRow('Injuries:', soldier.injuryDescription ?? 'None'),
          _buildProfileRow(
              'Height:', '${soldier.height.toStringAsFixed(0)} cm'),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Soldier soldier) {
    final headerStyle = GoogleFonts.cinzel(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold);

    if (_aravtMembers.isEmpty || _aravtMembers.length <= 1) {
      return Text('SOLDIER PROFILE', style: headerStyle);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => _navigateToSoldier(_currentIndex - 1),
          tooltip: 'Previous Member',
        ),
        Expanded(
          child: Center(
            child: DropdownButton<int>(
              value: _currentIndex,
              dropdownColor: Colors.grey[900],
              style: headerStyle,
              underline: Container(), // Remove underline
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              isExpanded: false, // Don't expand to full width to keep centered
              items: _aravtMembers.asMap().entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text(
                    entry.value.name,
                    style: headerStyle.copyWith(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (int? newIndex) {
                if (newIndex != null) {
                  _navigateToSoldier(newIndex);
                }
              },
            ),
          ),
        ),
        TutorialHighlighter(
          highlightKey: 'navigate_next_soldier',
          shape: BoxShape.circle,
          child: IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => _navigateToSoldier(_currentIndex + 1),
            tooltip: 'Next Member',
          ),
        ),
      ],
    );
  }

  Widget _buildProfileRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.cinzel(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(value, style: GoogleFonts.cinzel(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildGearAndActionsPanel(Soldier soldier, GameState gameState) {
    final headerStyle = GoogleFonts.cinzel(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold);

    final sortedEquippedItems = soldier.equippedItems.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    return UiPanel(
      width: 250,
      height: 620,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EQUIPPED GEAR', style: headerStyle),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sortedEquippedItems.length,
              itemBuilder: (context, index) {
                final entry = sortedEquippedItems[index];
                final slot = entry.key;
                final item = entry.value;

                return _buildInventoryRow(
                  _placeholderIconMap[slot] ?? Icons.inventory_2_outlined,
                  '${slot.name}: ${item.name}',
                );
              },
            ),
          ),
          const Divider(color: Colors.white54),
          Text('Supplies: ${soldier.suppliesWealth.toStringAsFixed(0)}',
              style: GoogleFonts.cinzel(color: Colors.white)),
          Text('Treasure: ${soldier.treasureWealth.toStringAsFixed(0)}',
              style: GoogleFonts.cinzel(color: Colors.white)),
          if (!soldier.isPlayer) ...[
            const Divider(color: Colors.white54),
            _buildManagementPanel(context, gameState, soldier),
          ]
        ],
      ),
    );
  }

  // [GEMINI-UPDATED] Management Panel with Role Checks
  Widget _buildManagementPanel(
      BuildContext context, GameState gameState, Soldier soldier) {
    final headerStyle = GoogleFonts.cinzel(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold);

    // Role Checks
    final bool isHordeLeader =
        gameState.player?.role == SoldierRole.hordeLeader;
    final bool isInPlayerAravt = soldier.aravt == gameState.player?.aravt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACTIONS', style: headerStyle),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0, // Horizontal gap
          runSpacing: 8.0, // Vertical gap
          children: [
            // --- Interaction Buttons (Always available) ---
            _buildManagementButton(
              text: 'Gift',
              color: Colors.brown[800]!,
              onPressed: () => _showGiftDialog(context, gameState, soldier),
            ),
            _buildManagementButton(
              text: 'Trade',
              color: Colors.brown[800]!,
              onPressed: () => _showTradeDialog(context, gameState, soldier),
            ),

            // --- Management Buttons (Restricted by Role) ---

            // REASSIGN: Only Horde Leader
            if (isHordeLeader)
              _buildManagementButton(
                text: 'Reassign',
                color: Colors.blue[800]!,
                onPressed: () =>
                    _showReassignDialog(context, gameState, soldier),
              ),

            // IMPRISON: Only Horde Leader
            if (isHordeLeader)
              _buildManagementButton(
                text: soldier.isImprisoned ? 'Release' : 'Imprison',
                color: Colors.orange[900]!,
                onPressed: () {
                  gameState.imprisonSoldier(soldier);
                  setState(() {}); // Refresh UI to show new status
                },
              ),

            // EXPEL: Horde Leader OR own Aravt
            if (isHordeLeader || isInPlayerAravt)
              _buildManagementButton(
                text: 'Expel',
                color: Colors.red[900]!,
                onPressed: () => _showConfirmationDialog(
                  context,
                  'Expel ${soldier.name}?',
                  'This will permanently remove ${soldier.name} from the horde. They will leave with their personal equipment.',
                  () {
                    gameState.expelSoldier(soldier);
                    Navigator.of(context).pop(); // Exit profile after expulsion
                  },
                ),
              ),

            // EXECUTE: Only Horde Leader
            if (isHordeLeader)
              _buildManagementButton(
                text: 'Execute',
                color: Colors.red[900]!,
                onPressed: () => _showConfirmationDialog(
                  context,
                  'Execute ${soldier.name}?',
                  'This will permanently remove ${soldier.name} from the horde. Their equipment and items will be forfeit.',
                  () {
                    gameState.executeSoldier(soldier);
                    Navigator.of(context).pop(); // Exit profile after execution
                  },
                ),
              ),
          ],
        )
      ],
    );
  }

  Widget _buildManagementButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[700],
        disabledForegroundColor: Colors.grey[400],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  void _showReassignDialog(
      BuildContext context, GameState gameState, Soldier soldier) {
    final aravts = gameState.aravts;
    final titleStyle = GoogleFonts.cinzel(
        color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[200],
          title: Text('Reassign ${soldier.name}', style: titleStyle),
          content: SizedBox(
            width: 300,
            height: 400,
            child: ListView.builder(
              itemCount: aravts.length,
              itemBuilder: (context, index) {
                final aravt = aravts[index];
                final bool isCurrentAravt = (aravt.id == soldier.aravt);

                return ListTile(
                  title: Text(aravt.id, style: GoogleFonts.cinzel()),
                  trailing: isCurrentAravt
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: isCurrentAravt
                      ? null // Disable tapping on the current aravt
                      : () {
                          gameState.transferSoldier(soldier, aravt);
                          Navigator.of(context).pop();
                          setState(() {}); // Refresh profile to show new aravt
                        },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.cinzel()),
            )
          ],
        );
      },
    );
  }

  Future<void> _showConfirmationDialog(
    BuildContext context,
    String title,
    String content,
    VoidCallback onConfirm,
  ) async {
    final titleStyle = GoogleFonts.cinzel(
        color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold);
    final bodyStyle = GoogleFonts.cinzel(color: Colors.black, fontSize: 14);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[200],
          title: Text(title, style: titleStyle),
          content: Text(content, style: bodyStyle),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.cinzel()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red[900]),
              child: Text('Confirm', style: GoogleFonts.cinzel()),
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInventoryRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.cinzel(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionPanel(
      BuildContext context, Soldier soldier, GameState gameState) {
    final headerStyle = GoogleFonts.cinzel(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold);
    final textStyle = GoogleFonts.cinzel(color: Colors.white);
    final Soldier player = gameState.player!;
    final bool canInteract =
        gameState.interactionTokensRemaining > 0 && !soldier.isPlayer;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController
            .jumpTo(_logScrollController.position.maxScrollExtent);
      }
    });

    return UiPanel(
      width: 335,
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INTERACTION', style: headerStyle),
          const Divider(color: Colors.white54),
          Text('Log:', style: textStyle.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            height: 240, // Fixed height for log
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((255 * 0.3).round()),
              border: Border.all(
                  color: Colors.white.withAlpha((255 * 0.1).round())),
              borderRadius: BorderRadius.circular(4),
            ),
            child: soldier.interactionLog.isEmpty
                ? Center(
                    child: Text('No interactions yet.', style: textStyle),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: soldier.interactionLog.length,
                    itemBuilder: (context, index) {
                      final log = soldier.interactionLog[index];
                      // Build the log text with all fields
                      String logText =
                          '[${log.dateString}] ${log.interactionSummary} ${log.outcomeSummary}';
                      if (log.informationRevealed.isNotEmpty) {
                        logText += '\n${log.informationRevealed}';
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 3.0, horizontal: 6.0),
                        child: Text(
                          logText,
                          style: textStyle.copyWith(fontSize: 12),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInteractionButton(
                context: context,
                text: 'Scold',
                onPressed: canInteract
                    ? () => _handleInteraction(
                        InteractionType.scold, gameState, player, soldier)
                    : null,
              ),
              _buildInteractionButton(
                context: context,
                text: 'Praise',
                onPressed: canInteract
                    ? () => _handleInteraction(
                        InteractionType.praise, gameState, player, soldier)
                    : null,
              ),
              TutorialHighlighter(
                highlightKey: 'inquire_soldier',
                child: _buildInteractionButton(
                  context: context,
                  text: 'Inquire',
                  onPressed: canInteract
                      ? () => _handleInteraction(
                          InteractionType.inquire, gameState, player, soldier)
                      : null,
                ),
              ),
              _buildInteractionButton(
                context: context,
                text: 'Listen',
                onPressed: canInteract && soldier.queuedListenItem != null
                    ? () => _handleInteraction(
                        InteractionType.listen, gameState, player, soldier)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionTokenDisplay(int tokensRemaining) {
    return IgnorePointer(
      child: Row(
        mainAxisSize: MainAxisSize.min, // Don't take full width
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(10, (index) {
          return Icon(
            index < tokensRemaining ? Icons.circle : Icons.circle_outlined,
            color: const Color(0xFFE0D5C1).withOpacity(0.8),
            size: 20,
          );
        }),
      ),
    );
  }

  Widget _buildInteractionButton(
      {required BuildContext context,
      required String text,
      required VoidCallback? onPressed}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.brown[800],
        disabledBackgroundColor: Colors.grey[700],
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.grey[400],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  Future<void> _handleInteraction(InteractionType type, GameState gameState,
      Soldier player, Soldier target) async {
    // [GEMINI-FIX] No dialog needed. Just execute and refresh.
    switch (type) {
      case InteractionType.scold:
        InteractionService.resolveScold(gameState, player, target);
        break;
      case InteractionType.praise:
        InteractionService.resolvePraise(gameState, player, target);
        break;
      case InteractionType.inquire:
        InteractionService.resolveInquire(gameState, player, target);
        break;
      case InteractionType.listen:
        InteractionService.resolveListen(gameState, player, target);
        break;
      case InteractionType.gift:
        // Gift interaction handled via _showGiftDialog, not here
        break;
    }

    gameState.useInteractionToken();
    if (mounted) setState(() {}); // Refresh UI to show new log entry
  }

  void _showGiftDialog(
      BuildContext context, GameState gameState, Soldier target) {
    showDialog(
      context: context,
      builder: (_) => GiftingDialog(gameState: gameState, target: target),
    );
  }

  void _showTradeDialog(
      BuildContext context, GameState gameState, Soldier target) {
    // TODO: Build a full UI showing player and soldier inventories side-by-side
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trade with ${target.name}'),
        content: const Text('TODO: Show trade UI here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          )
        ],
      ),
    );
  }

  Widget _buildHiddenStatsPanel(Soldier soldier) {
    const double panelHeight = 280; // Reduced from 350
    final textStyle =
        GoogleFonts.cinzel(color: Colors.white, fontSize: 11); // Smaller font

    return UiPanel(
      width: 220, // Reduced from 250
      height: panelHeight,
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hidden Stats',
                  style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('XP: ${soldier.experience.toStringAsFixed(1)}',
                  style: textStyle),
              Text(
                  'DOB: ${soldier.dateOfBirth.toLocal().toString().split(' ')[0]}',
                  style: textStyle),
              const Divider(color: Colors.white54, height: 8),
              Text('Injuries: ${soldier.injuryDescription ?? 'None'}',
                  style: textStyle),
              Text('Ailments: ${soldier.ailments ?? 'None'}', style: textStyle),
              Text('Scars: ${soldier.scars ?? 'None'}', style: textStyle),
              Text('Health: ${soldier.healthMax}', style: textStyle),
              Text('  Head: ${soldier.headHealthCurrent}', style: textStyle),
              Text('  Body: ${soldier.bodyHealthCurrent}', style: textStyle),
              Text('  R.Arm: ${soldier.rightArmHealthCurrent}',
                  style: textStyle),
              Text('  L.Arm: ${soldier.leftArmHealthCurrent}',
                  style: textStyle),
              Text('  R.Leg: ${soldier.rightLegHealthCurrent}',
                  style: textStyle),
              Text('  L.Leg: ${soldier.leftLegHealthCurrent}',
                  style: textStyle),
              Text('Exhaustion: ${soldier.exhaustion}', style: textStyle),
              Text('Stress: ${soldier.stress}', style: textStyle),
              Text('Hygiene: ${soldier.hygiene}', style: textStyle),
              const Divider(color: Colors.white54, height: 8),
              Text('Ambition: ${soldier.ambition}', style: textStyle),
              Text('Courage: ${soldier.courage}', style: textStyle),
              Text('Honesty: ${soldier.honesty}', style: textStyle),
              Text('Temperament: ${soldier.temperament}', style: textStyle),
              Text('Patience: ${soldier.patience}', style: textStyle),
              Text('Judgment: ${soldier.judgment}', style: textStyle),
              Text('Perception: ${soldier.perception}', style: textStyle),
              Text('Intelligence: ${soldier.intelligence}', style: textStyle),
              Text('Knowledge: ${soldier.knowledge}', style: textStyle),
              Text('Strength: ${soldier.strength}', style: textStyle),
              Text('Stamina: ${soldier.stamina}', style: textStyle),
              Text('Horsemanship: ${soldier.horsemanship}', style: textStyle),
              Text('Animal Handling: ${soldier.animalHandling}',
                  style: textStyle),
              Text('Charisma: ${soldier.charisma}', style: textStyle),
              Text('Leadership: ${soldier.leadership}', style: textStyle),
              Text('Adaptability: ${soldier.adaptability}', style: textStyle),
              const Divider(color: Colors.white54, height: 8),
              Text('Archery: ${soldier.longRangeArcherySkill}',
                  style: textStyle),
              Text('Mounted Archery: ${soldier.mountedArcherySkill}',
                  style: textStyle),
              Text('Spear: ${soldier.spearSkill}', style: textStyle),
              Text('Sword: ${soldier.swordSkill}', style: textStyle),
              Text('Shield: ${soldier.shieldSkill}', style: textStyle),
              Text(
                  'Special: ${soldier.specialSkills.isEmpty ? 'None' : soldier.specialSkills.map((s) => s.name).join(', ')}',
                  style: textStyle),
              Text(
                  'Attributes: ${soldier.attributes.isEmpty ? 'None' : soldier.attributes.map((a) => a.name).join(', ')}',
                  style: textStyle),
              const Divider(color: Colors.white54, height: 8),
              Text('Origin: ${soldier.placeOrTribeOfOrigin}', style: textStyle),
              Text('Languages: ${soldier.languages.join(', ')}',
                  style: textStyle),
              Text(
                  'Religion: ${soldier.religionIntensity.name} ${soldier.religionType.name}',
                  style: textStyle),
              Text('Gift Origin Pref: ${soldier.giftOriginPreference.name}',
                  style: textStyle),
              Text('Gift Type Pref: ${soldier.giftTypePreference.name}',
                  style: textStyle),
              const Divider(color: Colors.white54, height: 8),
              Text('Supplies: ${soldier.suppliesWealth.toStringAsFixed(2)}',
                  style: textStyle),
              Text('Treasure: ${soldier.treasureWealth.toStringAsFixed(2)}',
                  style: textStyle),
              Text('Meat: ${soldier.kilosOfMeat.toStringAsFixed(2)}',
                  style: textStyle),
              Text('Rice: ${soldier.kilosOfRice.toStringAsFixed(2)}',
                  style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class UiPanel extends StatelessWidget {
  final Widget child;
  final double width;
  final double? height;

  const UiPanel({
    super.key,
    required this.child,
    required this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((255 * 0.65).round()),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Colors.white.withAlpha((255 * 0.3).round()),
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}
