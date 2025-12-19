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

// lib/services/unassigned_actions_helpers/gossip_helper.dart

import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/social_interaction_data.dart';
import 'package:aravt/providers/game_state.dart';

/// Helper class for gossip and information sharing
class GossipHelper {
  static final Random _random = Random();

  /// Calculate probability of gossiping
  /// 2% baseline, 10% for gossip trait
  static double getGossipProbability(Soldier soldier) {
    double baseProb = 0.02;
    if (soldier.attributes.contains(SoldierAttribute.gossip)) {
      baseProb *= 5.0; // 10% for gossips
    }
    return baseProb;
  }

  /// Select most interesting piece of information to share
  /// Weighted by interest level
  static InformationPiece? selectInformationToShare(Soldier soldier) {
    if (soldier.knownInformation.isEmpty) return null;

    // Weight by interest level (3 = most interesting)
    List<({InformationPiece info, double weight})> weighted = [];
    for (var info in soldier.knownInformation) {
      weighted.add((info: info, weight: info.interestLevel.toDouble()));
    }

    double totalWeight = weighted.fold(0.0, (sum, w) => sum + w.weight);
    double roll = _random.nextDouble() * totalWeight;

    double cumulativeWeight = 0.0;
    for (var item in weighted) {
      cumulativeWeight += item.weight;
      if (roll <= cumulativeWeight) {
        return item.info;
      }
    }

    return soldier.knownInformation.first; // Fallback
  }

  /// Execute gossip exchange
  static Map<String, InformationPiece?> executeGossip(
      Soldier soldier, Soldier target, GameState gameState) {
    InformationPiece? sharedInfo = selectInformationToShare(soldier);

    if (sharedInfo != null) {
      // Share information with target
      target.knownInformation.add(sharedInfo);

      // Small relationship boost
      final rel = target.getRelationship(soldier.id);
      rel.updateAdmiration(0.05);

      // 50% chance target shares something back
      if (_random.nextDouble() < 0.5) {
        InformationPiece? reciprocalInfo = selectInformationToShare(target);
        if (reciprocalInfo != null) {
          soldier.knownInformation.add(reciprocalInfo);
          return {
            'shared': sharedInfo,
            'received': reciprocalInfo,
          };
        }
      }

      return {
        'shared': sharedInfo,
        'received': null,
      };
    }

    return {
      'shared': null,
      'received': null,
    };
  }

  /// Generate description for gossip event
  static String generateGossipDescription(
      Soldier soldier, Soldier target, Map<String, InformationPiece?> result) {
    if (result['shared'] != null && result['received'] != null) {
      return "${soldier.name} and ${target.name} exchanged gossip.";
    } else if (result['shared'] != null) {
      return "${soldier.name} shared gossip with ${target.name}.";
    } else {
      return "${soldier.name} tried to gossip with ${target.name}, but had nothing to share.";
    }
  }

  // Utility methods to create information pieces

  static InformationPiece createMurderPlotInfo(
      int plotterId, int targetId, int turnNumber) {
    return InformationPiece(
      content: "Soldier $plotterId is plotting to murder Soldier $targetId",
      interestLevel: 3,
      isTrue: true,
      originTurn: turnNumber,
      subjectSoldierId: plotterId,
    );
  }

  static InformationPiece createTheftInfo(
      int thiefId, String itemName, int turnNumber) {
    return InformationPiece(
      content: "Soldier $thiefId stole $itemName",
      interestLevel: 3,
      isTrue: true,
      originTurn: turnNumber,
      subjectSoldierId: thiefId,
    );
  }

  static InformationPiece createHatredInfo(
      int soldier1Id, int soldier2Id, int turnNumber) {
    return InformationPiece(
      content: "Soldier $soldier1Id hates Soldier $soldier2Id",
      interestLevel: 2,
      isTrue: true,
      originTurn: turnNumber,
      subjectSoldierId: soldier1Id,
    );
  }

  static InformationPiece createCombatProwessInfo(
      int soldierId, String achievement, int turnNumber) {
    return InformationPiece(
      content: "Soldier $soldierId $achievement",
      interestLevel: 2,
      isTrue: true,
      originTurn: turnNumber,
      subjectSoldierId: soldierId,
    );
  }

  static InformationPiece createSkillInfo(
      int soldierId, String skillName, int turnNumber) {
    return InformationPiece(
      content: "Soldier $soldierId is skilled at $skillName",
      interestLevel: 1,
      isTrue: true,
      originTurn: turnNumber,
      subjectSoldierId: soldierId,
    );
  }

  static InformationPiece createAttributeInfo(
      int soldierId, String attributeName, int turnNumber) {
    return InformationPiece(
      content: "Soldier $soldierId is $attributeName",
      interestLevel: 1,
      isTrue: true,
      originTurn: turnNumber,
      subjectSoldierId: soldierId,
    );
  }
}
