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

class LoyaltyService {
  /// Updates the loyalty of [subject] towards [targetId] by [amount].
  /// Also applies diffuse loss to other top loyalties if [amount] is positive.
  static void updateLoyalty(Soldier subject, int targetId, double amount) {
    // 1. Update target loyalty
    var targetRel = subject.getRelationship(targetId);
    double actualGain = targetRel.updateLoyalty(amount);

    // If actual gain is positive, apply diffuse loss
    if (actualGain > 0) {
      _applyDiffuseLoss(subject, targetId, actualGain);
    }
  }

  static void _applyDiffuseLoss(
      Soldier subject, int targetId, double gainAmount) {
    // Loss amount per other entity (25% of gain)
    double lossAmount = gainAmount * 0.25;

    // Collect all loyalties from horde relationships
    List<MapEntry<int, double>> allLoyalties = [];

    subject.hordeRelationships.forEach((id, rel) {
      if (id != targetId && rel.loyalty > 0) {
        allLoyalties.add(MapEntry(id, rel.loyalty));
      }
    });

    // Sort by loyalty descending
    allLoyalties.sort((a, b) => b.value.compareTo(a.value));

    // Take top 4
    var top4 = allLoyalties.take(4);

    // Apply loss
    for (var entry in top4) {
      subject.getRelationship(entry.key).updateLoyalty(-lossAmount);
    }
  }
}
