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

import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/interaction_models.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/providers/game_state.dart';
// For AravtDuty enum
import 'package:aravt/services/dialogue_helpers.dart';
import 'package:aravt/models/justification_event.dart';
import 'package:aravt/services/loyalty_service.dart';

enum _InteractionTier { extraSuccess, success, lessSuccessful, unsuccessful }

class InteractionService {
  static final Random _random = Random();

  /// Resolves the INQUIRE interaction using dynamic dialogue generation.
  static InteractionResult resolveInquire(
      GameState gameState, Soldier player, Soldier target) {
    String dialogue = "";
    bool success = true;

    // Special Case: Horde Leader is harder to talk to
    if (target.role == SoldierRole.hordeLeader) {
      if (target.getRelationship(player.id).respect < 2.5) {
        dialogue = "'You are not in a position to ask questions, Captain.'";
        // Subtle shift for pestering the Khan
        target.getRelationship(player.id).updateRespect(-0.05);
        success = false;
      } else {
        // Simple non-repeating mechanic for leader for now
        if (!target.usedDialogueTopics.contains('leader_intro')) {
          target.usedDialogueTopics.add('leader_intro');
          dialogue =
              "'I am concerned about the Merkit raids to the east. A captain who solved that problem would earn my favor.'";
        } else {
          dialogue = "'Bring me results, Captain, not questions.'";
        }
      }
    } else {
      // Standard soldier: Use the deep dialogue engine
      dialogue = _generateUniqueDialogue(target, gameState);
    }

    final log = InteractionLogEntry(
      dateString: gameState.gameDate.toShortString(),
      type: InteractionType.inquire,

      interactionSummary: dialogue,
      outcomeSummary: "",
      informationRevealed: "",
    );

    target.interactionLog.add(log);
    return InteractionResult(
      success: success,
      outcomeSummary: "",
      statChangeSummary: "",
      informationRevealed: dialogue,
      logEntry: log,
    );
  }

  /// Resolves the SCOLD interaction with 4 tiers of success.
  static InteractionResult resolveScold(
      GameState gameState, Soldier player, Soldier target) {
    final int currentTurn = gameState.turn.turnNumber;
    final rel = target.getRelationship(player.id);

    // 1. Calculate Justification
    double justification = 0.0;
    JustificationEvent? usedEvent;

    // Check pending justifications first
    final scoldEvents = target.pendingJustifications
        .where((j) =>
            (j.type == JustificationType.scold ||
                j.type == JustificationType.any) &&
            j.expiryTurn >= currentTurn)
        .toList();

    if (scoldEvents.isNotEmpty) {
      usedEvent = scoldEvents.first;
      justification = usedEvent.magnitude;
    } else {
      // Fallback to performance log
      final poorPerformance = target.performanceLog
          .where((e) => !e.isPositive && (currentTurn - e.turnNumber) <= 2)
          .toList();
      justification =
          poorPerformance.fold(0.0, (prev, e) => prev + e.magnitude);
    }

    // 2. Base Chance
    double baseChance = 0.40;
    if (justification > 0) {
      baseChance += (justification * 0.15).clamp(0, 0.5);
    } else {
      baseChance -= 0.2;
    }

    baseChance += (target.patience * 0.01) + (target.knowledge * 0.01);
    if (target.age > player.age) baseChance -= 0.15;
    if (target.role == SoldierRole.hordeLeader) baseChance -= 0.5;

    // 3. Determine Tier & Apply Effects
    _InteractionTier tier = _determineTier(baseChance);
    final List<Soldier> socialCircle = _getSocialCircle(target, gameState);
    String statChanges = "";
    String infoRevealed = "";
    String outcomeSummary = "";

    switch (tier) {
      case _InteractionTier.extraSuccess:
        outcomeSummary = "They were deeply shamed and contrite.";
        double fearGain = 0.3 + (justification * 0.1).clamp(0.0, 0.3);
        double respectGain = 0.2 + (justification * 0.05).clamp(0.0, 0.2);
        rel.updateFear(fearGain);
        rel.updateRespect(respectGain);
        rel.updateFear(fearGain);
        rel.updateRespect(respectGain);
        LoyaltyService.updateLoyalty(target, player.id, 0.1);
        if (usedEvent != null) {
          target.pendingJustifications.remove(usedEvent);
        }
        if (gameState.isOmniscientMode) {
          statChanges =
              "${target.name} gains ${fearGain.toStringAsFixed(2)} Fear, ${respectGain.toStringAsFixed(2)} Respect.";
        }
        _applySocialEffect(socialCircle, player.id,
            respect: 0.05, admiration: 0.02, fear: 0.05);
        if (_random.nextDouble() < 0.7) {

          String dialogue = _generateDialogue(target, gameState);
          infoRevealed = dialogue.isNotEmpty
              ? '"$dialogue"'
              : '"${_generateSelfCriticism(target, gameState)}"';
        }

      case _InteractionTier.success:
        outcomeSummary = "They accepted the rebuke.";
        double fearGain = 0.15 + (justification * 0.05).clamp(0.0, 0.15);
        rel.updateFear(fearGain);
        rel.updateFear(fearGain);
        rel.updateRespect(0.1);
        if (usedEvent != null) {
          target.pendingJustifications.remove(usedEvent);
        }
        if (gameState.isOmniscientMode) {
          statChanges =
              "${target.name} gains ${fearGain.toStringAsFixed(2)} Fear, 0.1 Respect.";
        }
        _applySocialEffect(socialCircle, player.id, respect: 0.02, fear: 0.02);
        if (_random.nextDouble() < 0.4) {

          String dialogue = _generateDialogue(target, gameState);
          infoRevealed = dialogue.isNotEmpty
              ? '"$dialogue"'
              : '"${_generateSelfCriticism(target, gameState)}"';
        }

      case _InteractionTier.lessSuccessful:
        outcomeSummary = "They listened, but seemed resentful.";
        rel.updateAdmiration(-0.1);
        rel.updateAdmiration(-0.1);
        LoyaltyService.updateLoyalty(target, player.id, -0.05);
        rel.updateFear(0.05);
        rel.updateFear(0.05);
        if (gameState.isOmniscientMode) {
          statChanges =
              "${target.name} loses 0.1 Admiration, 0.05 Loyalty. Gains 0.05 Fear.";
        }
        if (_random.nextDouble() < 0.3) {
          infoRevealed = '"${_generateOtherCriticism(target, gameState)}"';
        }

      case _InteractionTier.unsuccessful:
        outcomeSummary = "They rejected your authority!";
        rel.updateAdmiration(-0.3);
        rel.updateAdmiration(-0.3);
        LoyaltyService.updateLoyalty(target, player.id, -0.2);
        rel.updateRespect(-0.2);
        rel.updateRespect(-0.2);
        if (gameState.isOmniscientMode) {
          statChanges =
              "${target.name} loses 0.3 Admiration, 0.2 Loyalty, 0.2 Respect.";
        }
        _applySocialEffect(socialCircle, player.id,
            respect: -0.05, admiration: -0.05);
        if (_random.nextDouble() < 0.6) {
          infoRevealed = '"${_generateOtherCriticism(target, gameState)}"';
        }
    }

    final log = InteractionLogEntry(
      dateString: gameState.gameDate.toShortString(),
      type: InteractionType.scold,
      interactionSummary: "You scolded ${target.name}.",
      outcomeSummary: outcomeSummary,
      informationRevealed: infoRevealed,
    );

    target.interactionLog.add(log);
    return InteractionResult(
      success: tier == _InteractionTier.success ||
          tier == _InteractionTier.extraSuccess,
      outcomeSummary: log.outcomeSummary,
      statChangeSummary: statChanges,
      informationRevealed: infoRevealed,
      logEntry: log,
    );
  }

  /// Resolves the PRAISE interaction with 4 tiers of success.
  static InteractionResult resolvePraise(
      GameState gameState, Soldier player, Soldier target) {
    final int currentTurn = gameState.turn.turnNumber;
    final rel = target.getRelationship(player.id);

    // 1. Calculate Justification
    double justification = 0.0;
    JustificationEvent? usedEvent;

    // Check pending justifications first
    final praiseEvents = target.pendingJustifications
        .where((j) =>
            (j.type == JustificationType.praise ||
                j.type == JustificationType.any) &&
            j.expiryTurn >= currentTurn)
        .toList();

    if (praiseEvents.isNotEmpty) {
      usedEvent = praiseEvents.first;
      justification = usedEvent.magnitude;
    } else {
      // Fallback to performance log
      final goodPerformance = target.performanceLog
          .where((e) => e.isPositive && (currentTurn - e.turnNumber) <= 2)
          .toList();
      justification =
          goodPerformance.fold(0.0, (prev, e) => prev + e.magnitude);
    }

    // 2. Base Chance
    double baseChance = 0.50;
    if (justification > 0) {
      baseChance += (justification * 0.15).clamp(0, 0.45);
    } else {
      baseChance -= 0.3;
    }

    baseChance += (target.ambition * 0.015) + (target.courage * 0.01);
    if (rel.admiration < 2.0) baseChance -= 0.1;
    if (target.role == SoldierRole.hordeLeader) baseChance -= 0.2;

    // 3. Determine Tier & Apply Effects
    _InteractionTier tier = _determineTier(baseChance);
    final List<Soldier> socialCircle = _getSocialCircle(target, gameState);
    String statChanges = "";
    String infoRevealed = "";
    String outcomeSummary = "";

    switch (tier) {
      case _InteractionTier.extraSuccess:
        outcomeSummary = "They beamed with pride and shared the credit.";
        double admGain = 0.3 + (justification * 0.1).clamp(0.0, 0.3);
        double loyGain = 0.2 + (target.ambition * 0.02);
        rel.updateAdmiration(admGain);
        rel.updateAdmiration(admGain);
        LoyaltyService.updateLoyalty(target, player.id, loyGain);
        rel.updateRespect(0.1);
        if (usedEvent != null) {
          target.pendingJustifications.remove(usedEvent);
        }
        rel.updateRespect(0.1);
        if (gameState.isOmniscientMode) {
          statChanges =
              "${target.name} gains ${admGain.toStringAsFixed(2)} Admiration, ${loyGain.toStringAsFixed(2)} Loyalty, 0.1 Respect.";
        }
        _applySocialEffect(socialCircle, player.id,
            respect: 0.05, admiration: 0.1, loyalty: 0.02);
        if (_random.nextDouble() < 0.7) {

          String dialogue = _generateDialogue(target, gameState);
          infoRevealed = dialogue.isNotEmpty
              ? '"$dialogue"'
              : '"${_generateOtherPraise(target, gameState)}"';
        }

      case _InteractionTier.success:
        outcomeSummary = "They were encouraged.";
        double admGain = 0.15 + (justification * 0.05).clamp(0.0, 0.15);
        rel.updateAdmiration(admGain);
        rel.updateAdmiration(admGain);
        LoyaltyService.updateLoyalty(target, player.id, 0.1);
        if (usedEvent != null) {
          target.pendingJustifications.remove(usedEvent);
        }
        if (gameState.isOmniscientMode) {
          statChanges =
              "${target.name} gains ${admGain.toStringAsFixed(2)} Admiration, 0.1 Loyalty.";
        }
        _applySocialEffect(socialCircle, player.id,
            respect: 0.02, admiration: 0.05);
        if (_random.nextDouble() < 0.4) {

          String dialogue = _generateDialogue(target, gameState);
          infoRevealed = dialogue.isNotEmpty
              ? '"$dialogue"'
              : '"${_generateOtherPraise(target, gameState)}"';
        }

      case _InteractionTier.lessSuccessful:
        outcomeSummary = "They accepted it awkwardly.";
        rel.updateRespect(-0.05);
        if (gameState.isOmniscientMode) {
          statChanges = "${target.name} loses 0.05 Respect.";
        }
        if (_random.nextDouble() < 0.3) {
          infoRevealed = '"${_generateSelfPraise(target, gameState)}"';
        }

      case _InteractionTier.unsuccessful:
        outcomeSummary = "They saw through the empty flattery.";
        rel.updateRespect(-0.2);
        rel.updateAdmiration(-0.1);
        if (gameState.isOmniscientMode) {
          statChanges = "${target.name} loses 0.2 Respect, 0.1 Admiration.";
        }
        _applySocialEffect(socialCircle, player.id, respect: -0.05);
        if (_random.nextDouble() < 0.6) {
          infoRevealed = '"${_generateSelfPraise(target, gameState)}"';
        }
    }

    final log = InteractionLogEntry(
      dateString: gameState.gameDate.toShortString(),
      type: InteractionType.praise,
      interactionSummary: "You praised ${target.name}.",
      outcomeSummary: outcomeSummary,
      informationRevealed: infoRevealed,
    );

    target.interactionLog.add(log);
    return InteractionResult(
      success: tier == _InteractionTier.success ||
          tier == _InteractionTier.extraSuccess,
      outcomeSummary: log.outcomeSummary,
      statChangeSummary: statChanges,
      informationRevealed: infoRevealed,
      logEntry: log,
    );
  }

  static InteractionResult resolveListen(
      GameState gameState, Soldier player, Soldier target) {
    final queuedItem = target.queuedListenItem;

    if (queuedItem == null) {
      final log = InteractionLogEntry(
        dateString: gameState.gameDate.toShortString(),
        type: InteractionType.listen,
        interactionSummary: "You offered to listen to ${target.name}.",
        outcomeSummary: "They had nothing to say.",
        informationRevealed: "'...'",
      );
      target.interactionLog.add(log);
      return InteractionResult(
        success: false,
        outcomeSummary: log.outcomeSummary,
        statChangeSummary: "",
        informationRevealed: "'...'",
        logEntry: log,
      );
    }

    String infoRevealed = "'${queuedItem.message}'";
    String outcomeSummary = "You listened to what they had to say.";
    String statChanges = '';

    if (target.role == SoldierRole.hordeLeader) {
      target.getRelationship(player.id).updateAdmiration(0.1);
      target.getRelationship(player.id).updateRespect(0.1);
      if (gameState.isOmniscientMode) {
        statChanges = "The Khan gains 0.1 Admiration and 0.1 Respect.";
      }
    }

    target.queuedListenItem = null;

    final log = InteractionLogEntry(
      dateString: gameState.gameDate.toShortString(),
      type: InteractionType.listen,
      interactionSummary: "You listened to ${target.name}.",
      outcomeSummary: outcomeSummary,
      informationRevealed: infoRevealed,
    );

    target.interactionLog.add(log);
    return InteractionResult(
      success: true,
      outcomeSummary: log.outcomeSummary,
      statChangeSummary: statChanges,
      informationRevealed: infoRevealed,
      logEntry: log,
    );
  }

  /// Resolves the GIFT interaction with relationship impacts based on appropriateness and preferences.
  static InteractionResult resolveGift(
      GameState gameState, Soldier player, Soldier target, InventoryItem gift) {
    final int currentTurn = gameState.turn.turnNumber;
    final rel = target.getRelationship(player.id);

    // 1. Check if it's the recipient's birthday
    final currentDate = gameState.gameDate;
    final isBirthday = (target.dateOfBirth.month == currentDate.month &&
        target.dateOfBirth.day == currentDate.day);

    // 2. Check if gift is appropriate
    double justification = 0.0;
    JustificationEvent? usedEvent;

    // Check pending justifications first
    final giftEvents = target.pendingJustifications
        .where((j) =>
            (j.type == JustificationType.gift ||
                j.type == JustificationType.any) &&
            j.expiryTurn >= currentTurn)
        .toList();

    if (giftEvents.isNotEmpty) {
      usedEvent = giftEvents.first;
      justification = usedEvent.magnitude;
    } else {
      // Fallback to performance log
      final goodPerformance = target.performanceLog
          .where((e) => e.isPositive && (currentTurn - e.turnNumber) <= 2)
          .toList();
      justification =
          goodPerformance.fold(0.0, (prev, e) => prev + e.magnitude);
    }

    final bool isAppropriate = (justification > 0) || isBirthday;

    // 3. Calculate base relationship impact from gift value
    double baseAdmirationGain = (gift.baseValue * 0.01).clamp(0.1, 0.5);
    double baseRespectGain = (gift.baseValue * 0.005).clamp(0.05, 0.3);

    // 4. Check gift type preference match
    double typeMultiplier = 1.0;
    bool matchesTypePreference =
        _checkGiftTypeMatch(gift.itemType, target.giftTypePreference);
    if (matchesTypePreference) {
      typeMultiplier = 1.5;
    }

    // 5. Check gift origin preference match
    double originMultiplier = 1.0;
    bool matchesOriginPreference = _checkGiftOriginMatch(
        gift.origin, target.giftOriginPreference, target.placeOrTribeOfOrigin);
    if (matchesOriginPreference &&
        target.giftOriginPreference != GiftOriginPreference.unappreciative) {
      originMultiplier = 1.5;
    }

    final List<Soldier> socialCircle = _getSocialCircle(target, gameState);
    String statChanges = "";
    String outcomeSummary = "";
    String infoRevealed = "";

    if (isAppropriate) {
      // Appropriate gift: positive relationship gains
      double finalAdmiration =
          baseAdmirationGain * typeMultiplier * originMultiplier;
      double finalRespect = baseRespectGain * typeMultiplier * originMultiplier;

      rel.updateAdmiration(finalAdmiration);
      rel.updateRespect(finalRespect);

      if (isBirthday) {
        outcomeSummary = "They were delighted by the birthday gift!";
        LoyaltyService.updateLoyalty(target, player.id, 0.1); // Birthday bonus
        if (usedEvent != null) {
          target.pendingJustifications.remove(usedEvent);
        }
      } else {
        outcomeSummary = "They appreciated the thoughtful gift.";
      }

      if (gameState.isOmniscientMode) {
        statChanges =
            "${target.name} gains ${finalAdmiration.toStringAsFixed(2)} Admiration, ${finalRespect.toStringAsFixed(2)} Respect.";
        if (isBirthday) {
          statChanges += " +0.1 Loyalty (birthday).";
        }
      }

      // Social circle effect for appropriate gifts
      _applySocialEffect(socialCircle, player.id,
          respect: 0.03, admiration: 0.05);


      if (_random.nextDouble() < 0.6) {
        // Use dialogue generation for more dynamic responses
        String dynamicResponse = _generateDialogue(target, gameState);
        if (dynamicResponse.isNotEmpty) {
          infoRevealed = "'$dynamicResponse'";
        } else {
          // Fallback to preference-based responses
          if (matchesTypePreference && matchesOriginPreference) {
            infoRevealed =
                "'This is exactly what I wanted! Thank you, Captain!'";
          } else if (matchesTypePreference) {
            infoRevealed = "'I've always wanted one of these!'";
          } else if (matchesOriginPreference) {
            infoRevealed =
                "'Fine craftsmanship from ${gift.origin}. I appreciate this.'";
          } else {
            infoRevealed = "'Thank you for thinking of me.'";
          }
        }
      } else {
        // Preference match feedback (original logic)
        if (matchesTypePreference && matchesOriginPreference) {
          infoRevealed = "'This is exactly what I wanted! Thank you, Captain!'";
        } else if (matchesTypePreference) {
          infoRevealed = "'I've always wanted one of these!'";
        } else if (matchesOriginPreference) {
          infoRevealed =
              "'Fine craftsmanship from ${gift.origin}. I appreciate this.'";
        } else {
          infoRevealed = "'Thank you for thinking of me.'";
        }
      }
    } else {
      // Inappropriate gift: negative relationship impact
      outcomeSummary = "They seemed confused by the gift.";
      double respectLoss = -(0.2 + (gift.baseValue * 0.002).clamp(0.0, 0.2));
      double fearLoss = -(0.1 + (gift.baseValue * 0.001).clamp(0.0, 0.1));

      rel.updateRespect(respectLoss);
      rel.updateFear(fearLoss);

      if (gameState.isOmniscientMode) {
        statChanges =
            "${target.name} loses ${(-respectLoss).toStringAsFixed(2)} Respect, ${(-fearLoss).toStringAsFixed(2)} Fear.";
      }

      infoRevealed =
          "'Why are you giving me this? I haven't done anything to deserve it...'";
    }

    final log = InteractionLogEntry(
      dateString: gameState.gameDate.toShortString(),
      type: InteractionType.gift,
      interactionSummary: "You gave ${gift.name} to ${target.name}.",
      outcomeSummary: outcomeSummary,
      informationRevealed: infoRevealed,
    );

    target.interactionLog.add(log);
    return InteractionResult(
      success: isAppropriate,
      outcomeSummary: log.outcomeSummary,
      statChangeSummary: statChanges,
      informationRevealed: infoRevealed,
      logEntry: log,
    );
  }

  // Helper method to check if gift type matches soldier's preference
  static bool _checkGiftTypeMatch(
      ItemType itemType, GiftTypePreference preference) {
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

  // Helper method to check if gift origin matches soldier's preference
  static bool _checkGiftOriginMatch(String itemOrigin,
      GiftOriginPreference preference, String soldierOrigin) {
    switch (preference) {
      case GiftOriginPreference.allAppreciative:
        return true;
      case GiftOriginPreference.unappreciative:
        return false;
      case GiftOriginPreference.fromHome:
        return itemOrigin.toLowerCase() == soldierOrigin.toLowerCase();
      case GiftOriginPreference.fromRival:
        // This would need a mapping of rival regions, for now just check if different
        return itemOrigin.toLowerCase() != soldierOrigin.toLowerCase();
      default:
        return false;
    }
  }

  // --- DIALOGUE GENERATION ENGINE ---

  static String _generateUniqueDialogue(Soldier speaker, GameState gameState) {
    for (int i = 0; i < 15; i++) {
      String potentialDialogue = _generateDialogue(speaker, gameState);
      if (potentialDialogue.isNotEmpty) {
        return potentialDialogue;
      }
    }
    return "'I have nothing more to say right now, Captain.'";
  }

  static String _generateDialogue(Soldier speaker, GameState gameState) {
    double roll = _random.nextDouble();
    if (roll < 0.35) {
      return _generateSubjectSelf(speaker, gameState);
    } else if (roll < 0.65) {
      return _generateSubjectMate(speaker, gameState);
    } else if (roll < 0.85) {
      return _generateSubjectLeader(speaker, gameState);
    } else {
      return _generateSubjectRandom(speaker, gameState);
    }
  }

  // --- TOPIC GENERATORS (With Memory Checks) ---

  static String _generateSubjectSelf(Soldier speaker, GameState gameState) {
    List<String Function()> topics = [
      () => _topicDutyPreference(speaker, speaker, "self"),
      () => _topicDutyPreference(speaker, speaker, "self", like: false),
      () => _topicGiftPreference(speaker, speaker, "self"),
      () => _topicGiftOrigin(speaker, speaker, "self"),
      () => _topicReligion(speaker, speaker, "self"),
      () => _topicSpecialSkill(speaker, speaker, "self"),
      () => _topicAttribute(speaker, speaker, "self"),
      () => _topicSkillProficiency(speaker, speaker, "self", high: true),
      () => _topicSkillProficiency(speaker, speaker, "self", high: false),
      () => _topicHighStat(speaker, speaker, "self"),
      () => _topicLowStat(speaker, speaker, "self"),
      () => _topicIneptitudeAdmission(speaker),
      () => _topicMurdererHint(speaker),
      () =>
          DialogueHelpers.topicOwnBirthday(speaker, gameState),
    ];
    topics.shuffle(_random);
    for (var topicGen in topics) {
      String result = topicGen();
      if (result.isNotEmpty) return result;
    }
    return "";
  }

  static String _generateSubjectMate(Soldier speaker, GameState gameState) {
    Soldier? mate = _getRandomAravtMate(speaker, gameState);
    if (mate == null) return _generateSubjectSelf(speaker, gameState);

    List<String Function(Soldier)> topics = [
      (s) => _topicRelationship(speaker, s, 'hate'),
      (s) => _topicRelationship(speaker, s, 'admire'),
      (s) => _topicRelationship(speaker, s, 'respect'),
      (s) => _topicRelationship(speaker, s, 'fear'),
      (s) => _topicRelationship(speaker, s, 'disrespect'),
      (s) => _topicGossipInept(speaker, s),
      (s) => _topicGossipMurder(speaker, s),
      (s) => _topicHighSkill(speaker, s, "mate"),
      (s) => _topicLowSkill(speaker, s, "mate"),
      (s) => DialogueHelpers.topicMateBirthday(
          speaker, s, gameState),
    ];
    topics.shuffle(_random);
    for (var topicGen in topics) {
      String result = topicGen(mate);
      if (result.isNotEmpty) return result;
    }
    return "";
  }

  static String _generateSubjectLeader(Soldier speaker, GameState gameState) {
    Soldier? leader = _getHordeLeader(gameState);
    if (leader == null || leader.id == speaker.id) return "";
    List<String Function(Soldier)> topics = [
      (s) => _topicRelationship(speaker, s, 'admire'),
      (s) => _topicRelationship(speaker, s, 'respect'),
      (s) => _topicRelationship(speaker, s, 'fear'),
      (s) => _topicRelationship(speaker, s, 'disrespect'),
    ];
    topics.shuffle(_random);
    for (var topicGen in topics) {
      String result = topicGen(leader);
      if (result.isNotEmpty) return result;
    }
    return "";
  }

  static String _generateSubjectRandom(Soldier speaker, GameState gameState) {

    if (_random.nextDouble() > 0.05) return "";

    Soldier? rando = _getRandomOutsider(speaker, gameState);
    if (rando == null) return "";
    return _useTopic(speaker, 'random_gossip_${rando.id}',
        "'I've heard ${rando.name} just got a new haircut.'");
  }

  // --- Specific Topic Implementations (FULL NAMES USED) ---

  static String _useTopic(Soldier soldier, String key, String content) {
    if (soldier.usedDialogueTopics.contains(key)) {
      return "";
    }
    soldier.usedDialogueTopics.add(key);
    return content;
  }

  static String _topicDutyPreference(
      Soldier speaker, Soldier subject, String rel,
      {bool like = true}) {
    if (like) {
      if (subject.preferredDuties.isEmpty) return "";
      final duty = subject
          .preferredDuties[_random.nextInt(subject.preferredDuties.length)];
      if (rel == "self") {
        return _useTopic(speaker, 'duty_like_${duty.name}',
            "'I wouldn't mind being assigned to ${duty.name}. I have a knack for it.'");
      }
      return _useTopic(speaker, 'mate_duty_like_${subject.id}_${duty.name}',
          "${subject.name} actually enjoys being a ${duty.name}. Strange.");
    } else {
      if (subject.despisedDuties.isEmpty) return "";
      final duty = subject
          .despisedDuties[_random.nextInt(subject.despisedDuties.length)];
      if (rel == "self") {
        return _useTopic(speaker, 'duty_hate_${duty.name}',
            "'Don't make me do ${duty.name}, Captain. I can't stand it.'");
      }
      return _useTopic(speaker, 'mate_duty_hate_${subject.id}_${duty.name}',
          "Never assign ${subject.name} to ${duty.name}. They won't stop complaining.");
    }
  }

  static String _topicGiftPreference(
      Soldier speaker, Soldier subject, String rel) {
    final pref = subject.giftTypePreference.name;
    if (rel == "self") {
      return _useTopic(speaker, 'gift_pref_$pref',
          "'If we ever get rich, I've always wanted a fine $pref.'");
    }
    return _useTopic(speaker, 'mate_gift_pref_${subject.id}_$pref',
        "You know what ${subject.name} wants? A $pref. It's all they talk about.");
  }

  static String _topicGiftOrigin(Soldier speaker, Soldier subject, String rel) {
    String originName =
        subject.giftOriginPreference.name.replaceAll('from', '').toLowerCase();
    if (originName == 'allappreciative') originName = 'any';

    if (subject.giftOriginPreference == GiftOriginPreference.unappreciative) {
      if (rel == "self") {
        return _useTopic(speaker, 'gift_origin_unappreciative',
            "Most 'gifts' we get are trash.");
      }
      return _useTopic(speaker, 'mate_gift_origin_unappreciative_${subject.id}',
          "${subject.name} is never happy with their share.");
    }

    if (rel == "self") {
      return _useTopic(
          speaker,
          'gift_origin_${subject.giftOriginPreference.name}',
          "'I prefer goods from the $originName lands. Better craftsmanship.'");
    }
    return "";
  }

  static String _topicReligion(Soldier speaker, Soldier subject, String rel) {
    if (subject.religionType == ReligionType.none) return "";
    if (rel == "self") {
      return _useTopic(speaker, 'religion_${subject.religionType.name}',
          "'May ${subject.religionType.name == 'tengri' ? 'the Eternal Blue Sky' : subject.religionType.name} watch over us.'");
    }
    return _useTopic(speaker, 'mate_religion_${subject.id}',
        "${subject.name} follows the ${subject.religionType.name} spirits.");
  }

  static String _topicSpecialSkill(
      Soldier speaker, Soldier subject, String rel) {
    if (subject.specialSkills.isEmpty) return "";
    final skill = subject.specialSkills.first.name;
    if (rel == "self") {
      return _useTopic(speaker, 'special_$skill',
          "'Before I rode with the horde, I was a $skill. Useful, sometimes.'");
    }
    return _useTopic(speaker, 'mate_special_${subject.id}_$skill',
        "Did you know ${subject.name} is a $skill? We should use that.");
  }

  static String _topicAttribute(Soldier speaker, Soldier subject, String rel) {
    if (subject.attributes.isEmpty) return "";
    final visibleAttributes = subject.attributes
        .where((a) =>
            a != SoldierAttribute.murderer && a != SoldierAttribute.inept)
        .toList();
    if (visibleAttributes.isEmpty) return "";
    final attr = visibleAttributes[_random.nextInt(visibleAttributes.length)];

    if (rel == "self") {
      return _useTopic(speaker, 'attr_${attr.name}',
          "'People say I am ${attr.name}. I suppose it's true.'");
    }
    return _useTopic(speaker, 'mate_attr_${subject.id}_${attr.name}',
        "${subject.name} is quite the ${attr.name}, don't you think?");
  }

  static String _topicSkillProficiency(
      Soldier speaker, Soldier subject, String rel,
      {bool high = true}) {
    Map<String, num> skills = {
      'archery': subject.longRangeArcherySkill,
      'mounted archery': subject.mountedArcherySkill,
      'riding': subject.horsemanship,
      'swordsmanship': subject.swordSkill,
      'spear use': subject.spearSkill,
      'shield use': subject.shieldSkill,
      'animal handling': subject.animalHandling,
    };
    var entries = high
        ? skills.entries.where((e) => e.value >= 7).toList()
        : skills.entries
            .where((e) => e.value <= 6)
            .toList(); // Expanded to 6 to support mid-range feedback
    if (entries.isEmpty) return "";
    final entry = entries[_random.nextInt(entries.length)];

    if (high) {
      if (entry.key == 'spear use' && entry.value >= 7) {
        if (rel == "self") {
          return _useTopic(speaker, 'skill_high_spear_7',
              "'I am deadly with a spear. Try me.'");
        }
        final name = subject.isPlayer ? "Your" : "${subject.name}'s";
        return _useTopic(speaker, 'mate_skill_high_${subject.id}_spear_7',
            "$name spear use is deadly.");
      }
      if (rel == "self") {
        return _useTopic(speaker, 'skill_high_${entry.key}',
            "'I am confident in my ${entry.key}. I won't let you down.'");
      }
      final name = subject.isPlayer ? "your" : "${subject.name}'s";
      return _useTopic(speaker, 'mate_skill_high_${subject.id}_${entry.key}',
          "You should see $name ${entry.key}. Impressive.");
    } else {

      if (entry.key == 'spear use') {
        if (entry.value <= 2) {
          if (rel == "self") {
            return _useTopic(speaker, 'skill_low_spear_0',
                "'Honestly, Captain... my spear use is terrible. I need practice.'");
          }
          final String subjectName = subject.isPlayer ? "You" : subject.name;
          final String verb = subject.isPlayer ? "are" : "is";
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_spear_0',
              "$subjectName $verb terrible at spear use.");
        } else if (entry.value <= 4) {
          if (rel == "self") {
            return _useTopic(speaker, 'skill_low_spear_3',
                "'My spear use isn't great, Captain. Still learning.'");
          }
          final String subjectName = subject.isPlayer ? "You" : subject.name;
          final String verb = subject.isPlayer ? "are" : "is";
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_spear_3',
              "$subjectName $verb not great at spear use.");
        } else if (entry.value <= 6) {
          if (rel == "self") {
            return _useTopic(speaker, 'skill_low_spear_5',
                "'I'm pretty good with a spear, but always room to improve.'");
          }
          final String subjectName = subject.isPlayer ? "You" : subject.name;
          final String verb = subject.isPlayer ? "are" : "is";
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_spear_5',
              "$subjectName $verb pretty good with a spear.");
        }
      } else if (entry.key == 'swordsmanship') {
        if (entry.value <= 2) {
          if (rel == "self")
            return _useTopic(speaker, 'skill_low_sword_0',
                "'I can barely hold a sword, Captain.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_sword_0',
              "${subject.isPlayer ? "You are" : "${subject.name} is"} dangerous with a sword... to ${subject.isPlayer ? "yourself" : "themselves"}.");
        } else if (entry.value <= 4) {
          if (rel == "self")
            return _useTopic(
                speaker, 'skill_low_sword_3', "'My swordsmanship needs work.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_sword_3',
              "${subject.isPlayer ? "You aren't" : "${subject.name} isn't"} very skilled with a sword.");
        }
      } else if (entry.key == 'archery' || entry.key == 'mounted archery') {
        if (entry.value <= 2) {
          if (rel == "self")
            return _useTopic(speaker, 'skill_low_archery_0',
                "'I couldn't hit a yurt from the inside.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_archery_0',
              "${subject.isPlayer ? "You couldn't" : "${subject.name} couldn't"} hit a yurt from the inside.");
        } else if (entry.value <= 4) {
          if (rel == "self")
            return _useTopic(speaker, 'skill_low_archery_3',
                "'My aim is a bit off lately.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_archery_3',
              "${subject.isPlayer ? "You need" : "${subject.name} needs"} more practice with a bow.");
        }
      } else if (entry.key == 'shield use') {
        if (entry.value <= 2) {
          if (rel == "self")
            return _useTopic(speaker, 'skill_low_shield_0',
                "'I keep forgetting to raise my shield.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_shield_0',
              "${subject.isPlayer ? "You forget" : "${subject.name} forgets"} to use ${subject.isPlayer ? "your" : "their"} shield.");
        } else if (entry.value <= 4) {
          if (rel == "self")
            return _useTopic(speaker, 'skill_low_shield_3',
                "'I'm not used to fighting with a shield.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_shield_3',
              "${subject.isPlayer ? "You aren't" : "${subject.name} isn't"} used to shields.");
        }
      } else if (entry.key == 'riding') {
        if (entry.value <= 2) {
          if (rel == "self")
            return _useTopic(speaker, 'skill_low_riding_0',
                "'I'm more comfortable on my own two feet.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_riding_0',
              "${subject.isPlayer ? "You ride" : "${subject.name} rides"} like a sack of grain.");
        } else if (entry.value <= 4) {
          if (rel == "self")
            return _useTopic(speaker, 'skill_low_riding_3',
                "'I'm still getting used to this horse.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_riding_3',
              "${subject.isPlayer ? "You need" : "${subject.name} needs"} more time in the saddle.");
        }
      } else if (entry.key == 'animal handling') {
        if (entry.value <= 2) {
          if (rel == "self")
            return _useTopic(speaker, 'skill_low_animal_0',
                "'Animals don't seem to like me.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_animal_0',
              "Animals hate ${subject.isPlayer ? "you" : subject.name}.");
        } else if (entry.value <= 4) {
          if (rel == "self")
            return _useTopic(
                speaker, 'skill_low_animal_3', "'I'm not great with animals.'");
          return _useTopic(speaker, 'mate_skill_low_${subject.id}_animal_3',
              "${subject.isPlayer ? "You aren't" : "${subject.name} isn't"} great with animals.");
        }
      }

      if (rel == "self") {
        return _useTopic(speaker, 'skill_low_${entry.key}',
            "'Honestly, Captain... my ${entry.key} is not good. I need practice.'");
      }
      final String subjectName = subject.isPlayer ? "You" : subject.name;
      final String verb = subject.isPlayer ? "are" : "is";
      return _useTopic(speaker, 'mate_skill_low_${subject.id}_${entry.key}',
          "$subjectName $verb terrible at ${entry.key}.");
    }
  }

  static String _topicHighSkill(Soldier speaker, Soldier subject, String rel) {
    return _topicSkillProficiency(speaker, subject, rel, high: true);
  }

  static String _topicLowSkill(Soldier speaker, Soldier subject, String rel) {
    return _topicSkillProficiency(speaker, subject, rel, high: false);
  }

  static String _topicHighStat(Soldier speaker, Soldier subject, String rel) {
    if (subject.strength > 7) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_str' : 'mate_stat_high_str_${subject.id}',
          rel == "self"
              ? "'I can carry more than most. Use that.'"
              : (subject.isPlayer
                  ? "You are strong as an ox."
                  : "${subject.name} is strong as an ox."));
    }
    if (subject.intelligence > 7) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_int' : 'mate_stat_high_int_${subject.id}',
          rel == "self"
              ? "'I see things others miss.'"
              : (subject.isPlayer
                  ? "You are sharp. Maybe too sharp."
                  : "${subject.name} is sharp. Maybe too sharp."));
    }
    if (subject.courage > 7) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_cou' : 'mate_stat_high_cou_${subject.id}',
          rel == "self"
              ? "'I'm not afraid of anything!'"
              : (subject.isPlayer
                  ? "You have the heart of a lion."
                  : "${subject.name} has the heart of a lion."));
    }
    if (subject.leadership > 7) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_lea' : 'mate_stat_high_lea_${subject.id}',
          rel == "self"
              ? "'People tend to follow my lead.'"
              : (subject.isPlayer
                  ? "You are a natural born leader."
                  : "${subject.name} is a natural born leader."));
    }
    if (subject.charisma > 7) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_cha' : 'mate_stat_high_cha_${subject.id}',
          rel == "self"
              ? "'I can talk my way out of anything.'"
              : (subject.isPlayer
                  ? "You could charm the birds from the trees."
                  : "${subject.name} could charm the birds from the trees."));
    }
    if (subject.ambition > 7) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_amb' : 'mate_stat_high_amb_${subject.id}',
          rel == "self"
              ? "'I have big plans for the future.'"
              : (subject.isPlayer
                  ? "You are very ambitious. Watch your back."
                  : "${subject.name} is very ambitious. Keep an eye on them."));
    }
    if (subject.honesty > 7) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_hon' : 'mate_stat_high_hon_${subject.id}',
          rel == "self"
              ? "'I cannot tell a lie.'"
              : (subject.isPlayer
                  ? "You are honest to a fault."
                  : "${subject.name} is honest to a fault."));
    }
    if (subject.adaptability > 7) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_ada' : 'mate_stat_high_ada_${subject.id}',
          rel == "self"
              ? "'I can adapt to any situation.'"
              : (subject.isPlayer
                  ? "You are like water, adapting to everything."
                  : "${subject.name} is like water, adapting to everything."));
    }

    return "";
  }

  static String _topicLowStat(Soldier speaker, Soldier subject, String rel) {
    if (subject.intelligence < 4) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_low_int' : 'mate_stat_low_int_${subject.id}',
          rel == "self"
              ? "'Too much thinking makes my head hurt.'"
              : (subject.isPlayer
                  ? "You aren't the smartest rider in the horde."
                  : "${subject.name} isn't the smartest rider in the horde."));
    }
    if (subject.stamina < 4) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_low_sta' : 'mate_stat_low_sta_${subject.id}',
          rel == "self"
              ? "'I get winded easily these days.'"
              : (subject.isPlayer
                  ? "You tire too quickly in a fight."
                  : "${subject.name} tires too quickly in a fight."));
    }
    if (subject.patience < 4) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_low_pat' : 'mate_stat_low_pat_${subject.id}',
          rel == "self"
              ? "'I have no patience for this!'"
              : (subject.isPlayer
                  ? "You are really impatient."
                  : "${subject.name} is really impatient."));
    }
    if (subject.courage < 4) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_low_cou' : 'mate_stat_low_cou_${subject.id}',
          rel == "self"
              ? "'I... I don't want to die out here.'"
              : (subject.isPlayer
                  ? "You are a bit of a coward, aren't you?"
                  : "${subject.name} is a bit of a coward."));
    }
    if (subject.honesty < 4) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_low_hon' : 'mate_stat_low_hon_${subject.id}',
          rel == "self"
              ? "'A little lie never hurt anyone.'"
              : (subject.isPlayer
                  ? "You are a liar."
                  : "${subject.name} is a liar."));
    }
    if (subject.exhaustion > 50) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_exh' : 'mate_stat_high_exh_${subject.id}',
          rel == "self"
              ? "'I am exhausted. I need rest.'"
              : (subject.isPlayer
                  ? "You look exhausted."
                  : "${subject.name} looks exhausted."));
    }
    if (subject.stress > 50) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_high_str' : 'mate_stat_high_str_${subject.id}',
          rel == "self"
              ? "'I am cracking under the pressure.'"
              : (subject.isPlayer
                  ? "You look stressed out."
                  : "${subject.name} looks stressed out."));
    }
    if (subject.hygiene < 20) {
      return _useTopic(
          speaker,
          rel == "self" ? 'stat_low_hyg' : 'mate_stat_low_hyg_${subject.id}',
          rel == "self"
              ? "'I smell like a horse's backside.'"
              : (subject.isPlayer
                  ? "You smell terrible."
                  : "${subject.name} smells terrible."));
    }

    return "";
  }

  static String _topicIneptitudeAdmission(Soldier speaker) {
    if (speaker.attributes.contains(SoldierAttribute.inept)) {
      if (_random.nextDouble() < 0.4) {
        return _useTopic(speaker, 'inept_self_admission',
            "'Sorry about that mess yesterday, Captain. My hands just... slipped.'");
      }
    }
    return "";
  }

  static String _topicMurdererHint(Soldier speaker) {
    if (speaker.attributes.contains(SoldierAttribute.murderer)) {
      if (_random.nextDouble() < 0.3) {
        return _useTopic(speaker, 'murder_self_hint',
            "'It's easier when it's dark. No one sees what you do.'");
      }
    }
    return "";
  }

  static String _topicRelationship(
      Soldier speaker, Soldier target, String type) {
    final rel = speaker.getRelationship(target.id);
    String key = 'rel_${type}_${target.id}';

    switch (type) {
      case 'hate':
        if (rel.admiration < 2.0 && rel.respect < 2.0) {
          final name = target.isPlayer ? "you" : target.name;
          final pronoun = target.isPlayer ? "you" : "them";
          return _useTopic(
              speaker, key, "'I can't stand $name. Keep an eye on $pronoun.'");
        }
        break;
      case 'admire':
        if (rel.admiration > 4.0) {
          final name = target.isPlayer ? "You are" : "${target.name} is";
          final pronoun = target.isPlayer ? "you" : "them";
          return _useTopic(speaker, key,
              "'$name a true hero. We are lucky to have $pronoun.'");
        }
        break;
      case 'respect':
        if (rel.respect > 4.0) {
          final name = target.isPlayer ? "You know" : "${target.name} knows";
          final pronoun = target.isPlayer ? "you are" : "they are";
          return _useTopic(
              speaker, key, "'$name what $pronoun doing. A good soldier.'");
        }
        break;
      case 'fear':
        if (rel.fear > 4.0) {
          final name = target.isPlayer ? "you" : target.name;
          final pronoun = target.isPlayer ? "You scare" : "They scare";
          return _useTopic(
              speaker, key, "'Stay away from $name. $pronoun me.'");
        }
        break;
      case 'disrespect':
        if (rel.respect < 2.0) {
          final name = target.isPlayer ? "You are" : "${target.name} is";
          final pronoun = target.isPlayer ? "you" : "they";
          return _useTopic(
              speaker, key, "'$name useless. Why are $pronoun even here?'");
        }
        break;
    }
    return "";
  }

  static String _topicGossipInept(Soldier speaker, Soldier target) {
    if (target.attributes.contains(SoldierAttribute.inept)) {
      if (speaker.attributes.contains(SoldierAttribute.gossip) ||
          speaker.perception > 6) {
        final name = target.isPlayer ? "you" : target.name;
        final pronoun = target.isPlayer ? "You" : "They";
        return _useTopic(speaker, 'gossip_inept_${target.id}',
            "'Have you noticed $name? $pronoun keep dropping things. Dangerous.'");
      }
    }
    return "";
  }

  static String _topicGossipMurder(Soldier speaker, Soldier target) {
    if (target.attributes.contains(SoldierAttribute.murderer)) {
      if (speaker.perception > 7) {
        final name = target.isPlayer ? "you" : target.name;
        final pronoun = target.isPlayer ? "you" : "they";
        return _useTopic(speaker, 'gossip_murder_${target.id}',
            "'There's something off about $name. The way $pronoun look at people when $pronoun think no one is watching...'");
      }
    }
    return "";
  }

  // --- REACTIVE DIALOGUE (Scold/Praise Responses) ---

  static String _generateOtherPraise(Soldier speaker, GameState gameState) {
    final mate = _getRandomAravtMate(speaker, gameState);
    if (mate == null) return "It was a team effort, Captain.";
    String line = _topicHighSkill(speaker, mate, "mate");
    if (line.isEmpty) line = _topicHighStat(speaker, mate, "mate");
    if (line.isEmpty) line = _topicRelationship(speaker, mate, 'admire');
    if (line.isEmpty) return "${mate.name} deserves credit too.";
    return line;
  }

  static String _generateSelfPraise(Soldier speaker, GameState gameState) {
    String line = _topicHighSkill(speaker, speaker, "self");
    if (line.isEmpty) line = _topicHighStat(speaker, speaker, "self");
    if (line.isEmpty) return "I did well, didn't I?";
    return line;
  }

  static String _generateSelfCriticism(Soldier speaker, GameState gameState) {
    if (speaker.attributes.contains(SoldierAttribute.inept)) {
      return "I know, Captain. I'm just... so clumsy sometimes. I'll try harder.";
    }
    String line = _topicLowSkill(speaker, speaker, "self");
    if (line.isEmpty) line = _topicLowStat(speaker, speaker, "self");
    if (line.isEmpty) return "You are right. I must do better.";
    return line;
  }

  static String _generateOtherCriticism(Soldier speaker, GameState gameState) {
    final mate = _getRandomAravtMate(speaker, gameState);
    if (mate == null) return "It wasn't entirely my fault!";

    if (speaker.attributes.contains(SoldierAttribute.murderer)) {
      return "Maybe you should be watching ${mate.name} instead of me. Just saying.";
    }
    String line = _topicLowSkill(speaker, mate, "mate");
    if (line.isEmpty) line = _topicLowStat(speaker, mate, "mate");
    if (line.isEmpty) line = _topicRelationship(speaker, mate, 'disrespect');
    if (line.isEmpty) return "${mate.name} was the one who messed up, not me.";
    return line;
  }

  // --- PRIVATE HELPERS ---

  static _InteractionTier _determineTier(double baseChance) {
    double roll = _random.nextDouble();
    double chance = baseChance.clamp(0.05, 0.95);

    if (roll < chance * 0.4) return _InteractionTier.extraSuccess;
    if (roll < chance) return _InteractionTier.success;
    if (roll < chance + 0.25) return _InteractionTier.lessSuccessful;
    return _InteractionTier.unsuccessful;
  }

  static Soldier? _getRandomAravtMate(Soldier speaker, GameState gameState) {
    final mates = gameState.horde
        .where((s) => s.aravt == speaker.aravt && s.id != speaker.id)
        .toList();
    if (mates.isEmpty) return null;
    return mates[_random.nextInt(mates.length)];
  }

  static Soldier? _getHordeLeader(GameState gameState) {
    try {
      return gameState.horde
          .firstWhere((s) => s.role == SoldierRole.hordeLeader);
    } catch (e) {
      return null;
    }
  }

  static Soldier? _getRandomOutsider(Soldier speaker, GameState gameState) {
    final outsiders = gameState.horde
        .where((s) => s.aravt != speaker.aravt && s.id != speaker.id)
        .toList();
    return outsiders.isNotEmpty
        ? outsiders[_random.nextInt(outsiders.length)]
        : null;
  }


  static List<Soldier> _getSocialCircle(Soldier target, GameState gameState) {
    List<Soldier> circle = [];
    if (target.yurtId != null) {
      circle.addAll(gameState.horde
          .where((s) => s.yurtId == target.yurtId && s.id != target.id));
    }
    circle.addAll(gameState.horde
        .where((s) => s.aravt == target.aravt && s.id != target.id));
    try {
      final aravt = gameState.aravts.firstWhere((a) => a.id == target.aravt);
      final captain = gameState.findSoldierById(aravt.captainId);
      if (captain != null && captain.id != target.id) {
        circle.add(captain);
      }
    } catch (e) {
      // Ignore if no mates available
    }
    final leader = gameState.horde.firstWhere(
        (s) => s.role == SoldierRole.hordeLeader,
        orElse: () => gameState.player!);
    if (leader.id != target.id) {
      circle.add(leader);
    }
    return circle.toSet().toList();
  }

  static void _applySocialEffect(
    List<Soldier> circle,
    int playerId, {
    double respect = 0,
    double admiration = 0,
    double fear = 0,
    double loyalty = 0,
  }) {
    for (final soldier in circle) {
      final rel = soldier.getRelationship(playerId);
      if (respect != 0) rel.updateRespect(respect);
      if (admiration != 0) rel.updateAdmiration(admiration);
      if (fear != 0) rel.updateFear(fear);
      if (loyalty != 0) rel.updateLoyalty(loyalty);
    }
  }
}
