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

// lib/services/unassigned_actions_helpers/advice_helper.dart

import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';

/// Helper class for advice-giving mechanics
class AdviceHelper {
  static final Random _random = Random();

  /// Calculate probability of giving advice
  /// 1.5% baseline, 7.5% for mentor trait
  static double getAdviceProbability(Soldier soldier) {
    double baseProb = 0.015;

    if (soldier.attributes.contains(SoldierAttribute.mentor)) {
      baseProb *= 5.0; // 7.5% for mentors
    }

    // Boost for high knowledge/intelligence
    baseProb += (soldier.knowledge / 400.0); // Up to +2.5%
    baseProb += (soldier.intelligence / 400.0); // Up to +2.5%

    return baseProb;
  }

  /// Determine advice outcome
  /// Returns: 0 = extremely unsuccessful, 1 = very unsuccessful, 2 = unsuccessful, 3 = successful
  static int determineAdviceOutcome(
      Soldier advisor, Soldier advisee, GameState gameState) {
    double successScore = 0.0;

    // Advisor factors
    successScore += (advisor.temperament / 20.0); // Up to +5
    successScore += (advisor.patience / 20.0); // Up to +5 (patience is an int)
    successScore += (advisor.perception / 20.0); // Up to +5
    successScore += (advisor.intelligence / 20.0); // Up to +5
    successScore += (advisor.knowledge / 20.0); // Up to +5

    // Advisee receptivity
    final rel = advisee.getRelationship(advisor.id);
    successScore += (rel.admiration / 2.0); // Up to +5
    successScore += (rel.respect / 2.0); // Up to +5

    // Random factor
    successScore += _random.nextDouble() * 10.0; // 0-10

    // Determine outcome
    if (successScore >= 30.0) {
      return 3; // Successful
    } else if (successScore >= 20.0) {
      return 2; // Unsuccessful but not harmful
    } else if (successScore >= 10.0) {
      return 1; // Very unsuccessful
    } else {
      return 0; // Extremely unsuccessful
    }
  }

  /// Execute advice-giving
  static Map<String, dynamic> executeAdvice(
      Soldier advisor, Soldier advisee, GameState gameState) {
    int outcome = determineAdviceOutcome(advisor, advisee, gameState);
    final rel = advisee.getRelationship(advisor.id);

    Map<String, dynamic> result = {
      'outcome': outcome,
      'gain': null,
    };

    switch (outcome) {
      case 3: // Successful
        rel.updateAdmiration(0.2);
        rel.updateRespect(0.3);

        // Grant advisee a gain
        result['gain'] = _grantAdviceGain(advisee);
        break;

      case 2: // Unsuccessful
        rel.updateAdmiration(0.05);
        rel.updateRespect(0.05);
        break;

      case 1: // Very unsuccessful
        rel.updateAdmiration(-0.1);
        rel.updateRespect(-0.05);
        break;

      case 0: // Extremely unsuccessful
        rel.updateAdmiration(-0.2);
        rel.updateRespect(-0.15);
        break;
    }

    return result;
  }

  /// Grant a gain to the advisee
  static Map<String, dynamic> _grantAdviceGain(Soldier advisee) {
    double roll = _random.nextDouble();

    if (roll < 0.40) {
      // 40%: Skill points
      int skillGain = _random.nextInt(3) + 1; // 1-3 points
      String skill = _selectRandomSkill();
      _applySkillGain(advisee, skill, skillGain);
      return {
        'type': 'skill',
        'skill': skill,
        'amount': skillGain,
      };
    } else if (roll < 0.70) {
      // 30%: Experience
      int expGain = _random.nextInt(50) + 25; // 25-75 exp
      advisee.experience += expGain;
      return {
        'type': 'experience',
        'amount': expGain,
      };
    } else if (roll < 0.90) {
      // 20%: Attribute points
      int attrGain = _random.nextInt(2) + 1; // 1-2 points
      String attribute = _selectRandomAttribute();
      _applyAttributeGain(advisee, attribute, attrGain);
      return {
        'type': 'attribute',
        'attribute': attribute,
        'amount': attrGain,
      };
    } else if (roll < 0.95) {
      // 5%: Special skill
      SpecialSkill skill = _selectRandomSpecialSkill();
      if (!advisee.specialSkills.contains(skill)) {
        advisee.specialSkills.add(skill);
        return {
          'type': 'specialSkill',
          'skill': skill.name,
        };
      } else {
        // Already has it, give attribute instead
        return _grantAdviceGain(advisee); // Reroll
      }
    } else {
      // 5%: Attribute (permanent)
      SoldierAttribute attr = _selectRandomSoldierAttribute();
      if (!advisee.attributes.contains(attr)) {
        advisee.attributes.add(attr);
        return {
          'type': 'soldierAttribute',
          'attribute': attr.name,
        };
      } else {
        // Already has it, give attribute points instead
        return _grantAdviceGain(advisee); // Reroll
      }
    }
  }

  static String _selectRandomSkill() {
    List<String> skills = [
      'longRangeArchery',
      'mountedArchery',
      'spear',
      'sword',
      'shield',
      'horsemanship',
      'animalHandling',
      'perception',
      'knowledge',
    ];
    return skills[_random.nextInt(skills.length)];
  }

  static void _applySkillGain(Soldier soldier, String skill, int amount) {
    switch (skill) {
      case 'longRangeArchery':
        soldier.longRangeArcherySkill =
            (soldier.longRangeArcherySkill + amount).clamp(0, 100);
        break;
      case 'mountedArchery':
        soldier.mountedArcherySkill =
            (soldier.mountedArcherySkill + amount).clamp(0, 100);
        break;
      case 'spear':
        soldier.spearSkill = (soldier.spearSkill + amount).clamp(0, 100);
        break;
      case 'sword':
        soldier.swordSkill = (soldier.swordSkill + amount).clamp(0, 100);
        break;
      case 'shield':
        soldier.shieldSkill = (soldier.shieldSkill + amount).clamp(0, 100);
        break;
      case 'horsemanship':
        soldier.horsemanship = (soldier.horsemanship + amount).clamp(0, 100);
        break;
      case 'animalHandling':
        soldier.animalHandling =
            (soldier.animalHandling + amount).clamp(0, 100);
        break;
      case 'perception':
        soldier.perception = (soldier.perception + amount).clamp(0, 100);
        break;
      case 'knowledge':
        soldier.knowledge = (soldier.knowledge + amount).clamp(0, 100);
        break;
    }
  }

  static String _selectRandomAttribute() {
    List<String> attributes = [
      'strength',
      'courage',
      'intelligence',
      'charisma',
      'temperament',
      'stamina',
    ];
    return attributes[_random.nextInt(attributes.length)];
  }

  static void _applyAttributeGain(
      Soldier soldier, String attribute, int amount) {
    switch (attribute) {
      case 'strength':
        soldier.strength = (soldier.strength + amount).clamp(0, 100);
        break;
      case 'courage':
        soldier.courage = (soldier.courage + amount).clamp(0, 100);
        break;
      case 'intelligence':
        soldier.intelligence = (soldier.intelligence + amount).clamp(0, 100);
        break;
      case 'charisma':
        soldier.charisma = (soldier.charisma + amount).clamp(0, 100);
        break;
      case 'temperament':
        soldier.temperament = (soldier.temperament + amount).clamp(0, 10);
        break;
      case 'stamina':
        soldier.stamina = (soldier.stamina + amount).clamp(0, 100);
        break;
    }
  }

  static SpecialSkill _selectRandomSpecialSkill() {
    List<SpecialSkill> skills = SpecialSkill.values;
    return skills[_random.nextInt(skills.length)];
  }

  static SoldierAttribute _selectRandomSoldierAttribute() {
    List<SoldierAttribute> attributes = [
      SoldierAttribute.peacemaker,
      SoldierAttribute.mentor,
      SoldierAttribute.gregarious,
      SoldierAttribute.forgiving,
      SoldierAttribute.glorySeeker,
    ];
    return attributes[_random.nextInt(attributes.length)];
  }

  /// Generate description for advice event
  static String generateAdviceDescription(
      Soldier advisor, Soldier advisee, Map<String, dynamic> result) {
    int outcome = result['outcome'];
    String baseDesc = "${advisor.name} gave advice to ${advisee.name}";

    switch (outcome) {
      case 3: // Successful
        if (result['gain'] != null) {
          var gain = result['gain'];
          String gainDesc = "";
          switch (gain['type']) {
            case 'skill':
              gainDesc =
                  " and improved their ${gain['skill']} by ${gain['amount']}";
              break;
            case 'experience':
              gainDesc = " and gained ${gain['amount']} experience";
              break;
            case 'attribute':
              gainDesc =
                  " and improved their ${gain['attribute']} by ${gain['amount']}";
              break;
            case 'specialSkill':
              gainDesc = " and learned ${gain['skill']}";
              break;
            case 'soldierAttribute':
              gainDesc = " and gained the ${gain['attribute']} attribute";
              break;
          }
          return "$baseDesc$gainDesc.";
        }
        return "$baseDesc. It was very helpful.";

      case 2: // Unsuccessful
        return "$baseDesc, but it wasn't particularly helpful.";

      case 1: // Very unsuccessful
        return "$baseDesc, but it was poorly received.";

      case 0: // Extremely unsuccessful
        return "$baseDesc, and it backfired badly.";

      default:
        return baseDesc;
    }
  }
}
