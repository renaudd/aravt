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

import 'package:flutter_test/flutter_test.dart';
import 'package:aravt/models/soldier_data.dart';

void main() {
  group('Soldier Combat Point Value Tests', () {
    test('calculateCombatPointValue weighs stats correctly', () {
      final soldier = SoldierGenerator.generateNewSoldier(
        id: 1,
        aravt: 'Test',
        overrideStrength: 10,
        overrideIntelligence: 10,
      );

      final weakSoldier = SoldierGenerator.generateNewSoldier(
        id: 2,
        aravt: 'Test',
        overrideStrength: 1,
        overrideIntelligence: 1,
      );

      expect(soldier.calculateCombatPointValue(),
          greaterThan(weakSoldier.calculateCombatPointValue()));
    });

    test('calculateCombatPointValue accounts for skills', () {
      final archer = SoldierGenerator.generateNewSoldier(
        id: 3,
        aravt: 'Test',
        overrideLongRangeArchery: 10,
        overrideMountedArchery: 10,
      );

      final recruit = SoldierGenerator.generateNewSoldier(
        id: 4,
        aravt: 'Test',
        overrideLongRangeArchery: 1,
        overrideMountedArchery: 1,
      );

      expect(archer.calculateCombatPointValue(),
          greaterThan(recruit.calculateCombatPointValue()));
    });
  });
}
