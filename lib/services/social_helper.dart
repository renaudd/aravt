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

class SocialHelper {
  /// Calculates the actual change to apply based on current value and raw change amount.
  /// Uses a bell curve damping to reduce effect at extremes (0 and 5).
  ///
  /// At 2.5 (center), multiplier is 1.0.
  /// At 0.0 or 5.0 (extremes), multiplier is ~0.2.
  static double calculateDampedChange(double currentValue, double rawChange) {
    // Normalized distance from center (0.0 to 1.0)
    // 2.5 -> 0 distance
    // 0.0 or 5.0 -> 1.0 distance
    double dist = (currentValue - 2.5).abs() / 2.5;

    // Bell curve approximation: 0.2 + 0.8 * (1 - dist^2)
    double multiplier = 0.2 + 0.8 * (1.0 - (dist * dist));

    return rawChange * multiplier;
  }
}
