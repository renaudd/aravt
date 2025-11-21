import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/soldier_data.dart';
import '../models/horde_data.dart';
import 'soldier_portrait_widget.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/narrative_models.dart';
import 'narrative/tournament_conclusion_dialog.dart';

class NarrativeOverlayWidget extends StatefulWidget {
  const NarrativeOverlayWidget({super.key});

  @override
  State<NarrativeOverlayWidget> createState() => _NarrativeOverlayWidgetState();
}

class _NarrativeOverlayWidgetState extends State<NarrativeOverlayWidget> {
  // Use ID instead of object for robust dropdown equality checks
  int? _selectedSoldierId;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, child) {
        final event = gameState.activeNarrativeEvent;
        if (event == null) return const SizedBox.shrink();

        switch (event.type) {
          case NarrativeEventType.day5Trade:
            return _buildTradeDialog(context, gameState, event);
          case NarrativeEventType.tournamentConclusion:
            return TournamentConclusionDialog(event: event);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildTradeDialog(
      BuildContext context, GameState gameState, NarrativeEvent event) {
    final captain = gameState.findSoldierById(event.instigatorId);
    final offeredSoldier = gameState.findSoldierById(event.targetId);

    if (captain == null || offeredSoldier == null) {
      // Failsafe: if data is missing, auto-dismiss to avoid soft-lock
      WidgetsBinding.instance.addPostFrameCallback((_) {
        gameState.dismissNarrativeEvent();
      });
      return const SizedBox.shrink();
    }

    // Find player's aravt to know where to put the new soldier / take the old one from
    final playerAravt = gameState.aravts
        .firstWhere((a) => a.soldierIds.contains(gameState.player?.id));
    final bool hasRoom = playerAravt.soldierIds.length < 10;

    // Get list of tradeable soldiers (everyone in player's aravt except player)
    final tradeableSoldiers = gameState.horde
        .where((s) => !s.isPlayer && s.aravt == playerAravt.id)
        .toList();

    // Reset selection if it's no longer valid (e.g. after a reload)
    if (_selectedSoldierId != null &&
        !tradeableSoldiers.any((s) => s.id == _selectedSoldierId)) {
      _selectedSoldierId = null;
    }

    return Positioned.fill(
      // Semi-transparent black background to block interaction with game behind
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                border: Border.all(color: const Color(0xFF8B4513), width: 4),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black87, blurRadius: 20, spreadRadius: 5)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER (Captain Portrait & Name) ---
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFF8B4513), width: 2)),
                        child: SoldierPortrait(
                          index: captain.portraitIndex,
                          size: 70,
                          backgroundColor: captain.backgroundColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(captain.name,
                                style: GoogleFonts.cinzel(
                                    color: Colors.amber[200],
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            Text("Aravt Captain (Friendly)",
                                style: GoogleFonts.cinzel(
                                    color: Colors.green[200], fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF8B4513), height: 30),

                  // --- BODY (The Offer) ---
                  Text(
                    '"Brother, I have a soldier, ${offeredSoldier.firstName}, who is... struggling. Perhaps they would fare better under your command before I must cut them loose?"',
                    style: GoogleFonts.cinzel(
                        color: Colors.white, fontSize: 18, height: 1.3),
                  ),
                  const SizedBox(height: 20),
                  // Offered Soldier Preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.black38,
                        border: Border.all(color: Colors.white12)),
                    child: Row(
                      children: [
                        SoldierPortrait(
                          index: offeredSoldier.portraitIndex,
                          size: 50,
                          backgroundColor: offeredSoldier.backgroundColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          offeredSoldier.name,
                          style: GoogleFonts.cinzel(
                              color: Colors.white, fontSize: 16),
                        ),
                        // intentionally NOT showing stats here to keep it a gamble
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- ACTIONS ---
                  // 1. Accept (only if room)
                  if (hasRoom) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[900],
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () {
                          _handleAccept(gameState, event, playerAravt, captain);
                        },
                        child: Text("Accept ${offeredSoldier.firstName}",
                            style: GoogleFonts.cinzel(
                                color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                        child: Text("- OR -",
                            style: GoogleFonts.cinzel(color: Colors.white38))),
                    const SizedBox(height: 12),
                  ],

                  // 2. Trade (Always an option if you have soldiers to trade)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        color: Colors.white10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Offer Swap:",
                            style: GoogleFonts.cinzel(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: _selectedSoldierId,
                                  hint: Text("Select a soldier...",
                                      style: GoogleFonts.cinzel(
                                          color: Colors.white54)),
                                  dropdownColor: const Color(0xFF333333),
                                  items: tradeableSoldiers.map((s) {
                                    return DropdownMenuItem<int>(
                                      value: s.id,
                                      child: Row(
                                        children: [
                                          // Small portrait in dropdown for polish
                                          SoldierPortrait(
                                              index: s.portraitIndex,
                                              size: 30,
                                              backgroundColor:
                                                  s.backgroundColor),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(s.name,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.cinzel(
                                                    color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (int? id) {
                                    setState(() {
                                      _selectedSoldierId = id;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[800],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14)),
                              onPressed: _selectedSoldierId == null
                                  ? null
                                  : () {
                                      _handleTrade(gameState, event,
                                          playerAravt, captain);
                                    },
                              child: Text("Swap",
                                  style: GoogleFonts.cinzel(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Reject
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        _handleReject(gameState, event, captain);
                      },
                      child: Text('"Handle your own problems." (Reject)',
                          style: GoogleFonts.cinzel(color: Colors.red[300])),
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

  // Moves strictly within Horde (Friendly Captain -> Player)
  void _handleAccept(GameState gameState, NarrativeEvent event,
      Aravt playerAravt, Soldier captain) {
    final soldier = gameState.findSoldierById(event.targetId)!;
    final captainsAravt = gameState.findAravtById(captain.aravt)!;

    // 1. Remove from friendly captain's aravt
    captainsAravt.soldierIds.remove(soldier.id);

    // 2. Add to player's aravt
    playerAravt.soldierIds.add(soldier.id);
    soldier.aravt = playerAravt.id;

    gameState.logEvent("You accepted ${soldier.name} from ${captain.name}.",
        category: EventCategory.general);
    gameState.dismissNarrativeEvent();
  }

  // Swaps strictly within Horde (Player <-> Friendly Captain)
  void _handleTrade(GameState gameState, NarrativeEvent event,
      Aravt playerAravt, Soldier captain) {
    final incomingSoldier = gameState.findSoldierById(event.targetId)!;
    final outgoingSoldier = gameState.findSoldierById(_selectedSoldierId!)!;
    final captainsAravt = gameState.findAravtById(captain.aravt)!;

    // 1. Swap Aravt IDs on soldiers
    incomingSoldier.aravt = playerAravt.id;
    outgoingSoldier.aravt = captainsAravt.id;

    // 2. Update Aravt rosters
    playerAravt.soldierIds.remove(outgoingSoldier.id);
    playerAravt.soldierIds.add(incomingSoldier.id);

    captainsAravt.soldierIds.remove(incomingSoldier.id);
    captainsAravt.soldierIds.add(outgoingSoldier.id);

    gameState.logEvent(
        "Swapped ${outgoingSoldier.name} for ${incomingSoldier.name} with ${captain.name}.",
        category: EventCategory.general);
    gameState.dismissNarrativeEvent();
  }

  // Expels from Horde entirely on reject
  void _handleReject(
      GameState gameState, NarrativeEvent event, Soldier captain) {
    final soldier = gameState.findSoldierById(event.targetId)!;

    // We use the GameState's built-in expel method to ensure
    // all cleanup (yurts, relationships, etc.) happens correctly.
    gameState.expelSoldier(soldier);

    gameState.logEvent(
        "${captain.name} has expelled ${soldier.name} from the horde.",
        category: EventCategory.general);
    gameState.dismissNarrativeEvent();
  }
}
