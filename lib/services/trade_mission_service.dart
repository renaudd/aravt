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
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/horde_data.dart';

class TradeMissionService {
  static double calculateCarryingCapacity(
      Aravt aravt, List<Soldier> allSoldiers) {
    double capacity = 0.0;
    for (var soldierId in aravt.soldierIds) {
      final soldier = allSoldiers.firstWhere((s) => s.id == soldierId);
      // Base capacity per soldier (minimal)
      capacity += 10.0;
      // Mount capacity
      if (soldier.equippedItems.containsKey(EquipmentSlot.mount)) {
        final mount = soldier.equippedItems[EquipmentSlot.mount] as Mount?;
        if (mount != null) {
          capacity += 100.0; // Example capacity per mount
        }
      }
    }
    return capacity;
  }

  static double calculateEncumbrance(double load, double capacity) {
    if (capacity == 0) return 1.0;
    return (load / capacity).clamp(0.0, 1.0);
  }

  static double calculateTravelTimeMultiplier(double encumbrance) {
    // 0% encumbrance = 1.0x time
    // 100% encumbrance = 2.0x time
    return 1.0 + encumbrance;
  }
}
