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

import 'package:aravt/models/soldier_data.dart';

/// The specific type of unassigned action a soldier might take.
enum UnassignedActionType {
  // Social & Interpersonal
  barter,
  startFight,
  murderAttempt,
  lodgeRequest,
  socialInteraction, // (insult, compliment, joke)
  zodiacInteraction, // Zodiac-based social interaction
  gossip,
  giveAdvice,
  proselytize,
  giftItem,
  // Trait & Skill Based
  traitActionSurgeon, // (e.g., cut hair)
  traitActionFalconer, // (e.g., bait birds)
  tendHorses,
  playGame,

  // Responsive & Default
  responsiveAction, // (e.g., mourning, fasting)
  spreadDisease,
  divulgeInfoToPlayer, // (Default for player's aravt)
  idle, // (Does nothing)

  // Murder methods (specific types)
  murderFight, // Fight to kill
  murderSleep, // Stab in sleep
  murderPoison, // Poisoning
  murderAccident, // Disguised as accident
}

/// Represents a single possible action in a soldier's "event chart"
/// Each soldier will generate a list of these, and one will be chosen.
class SoldierActionProposal {
  final UnassignedActionType actionType;
  final Soldier soldier;
  final double probability; // A weighting for this action
  // Optional targets or context
  final int? targetSoldierId;
  final String? contextData; // (e.g., item to barter, piece of gossip)

  SoldierActionProposal({
    required this.actionType,
    required this.soldier,
    required this.probability,
    this.targetSoldierId,
    this.contextData,
  });
}
