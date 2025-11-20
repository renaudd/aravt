// models/combat_report.dart
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/game_date.dart';

class LootReport {
  final int currency;
  final Map<String, int> items; // Key: itemID, Value: quantity

  const LootReport({
    this.currency = 0,
    this.items = const {},
  });

  bool get isEmpty => currency == 0 && items.isEmpty;
  bool get isNotEmpty => !isEmpty;

  factory LootReport.empty() => const LootReport();

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'items': items,
      };

  factory LootReport.fromJson(Map<String, dynamic> json) {
    return LootReport(
      currency: json['currency'] ?? 0,
      items: (json['items'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value as int)) ??
          const {},
    );
  }
}

class CombatReport {
  final String id;
  final GameDate date;
  final CombatResult result;
  final List<CombatReportSoldierSummary> playerSoldiers;
  final List<CombatReportSoldierSummary> enemySoldiers;
  final LootReport lootObtained;
  final LootReport lootLost;

  final List<Soldier> captives;
  // [GEMINI-NEW] Turn number for highlighting
  final int turn;

  CombatReport({
    required this.id,
    required this.date,
    required this.result,
    required this.playerSoldiers,
    required this.enemySoldiers,
    this.lootObtained = const LootReport(),
    this.lootLost = const LootReport(),
    this.captives = const [],
    this.turn = 0, // Default for migration
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toJson(),
        'result': result.name,
        'playerSoldiers': playerSoldiers.map((s) => s.toJson()).toList(),
        'enemySoldiers': enemySoldiers.map((s) => s.toJson()).toList(),
        'lootObtained': lootObtained.toJson(),
        'lootLost': lootLost.toJson(),
        'captiveIds': captives.map((s) => s.id).toList(),
        'turn': turn,
      };

  factory CombatReport.fromJson(
      Map<String, dynamic> json, Map<int, Soldier> soldierMap) {
    return CombatReport(
      id: json['id'],
      date: GameDate.fromJson(json['date']),
      result: combatResultFromName(json['result']),
      playerSoldiers: (json['playerSoldiers'] as List)
          .map((s) => CombatReportSoldierSummary.fromJson(s, soldierMap))
          .toList(),
      enemySoldiers: (json['enemySoldiers'] as List)
          .map((s) => CombatReportSoldierSummary.fromJson(s, soldierMap))
          .toList(),
      lootObtained: LootReport.fromJson(json['lootObtained']),
      lootLost: LootReport.fromJson(json['lootLost']),
      captives: (json['captiveIds'] as List)
          .map((id) => soldierMap[id])
          .whereType<Soldier>()
          .toList(),
      turn: json['turn'] ?? 0,
    );
  }

  // --- Helper Getters ---
  int get playerInitialCount => playerSoldiers.length;
  int get enemyInitialCount => enemySoldiers.length;

  int getPlayerCount(SoldierStatus status) =>
      playerSoldiers.where((s) => s.finalStatus == status).length;
  int getEnemyCount(SoldierStatus status) =>
      enemySoldiers.where((s) => s.finalStatus == status).length;

  int get playerKills => playerSoldiers.fold(0, (prev, s) => prev + s.kills);
  int get enemyKills => enemySoldiers.fold(0, (prev, s) => prev + s.kills);

  bool get hasCaptivesToProcess =>
      (result == CombatResult.playerVictory ||
          result == CombatResult.enemyRout) &&
      captives.isNotEmpty;
}

class CombatReportSoldierSummary {
  final Soldier originalSoldier;
  final List<Soldier> defeatedSoldiers;

  final SoldierStatus finalStatus;
  final List<Injury> injuriesSustained;
  final bool wasUnconscious;

  // --- MODIFIED: This is the fix for Issue #1 ---
  // The old getter was checking the status of soldiers whose status
  // hadn't been updated yet. If they are in this list, they are a kill.
  int get kills => defeatedSoldiers.length;
  // --- END MODIFIED ---

  const CombatReportSoldierSummary({
    required this.originalSoldier,
    required this.finalStatus,
    required this.injuriesSustained,
    this.defeatedSoldiers = const [],
    required this.wasUnconscious,
  });

  Map<String, dynamic> toJson() => {
        'originalSoldierId': originalSoldier.id,
        'defeatedSoldierIds': defeatedSoldiers.map((s) => s.id).toList(),
        'finalStatus': finalStatus.name,
        'injuriesSustained': injuriesSustained.map((i) => i.toJson()).toList(),
        'wasUnconscious': wasUnconscious,
      };

  factory CombatReportSoldierSummary.fromJson(
      Map<String, dynamic> json, Map<int, Soldier> soldierMap) {
    final Soldier? original = soldierMap[json['originalSoldierId']];
    final List<Soldier> defeated = (json['defeatedSoldierIds'] as List)
        .map((id) => soldierMap[id])
        .whereType<Soldier>()
        .toList();

    if (original == null) {
      throw Exception(
          "Could not find original soldier with ID ${json['originalSoldierId']} when loading combat report.");
    }

    return CombatReportSoldierSummary(
      originalSoldier: original,
      defeatedSoldiers: defeated,
      finalStatus: soldierStatusFromName(json['finalStatus']),
      injuriesSustained: (json['injuriesSustained'] as List)
          .map((i) => Injury.fromJson(i))
          .toList(),
      wasUnconscious: json['wasUnconscious'],
    );
  }
}
