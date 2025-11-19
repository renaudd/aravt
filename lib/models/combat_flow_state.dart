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

