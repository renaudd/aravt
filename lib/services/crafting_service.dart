import 'dart:math';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/justification_event.dart';

class CraftingService {
  final Random _random = Random();

  Future<void> resolveFletching({
    required Aravt aravt,
    required GameState gameState,
  }) async {
    int totalArrowsCrafted = 0;
    double woodConsumed = 0;
    double scrapConsumed = 0;
    int currentTurn = gameState.turn.turnNumber;

    for (var id in aravt.soldierIds) {
      final soldier = gameState.findSoldierById(id);
      if (soldier != null &&
          soldier.status == SoldierStatus.alive &&
          !soldier.isImprisoned) {
        if (gameState.communalWood < 3.75 || gameState.communalScrap < 15) {
          break;
        }

        // Calculate productivity
        double score = (soldier.patience * 2.0) +
            soldier.experience +
            soldier.shieldSkill +
            (soldier.stamina * 0.5) +
            (_random.nextInt(20) - 10);

        int arrowsMade = 0;
        if (score > 35) {
          arrowsMade = 30; // Extra successful
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Crafted an exceptional batch of arrows.",
              isPositive: true,
              magnitude: 2.0));
          soldier.pendingJustifications.add(JustificationEvent(
              description: "Crafted exceptional arrows",
              type: JustificationType.praise,
              expiryTurn: currentTurn + 2,
              magnitude: 1.0));
        } else if (score > 20) {
          arrowsMade = 15; // Successful
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Crafted a standard batch of arrows.",
              isPositive: true,
              magnitude: 1.0));
          soldier.pendingJustifications.add(JustificationEvent(
              description: "Crafted arrows",
              type: JustificationType.praise,
              expiryTurn: currentTurn + 2,
              magnitude: 0.5));
        } else {
          arrowsMade = _random.nextInt(10); // Unsuccessful/Poor
          soldier.performanceLog.add(PerformanceEvent(
              turnNumber: currentTurn,
              description: "Wasted materials fletching arrows.",
              isPositive: false,
              magnitude: 2.0));
          soldier.pendingJustifications.add(JustificationEvent(
              description: "Wasted materials crafting",
              type: JustificationType.scold,
              expiryTurn: currentTurn + 2,
              magnitude: 0.5));
        }

        double woodCost = arrowsMade * 0.25;
        double scrapCost = arrowsMade * 1.0;

        if (gameState.communalWood >= woodCost &&
            gameState.communalScrap >= scrapCost) {
          gameState.addCommunalWood(-woodCost);
          gameState.removeCommunalScrap(scrapCost);
          totalArrowsCrafted += arrowsMade;
          woodConsumed += woodCost;
          scrapConsumed += scrapCost;
          soldier.exhaustion = (soldier.exhaustion + 0.5).clamp(0, 10);
        } else {
          break;
        }
      }
    }

    if (totalArrowsCrafted > 0) {
      gameState.addCommunalArrows(totalArrowsCrafted);
      gameState.logEvent(
        "${aravt.id} fletched $totalArrowsCrafted arrows (used ${woodConsumed.toStringAsFixed(1)}kg wood, ${scrapConsumed.toStringAsFixed(0)} scrap).",
        category: EventCategory.general,
        aravtId: aravt.id,
      );
    } else {
      gameState.logEvent(
        "${aravt.id} could not fletch arrows due to lack of resources.",
        category: EventCategory.general,
        severity: EventSeverity.low,
        aravtId: aravt.id,
      );
    }
  }
}
