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

// lib/models/combat_flow_state.dart

/// Defines the current UI flow state for a combat encounter.
enum CombatFlowState {
  /// No combat is active, pending, or being reported. The player is in the main game.
  none,

  /// Combat has been initiated, but not started. The PreCombatScreen should be shown.
  preCombat,

  /// Combat is actively in progress. The CombatScreen should be shown.
  inCombat,

  /// Combat has finished. The PostCombatReportScreen should be shown.
  postCombat,
}
