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
