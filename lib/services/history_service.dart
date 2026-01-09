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

import 'package:aravt/models/history_models.dart';
import 'package:aravt/providers/game_state.dart';

import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/horde_data.dart';

class HistoryService {
  final List<DailySnapshot> _history = [];

  List<DailySnapshot> get history => List.unmodifiable(_history);

  // Constants for "Perception" noise
  // Without a dedicated intelligence system, we simulate uncertainty based on role/distance
  static const double _baseUncertainty =
      0.15; // +/- 15% error for standard soldiers

  void recordDailySnapshot(GameState gameState) {
    if (gameState.currentDate == null) return;

    final List<EntitySnapshot> entitySnapshots = [];

    // 1. Horde Level Snapshot (ID: "horde")
    entitySnapshots.add(_createHordeSnapshot(gameState));

    // 2. Aravt Level Snapshots
    for (final aravt in gameState.aravts) {
      entitySnapshots.add(_createAravtSnapshot(gameState, aravt));
    }

    // 3. Soldier Level Snapshots
    for (final soldier in gameState.horde) {
      entitySnapshots.add(_createSoldierSnapshot(gameState, soldier));
    }

    // Add to history
    _history.add(DailySnapshot(
      turnNumber: gameState.turn.turnNumber,
      date: gameState.gameDate,
      entities: entitySnapshots,
    ));

    // Pruning (Optional: Keep last 365 days? Or keep all for now as per plan)
    // if (_history.length > 730) _history.removeAt(0);
  }

  EntitySnapshot _createHordeSnapshot(GameState gameState) {
    final Map<MetricType, MetricValue> metrics = {};

    // Wealth
    // Calculate total horde wealth including communal resources and player treasure
    double totalTreasure = (gameState.player?.treasureWealth ?? 0);
    // Add up everyone's personal treasure? Maybe just player + communal logic?
    // User requested: "horde treasure wealth in cash (rupee count), and horde debts and loans"
    metrics[MetricType.rupees] = _createValue(gameState.communalRupees);
    metrics[MetricType.treasureWealth] =
        _createValue(totalTreasure); // Player is banker?

    // Supply
    metrics[MetricType.scrap] = _createValue(gameState.communalScrap);
    metrics[MetricType.wood] = _createValue(gameState.communalWood);
    metrics[MetricType.iron] = _createValue(gameState.communalIronOre);
    metrics[MetricType.arrows] = _createValue(
        (gameState.communalShortArrows + gameState.communalLongArrows)
            .toDouble());

    // Herd
    metrics[MetricType.horses] =
        _createValue(gameState.communalHerd.length.toDouble());
    metrics[MetricType.cattle] =
        _createValue(gameState.communalCattle.totalPopulation.toDouble());

    // Horde Size
    metrics[MetricType.population] =
        _createValue(gameState.horde.length.toDouble());

    // Food
    metrics[MetricType.meat] = _createValue(gameState.communalMeat);
    metrics[MetricType.grain] = _createValue(gameState.communalGrain);
    metrics[MetricType.dairy] =
        _createValue(gameState.communalMilk + gameState.communalCheese);

    // Aggregates (Averages across entire horde)
    // We track averages relative to the Player/Leader
    final int leaderId = gameState.player?.id ?? -1;

    metrics[MetricType.fear] = _createAverage(
        gameState.horde, (s) => _getRelValue(s, leaderId, (r) => r.fear));
    metrics[MetricType.admiration] = _createAverage(
        gameState.horde, (s) => _getRelValue(s, leaderId, (r) => r.admiration));
    metrics[MetricType.respect] = _createAverage(
        gameState.horde, (s) => _getRelValue(s, leaderId, (r) => r.respect));
    metrics[MetricType.loyalty] = _createAverage(
        gameState.horde, (s) => _getRelValue(s, leaderId, (r) => r.loyalty));
    metrics[MetricType.morale] =
        _createAverage(gameState.horde, (s) => 10.0 - s.stress); // Morale proxy

    return EntitySnapshot(entityId: "horde", metrics: metrics);
  }

  EntitySnapshot _createAravtSnapshot(GameState gameState, Aravt aravt) {
    final Map<MetricType, MetricValue> metrics = {};
    final soldiers = gameState.horde.where((s) => s.aravt == aravt.id).toList();
    final int leaderId = gameState.player?.id ?? -1;

    // Size
    metrics[MetricType.population] = _createValue(soldiers.length.toDouble());

    // Aggregates
    metrics[MetricType.fear] = _createAverage(
        soldiers, (s) => _getRelValue(s, leaderId, (r) => r.fear));
    metrics[MetricType.admiration] = _createAverage(
        soldiers, (s) => _getRelValue(s, leaderId, (r) => r.admiration));
    metrics[MetricType.respect] = _createAverage(
        soldiers, (s) => _getRelValue(s, leaderId, (r) => r.respect));
    metrics[MetricType.loyalty] = _createAverage(
        soldiers, (s) => _getRelValue(s, leaderId, (r) => r.loyalty));

    metrics[MetricType.morale] =
        _createAverage(soldiers, (s) => 10.0 - s.stress);
    metrics[MetricType.health] = _createAverage(
        soldiers,
        (s) => s.healthMax
            .toDouble()); // healthMax vs current? Using Max as base stat.

    // Wealth (Sum of members)
    double aravtApparentWealth = 0;
    for (var s in soldiers) {
      aravtApparentWealth += s.treasureWealth + s.suppliesWealth;
    }
    metrics[MetricType.totalWealth] = _createValue(aravtApparentWealth);

    return EntitySnapshot(entityId: aravt.id, metrics: metrics);
  }

  EntitySnapshot _createSoldierSnapshot(GameState gameState, Soldier soldier) {
    final Map<MetricType, MetricValue> metrics = {};
    final int leaderId = gameState.player?.id ?? -1;

    // Social
    metrics[MetricType.fear] = _createPerceivedValue(
        _getRelValue(soldier, leaderId, (r) => r.fear), _baseUncertainty);
    metrics[MetricType.admiration] = _createPerceivedValue(
        _getRelValue(soldier, leaderId, (r) => r.admiration), _baseUncertainty);
    metrics[MetricType.respect] = _createPerceivedValue(
        _getRelValue(soldier, leaderId, (r) => r.respect), _baseUncertainty);
    metrics[MetricType.loyalty] = _createPerceivedValue(
        _getRelValue(soldier, leaderId, (r) => r.loyalty), _baseUncertainty);

    // Stats
    metrics[MetricType.morale] =
        _createPerceivedValue(10.0 - soldier.stress, 0.05);
    metrics[MetricType.health] = _createValue(soldier.healthMax.toDouble());
    metrics[MetricType.stamina] = _createValue(soldier.stamina.toDouble());

    // Combat - Use experience as rating proxy since kills isn't available
    metrics[MetricType.combatRating] =
        _createValue(soldier.experience.toDouble());

    // Personal Wealth
    metrics[MetricType.supplyWealth] = _createValue(soldier.suppliesWealth);
    metrics[MetricType.treasureWealth] = _createValue(soldier.treasureWealth);

    return EntitySnapshot(entityId: soldier.id.toString(), metrics: metrics);
  }

  double _getRelValue(Soldier soldier, int targetId,
      double Function(RelationshipValues) selector) {
    if (soldier.hordeRelationships.containsKey(targetId)) {
      return selector(soldier.hordeRelationships[targetId]!);
    }
    return 2.5; // Default neutral
  }

  // Helper for "Exact" values (Horde resources, etc. are known by logkeepers)
  MetricValue _createValue(double val) {
    return MetricValue(
      trueValue: val,
      perceivedValue: val,
      perceivedMin: val,
      perceivedMax: val,
    );
  }

  // Helper for "Fuzzy" values (Social stats)
  MetricValue _createPerceivedValue(double val, double uncertaintyPercent) {
    // Generate a consistent "perceived" value (mocked as true with range for now)
    // In a real system, perceivedValue would be stored/drifted.
    // Here we define the *band* the player sees.
    double noise = val * uncertaintyPercent;
    return MetricValue(
      trueValue: val,
      perceivedValue: val, // Center of the band is true for now
      perceivedMin: val - noise,
      perceivedMax: val + noise,
    );
  }

  MetricValue _createAverage(
      List<Soldier> soldiers, double Function(Soldier) selector) {
    if (soldiers.isEmpty) return _createValue(0);
    double sum = 0;
    for (var s in soldiers) {
      sum += selector(s);
    }
    double avg = sum / soldiers.length;
    return _createValue(avg);
  }
}
