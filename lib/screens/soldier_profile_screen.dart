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
import 'package:aravt/services/tutorial_service.dart';

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
  /// When navigating from one soldier to another, pass the current tab index
  /// so the same tab stays selected on the new profile screen.
  final int initialTabIndex;

  const SoldierProfileScreen({
    super.key,
    required this.soldierId,
    this.initialTabIndex = 0,
  });

  @override
  State<SoldierProfileScreen> createState() => _SoldierProfileScreenState();
}

class _SoldierProfileScreenState extends State<SoldierProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _logScrollController = ScrollController();
  List<Widget> _tabs = [];
  bool? _wasOmniscient;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAravtMembers();

    final gameState = Provider.of<GameState>(context);
    final isOmniscient = gameState.isOmniscientMode;

    if (_wasOmniscient != isOmniscient) {
      _wasOmniscient = isOmniscient;
      _updateTabs(isOmniscient);
    }
  }

  void _updateTabs(bool isOmniscient) {
    _tabs = [
      const Tooltip(message: 'Profile', child: Tab(icon: Icon(Icons.person))),
      const TutorialHighlighter(
          highlightKey: 'open_aravt_tab',
          child:
              Tooltip(message: 'Aravt', child: Tab(icon: Icon(Icons.group)))),
      const Tooltip(message: 'Yurt', child: Tab(icon: Icon(Icons.home))),
      const Tooltip(
          message: 'Inventory', child: Tab(icon: Icon(Icons.inventory))),
      const Tooltip(
          message: 'Reports', child: Tab(icon: Icon(Icons.assignment))),
      if (isOmniscient)
        const Tooltip(
            message: 'Relationships', child: Tab(icon: Icon(Icons.favorite))),
    ];

    int newIndex = widget.initialTabIndex; // default: honour caller's preference
    try {
      newIndex = _tabController.index; // if already initialised, keep current tab
      _tabController.dispose();
    } catch (e) {
      // Not initialized yet — use initialTabIndex from widget
    }

    _tabController = TabController(
        length: _tabs.length,
        vsync: this,
        initialIndex: newIndex < _tabs.length ? newIndex : 0);
    _tabController.addListener(_handleTabSelection);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tutorial = context.read<TutorialService>();
      if (tutorial.tutorialTabIndex != null) {
        if (tutorial.tutorialTabIndex! < _tabs.length) {
          _tabController.animateTo(tutorial.tutorialTabIndex!);
        }
        tutorial.resetTutorialNavigation();
      }
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      try {
        final tutorial = Provider.of<TutorialService>(context, listen: false);
        final gameState = Provider.of<GameState>(context, listen: false);
        tutorial.advanceIfHighlighted(context, gameState, 'open_aravt_tab');
      } catch (e) {
        // Ignore
      }
    }
  }

  List<Soldier> _aravtMembers = [];
  int _currentIndex = 0;

  void _loadAravtMembers() {
    final gameState = Provider.of<GameState>(context, listen: false);
    try {
      final soldier =
          gameState.horde.firstWhere((s) => s.id == widget.soldierId);
      if (soldier.aravt != 'None') {
        _aravtMembers =
            gameState.horde.where((s) => s.aravt == soldier.aravt).toList();
        _aravtMembers.sort((a, b) {
          if (a.role == SoldierRole.aravtCaptain) return -1;
          if (b.role == SoldierRole.aravtCaptain) return 1;
          return a.id.compareTo(b.id);
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

    int targetIndex = index;
    if (targetIndex < 0) targetIndex = _aravtMembers.length - 1;
    if (targetIndex >= _aravtMembers.length) targetIndex = 0;

    final targetSoldier = _aravtMembers[targetIndex];
    // Capture the current tab before pushing so the new screen opens on the same tab.
    final int currentTab = _tabController.index;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SoldierProfileScreen(
          soldierId: targetSoldier.id,
          initialTabIndex: currentTab,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────
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
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/steppe_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark scrim so text is readable
          Container(color: Colors.black.withOpacity(0.45)),

          // Main body column
          Column(
            children: [
              _buildCompactHeader(context, soldier, gameState),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _tabController,
                  children: [
                    // 1. Profile Tab — redesigned mobile-first layout
                    _buildProfileTab(context, soldier, gameState),
                    // 2. Aravt Tab
                    SoldierProfileAravtPanel(soldier: soldier),
                    // 3. Yurt Tab
                    SoldierProfileYurtPanel(soldier: soldier),
                    // 4. Inventory Tab
                    SoldierProfileInventoryPanel(soldier: soldier),
                    // 5. Reports Tab
                    SoldierProfileReportsPanel(soldier: soldier),
                    // 6. Relationships Tab (omniscient only)
                    if (gameState.isOmniscientMode)
                      SoldierProfileRelationshipsPanel(soldier: soldier),
                  ],
                ),
              ),
            ],
          ),

          const PersistentMenuWidget(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // COMPACT HEADER: ← | [Portrait mini] Name | Nav arrows | Tabs
  // ─────────────────────────────────────────────────────────────────
  Widget _buildCompactHeader(
      BuildContext context, Soldier soldier, GameState gameState) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: Colors.black.withOpacity(0.80),
      padding: EdgeInsets.only(top: top + 2, bottom: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row: ← | portrait chip + name + nav arrows
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
              // Mini portrait
              SoldierPortrait(
                index: soldier.portraitIndex,
                backgroundColor: soldier.backgroundColor,
                size: 36.0,
              ),
              const SizedBox(width: 8),
              // Name + aravt — tapping name opens aravt member list
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAravtMemberList(context, gameState),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        soldier.name,
                        style: GoogleFonts.cinzel(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        gameState.findAravtById(soldier.aravt)?.name ??
                            soldier.aravt,
                        style: GoogleFonts.cinzel(
                            color: Colors.amber.shade300, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Nav arrows (only if in aravt)
              if (_aravtMembers.length > 1) ...[
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white70, size: 22),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  onPressed: () => _navigateToSoldier(_currentIndex - 1),
                  tooltip: 'Previous',
                ),
                TutorialHighlighter(
                  highlightKey: 'navigate_next_soldier',
                  shape: BoxShape.circle,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: Colors.white70, size: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      context.read<TutorialService>().advanceIfHighlighted(
                          context, gameState, 'navigate_next_soldier');
                      _navigateToSoldier(_currentIndex + 1);
                    },
                    tooltip: 'Next',
                  ),
                ),
              ],
              const SizedBox(width: 4),
            ],
          ),
          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: _tabs,
            isScrollable: false,
            labelStyle:
                GoogleFonts.cinzel(color: Colors.amber, fontSize: 10),
            unselectedLabelStyle:
                GoogleFonts.cinzel(color: Colors.white70, fontSize: 10),
            indicatorColor: Colors.amber,
            indicatorWeight: 2,
            dividerColor: Colors.transparent,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // PROFILE TAB — mobile-first, single column
  // ─────────────────────────────────────────────────────────────────

  // Quality string → a 0‑3 rank (Worn=0, Humble=1, Good=2, Excellent=3)
  static int _qualityRank(String? q) {
    switch (q) {
      case 'Worn':
      case 'Subpar':
        return 0;
      case 'Humble':
      case 'Average':
      case 'Simple':
        return 1;
      case 'Good':
      case 'Superior':
      case 'Ornate':
        return 2;
      case 'Excellent':
      case 'Gemmed':
        return 3;
      default:
        return 1;
    }
  }

  // Colour for a filled slot based on quality rank
  static Color _gearSlotColor(String? quality) {
    switch (_qualityRank(quality)) {
      case 0: return const Color(0xFFB8860B); // worn → dark gold/yellow
      case 1: return const Color(0xFF2E7D32); // humble → mid green
      case 2: return const Color(0xFF1B5E20); // good → dark green
      case 3: return const Color(0xFF0D3B11); // excellent → very dark green
      default: return const Color(0xFF2E7D32);
    }
  }

  Widget _buildGearPreview(Soldier soldier) {
    // Show all 14 slots in two rows of 7
    final slots = EquipmentSlot.values;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: slots.map((slot) {
          final item = soldier.equippedItems[slot];
          final filled = item != null;
          final color = filled ? _gearSlotColor(item.quality) : Colors.red.shade900.withOpacity(0.7);
          final icon = _placeholderIconMap[slot] ?? Icons.inventory_2_outlined;
          return Tooltip(
            message: filled ? '${slot.name}: ${item.name}' : '${slot.name}: empty',
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Icon(icon,
                  color: filled ? Colors.white70 : Colors.red.shade200,
                  size: 13),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatBarsPreview(Soldier soldier) {
    // Overall health: average across 6 body parts
    final maxSum = soldier.headHealthMax + soldier.bodyHealthMax +
        soldier.rightArmHealthMax + soldier.leftArmHealthMax +
        soldier.rightLegHealthMax + soldier.leftLegHealthMax;
    final curSum = soldier.headHealthCurrent + soldier.bodyHealthCurrent +
        soldier.rightArmHealthCurrent + soldier.leftArmHealthCurrent +
        soldier.rightLegHealthCurrent + soldier.leftLegHealthCurrent;
    final healthFrac = maxSum > 0 ? (curSum / maxSum).clamp(0.0, 1.0) : 1.0;

    // Mood: composite of stress (neg), exhaustion (neg), temperament (pos)
    // temperament is 1-10 scale, stress/exhaustion 0-10 scale.
    // mood = (temperament/10 * 0.5) + ((10-stress)/10 * 0.3) + ((10-exhaustion)/10 * 0.2)
    final tempNorm = (soldier.temperament / 10).clamp(0.0, 1.0);
    final stressNorm = ((10 - soldier.stress) / 10).clamp(0.0, 1.0);
    final exhaustNorm = ((10 - soldier.exhaustion) / 10).clamp(0.0, 1.0);
    final moodFrac = (tempNorm * 0.5 + stressNorm * 0.3 + exhaustNorm * 0.2).clamp(0.0, 1.0);

    Color barColor(double frac) {
      if (frac > 0.6) return Colors.green.shade700;
      if (frac > 0.3) return Colors.orange.shade700;
      return Colors.red.shade700;
    }

    Widget statBar(String label, double frac, Color col) {
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(label,
                  style: GoogleFonts.cinzel(
                      color: Colors.white60, fontSize: 8)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: frac,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(col),
                  minHeight: 7,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        statBar('Health', healthFrac, barColor(healthFrac)),
        statBar('Mood', moodFrac, barColor(moodFrac)),
      ],
    );
  }

  Widget _buildProfileTab(
      BuildContext context, Soldier soldier, GameState gameState) {
    final titles = _collectTitles(soldier, gameState);
    final Soldier? player = gameState.player;
    final bool canInteract =
        gameState.interactionTokensRemaining > 0 && !soldier.isPlayer;
    final bool isHordeLeader =
        gameState.player?.role == SoldierRole.hordeLeader;
    final bool isInPlayerAravt = soldier.aravt == gameState.player?.aravt;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── IDENTITY CARD ──────────────────────────────────────
          _SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoldierPortrait(
                  index: soldier.portraitIndex,
                  backgroundColor: soldier.backgroundColor,
                  size: 90.0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _StatChip(label: 'Age ${soldier.age}', icon: Icons.person),
                          _StatChip(label: '${soldier.yearsWithHorde} yrs', icon: Icons.military_tech),
                          if (soldier.isImprisoned)
                            _StatChip(label: 'Imprisoned', icon: Icons.lock, color: Colors.red.shade700),
                          if (soldier.ailments != null)
                            _StatChip(label: 'Ailment', icon: Icons.sick, color: Colors.orange.shade700),
                          if (soldier.injuries.isNotEmpty)
                            _StatChip(label: '${soldier.injuries.length} injury', icon: Icons.healing, color: Colors.red.shade800),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (titles.isNotEmpty)
                        Wrap(
                          spacing: 5,
                          runSpacing: 3,
                          children: titles.map((t) => _TitleBadge(title: t)).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── QUICK ACTION BUTTONS (Gear / Details) ──────────────
          Row(
            children: [
              Expanded(
                child: _HighlightButton(
                  icon: Icons.shield,
                  label: 'Gear',
                  sublabel: '${soldier.equippedItems.length}/${EquipmentSlot.values.length} equipped',
                  preview: _buildGearPreview(soldier),
                  onTap: () => _openGearSheet(context, soldier),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HighlightButton(
                  icon: Icons.analytics_outlined,
                  label: 'Details',
                  sublabel: 'Origin, background, traits',
                  preview: _buildStatBarsPreview(soldier),
                  onTap: () => _openDetailsSheet(context, soldier, gameState),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── INLINE INTERACTION + MANAGEMENT SECTION ────────────
          // Only shown for non-player soldiers.
          if (!soldier.isPlayer)
            TutorialHighlighter(
              highlightKey: 'interact_section',
              child: _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: title + token pips ────────────────
                    Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: Colors.amber.shade300, size: 16),
                        const SizedBox(width: 6),
                        Text('Interact',
                            style: GoogleFonts.cinzel(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        ...List.generate(10, (i) => Icon(
                              i < gameState.interactionTokensRemaining
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              color: const Color(0xFFE0D5C1).withOpacity(0.7),
                              size: 10,
                            )),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // ── Interaction log ───────────────────────────
                    if (soldier.interactionLog.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 90),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(6),
                          shrinkWrap: true,
                          reverse: true,
                          itemCount: soldier.interactionLog.length.clamp(0, 4),
                          itemBuilder: (ctx, i) {
                            final entry = soldier.interactionLog.reversed.toList()[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '[${entry.dateString}] ${entry.interactionSummary} ${entry.outcomeSummary}',
                                style: GoogleFonts.cinzel(
                                    color: Colors.white70, fontSize: 10),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Text('No interactions yet.',
                          style: GoogleFonts.cinzel(
                              color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 8),

                    // ── Unified 8-button row ──────────────────────
                    // Left 4: Scold / Praise / Inquire / Listen  (interaction)
                    // Right 4: Gift / Expel / Imprison / Execute  (management)
                    // Thin divider between groups.
                    Row(
                      children: [
                        Expanded(child: _buildSmallButton(
                          text: 'Scold',
                          color: Colors.brown[800]!,
                          enabled: canInteract && player != null,
                          onPressed: canInteract && player != null
                              ? () => _handleInteraction(
                                  InteractionType.scold, gameState, player!, soldier)
                              : null,
                        )),
                        const SizedBox(width: 3),
                        Expanded(child: _buildSmallButton(
                          text: 'Praise',
                          color: Colors.brown[800]!,
                          enabled: canInteract && player != null,
                          onPressed: canInteract && player != null
                              ? () => _handleInteraction(
                                  InteractionType.praise, gameState, player!, soldier)
                              : null,
                        )),
                        const SizedBox(width: 3),
                        Expanded(
                          child: TutorialHighlighter(
                            highlightKey: 'inquire_soldier',
                            child: _buildSmallButton(
                              text: 'Inquire',
                              color: Colors.brown[800]!,
                              enabled: canInteract && player != null,
                              onPressed: canInteract && player != null
                                  ? () {
                                      context.read<TutorialService>().advanceIfHighlighted(
                                          context, gameState, 'inquire_soldier');
                                      _handleInteraction(InteractionType.inquire,
                                          gameState, player!, soldier);
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(child: _buildSmallButton(
                          text: 'Listen',
                          color: Colors.brown[800]!,
                          enabled: canInteract && player != null &&
                              soldier.queuedListenItem != null,
                          onPressed: canInteract && player != null &&
                                  soldier.queuedListenItem != null
                              ? () => _handleInteraction(
                                  InteractionType.listen, gameState, player!, soldier)
                              : null,
                        )),
                        Container(
                          width: 1,
                          height: 30,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          color: Colors.white24,
                        ),
                        Expanded(child: _buildSmallButton(
                          text: 'Gift',
                          color: Colors.teal[900]!,
                          enabled: true,
                          onPressed: () => _showGiftDialog(context, gameState, soldier),
                        )),
                        const SizedBox(width: 3),
                        Expanded(child: _buildSmallButton(
                          text: 'Expel',
                          color: Colors.red[900]!,
                          enabled: isHordeLeader || isInPlayerAravt,
                          onPressed: isHordeLeader || isInPlayerAravt
                              ? () => _showConfirmationDialog(
                                  context,
                                  'Expel ${soldier.name}?',
                                  'Permanently removes ${soldier.name} from the horde.',
                                  () {
                                    gameState.expelSoldier(soldier);
                                    Navigator.of(context).pop();
                                  },
                                )
                              : null,
                        )),
                        const SizedBox(width: 3),
                        Expanded(child: _buildSmallButton(
                          text: soldier.isImprisoned ? 'Release' : 'Imprison',
                          color: Colors.orange[900]!,
                          enabled: isHordeLeader,
                          onPressed: isHordeLeader
                              ? () {
                                  gameState.imprisonSoldier(soldier);
                                  setState(() {});
                                }
                              : null,
                        )),
                        const SizedBox(width: 3),
                        Expanded(child: _buildSmallButton(
                          text: 'Execute',
                          color: Colors.red[900]!,
                          enabled: isHordeLeader,
                          onPressed: isHordeLeader
                              ? () => _showConfirmationDialog(
                                  context,
                                  'Execute ${soldier.name}?',
                                  'Permanently removes ${soldier.name}.',
                                  () {
                                    gameState.executeSoldier(soldier);
                                    Navigator.of(context).pop();
                                  },
                                )
                              : null,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // BOTTOM SHEETS
  // ─────────────────────────────────────────────────────────────────


  /// Shows a bottom sheet listing all members of the current soldier's aravt,
  /// captain first. Tapping a member navigates to their profile.
  void _showAravtMemberList(BuildContext context, GameState gameState) {
    if (_aravtMembers.isEmpty) return;

    // _aravtMembers is already captain-first sorted (done in _loadAravtMembers).
    final aravtName = _aravtMembers.isNotEmpty
        ? gameState.findAravtById(_aravtMembers.first.aravt)?.name ?? 'Aravt'
        : 'Aravt';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1610),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  aravtName,
                  style: GoogleFonts.cinzel(
                      color: Colors.amber.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _aravtMembers.length,
                  itemBuilder: (ctx, i) {
                    final member = _aravtMembers[i];
                    final isCurrent = member.id == widget.soldierId;
                    final isCaptain =
                        member.role == SoldierRole.aravtCaptain;
                    return ListTile(
                      dense: true,
                      leading: SoldierPortrait(
                        index: member.portraitIndex,
                        backgroundColor: member.backgroundColor,
                        size: 32,
                      ),
                      title: Text(
                        member.name,
                        style: GoogleFonts.cinzel(
                          color: isCurrent
                              ? Colors.amber.shade300
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: isCaptain
                          ? Text('Captain',
                              style: GoogleFonts.cinzel(
                                  color: Colors.amber.shade700, fontSize: 10))
                          : null,
                      trailing: isCurrent
                          ? const Icon(Icons.arrow_right,
                              color: Colors.amber, size: 16)
                          : null,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        if (!isCurrent) {
                          _navigateToSoldier(i);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openGearSheet(BuildContext context, Soldier soldier) {
    final sorted = soldier.equippedItems.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    _showDetailSheet(
      context: context,
      title: 'Equipped Gear',
      icon: Icons.shield,
      child: sorted.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No gear equipped.',
                  style: TextStyle(color: Colors.white70)),
            )
          : Column(
              children: sorted.map((entry) {
                final slot = entry.key;
                final item = entry.value;
                return ListTile(
                  dense: true,
                  leading: Icon(
                      _placeholderIconMap[slot] ?? Icons.inventory_2_outlined,
                      color: Colors.amber.shade200,
                      size: 20),
                  title: Text(
                    item.name,
                    style:
                        GoogleFonts.cinzel(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    slot.name,
                    style: GoogleFonts.cinzel(
                        color: Colors.white54, fontSize: 10),
                  ),
                );
              }).toList(),
            ),
    );
  }



  void _openDetailsSheet(
      BuildContext context, Soldier soldier, GameState gameState) {
    final bool omni = gameState.isOmniscientMode;
    final textStyle = GoogleFonts.cinzel(color: Colors.white, fontSize: 12);
    final labelStyle = GoogleFonts.cinzel(
        color: Colors.amber.shade300,
        fontSize: 11,
        fontWeight: FontWeight.bold);

    // Compute mood for display
    final tempNorm = (soldier.temperament / 10).clamp(0.0, 1.0);
    final stressNorm = ((10 - soldier.stress) / 10).clamp(0.0, 1.0);
    final exhaustNorm = ((10 - soldier.exhaustion) / 10).clamp(0.0, 1.0);
    final moodPct = ((tempNorm * 0.5 + stressNorm * 0.3 + exhaustNorm * 0.2) * 100).round();

    final maxSum = soldier.headHealthMax + soldier.bodyHealthMax +
        soldier.rightArmHealthMax + soldier.leftArmHealthMax +
        soldier.rightLegHealthMax + soldier.leftLegHealthMax;
    final curSum = soldier.headHealthCurrent + soldier.bodyHealthCurrent +
        soldier.rightArmHealthCurrent + soldier.leftArmHealthCurrent +
        soldier.rightLegHealthCurrent + soldier.leftLegHealthCurrent;
    final healthPct = maxSum > 0 ? (curSum * 100 ~/ maxSum) : 100;

    _showDetailSheet(
      context: context,
      title: 'Details',
      icon: Icons.analytics_outlined,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CONDITION (always visible) ──────────────────────
            Text('CONDITION', style: labelStyle),
            const SizedBox(height: 6),
            _DetailRow('Height', '${soldier.height.toStringAsFixed(0)} cm', textStyle),
            _DetailRow('Health', '$healthPct%', textStyle),
            _DetailRow('Mood', '$moodPct%', textStyle),
            if (soldier.ailments != null)
              _DetailRow('Ailments', soldier.ailments!, textStyle),
            if (soldier.injuryDescription != null)
              _DetailRow('Injuries', soldier.injuryDescription!, textStyle)
            else
              _DetailRow('Injuries', 'None', textStyle),
            if (soldier.scars != null)
              _DetailRow('Scars', soldier.scars!, textStyle),
            // Stress & Exhaustion are internal stats — only in omniscient mode
            if (omni) ...[
              _DetailRow('Exhaustion', '${soldier.exhaustion.toStringAsFixed(1)}', textStyle),
              _DetailRow('Stress', '${soldier.stress.toStringAsFixed(1)}', textStyle),
              _DetailRow('Hygiene', '${soldier.hygiene.toStringAsFixed(1)}', textStyle),
            ],
            const Divider(color: Colors.white24, height: 20),
            // ── BACKGROUND (always visible) ─────────────────────
            Text('BACKGROUND', style: labelStyle),
            const SizedBox(height: 4),
            _DetailRow('Origin', soldier.placeOrTribeOfOrigin, textStyle),
            _DetailRow('Languages', soldier.languages.join(', '), textStyle),
            _DetailRow(
                'Religion',
                '\${soldier.religionIntensity.name} \${soldier.religionType.name}',
                textStyle),
            _DetailRow('Zodiac', soldier.zodiac.name, textStyle),
            if (soldier.startingInjury != StartingInjuryType.none)
              _DetailRow('Born with', soldier.startingInjury.name, textStyle),
            const Divider(color: Colors.white24, height: 20),
            // ── OMNISCIENT-ONLY SECTIONS ─────────────────────────
            if (omni) ...[
              Text('CORE TRAITS', style: labelStyle),
              const SizedBox(height: 4),
              _DetailRow('Courage', '\${soldier.courage}', textStyle),
              _DetailRow('Ambition', '\${soldier.ambition}', textStyle),
              _DetailRow('Temperament', '\${soldier.temperament}', textStyle),
              _DetailRow('Charisma', '\${soldier.charisma}', textStyle),
              _DetailRow('Leadership', '\${soldier.leadership}', textStyle),
              _DetailRow('Honesty', '\${soldier.honesty}', textStyle),
              _DetailRow('Adaptability', '\${soldier.adaptability}', textStyle),
              const Divider(color: Colors.white24, height: 20),
              Text('PHYSICAL', style: labelStyle),
              const SizedBox(height: 4),
              _DetailRow('Strength', '\${soldier.strength}', textStyle),
              _DetailRow('Stamina', '\${soldier.stamina}', textStyle),
              _DetailRow('Horsemanship', '\${soldier.horsemanship}', textStyle),
              _DetailRow('Animal Handling', '\${soldier.animalHandling}', textStyle),
              const Divider(color: Colors.white24, height: 20),
              Text('MENTAL', style: labelStyle),
              const SizedBox(height: 4),
              _DetailRow('Intelligence', '\${soldier.intelligence}', textStyle),
              _DetailRow('Perception', '\${soldier.perception}', textStyle),
              _DetailRow('Knowledge', '\${soldier.knowledge}', textStyle),
              _DetailRow('Patience', '\${soldier.patience}', textStyle),
              _DetailRow('Judgment', '\${soldier.judgment}', textStyle),
              const Divider(color: Colors.white24, height: 20),
              Text('COMBAT SKILLS', style: labelStyle),
              const SizedBox(height: 4),
              _DetailRow('Archery', soldier.longRangeArcherySkill.toStringAsFixed(1), textStyle),
              _DetailRow('Mounted Archery', soldier.mountedArcherySkill.toStringAsFixed(1), textStyle),
              _DetailRow('Spear', soldier.spearSkill.toStringAsFixed(1), textStyle),
              _DetailRow('Sword', soldier.swordSkill.toStringAsFixed(1), textStyle),
              _DetailRow('Shield', soldier.shieldSkill.toStringAsFixed(1), textStyle),
              _DetailRow('Experience', '\${soldier.experience.toInt()} xp', textStyle),
              if (soldier.specialSkills.isNotEmpty)
                _DetailRow('Special', soldier.specialSkills.map((s) => s.name).join(', '), textStyle),
              if (soldier.attributes.isNotEmpty) ...[
                const Divider(color: Colors.white24, height: 20),
                Text('ATTRIBUTES', style: labelStyle),
                const SizedBox(height: 4),
                ...soldier.attributes.map((a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• \${a.name}',
                          style: GoogleFonts.cinzel(
                              color: Colors.white70, fontSize: 11)),
                    )),
              ],
              const Divider(color: Colors.white24, height: 20),
              Text('PREFERENCES', style: labelStyle),
              const SizedBox(height: 4),
              _DetailRow('Prefers duty', soldier.preferredDuties.isEmpty
                  ? 'None' : soldier.preferredDuties.map((d) => d.name).join(', '), textStyle),
              _DetailRow('Despises duty', soldier.despisedDuties.isEmpty
                  ? 'None' : soldier.despisedDuties.map((d) => d.name).join(', '), textStyle),
              _DetailRow('Gift: type', soldier.giftTypePreference.name, textStyle),
              _DetailRow('Gift: origin', soldier.giftOriginPreference.name, textStyle),
              const Divider(color: Colors.white24, height: 20),
              Text('RESOURCES', style: labelStyle),
              const SizedBox(height: 4),
              _DetailRow('Supplies', soldier.suppliesWealth.toStringAsFixed(1), textStyle),
              _DetailRow('Treasure', soldier.treasureWealth.toStringAsFixed(1), textStyle),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // _openManageSheet removed — management actions are now inline in the Interact card.
  // Kept as a no-op placeholder to avoid breaking any lingering references.
  // ignore: unused_element
  void _openManageSheet_REMOVED(
      BuildContext context, Soldier soldier, GameState gameState) {
    final bool isHordeLeader =
        gameState.player?.role == SoldierRole.hordeLeader;
    final bool isInPlayerAravt =
        soldier.aravt == gameState.player?.aravt;

    _showDetailSheet(
      context: context,
      title: 'Manage',
      icon: Icons.manage_accounts_outlined,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildManagementButton(
              text: 'Gift',
              color: Colors.brown[800]!,
              onPressed: () {
                Navigator.pop(context);
                _showGiftDialog(context, gameState, soldier);
              },
            ),
            if (isHordeLeader)
              _buildManagementButton(
                text: 'Reassign',
                color: Colors.blue[800]!,
                onPressed: () {
                  Navigator.pop(context);
                  _showReassignDialog(context, gameState, soldier);
                },
              ),
            if (isHordeLeader)
              _buildManagementButton(
                text: soldier.isImprisoned ? 'Release' : 'Imprison',
                color: Colors.orange[900]!,
                onPressed: () {
                  gameState.imprisonSoldier(soldier);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            if (isHordeLeader || isInPlayerAravt)
              _buildManagementButton(
                text: 'Expel',
                color: Colors.red[900]!,
                onPressed: () {
                  Navigator.pop(context);
                  _showConfirmationDialog(
                    context,
                    'Expel ${soldier.name}?',
                    'This will permanently remove ${soldier.name} from the horde.',
                    () {
                      gameState.expelSoldier(soldier);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            if (isHordeLeader)
              _buildManagementButton(
                text: 'Execute',
                color: Colors.red[900]!,
                onPressed: () {
                  Navigator.pop(context);
                  _showConfirmationDialog(
                    context,
                    'Execute ${soldier.name}?',
                    'This will permanently remove ${soldier.name}. Their equipment will be forfeit.',
                    () {
                      gameState.executeSoldier(soldier);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            if (isHordeLeader &&
                soldier.role == SoldierRole.soldier &&
                gameState.canPromoteToCaptain(soldier))
              _buildManagementButton(
                text: 'Promote Captain',
                color: Colors.amber[800]!,
                onPressed: () {
                  Navigator.pop(context);
                  _showConfirmationDialog(
                    context,
                    'Promote to Captain?',
                    'This will create a new Aravt with ${soldier.name} as its captain.',
                    () {
                      gameState.promoteSoldierToCaptain(soldier);
                      setState(() {});
                    },
                  );
                },
              ),
            if (isHordeLeader &&
                soldier.role == SoldierRole.aravtCaptain)
              _buildManagementButton(
                text: 'Promote General',
                color: Colors.amber[900]!,
                onPressed: gameState.canPromoteToGeneral(soldier)
                    ? () {
                        Navigator.pop(context);
                        _showConfirmationDialog(
                          context,
                          'Promote to General?',
                          '${soldier.name} will be promoted to General.',
                          () {
                            gameState.promoteToGeneral(soldier);
                            setState(() {});
                          },
                        );
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  /// Generic bottom sheet helper
  void _showDetailSheet({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1208),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
                color: Colors.amber.withOpacity(0.25), width: 1),
          ),
          child: Column(
            children: [
              // Handle + header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.amber.shade300, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(_),
                      child: Icon(Icons.close,
                          color: Colors.white54, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

  List<String> _collectTitles(Soldier soldier, GameState gameState) {
    final List<String> titles = [];

    if (soldier.role == SoldierRole.aravtCaptain) {
      titles.add("Arban-u Darga");
    } else if (soldier.role == SoldierRole.hordeLeader) {
      titles.add("Noyan");
    } else if (soldier.role == SoldierRole.general) {
      titles.add("General");
    }

    final aravt = gameState.findAravtById(soldier.aravt);
    if (aravt != null) {
      aravt.dutyAssignments.forEach((duty, assigneeId) {
        if (assigneeId == soldier.id) {
          String dutyName =
              duty.name.substring(0, 1).toUpperCase() + duty.name.substring(1);
          titles.add(dutyName);
        }
      });
    }

    gameState.currentChampions.forEach((type, championId) {
      if (championId == soldier.id) {
        String typeName =
            type.name.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), ' ');
        typeName =
            typeName.substring(0, 1).toUpperCase() + typeName.substring(1);
        titles.add("$typeName Champion");
      }
    });

    return titles;
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle:
            GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 12),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  /// Compact button for the unified 8-button interact row.
  Widget _buildSmallButton({
    required String text,
    required Color color,
    required bool enabled,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey[800],
          foregroundColor: enabled ? Colors.white : Colors.white38,
          disabledBackgroundColor: Colors.grey[850],
          disabledForegroundColor: Colors.white24,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.cinzel(
              fontWeight: FontWeight.w600, fontSize: 10, letterSpacing: 0.3),
          elevation: enabled ? 2 : 0,
        ),
        onPressed: onPressed,
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildInteractionButton({
    required BuildContext context,
    required String text,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.brown[800],
        disabledBackgroundColor: Colors.grey[700],
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.grey[400],
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 11),
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
                      ? null
                      : () {
                          gameState.transferSoldier(soldier, aravt);
                          Navigator.of(context).pop();
                          setState(() {});
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

  void _showGiftDialog(
      BuildContext context, GameState gameState, Soldier target) {
    showDialog(
      context: context,
      builder: (_) => GiftingDialog(gameState: gameState, target: target),
    );
  }

  Future<void> _handleInteraction(InteractionType type, GameState gameState,
      Soldier player, Soldier target) async {
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
        final result =
            InteractionService.resolveListen(gameState, player, target);
        if (result.requiresResponse) {
          _showResponseDialog(context, result, gameState, player, target);
        }
        break;
      case InteractionType.gift:
        break;
    }

    gameState.useInteractionToken();
    if (mounted) setState(() {});
  }

  void _showResponseDialog(BuildContext context, InteractionResult result,
      GameState gameState, Soldier player, Soldier target) {
    String title = "Respond to ${target.name}";
    String content = result.informationRevealed;
    List<Widget> actions = [];

    switch (result.listenQuestType) {
      case ListenQuestType.familyStruggling:
        actions = [
          TextButton(
            child: Text("I will help your family.", style: GoogleFonts.cinzel()),
            onPressed: () {
              target.getRelationship(player.id).updateLoyalty(0.1);
              target.getRelationship(player.id).updateAdmiration(0.05);
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text("We all have our burdens.", style: GoogleFonts.cinzel()),
            onPressed: () {
              target.getRelationship(player.id).updateLoyalty(-0.02);
              Navigator.of(context).pop();
            },
          ),
        ];
        break;
      case ListenQuestType.roleRequest:
        actions = [
          TextButton(
            child: Text("I will consider you for a role.",
                style: GoogleFonts.cinzel()),
            onPressed: () {
              target.getRelationship(player.id).updateLoyalty(0.05);
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text("Continue serving as you are.",
                style: GoogleFonts.cinzel()),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ];
        break;
      case ListenQuestType.rations:
        actions = [
          TextButton(
            child: Text("I will check our stores.", style: GoogleFonts.cinzel()),
            onPressed: () {
              target.getRelationship(player.id).updateRespect(0.02);
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text("We must endure for the horde.",
                style: GoogleFonts.cinzel()),
            onPressed: () {
              target.getRelationship(player.id).updateLoyalty(-0.01);
              target.getRelationship(player.id).updateRespect(0.02);
              Navigator.of(context).pop();
            },
          ),
        ];
        break;
      default:
        actions = [
          TextButton(
            child: Text("Acknowledged.", style: GoogleFonts.cinzel()),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown[900],
        title: Text(title, style: GoogleFonts.cinzel(color: Colors.white)),
        content: Text(content, style: GoogleFonts.cinzel(color: Colors.white)),
        actions: actions,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Semi-transparent dark card with amber border
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.25), width: 1),
      ),
      child: child,
    );
  }
}

/// Small colored chip showing a single stat
class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const _StatChip(
      {required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Colors.white.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.cinzel(
                  color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Pale amber badge for titles/roles
class _TitleBadge extends StatelessWidget {
  final String title;
  const _TitleBadge({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Text(title,
          style: GoogleFonts.cinzel(
              color: Colors.amber.shade200, fontSize: 10)),
    );
  }
}

/// Large tappable button that shows a summary and opens a detail sheet
class _HighlightButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback? onTap;
  final Color? color;
  /// Optional widget shown below the label row (e.g. gear grid, stat bars).
  final Widget? preview;

  const _HighlightButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    this.onTap,
    this.color,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = enabled
        ? (color ?? Colors.white.withOpacity(0.10))
        : Colors.white.withOpacity(0.04);
    final borderColor =
        enabled ? Colors.amber.withOpacity(0.4) : Colors.white12;
    final textColor = enabled ? Colors.white : Colors.white38;
    final subColor = enabled ? Colors.white60 : Colors.white24;
    final iconColor = enabled ? Colors.amber.shade300 : Colors.white24;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: GoogleFonts.cinzel(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      Text(sublabel,
                          style: GoogleFonts.cinzel(
                              color: subColor, fontSize: 9)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: subColor, size: 16),
              ],
            ),
            if (preview != null) ...[
              const SizedBox(height: 6),
              preview!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A simple label: value row for detail sheets
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle style;
  const _DetailRow(this.label, this.value, this.style);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: style.copyWith(
                    color: Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}

/// Legacy UiPanel kept for compatibility with other tabs that may still reference it.
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
      padding: const EdgeInsets.all(8.0),
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
