import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/services/interaction_service.dart';

class GiftingDialog extends StatefulWidget {
  final GameState gameState;
  final Soldier target;

  const GiftingDialog({
    super.key,
    required this.gameState,
    required this.target,
  });

  @override
  State<GiftingDialog> createState() => _GiftingDialogState();
}

class _GiftingDialogState extends State<GiftingDialog> {
  @override
  Widget build(BuildContext context) {
    final player = widget.gameState.player!;
    final titleStyle = GoogleFonts.cinzel(
        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold);
    final bodyStyle = GoogleFonts.cinzel(color: Colors.white, fontSize: 16);
    final smallStyle = GoogleFonts.cinzel(color: Colors.white70, fontSize: 14);

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text('Gift to ${widget.target.name}', style: titleStyle),
      content: SizedBox(
        width: 500,
        height: 400,
        child: player.personalInventory.isEmpty
            ? Center(
                child: Text(
                  'You have no items to gift.',
                  style: bodyStyle,
                ),
              )
            : ListView.builder(
                itemCount: player.personalInventory.length,
                itemBuilder: (context, index) {
                  final item = player.personalInventory[index];

                  // Calculate predicted impact
                  final String prediction = _predictGiftImpact(
                      widget.gameState, player, widget.target, item);

                  return Card(
                    color: Colors.grey[850],
                    margin:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(
                          item.name,
                          style: bodyStyle.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Value: ${item.baseValue} | Origin: ${item.origin}',
                              style: smallStyle,
                            ),
                            if (prediction.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                prediction,
                                style: smallStyle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                  color: prediction.contains('⚠️')
                                      ? Colors.red[900]
                                      : Colors.green[900],
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          onPressed: () {
                            // Transfer item and resolve gift
                            setState(() {
                              player.personalInventory.remove(item);
                              widget.target.personalInventory.add(item);
                            });

                            InteractionService.resolveGift(
                                widget.gameState, player, widget.target, item);

                            widget.gameState.useInteractionToken();
                            Navigator.of(context).pop();
                            // Gift result now goes directly to interaction log
                          },
                          child: Text('Give',
                              style: GoogleFonts.cinzel(fontSize: 16)),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              Text('Cancel', style: bodyStyle.copyWith(color: Colors.white70)),
        ),
      ],
    );
  }

  String _predictGiftImpact(
      GameState gameState, Soldier player, Soldier target, InventoryItem item) {
    // Only show predictions in Omniscient Mode
    if (!gameState.isOmniscientMode) {
      return '';
    }

    final int currentTurn = gameState.turn.turnNumber;

    // Check birthday
    final currentDate = gameState.gameDate;
    final isBirthday = (target.dateOfBirth.month == currentDate.month &&
        target.dateOfBirth.day == currentDate.day);

    // Check recent performance
    final goodPerformance = target.performanceLog
        .where((e) => e.isPositive && (currentTurn - e.turnNumber) <= 2)
        .toList();
    double justification =
        goodPerformance.fold(0.0, (prev, e) => prev + e.magnitude);

    final bool isAppropriate = (justification > 0) || isBirthday;

    if (!isAppropriate) {
      return '⚠️ Gift may be inappropriate (no recent good performance)';
    }

    // Calculate base impact
    double baseAdmiration = (item.baseValue * 0.01).clamp(0.1, 0.5);
    double baseRespect = (item.baseValue * 0.005).clamp(0.05, 0.3);

    // Check preferences (simplified - just check if it matches)
    bool matchesType =
        _checkTypeMatch(item.itemType, target.giftTypePreference);
    bool matchesOrigin = _checkOriginMatch(
        item.origin, target.giftOriginPreference, target.placeOrTribeOfOrigin);

    double multiplier = 1.0;
    if (matchesType) multiplier *= 1.5;
    if (matchesOrigin &&
        target.giftOriginPreference != GiftOriginPreference.unappreciative) {
      multiplier *= 1.5;
    }

    double finalAdmiration = baseAdmiration * multiplier;
    double finalRespect = baseRespect * multiplier;

    String bonus = '';
    if (isBirthday) bonus = ' +Birthday bonus!';
    if (matchesType && matchesOrigin)
      bonus += ' Perfect match!';
    else if (matchesType)
      bonus += ' Likes this type!';
    else if (matchesOrigin) bonus += ' Likes this origin!';

    return '✓ +${finalAdmiration.toStringAsFixed(2)} Admiration, +${finalRespect.toStringAsFixed(2)} Respect$bonus';
  }

  bool _checkTypeMatch(ItemType itemType, GiftTypePreference preference) {
    switch (preference) {
      case GiftTypePreference.sword:
        return itemType == ItemType.sword;
      case GiftTypePreference.bow:
        return itemType == ItemType.bow;
      case GiftTypePreference.spear:
        return itemType == ItemType.spear ||
            itemType == ItemType.lance ||
            itemType == ItemType.throwingSpear;
      case GiftTypePreference.horse:
        return itemType == ItemType.mount;
      case GiftTypePreference.armor:
        return itemType == ItemType.armor || itemType == ItemType.undergarments;
      case GiftTypePreference.helmet:
        return itemType == ItemType.helmet;
      case GiftTypePreference.gauntlets:
        return itemType == ItemType.gauntlets;
      case GiftTypePreference.boots:
        return itemType == ItemType.boots;
      case GiftTypePreference.jewelry:
        return itemType == ItemType.relic ||
            itemType == ItemType.ring ||
            itemType == ItemType.necklace;
      case GiftTypePreference.supplies:
        return itemType == ItemType.consumable ||
            itemType == ItemType.ammunition;
      case GiftTypePreference.treasure:
        return itemType == ItemType.relic ||
            itemType == ItemType.ring ||
            itemType == ItemType.necklace ||
            itemType == ItemType.misc;
    }
  }

  bool _checkOriginMatch(String itemOrigin, GiftOriginPreference preference,
      String soldierOrigin) {
    switch (preference) {
      case GiftOriginPreference.allAppreciative:
        return true;
      case GiftOriginPreference.unappreciative:
        return false;
      case GiftOriginPreference.fromHome:
        return itemOrigin.toLowerCase() == soldierOrigin.toLowerCase();
      case GiftOriginPreference.fromRival:
        return itemOrigin.toLowerCase() != soldierOrigin.toLowerCase();
      default:
        return false;
    }
  }
}

class GiftResultDialog extends StatelessWidget {
  final GameState gameState;
  final InteractionResult result;

  const GiftResultDialog({
    super.key,
    required this.gameState,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.cinzel(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold);
    final bodyStyle = GoogleFonts.cinzel(color: Colors.white, fontSize: 14);

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text('Gift Result', style: titleStyle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.outcomeSummary, style: bodyStyle),
          if (gameState.isOmniscientMode &&
              result.statChangeSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(result.statChangeSummary,
                style: bodyStyle.copyWith(fontWeight: FontWeight.bold)),
          ],
          if (result.informationRevealed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(result.informationRevealed,
                style: bodyStyle.copyWith(
                    fontStyle: FontStyle.italic, color: Colors.white70)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('OK', style: GoogleFonts.cinzel(color: Colors.white)),
        ),
      ],
    );
  }
}
