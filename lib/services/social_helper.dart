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
