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

// lib/services/unassigned_actions_helpers/proselytize_helper.dart

import 'dart:math';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/providers/game_state.dart';

/// Helper class for proselytization mechanics
class ProselytizeHelper {
  static final Random _random = Random();

  /// Calculate probability of attempting to proselytize
  /// Based on religion intensity
  static double getProselytizeProbability(Soldier soldier) {
    switch (soldier.religionIntensity) {
      case ReligionIntensity.fervent:
        return 0.10; // 10% for fervent believers
      case ReligionIntensity.normal:
        return 0.05; // 5% for normal believers
      case ReligionIntensity.syncretic:
        return 0.02; // 2% for syncretic believers
      case ReligionIntensity.agnostic:
      case ReligionIntensity.atheist:
        return 0.0; // Agnostics/atheists don't proselytize
    }
  }

  /// Calculate success probability of conversion
  static double getConversionSuccessProbability(
      Soldier proselytizer, Soldier target, GameState gameState) {
    double baseProb = 0.1; // 10% baseline

    // Proselytizer factors
    baseProb += (proselytizer.charisma / 200.0); // Up to +5%
    baseProb += (proselytizer.intelligence / 200.0); // Up to +5%
    if (proselytizer.patience >= 70) {
      baseProb += 0.05; // Patient people are better at converting
    }

    // Relationship factors
    final rel = target.getRelationship(proselytizer.id);
    baseProb += (rel.admiration / 20.0); // Up to +5%
    baseProb += (rel.respect / 40.0); // Up to +2.5%

    // Target receptivity (based on their intensity)
    switch (target.religionIntensity) {
      case ReligionIntensity.agnostic:
      case ReligionIntensity.atheist:
        baseProb *= 3.0; // Agnostics/atheists are easiest to convert
        break;
      case ReligionIntensity.syncretic:
      case ReligionIntensity.normal:
        baseProb *= 1.5; // Normal believers are somewhat receptive
        break;
      case ReligionIntensity.fervent:
        baseProb *= 0.1; // Fervent believers are very resistant
        break;
    }

    return baseProb.clamp(0.0, 0.9);
  }

  /// Execute proselytization attempt
  static Map<String, dynamic> executeProselytization(
      Soldier proselytizer, Soldier target, GameState gameState) {
    double successProb =
        getConversionSuccessProbability(proselytizer, target, gameState);
    bool success = _random.nextDouble() < successProb;

    final rel = target.getRelationship(proselytizer.id);

    if (success) {
      // Successful conversion
      ReligionType oldReligion = target.religionType;
      ReligionIntensity oldIntensity = target.religionIntensity;

      target.religionType = proselytizer.religionType;

      // Preserve intensity level (fanatics stay fanatics, agnostics stay agnostics)
      switch (oldIntensity) {
        case ReligionIntensity.atheist:
        case ReligionIntensity.agnostic:
          target.religionIntensity =
              ReligionIntensity.normal; // Become normal believer
          break;
        case ReligionIntensity.fervent:
          target.religionIntensity =
              ReligionIntensity.fervent; // Fanatic → fanatic (of new religion)
          break;
        case ReligionIntensity.normal:
        case ReligionIntensity.syncretic:
          target.religionIntensity = oldIntensity; // Keep same level
          break;
      }

      // Relationship boost
      rel.updateAdmiration(0.2);
      rel.updateRespect(0.1);

      return {
        'success': true,
        'oldReligion': oldReligion,
        'newReligion': target.religionType,
        'oldIntensity': oldIntensity,
        'newIntensity': target.religionIntensity,
      };
    } else {
      // Failed conversion
      // Slight relationship penalty
      rel.updateAdmiration(-0.05);

      // If target is fervent, they may become more intense in their own faith
      if (target.religionIntensity == ReligionIntensity.fervent &&
          _random.nextDouble() < 0.3) {
        // Already at max intensity, just note it
        return {
          'success': false,
          'intensified': true,
        };
      }

      return {
        'success': false,
        'intensified': false,
      };
    }
  }

  /// Generate description for proselytization event
  static String generateProselytizationDescription(
      Soldier proselytizer, Soldier target, Map<String, dynamic> result) {
    if (result['success']) {
      return "${proselytizer.name} successfully converted ${target.name} to ${result['newReligion'].toString().split('.').last}.";
    } else if (result['intensified'] == true) {
      return "${proselytizer.name} tried to convert ${target.name}, but it only strengthened ${target.name}'s faith in ${target.religionType.toString().split('.').last}.";
    } else {
      return "${proselytizer.name} tried to convert ${target.name} to ${proselytizer.religionType.toString().split('.').last}, but failed.";
    }
  }
}
