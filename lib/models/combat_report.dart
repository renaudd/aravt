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

// models/combat_report.dart
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/inventory_item.dart';

class LootEntry {
  final int soldierId;
  final String soldierName;
  final InventoryItem item;

  const LootEntry({
    required this.soldierId,
    required this.soldierName,
    required this.item,
  });

  Map<String, dynamic> toJson() => {
        'soldierId': soldierId,
        'soldierName': soldierName,
        'item': item.toJson(),
      };

  factory LootEntry.fromJson(Map<String, dynamic> json) {
    return LootEntry(
      soldierId: json['soldierId'],
      soldierName: json['soldierName'],
      item: InventoryItem.fromJson(json['item']),
    );
  }
}

class LootReport {
  final int currency;
  final List<LootEntry> entries;

  const LootReport({
    this.currency = 0,
    this.entries = const [],
  });

  bool get isEmpty => currency == 0 && entries.isEmpty;
  bool get isNotEmpty => !isEmpty;

  factory LootReport.empty() => const LootReport();

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory LootReport.fromJson(Map<String, dynamic> json) {
    return LootReport(
      currency: json['currency'] ?? 0,
      entries: (json['entries'] as List?)
              ?.map((e) => LootEntry.fromJson(e))
              .toList() ??
          const [],
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
  // Turn number for highlighting
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
  int get kills => defeatedSoldiers.length;

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
