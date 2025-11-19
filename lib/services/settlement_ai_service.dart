// lib/services/settlement_ai_service.dart


import 'dart:math';
import 'package:aravt/models/settlement_data.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/game_event.dart';


/// This service manages the turn-based decisions for a single settlement.
class SettlementAIService {
  final Random _random = Random();


  Future<void> resolveSettlementTurn(
      Settlement settlement, GameState gameState) async {
    // 1. Determine new goal (if idle)
    if (settlement.currentGoal == SettlementGoal.Idle) {
      _determineNewGoal(settlement, gameState);
    }


    // 2. Execute the current goal
    await _executeGoal(settlement, gameState);


    // 3. Log action for omniscient mode
    gameState.logEvent(
      "[Settlement: ${settlement.name}] resolves turn. Goal: ${settlement.currentGoal.name}",
      isPlayerKnown: false,
      category: EventCategory.general,
      severity: EventSeverity.low,
    );
  }


  /// Determines what the settlement should focus on this turn.
  void _determineNewGoal(Settlement settlement, GameState gameState) {
    // Placeholder random logic for Phase 1.
    double roll = _random.nextDouble();
    if (roll < 0.20) {
      settlement.currentGoal = SettlementGoal.ProduceFood;
    } else if (roll < 0.40) {
      settlement.currentGoal = SettlementGoal.ProduceSupplies;
    } else if (roll < 0.50) {
      settlement.currentGoal = SettlementGoal.ProduceWealth;
    } else if (roll < 0.60) {
       // [GEMINI-FIX] Check against calculated max militia size
       if (settlement.militiaStrength < settlement.maxMilitia) {
           settlement.currentGoal = SettlementGoal.TrainMilitia;
       } else {
           settlement.currentGoal = SettlementGoal.Idle;
       }
    } else if (roll < 0.70) {
        settlement.currentGoal = SettlementGoal.MineIron;
    } else if (roll < 0.80) {
        settlement.currentGoal = SettlementGoal.ManageHerd;
    } else {
      settlement.currentGoal = SettlementGoal.Idle;
    }
  }


  /// Executes the logic for the settlement's chosen goal.
  Future<void> _executeGoal(Settlement settlement, GameState gameState) async {
    switch (settlement.currentGoal) {
      case SettlementGoal.ProduceFood:
        // Peasant population drives basic food production
        double produced = (settlement.peasantPopulation * 0.1) * (_random.nextDouble() * 0.5 + 0.75);
        settlement.foodStockpile += produced;
        break;


      case SettlementGoal.ProduceSupplies:
         double produced = (settlement.peasantPopulation * 0.05) * (_random.nextDouble() * 0.5 + 0.75);
         settlement.suppliesStockpile += produced;
         break;


      case SettlementGoal.ProduceWealth:
         double produced = (settlement.peasantPopulation * 0.02) * (_random.nextDouble() * 0.5 + 0.75);
         settlement.treasureWealth += produced;
         break;


      case SettlementGoal.TrainMilitia:
        // [GEMINI-FIX] Cannot set militiaStrength directly. 
        // Real implementation will need to spawn new soldiers. For now, do nothing.
        break;


      case SettlementGoal.MineIron:
        settlement.ironOreStockpile += (_random.nextInt(5) + 1);
        break;


      // --- Handle all other goals to fix non-exhaustive switch error ---
      default:
        break;
    }


    // Universal daily consumption
    double foodNeeds = (settlement.peasantPopulation * 0.1) + (settlement.militiaStrength * 0.2);
    settlement.foodStockpile = (settlement.foodStockpile - foodNeeds).clamp(0.0, double.infinity);


    // Reset to idle to pick a new goal next turn
    settlement.currentGoal = SettlementGoal.Idle;
    
    await Future.delayed(Duration.zero);
  }
}



