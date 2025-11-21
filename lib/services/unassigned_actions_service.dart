import 'dart:math';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/soldier_action.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/social_interaction_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/services/unassigned_actions_helpers/zodiac_helper.dart';
import 'package:aravt/services/unassigned_actions_helpers/social_helper.dart';
import 'package:aravt/services/unassigned_actions_helpers/proselytize_helper.dart';
import 'package:aravt/services/unassigned_actions_helpers/gossip_helper.dart';
import 'package:aravt/services/unassigned_actions_helpers/advice_helper.dart';
import 'package:aravt/services/unassigned_actions_helpers/assassination_helper.dart';

/// Service to handle all of Step 4: Unassigned Soldier Actions
/// This is the core system that drives emergent social dynamics in the horde
class UnassignedActionsService {
  final Random _random = Random();

  /// Main entry point. Resolves unassigned actions for all soldiers.
  Future<void> resolveUnassignedActions(GameState gameState) async {
    print("Step 4: Resolving unassigned soldier actions...");

    List<Soldier> allSoldiers = gameState.horde;
    List<Soldier> soldiersToProcess = List.from(allSoldiers);
    List<Soldier> processedSoldiers = [];

    // --- Resolve plot-driven actions first (sorted by priority) ---
    List<Soldier> plotDrivenSoldiers = soldiersToProcess
        .where((s) => s.plotDrivenActionPriority != null)
        .toList();
    plotDrivenSoldiers.sort((a, b) =>
        a.plotDrivenActionPriority!.compareTo(b.plotDrivenActionPriority!));

    for (Soldier soldier in plotDrivenSoldiers) {
      if (processedSoldiers.contains(soldier)) continue;

      // Plot-driven actions would be handled here
      // For now, just mark as processed
      processedSoldiers.add(soldier);
    }

    // --- Process remaining soldiers in random order ---
    soldiersToProcess.shuffle(_random);

    for (Soldier soldier in soldiersToProcess) {
      if (processedSoldiers.contains(soldier)) {
        continue; // Soldier was involved in another action
      }

      // 1. Generate the "event chart" for this soldier
      List<SoldierActionProposal> actionTable =
          _generateActionTable(soldier, gameState);

      // 2. Select and execute one action from the chart
      SoldierActionProposal chosenAction = _selectAction(actionTable);

      // 3. Execute the action
      await _executeAction(chosenAction, gameState, processedSoldiers);

      processedSoldiers.add(soldier);
    }
  }

  /// 1. Generates the weighted "event chart" for a single soldier
  List<SoldierActionProposal> _generateActionTable(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> table = [];

    // --- Hostile Actions (Fight, Murder) ---
    table.addAll(_generateHostileActions(soldier, gameState));

    // --- Social Interactions ---
    table.addAll(_generateSocialActions(soldier, gameState));

    // --- Zodiac Interactions ---
    table.addAll(_generateZodiacActions(soldier, gameState));

    // --- Proselytize ---
    table.addAll(_generateProselytizeActions(soldier, gameState));

    // --- Gossip ---
    table.addAll(_generateGossipActions(soldier, gameState));

    // --- Give Advice ---
    table.addAll(_generateAdviceActions(soldier, gameState));

    // --- Trait-Based Actions ---
    table.addAll(_generateTraitActions(soldier, gameState));

    // --- Gifting ---
    table.addAll(_generateGiftingActions(soldier, gameState));

    // --- Divulge Info (Default for player's aravt/captains) ---
    table.addAll(_generateDivulgeInfoActions(soldier, gameState));

    // Add a default "Idle" action with baseline probability
    table.add(SoldierActionProposal(
        actionType: UnassignedActionType.idle,
        soldier: soldier,
        probability: 5.0)); // Higher weight for idle

    return table;
  }

  /// 2. Selects one action based on weighted probabilities
  SoldierActionProposal _selectAction(List<SoldierActionProposal> actionTable) {
    if (actionTable.isEmpty) {
      throw Exception("Action table was empty.");
    }

    double totalWeight =
        actionTable.fold(0.0, (prev, e) => prev + e.probability);
    double roll = _random.nextDouble() * totalWeight;

    double cumulativeWeight = 0.0;
    for (var proposal in actionTable) {
      cumulativeWeight += proposal.probability;
      if (roll <= cumulativeWeight) {
        return proposal;
      }
    }
    return actionTable.last; // Fallback
  }

  /// 3. Executes the chosen action
  Future<void> _executeAction(SoldierActionProposal action, GameState gameState,
      List<Soldier> processedSoldiers) async {
    // Mark target as processed if this is a multi-soldier action
    if (action.targetSoldierId != null) {
      final targetSoldier = gameState.findSoldierById(action.targetSoldierId!);
      if (targetSoldier != null && !processedSoldiers.contains(targetSoldier)) {
        processedSoldiers.add(targetSoldier);
      }
    }

    // Execute based on action type
    switch (action.actionType) {
      case UnassignedActionType.socialInteraction:
        _executeSocialInteraction(action, gameState);
        break;
      case UnassignedActionType.zodiacInteraction:
        _executeZodiacInteraction(action, gameState);
        break;
      case UnassignedActionType.proselytize:
        _executeProselytize(action, gameState);
        break;
      case UnassignedActionType.gossip:
        _executeGossip(action, gameState);
        break;
      case UnassignedActionType.giveAdvice:
        _executeAdvice(action, gameState);
        break;
      case UnassignedActionType.giftItem:
        _executeGift(action, gameState);
        break;
      case UnassignedActionType.divulgeInfoToPlayer:
        _executeDivulgeInfo(action, gameState);
        break;
      case UnassignedActionType.tendHorses:
        _executeTendHorses(action, gameState);
        break;
      case UnassignedActionType.playGame:
        _executePlayGame(action, gameState);
        break;
      case UnassignedActionType.murderAttempt:
        await _executeMurderAttempt(action, gameState);
        break;
      case UnassignedActionType.idle:
      default:
        // Do nothing
        break;
    }
  }

  // --- ACTION GENERATION METHODS ---

  List<SoldierActionProposal> _generateHostileActions(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> actions = [];

    // Check all relationships for low admiration
    for (var entry in soldier.hordeRelationships.entries) {
      if (entry.value.admiration <= 1.0) {
        Soldier? target = gameState.findSoldierById(entry.key);
        if (target == null) continue;

        // Calculate hostility probability (increases as admiration approaches 0)
        double hostilityProb =
            (1.0 - entry.value.admiration) * 0.05; // Up to 5%

        // Check if murder attempts are allowed
        bool canMurderPlayer = _canAttemptMurderOnPlayer(target, gameState);

        if (target.isPlayer && !canMurderPlayer) {
          // Can only fight player, not murder (yet)
          actions.add(SoldierActionProposal(
            actionType: UnassignedActionType.startFight,
            soldier: soldier,
            probability: hostilityProb,
            targetSoldierId: target.id,
          ));
        } else {
          // Can attempt murder (higher probability for lower admiration)
          double murderProb =
              hostilityProb * (entry.value.admiration < 0.5 ? 2.0 : 1.0);

          actions.add(SoldierActionProposal(
            actionType: UnassignedActionType.murderAttempt,
            soldier: soldier,
            probability: murderProb,
            targetSoldierId: target.id,
          ));
        }
      }
    }

    // [GEMINI-FIX] Murderer Attribute Logic
    // Murderers have a compulsion to kill, regardless of relationships.
    if (soldier.attributes.contains(SoldierAttribute.murderer)) {
      // Pick a random target from the horde
      final potentialVictims = gameState.horde
          .where((s) => s.id != soldier.id && s.status == SoldierStatus.alive)
          .toList();

      if (potentialVictims.isNotEmpty) {
        final target =
            potentialVictims[_random.nextInt(potentialVictims.length)];

        // Base probability for a "thrill kill"
        double murderProb = 0.15;

        // If target is player, check if allowed
        if (target.isPlayer) {
          if (_canAttemptMurderOnPlayer(target, gameState)) {
            actions.add(SoldierActionProposal(
              actionType: UnassignedActionType.murderAttempt,
              soldier: soldier,
              probability: murderProb,
              targetSoldierId: target.id,
            ));
          }
        } else {
          actions.add(SoldierActionProposal(
            actionType: UnassignedActionType.murderAttempt,
            soldier: soldier,
            probability: murderProb,
            targetSoldierId: target.id,
          ));
        }
      }
    }

    return actions;
  }

  bool _canAttemptMurderOnPlayer(Soldier target, GameState gameState) {
    if (!target.isPlayer) return true; // Can always murder non-players

    int turnThreshold;
    switch (gameState.difficulty) {
      case 'easy':
        turnThreshold = 21; // May 12
        break;
      case 'hard':
        turnThreshold = 14; // May 5
        break;
      default: // medium
        turnThreshold = 17; // May 8
    }

    return gameState.turn.turnNumber >= turnThreshold;
  }

  List<SoldierActionProposal> _generateSocialActions(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> actions = [];

    // Get potential targets (aravt mates and random horde members)
    List<Soldier> aravtMates = gameState.horde
        .where((s) => s.aravt == soldier.aravt && s.id != soldier.id)
        .toList();
    List<Soldier> otherSoldiers = gameState.horde
        .where((s) => s.aravt != soldier.aravt && s.id != soldier.id)
        .toList();

    // Aravt mate interactions (2% base)
    for (var mate in aravtMates) {
      double prob = SocialHelper.getSocialInteractionProbability(
          soldier, mate, gameState);
      actions.add(SoldierActionProposal(
        actionType: UnassignedActionType.socialInteraction,
        soldier: soldier,
        probability: prob,
        targetSoldierId: mate.id,
      ));
    }

    // Random horde member interactions (1% base)
    if (otherSoldiers.isNotEmpty) {
      Soldier randomTarget =
          otherSoldiers[_random.nextInt(otherSoldiers.length)];
      double prob = SocialHelper.getSocialInteractionProbability(
          soldier, randomTarget, gameState);
      actions.add(SoldierActionProposal(
        actionType: UnassignedActionType.socialInteraction,
        soldier: soldier,
        probability: prob,
        targetSoldierId: randomTarget.id,
      ));
    }

    return actions;
  }

  List<SoldierActionProposal> _generateZodiacActions(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> actions = [];

    // Check for zodiac-based interactions with all horde members
    for (var other in gameState.horde) {
      if (other.id == soldier.id) continue;

      if (ZodiacHelper.shouldZodiacInteractionOccur(
          soldier.zodiac, other.zodiac, _random.nextDouble())) {
        actions.add(SoldierActionProposal(
          actionType: UnassignedActionType.zodiacInteraction,
          soldier: soldier,
          probability: 0.01, // 1% baseline
          targetSoldierId: other.id,
        ));
      }
    }

    return actions;
  }

  List<SoldierActionProposal> _generateProselytizeActions(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> actions = [];

    double baseProb = ProselytizeHelper.getProselytizeProbability(soldier);
    if (baseProb == 0.0) return actions;

    // Select random targets from horde
    List<Soldier> potentialTargets =
        gameState.horde.where((s) => s.id != soldier.id).toList();

    if (potentialTargets.isNotEmpty) {
      // Try to convert 1-2 random people
      int targetCount = _random.nextInt(2) + 1;
      potentialTargets.shuffle(_random);

      for (int i = 0; i < targetCount && i < potentialTargets.length; i++) {
        actions.add(SoldierActionProposal(
          actionType: UnassignedActionType.proselytize,
          soldier: soldier,
          probability: baseProb,
          targetSoldierId: potentialTargets[i].id,
        ));
      }
    }

    return actions;
  }

  List<SoldierActionProposal> _generateGossipActions(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> actions = [];

    double baseProb = GossipHelper.getGossipProbability(soldier);

    // Gossip with aravt mates or random horde members
    List<Soldier> potentialTargets =
        gameState.horde.where((s) => s.id != soldier.id).toList();

    if (potentialTargets.isNotEmpty && soldier.knownInformation.isNotEmpty) {
      potentialTargets.shuffle(_random);
      Soldier target = potentialTargets.first;

      actions.add(SoldierActionProposal(
        actionType: UnassignedActionType.gossip,
        soldier: soldier,
        probability: baseProb,
        targetSoldierId: target.id,
      ));
    }

    return actions;
  }

  List<SoldierActionProposal> _generateAdviceActions(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> actions = [];

    double baseProb = AdviceHelper.getAdviceProbability(soldier);

    // Give advice to aravt mates or those with good relationships
    List<Soldier> potentialTargets =
        gameState.horde.where((s) => s.id != soldier.id).toList();

    if (potentialTargets.isNotEmpty) {
      potentialTargets.shuffle(_random);
      Soldier target = potentialTargets.first;

      actions.add(SoldierActionProposal(
        actionType: UnassignedActionType.giveAdvice,
        soldier: soldier,
        probability: baseProb,
        targetSoldierId: target.id,
      ));
    }

    return actions;
  }

  List<SoldierActionProposal> _generateTraitActions(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> actions = [];

    // Horse tending (all soldiers)
    double horseTendProb = 0.1 + (soldier.animalHandling / 100.0);
    actions.add(SoldierActionProposal(
      actionType: UnassignedActionType.tendHorses,
      soldier: soldier,
      probability: horseTendProb,
    ));

    // Game playing (based on skills)
    double gameProb =
        0.05 + (soldier.intelligence / 200.0) + (soldier.courage / 200.0);
    actions.add(SoldierActionProposal(
      actionType: UnassignedActionType.playGame,
      soldier: soldier,
      probability: gameProb,
    ));

    return actions;
  }

  List<SoldierActionProposal> _generateGiftingActions(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> actions = [];

    // Check for birthdays or high admiration targets
    for (var other in gameState.horde) {
      if (other.id == soldier.id) continue;

      bool isBirthday = (other.dateOfBirth.month == gameState.gameDate.month &&
          other.dateOfBirth.day == gameState.gameDate.day);

      final rel = soldier.getRelationship(other.id);

      if (isBirthday || rel.admiration >= 4.0) {
        double giftProb = isBirthday ? 0.3 : (rel.admiration - 3.0) * 0.05;

        // Only gift if soldier has items
        if (soldier.personalInventory.isNotEmpty) {
          actions.add(SoldierActionProposal(
            actionType: UnassignedActionType.giftItem,
            soldier: soldier,
            probability: giftProb,
            targetSoldierId: other.id,
          ));
        }
      }
    }

    return actions;
  }

  List<SoldierActionProposal> _generateDivulgeInfoActions(
      Soldier soldier, GameState gameState) {
    List<SoldierActionProposal> actions = [];

    // Only for player's aravt members or captains
    bool isInPlayerAravt =
        gameState.player != null && soldier.aravt == gameState.player!.aravt;
    bool isCaptain = soldier.role == SoldierRole.aravtCaptain;

    if (!isInPlayerAravt && !isCaptain) return actions;

    // Calculate probability based on horde size
    int hordeSize = gameState.horde.length;
    double baseProb = 0.6; // 60% at start

    if (hordeSize >= 400) {
      baseProb = 0.05; // 5% for large hordes
    } else if (hordeSize >= 200) {
      baseProb = 0.2; // 20% for medium hordes
    } else if (hordeSize >= 100) {
      baseProb = 0.4; // 40% for growing hordes
    }

    actions.add(SoldierActionProposal(
      actionType: UnassignedActionType.divulgeInfoToPlayer,
      soldier: soldier,
      probability: baseProb,
    ));

    return actions;
  }

  // --- ACTION EXECUTION METHODS ---

  void _executeSocialInteraction(
      SoldierActionProposal action, GameState gameState) {
    if (action.targetSoldierId == null) return;

    Soldier? target = gameState.findSoldierById(action.targetSoldierId!);
    if (target == null) return;

    SocialInteractionType type =
        SocialHelper.selectInteractionType(action.soldier, target, gameState);

    SocialHelper.executeSocialInteraction(
        action.soldier, target, type, gameState);

    String description = SocialHelper.generateInteractionDescription(
        action.soldier, target, type);

    gameState.logEvent(description,
        category: EventCategory.general, severity: EventSeverity.low);
  }

  void _executeZodiacInteraction(
      SoldierActionProposal action, GameState gameState) {
    if (action.targetSoldierId == null) return;

    Soldier? target = gameState.findSoldierById(action.targetSoldierId!);
    if (target == null) return;

    bool isPositive = ZodiacHelper.isZodiacInteractionPositive(
        action.soldier, target, _random.nextDouble());

    final rel = target.getRelationship(action.soldier.id);
    double modifier = ZodiacHelper.getCompatibilityModifier(
        action.soldier.zodiac, target.zodiac);

    if (isPositive) {
      rel.updateAdmiration(0.1 * modifier);
      rel.updateRespect(0.05 * modifier);
      gameState.logEvent(
          "${action.soldier.name} and ${target.name} bonded over their zodiac compatibility.",
          category: EventCategory.general,
          severity: EventSeverity.low);
    } else {
      rel.updateAdmiration(-0.1 * modifier);
      gameState.logEvent(
          "${action.soldier.name} and ${target.name} clashed due to zodiac incompatibility.",
          category: EventCategory.general,
          severity: EventSeverity.low);
    }
  }

  void _executeProselytize(SoldierActionProposal action, GameState gameState) {
    if (action.targetSoldierId == null) return;

    Soldier? target = gameState.findSoldierById(action.targetSoldierId!);
    if (target == null) return;

    Map<String, dynamic> result = ProselytizeHelper.executeProselytization(
        action.soldier, target, gameState);

    String description = ProselytizeHelper.generateProselytizationDescription(
        action.soldier, target, result);

    gameState.logEvent(description,
        category: EventCategory.general,
        severity: result['success'] ? EventSeverity.high : EventSeverity.low);
  }

  void _executeGossip(SoldierActionProposal action, GameState gameState) {
    if (action.targetSoldierId == null) return;

    Soldier? target = gameState.findSoldierById(action.targetSoldierId!);
    if (target == null) return;

    Map<String, InformationPiece?> result =
        GossipHelper.executeGossip(action.soldier, target, gameState);

    String description =
        GossipHelper.generateGossipDescription(action.soldier, target, result);

    if (result['shared'] != null) {
      gameState.logEvent(description,
          category: EventCategory.general, severity: EventSeverity.low);
    }
  }

  void _executeAdvice(SoldierActionProposal action, GameState gameState) {
    if (action.targetSoldierId == null) return;

    Soldier? target = gameState.findSoldierById(action.targetSoldierId!);
    if (target == null) return;

    Map<String, dynamic> result =
        AdviceHelper.executeAdvice(action.soldier, target, gameState);

    String description =
        AdviceHelper.generateAdviceDescription(action.soldier, target, result);

    gameState.logEvent(description,
        category: EventCategory.general,
        severity:
            result['gain'] != null ? EventSeverity.high : EventSeverity.low);
  }

  void _executeGift(SoldierActionProposal action, GameState gameState) {
    if (action.targetSoldierId == null) return;

    Soldier? target = gameState.findSoldierById(action.targetSoldierId!);
    if (target == null || action.soldier.personalInventory.isEmpty) return;

    // Select a random item to gift
    var item = action.soldier.personalInventory[
        _random.nextInt(action.soldier.personalInventory.length)];

    // Remove from giver, add to receiver
    action.soldier.personalInventory.remove(item);
    target.personalInventory.add(item);

    // Relationship boost
    final rel = target.getRelationship(action.soldier.id);
    rel.updateAdmiration(0.2);
    rel.updateRespect(0.1);

    gameState.logEvent(
        "${action.soldier.name} gave ${item.name} to ${target.name} as a gift.",
        category: EventCategory.general,
        severity: EventSeverity.low);
  }

  void _executeDivulgeInfo(SoldierActionProposal action, GameState gameState) {
    // Generate random information for the player
    String info = _generateRandomInformation(action.soldier, gameState);

    gameState.logEvent("${action.soldier.name} told you: $info",
        category: EventCategory.general, severity: EventSeverity.low);
  }

  void _executeTendHorses(SoldierActionProposal action, GameState gameState) {
    // Placeholder - could affect horse health/morale in future
    // For now, just a minor event
    if (_random.nextDouble() < 0.1) {
      // 10% chance to log
      gameState.logEvent(
          "${action.soldier.name} spent time tending to the horses.",
          category: EventCategory.general,
          severity: EventSeverity.low);
    }
  }

  void _executePlayGame(SoldierActionProposal action, GameState gameState) {
    // Placeholder - could trigger mini-tournaments in future
    if (_random.nextDouble() < 0.1) {
      // 10% chance to log
      gameState.logEvent(
          "${action.soldier.name} organized a pickup game with some soldiers.",
          category: EventCategory.games,
          severity: EventSeverity.low);
    }
  }

  String _generateRandomInformation(Soldier soldier, GameState gameState) {
    List<String> infoTemplates = [
      "The weather is changing.",
      "I heard rumors of bandits to the east.",
      "The horses seem restless today.",
      "Some of the men are getting tired of rice.",
      "I think we should scout ahead before moving.",
    ];

    return infoTemplates[_random.nextInt(infoTemplates.length)];
  }

  /// Execute murder attempt
  Future<void> _executeMurderAttempt(
      SoldierActionProposal action, GameState gameState) async {
    final assassin = action.soldier;
    final target = gameState.findSoldierById(action.targetSoldierId!);

    if (target == null) return;

    // Select assassination type
    final type = AssassinationHelper.selectAssassinationType(
        assassin, target, gameState);

    // Execute assassination
    final result = AssassinationHelper.executeAssassination(
        assassin, target, type, gameState);

    // Handle result
    if (result.success) {
      // Target dies
      if (target.isPlayer) {
        // PLAYER DEATH - GAME OVER
        gameState.logEvent(
          result.description,
          category: EventCategory.combat,
          severity: EventSeverity.critical,
          soldierId: target.id,
        );

        // Trigger game over
        gameState.triggerGameOver(
          "You were assassinated by ${assassin.name}",
        );
      } else {
        // NPC death
        gameState.logEvent(
          result.description,
          category: EventCategory.combat,
          severity: EventSeverity.critical,
          soldierId: target.id,
        );

        // Remove target from horde
        gameState.executeSoldier(target);
      }
    } else {
      // Assassination failed
      if (result.discovered) {
        // Assassin was discovered
        gameState.logEvent(
          result.description,
          category: EventCategory.combat,
          severity: EventSeverity.critical,
          soldierId: target.id,
        );

        // Severe consequences for assassin
        if (target.isPlayer) {
          // Player can execute the assassin
          gameState.logEvent(
            "${assassin.name} has been caught attempting to assassinate you! You may execute them.",
            category: EventCategory.system,
            severity: EventSeverity.critical,
            soldierId: assassin.id,
          );
        } else {
          // Target may execute or exile assassin
          if (_random.nextDouble() < 0.7) {
            gameState.logEvent(
              "${target.name} executed ${assassin.name} for the assassination attempt.",
              category: EventCategory.combat,
              severity: EventSeverity.high,
              soldierId: assassin.id,
            );
            gameState.executeSoldier(assassin);
          }
        }
      } else {
        // Failed but not discovered
        if (gameState.isOmniscientMode) {
          gameState.logEvent(
            result.description,
            category: EventCategory.combat,
            severity: EventSeverity.high,
            soldierId: target.id,
            isPlayerKnown: false,
          );
        }

        // Target may be injured
        if (result.injuryDamage != null) {
          target.bodyHealthCurrent =
              (target.bodyHealthCurrent - result.injuryDamage!).clamp(0, 100);
        }
      }
    }

    // Handle confrontation special case (one dies)
    if (result.type == AssassinationType.confront && !result.success) {
      // Assassin lost the confrontation and died
      gameState.logEvent(
        "${target.name} killed ${assassin.name} in self-defense.",
        category: EventCategory.combat,
        severity: EventSeverity.critical,
        soldierId: assassin.id,
      );
      gameState.executeSoldier(assassin);
    }
  }
}
