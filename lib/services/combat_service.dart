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

import 'dart:math';
import 'dart:ui' show Offset;

import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/models/combat_report.dart';

import 'package:aravt/models/horde_data.dart' show Aravt;

import 'package:aravt/services/loot_distribution_service.dart';
import 'package:aravt/services/injury_service.dart';
import 'package:aravt/models/location_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/area_data.dart';

enum CombatFormation { tight, loose, noPreference }

enum CombatTactic {
  maintainDistance,
  harassMounted,
  chargeSpears,
  feignedFlight,
  takeCover,
  layAmbush,
  noPreference
}

enum EngagementRule {
  fleeImmediately,
  fleeOutnumbered,
  fleeOnSevereWound,
  fleeOnCasualties,
  dontFlee,
  fightToDeath
}

class AravtCombatInstructions {
  CombatFormation formation = CombatFormation.noPreference;
  CombatTactic tactic = CombatTactic.noPreference;
  EngagementRule engagement = EngagementRule.dontFlee;
}

enum TerrainType {
  plains,
  hills,
  waterShallow,
  waterDeep,
  trees,
  rocks,
  building,
  mountainFace
}

class BattlefieldTile {
  final int x, y;
  TerrainType terrain;
  BattlefieldTile(
      {required this.x, required this.y, this.terrain = TerrainType.plains});
  bool get isPassable =>
      terrain != TerrainType.mountainFace &&
      terrain != TerrainType.waterDeep &&
      terrain != TerrainType.trees &&
      terrain != TerrainType.rocks &&
      terrain != TerrainType.building;
  bool get providesCover =>
      terrain == TerrainType.trees ||
      terrain == TerrainType.rocks ||
      terrain == TerrainType.building ||
      terrain == TerrainType.hills;
  double get movementCost {
    switch (terrain) {
      case TerrainType.hills:
        return 1.5;
      case TerrainType.waterShallow:
        return 3.0;
      case TerrainType.plains:
        return 1.0;
      case TerrainType.waterDeep:
      case TerrainType.trees:
      case TerrainType.rocks:
      case TerrainType.building:
      case TerrainType.mountainFace:
        return 999.0;
    }
  }
}

class BattlefieldState {
  final int width = 1000;
  final int length = 500;
  late List<List<BattlefieldTile>> grid;

  BattlefieldState() {
    grid = List.generate(width,
        (x) => List.generate(length, (y) => BattlefieldTile(x: x, y: y)));
    _generateTerrain();
  }

  void _generateTerrain() {
    final r = Random();

    // 1. Generate Clustered Terrain
    void createCluster(int count, TerrainType type, double chance) {
      for (int i = 0; i < count; i++) {
        if (r.nextDouble() < chance) {
          int centerX = r.nextInt(width);
          int centerY = r.nextInt(length);
          int radius = r.nextInt(3) + 2; // Cluster size 2-5

          for (int dx = -radius; dx <= radius; dx++) {
            for (int dy = -radius; dy <= radius; dy++) {
              int tx = centerX + dx;
              int ty = centerY + dy;
              if (tx >= 0 && tx < width && ty >= 0 && ty < length) {
                // Circular grouping roughly
                if (dx * dx + dy * dy <= radius * radius) {
                  grid[tx][ty].terrain = type;
                }
              }
            }
          }
        }
      }
    }

    createCluster(15, TerrainType.hills, 0.8);
    createCluster(20, TerrainType.trees, 0.7);
    createCluster(10, TerrainType.rocks, 0.6);

    // 2. Clear Engagement Zone (Center)
    int centerY = length ~/ 2;
    for (int x = 0; x < width; x++) {
      for (int y = centerY - 60; y < centerY + 60; y++) {
        if (y >= 0 && y < length) {
          // Leave some sparse hills/trees in center but mostly plains
          if (r.nextDouble() < 0.95) {
            grid[x][y].terrain = TerrainType.plains;
          }
        }
      }
    }
    print("Generated clustered terrain.");
  }

  BattlefieldTile? getTile(int x, int y) {
    if (x >= 0 && x < width && y >= 0 && y < length) return grid[x][y];
    return null;
  }

  List<Offset> findPath(Offset start, Offset end) => [start, end];
  bool hasLineOfSight(Offset start, Offset end) => true;
}

class CombatSoldier {
  final Soldier soldier;
  final int teamId;
  final String aravtId;
  final bool isCaptain;
  final String color;

  double x, y;
  double targetX, targetY;
  int initiative;
  double currentExhaustion;
  double currentStress;
  CombatSoldier? currentTarget;
  bool isFleeing = false;
  int arrowsRemaining = 20;
  int spearsRemaining = 2;
  int headHealthCurrent,
      bodyHealthCurrent,
      rightArmHealthCurrent,
      leftArmHealthCurrent,
      rightLegHealthCurrent,
      leftLegHealthCurrent;
  List<Injury> injuriesSustained = [];
  CombatSoldier? captain;
  double currentBleedingRate = 0.0;
  int turnsStunnedRemaining = 0;
  bool isUnconscious = false;
  bool hasFled = false;
  AravtCombatInstructions instructions = AravtCombatInstructions();
  int kills = 0;

  List<Soldier> defeatedSoldiers = [];

  int get captainLeadership =>
      captain?.soldier.leadership ?? soldier.leadership;
  bool get isAlive =>
      !isUnconscious &&
      headHealthCurrent > 0 &&
      bodyHealthCurrent > 0 &&
      !hasFled;
  bool get isMounted => soldier.equippedItems.containsKey(EquipmentSlot.mount);
  Mount? get mount => soldier.equippedItems[EquipmentSlot.mount] as Mount?;
  Offset get positionVector => Offset(x, y);

  // Equipment Accessors
  bool get hasBow =>
      soldier.equippedItems.values.any((i) => i.itemType == ItemType.bow);
  bool get hasSpear =>
      soldier.equippedItems.values.any((i) => i.itemType == ItemType.spear);
  bool get hasSword =>
      soldier.equippedItems.values.any((i) => i.itemType == ItemType.sword);
  bool get hasShield =>
      soldier.equippedItems.values.any((i) => i.itemType == ItemType.shield);

  CombatSoldier({
    required this.soldier,
    required this.teamId,
    required this.aravtId,
    required this.x,
    required this.y,
    this.isCaptain = false,
    this.initiative = 0,
    required this.color,
  })  : currentExhaustion = 1.0,
        currentStress = soldier.stress.toDouble(),
        targetX = x,
        targetY = y,
        headHealthCurrent = soldier.headHealthCurrent,
        bodyHealthCurrent = soldier.bodyHealthCurrent,
        rightArmHealthCurrent = soldier.rightArmHealthCurrent,
        leftArmHealthCurrent = soldier.leftArmHealthCurrent,
        rightLegHealthCurrent = soldier.rightLegHealthCurrent,
        leftLegHealthCurrent = soldier.leftLegHealthCurrent;

  double get currentMovementSpeed {
    if (!isAlive || turnsStunnedRemaining > 0) return 0.0;

    double base = isMounted ? (mount?.speed.toDouble() ?? 5.0) * 6.0 : 4.0;

    double penaltyFactor = 1.0;
    if (currentExhaustion > 2.0) {
      penaltyFactor -= (currentExhaustion - 2.0).clamp(0.0, 1.0) * 0.1;
    }
    if (currentExhaustion > 3.0) {
      penaltyFactor -= (currentExhaustion - 3.0).clamp(0.0, 1.0) * 0.2;
    }
    if (currentExhaustion > 4.0) {
      penaltyFactor -= (currentExhaustion - 4.0).clamp(0.0, 1.0) * 0.3;
    }
    base *= penaltyFactor.clamp(0.1, 1.0);

    bool legInjured =
        soldier.startingInjury == StartingInjuryType.limpRightLeg ||
            injuriesSustained.any((i) =>
                (i.location == HitLocation.leftLeg ||
                    i.location == HitLocation.rightLeg) &&
                i.severity >= 3);
    bool backInjured =
        soldier.startingInjury == StartingInjuryType.chronicBackPain;
    if (legInjured) base *= 0.8;
    if (backInjured) base *= 0.9;
    return max(0.0, base);
  }

  void takeDamage(HitLocation loc, int amt) {
    if (!isAlive && !isUnconscious) return;
    switch (loc) {
      case HitLocation.head:
        headHealthCurrent = max(0, headHealthCurrent - amt);
        break;
      case HitLocation.body:
        bodyHealthCurrent = max(0, bodyHealthCurrent - amt);
        break;
      case HitLocation.leftArm:
        leftArmHealthCurrent = max(0, leftArmHealthCurrent - amt);
        break;
      case HitLocation.rightArm:
        rightArmHealthCurrent = max(0, rightArmHealthCurrent - amt);
        break;
      case HitLocation.leftLeg:
        leftLegHealthCurrent = max(0, leftLegHealthCurrent - amt);
        break;
      case HitLocation.rightLeg:
        rightLegHealthCurrent = max(0, rightLegHealthCurrent - amt);
        break;
    }
    if (!isAlive && (headHealthCurrent <= 0 || bodyHealthCurrent <= 0)) {
      print("Soldier ${soldier.id} potentially killed or knocked out...");
    }
  }

  void addInjury(Injury injury, GameState gameState) {
    if (!isAlive && !isUnconscious) return;
    injuriesSustained.add(injury);
    // print("Soldier ${soldier.id} sustained: ${injury.name}");
    currentBleedingRate += injury.bleedingRate;
    turnsStunnedRemaining = max(turnsStunnedRemaining, injury.stunDuration);

    gameState.logEvent(
        "${soldier.name} suffers: ${injury.name} (from ${injury.inflictedBy})!",
        category: EventCategory.health,
        severity:
            injury.severity >= 3 ? EventSeverity.critical : EventSeverity.high,
        soldierId: soldier.id,
        aravtId: aravtId);

    if (injury.severity >= 3 && Random().nextDouble() < 0.5) {
      // 50% chance of unconsciousness on severe injury
      injury.causesUnconsciousness = true;
    }

    if (injury.causesUnconsciousness && isAlive) {
      isUnconscious = true;
      headHealthCurrent = max(1, headHealthCurrent);
      gameState.logEvent("${soldier.name} is knocked unconscious!",
          category: EventCategory.combat,
          severity: EventSeverity.high,
          soldierId: soldier.id);
    }
    if (injury.causesLimbLoss) {
      bool limbAlreadyLost = false;
      switch (injury.location) {
        case HitLocation.leftArm:
          if (leftArmHealthCurrent == 0) limbAlreadyLost = true;
          leftArmHealthCurrent = 0;
          break;
        case HitLocation.rightArm:
          if (rightArmHealthCurrent == 0) limbAlreadyLost = true;
          rightArmHealthCurrent = 0;
          break;
        case HitLocation.leftLeg:
          if (leftLegHealthCurrent == 0) limbAlreadyLost = true;
          leftLegHealthCurrent = 0;
          break;
        case HitLocation.rightLeg:
          if (rightLegHealthCurrent == 0) limbAlreadyLost = true;
          rightLegHealthCurrent = 0;
          break;
        case HitLocation.head:
          headHealthCurrent = 0;
          break;
        case HitLocation.body:
          bodyHealthCurrent = 0;
          break;
      }
      if (!limbAlreadyLost) {
        gameState.logEvent(
            "${soldier.name} loses their ${injury.location.name}!",
            category: EventCategory.health,
            severity: EventSeverity.critical,
            soldierId: soldier.id);
      }
    }
  }

  void applyEndOfTurnEffects(
      int currentTurn, GameState gameState, CombatSimulator simulator) {
    if (!isAlive && !isUnconscious) return;

    if (currentBleedingRate > 0 && (isAlive || isUnconscious)) {
      int bleedDmg = currentBleedingRate.round();
      if (bleedDmg > 0) {
        takeDamage(HitLocation.body, bleedDmg);
        gameState.logEvent("${soldier.name} bleeds for $bleedDmg dmg.",
            category: EventCategory.health,
            severity: EventSeverity.normal,
            soldierId: soldier.id);

        if (!isAlive && (headHealthCurrent <= 0 || bodyHealthCurrent <= 0)) {
          final Injury bleedOutInjury = Injury(
            name: "Bled Out",
            location: HitLocation.body,
            severity: 4,
            turnSustained: currentTurn,
            hpDamageMin: 99,
            hpDamageMax: 99,
            inflictedBy: "Wounds",
            bleedingRate: 0,
            stunDuration: 0,
            causesUnconsciousness: true,
            causesLimbLoss: true,
          );
          addInjury(bleedOutInjury, gameState);
          simulator._killSoldier(this, "bleeding out", gameState);
          return;
        }
      }
    }
    if ((isAlive || isUnconscious) && turnsStunnedRemaining > 0) {
      turnsStunnedRemaining--;
      if (turnsStunnedRemaining == 0) {
        gameState.logEvent("${soldier.name} recovers from stun.",
            category: EventCategory.combat,
            severity: EventSeverity.low,
            soldierId: soldier.id);
      }
    }
  }
}

class CombatSimulator {
  late BattlefieldState _battlefield;
  final List<CombatSoldier> _allCombatSoldiers = [];
  final Map<String, List<CombatSoldier>> _aravtsMap = {};
  final Map<String, CombatSoldier> _captainsMap = {};
  int _turn = 0;
  List<String> _turnOrder = [];
  int _currentTurnIndex = 0;
  final Random _random = Random();
  late GameState _gameState;

  static const List<String> playerColors = [
    'red',
    'blue',
    'green',
    'kellygreen'
  ];
  static const List<String> npcColors = ['purple', 'teal', 'pink', 'yellow'];

  final List<String> _availablePlayerColors =
      List.from(CombatSimulator.playerColors);
  final List<String> _availableNpcColors = List.from(CombatSimulator.npcColors);
  final Map<String, String> _aravtColorMap = {};
  final List<String> _combatLog = [];

  static const double FLEE_CASUALTY_WEIGHT = 0.4;
  static const double FLEE_INJURY_WEIGHT = 0.3;
  static const double FLEE_EXHAUSTION_WEIGHT = 0.15;
  static const double FLEE_STRESS_WEIGHT = 0.15;
  static const double FLEE_BASE_THRESHOLD = 0.60;
  static const double MAX_HEALTH_ESTIMATE = 90.0;

  List<CombatSoldier> get allCombatSoldiers => _allCombatSoldiers;
  BattlefieldState get battlefield => _battlefield;
  int get currentTurn => _turn;

  CombatSimulator();

  void startCombat(List<Aravt> playerAravts, List<Aravt> enemyAravts,
      List<Soldier> allSoldiers, GameState gameState) {
    _allCombatSoldiers.clear();
    _aravtsMap.clear();
    _captainsMap.clear();
    _turn = 1;
    _currentTurnIndex = 0;
    _turnOrder = [];
    _gameState = gameState;
    _availablePlayerColors.clear();
    _availablePlayerColors.addAll(CombatSimulator.playerColors);
    _availableNpcColors.clear();
    _availableNpcColors.addAll(CombatSimulator.npcColors);
    _aravtColorMap.clear();

    _battlefield = BattlefieldState();
    _assignAravtColors(playerAravts, true);
    _assignAravtColors(enemyAravts, false);

    _initializeUnits(playerAravts, 0, allSoldiers);
    _initializeUnits(enemyAravts, 1, allSoldiers);
    _assignCaptainReferences();
    _calculateInitiative();

    _logMessage("Combat started!",
        isInternal: false, severity: EventSeverity.high);
    if (_turnOrder.isNotEmpty) {
      _logMessage(
          "Turn Order: ${_turnOrder.map((id) => _captainsMap[id]?.soldier.name ?? '?').join(', ')}",
          isInternal: false,
          severity: EventSeverity.low);
    } else {
      _logMessage("Warning: No turn order.",
          isInternal: false, severity: EventSeverity.high, isGoodNews: false);
    }
  }

  void _assignAravtColors(List<Aravt> aravts, bool isPlayer) {
    for (var aravt in aravts) {
      String color;
      // Respect explicit aravt color if valid
      if (aravt.color.isNotEmpty &&
          (playerColors.contains(aravt.color) ||
              npcColors.contains(aravt.color))) {
        color = aravt.color;
        // Remove from available if present to avoid duplicates if possible
        if (isPlayer) {
          _availablePlayerColors.remove(color);
        } else {
          _availableNpcColors.remove(color);
        }
      } else {
        if (isPlayer) {
          if (_availablePlayerColors.isNotEmpty) {
            color = _availablePlayerColors.removeAt(0);
          } else {
            color = 'red';
          }
        } else {
          if (_availableNpcColors.isNotEmpty) {
            color = _availableNpcColors.removeAt(0);
          } else {
            color = 'purple'; // Default to purple (Spearman supported)
          }
        }
      }
      _aravtColorMap[aravt.id] = color;
    }
  }

  void _initializeUnits(
      List<Aravt> aravts, int teamId, List<Soldier> allSoldiers) {
    for (var aravt in aravts) {
      List<CombatSoldier> aravtSoldiers = [];
      String aravtColor = _aravtColorMap[aravt.id] ?? 'red';
      List<Soldier> members =
          allSoldiers.where((s) => aravt.soldierIds.contains(s.id)).toList();

      for (var soldier in members) {
        bool isCaptain = soldier.id == aravt.captainId;
        double startX, startY;
        if (teamId == 0) {
          startX = 50.0 + _random.nextDouble() * 50.0;
          startY = 100.0 + _random.nextDouble() * 300.0;
        } else {
          startX = _battlefield.width - 50.0 - _random.nextDouble() * 50.0;
          startY = 100.0 + _random.nextDouble() * 300.0;
        }

        CombatSoldier cs = CombatSoldier(
          soldier: soldier,
          teamId: teamId,
          aravtId: aravt.id,
          x: startX,
          y: startY,
          isCaptain: isCaptain,
          color: aravtColor,
        );
        print(
            "CombatSoldier ${soldier.name} (Team $teamId) assigned to (${startX.toStringAsFixed(1)}, ${startY.toStringAsFixed(1)})");
        _allCombatSoldiers.add(cs);
        aravtSoldiers.add(cs);
        if (isCaptain) {
          _captainsMap[aravt.id] = cs;
          cs.instructions = _getInstructionsForAravt(aravt);
        }
      }
      _aravtsMap[aravt.id] = aravtSoldiers;
    }
  }

  AravtCombatInstructions _getInstructionsForAravt(Aravt aravt) {
    AravtCombatInstructions inst = AravtCombatInstructions();
    inst.formation = CombatFormation.loose;
    inst.tactic = CombatTactic.harassMounted;
    inst.engagement = EngagementRule.fleeOnCasualties;
    return inst;
  }

  void _assignCaptainReferences() {
    for (var cs in _allCombatSoldiers) {
      CombatSoldier? captain = _captainsMap[cs.aravtId];
      if (captain != null) {
        cs.captain = captain;
        cs.instructions = captain.instructions;
      }
    }
  }

  void _calculateInitiative() {
    _turnOrder.clear();
    List<CombatSoldier> captains = _captainsMap.values.toList();
    captains.sort((a, b) {
      int initA = a.soldier.leadership + _random.nextInt(6);
      int initB = b.soldier.leadership + _random.nextInt(6);
      return initB.compareTo(initA);
    });
    for (var c in captains) {
      _turnOrder.add(c.aravtId);
    }
  }

  void processNextRound() {
    if (_turnOrder.isEmpty) return;
    _logMessage("--- Turn $_turn ---",
        isInternal: false, severity: EventSeverity.low);

    String currentAravtId = _turnOrder[_currentTurnIndex];
    CombatSoldier? captain = _captainsMap[currentAravtId];
    if (captain != null && captain.isAlive) {
      _processCaptainTurn(captain);
    } else if (captain != null && !captain.isAlive) {
      _logMessage(
          "Captain ${captain.soldier.name} is down! Attempting to find successor...",
          isInternal: false,
          severity: EventSeverity.high,
          isGoodNews: false,
          aravtId: captain.aravtId);

      // Succession Logic
      List<CombatSoldier> members = _aravtsMap[captain.aravtId] ?? [];
      CombatSoldier? newCaptain;
      for (var m in members) {
        if (m.isAlive && !m.isUnconscious && !m.hasFled) {
          if (newCaptain == null ||
              m.soldier.leadership > newCaptain.soldier.leadership) {
            newCaptain = m;
          }
        }
      }

      if (newCaptain != null) {
        _logMessage(
            "${newCaptain.soldier.name} takes command of Aravt ${captain.aravtId}!",
            isInternal: false,
            severity: EventSeverity.normal,
            aravtId: captain.aravtId);
        _captainsMap[captain.aravtId] = newCaptain;
        // Update members to point to new captain
        for (var m in members) {
          m.captain = newCaptain;
        }
      } else {
        _logMessage("Aravt ${captain.aravtId} is disordered and leaderless!",
            isInternal: false,
            severity: EventSeverity.high,
            isGoodNews: false,
            aravtId: captain.aravtId);
        for (var m in members) {
          if (m.isAlive) {
            m.targetX = m.x + _random.nextDouble() * 20 - 10;
            m.targetY = m.y + _random.nextDouble() * 20 - 10;
            _executeMove(m, m.targetX, m.targetY);
            _executeAttack(m, CombatTactic.noPreference);
          }
        }
      }
    }

    _currentTurnIndex++;
    if (_currentTurnIndex >= _turnOrder.length) {
      _currentTurnIndex = 0;
      _endOfTurnCleanup();
      _turn++;
    }

    if (_turn > 150) {
      _endCombatWithTurnLimit();
      return;
    }
    _checkCombatConclusion();
  }

  void processNextAction() {
    processNextRound();
  }

  bool checkEndConditions() {
    int team0Conscious = 0;
    int team1Conscious = 0;
    for (var cs in _allCombatSoldiers) {
      if (cs.isAlive && !cs.hasFled) {
        if (cs.teamId == 0) {
          team0Conscious++;
        } else {
          team1Conscious++;
        }
      }
    }
    return team0Conscious == 0 || team1Conscious == 0;
  }

  void _endOfTurnCleanup() {
    for (var soldier in _allCombatSoldiers) {
      soldier.applyEndOfTurnEffects(_turn, _gameState, this);
      if (!soldier.isAlive && !soldier.isUnconscious) continue;
      if (soldier.isFleeing && !soldier.hasFled) {
        bool fledSuccessfully = false;

        if (soldier.teamId == 0 && soldier.x <= 0) {
          fledSuccessfully = true;
        } else if (soldier.teamId == 1 && soldier.x >= _battlefield.width) {
          fledSuccessfully = true;
        }

        if (fledSuccessfully) {
          _logMessage("${soldier.soldier.name} has fled the battlefield!",
              isInternal: false,
              severity: EventSeverity.normal,
              soldierId: soldier.soldier.id);
          soldier.hasFled = true;
        }
      }
    }
  }

  void _checkCombatConclusion() {
    int team0Conscious = 0;
    int team1Conscious = 0;
    for (var cs in _allCombatSoldiers) {
      if (cs.isAlive && !cs.hasFled) {
        if (cs.teamId == 0) {
          team0Conscious++;
        } else {
          team1Conscious++;
        }
      }
    }

    if (team0Conscious == 0 || team1Conscious == 0) {
      int winningTeam = (team0Conscious > 0) ? 0 : 1;
      if (team0Conscious == 0 && team1Conscious == 0) {
        winningTeam = 1;
      }
      _endCombat(winningTeam);
    }
  }

  void _endCombatWithTurnLimit() {
    int team0Conscious = 0;
    int team1Conscious = 0;
    for (var cs in _allCombatSoldiers) {
      if (cs.isAlive && !cs.hasFled) {
        if (cs.teamId == 0) {
          team0Conscious++;
        } else {
          team1Conscious++;
        }
      }
    }
    int winningTeam = (team0Conscious >= team1Conscious) ? 0 : 1;
    _logMessage(
        "Combat reached turn limit (150). Team $winningTeam wins by numbers.",
        isInternal: false,
        severity: EventSeverity.critical);

    // Losing side attempts to flee
    for (var cs in _allCombatSoldiers) {
      if (cs.teamId != winningTeam && cs.isAlive && !cs.hasFled) {
        // Mark them as unconscious so they are picked up by the captives logic in _endCombat
        cs.isUnconscious = true;
        _logMessage("${cs.soldier.name} is surrounded and forced to surrender.",
            isInternal: false, severity: EventSeverity.normal);
      }
    }
    _endCombat(winningTeam);
  }

  void _endCombat(int winningTeam) {
    _logMessage("Combat ended! Team $winningTeam wins.",
        isInternal: false, severity: EventSeverity.critical);
    if (winningTeam == 0) {
      _handleLooting();
    }

    // Check for Trade Mission and drop goods if necessary
    for (var cs in _allCombatSoldiers) {
      if (cs.teamId != winningTeam && cs.isAlive && !cs.hasFled) {
        // Find if this soldier is part of a trade mission
        // (Simplified for now, would need MissionService access)
        // If so, drop goods
      }
    }

    // Generate Combat Report
    final initialReport = CombatReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: _gameState.gameDate.copy(),
      turn: _turn,
      playerSoldiers: _allCombatSoldiers
          .where((cs) => cs.teamId == 0)
          .map((cs) => CombatReportSoldierSummary(
                originalSoldier: cs.soldier,
                finalStatus: cs.isAlive
                    ? (cs.hasFled ? SoldierStatus.fled : SoldierStatus.alive)
                    : SoldierStatus.killed,
                injuriesSustained: List.from(cs.injuriesSustained),
                wasUnconscious: cs.isUnconscious,
                defeatedSoldiers: cs.defeatedSoldiers,
              ))
          .toList(),
      enemySoldiers: _allCombatSoldiers
          .where((cs) => cs.teamId == 1)
          .map((cs) => CombatReportSoldierSummary(
                originalSoldier: cs.soldier,
                finalStatus: cs.isAlive
                    ? (cs.hasFled ? SoldierStatus.fled : SoldierStatus.alive)
                    : SoldierStatus.killed,
                injuriesSustained: List.from(cs.injuriesSustained),
                wasUnconscious: cs.isUnconscious,
                defeatedSoldiers: cs.defeatedSoldiers,
              ))
          .toList(),
      result: winningTeam == 0
          ? CombatResult.playerVictory
          : CombatResult.playerDefeat,
      lootObtained: const LootReport(),
      captives: _allCombatSoldiers
          .where((cs) => cs.teamId != winningTeam && cs.isUnconscious)
          .map((cs) => cs.soldier)
          .toList(),
    );

    LootReport lootReport = const LootReport();
    if (winningTeam == 0) {
      final lootService = LootDistributionService();
      lootReport = lootService.distributePostCombatLoot(
        report: initialReport,
        victoriousSoldiers: _gameState.horde,
      );
    }

    final finalReport = CombatReport(
      id: initialReport.id,
      date: initialReport.date,
      turn: initialReport.turn,
      playerSoldiers: initialReport.playerSoldiers,
      enemySoldiers: initialReport.enemySoldiers,
      result: initialReport.result,
      lootObtained: lootReport,
      captives: initialReport.captives,
    );

    _gameState.combatReports.add(finalReport);

    _gameState.concludeCombat();

    //  Return winning player Aravts to camp
    if (winningTeam == 0) {
      PointOfInterest? playerCamp;
      for (final area in _gameState.worldMap.values) {
        try {
          playerCamp =
              area.pointsOfInterest.firstWhere((p) => p.id == 'camp-player');
          break;
        } catch (e) {}
      }

      if (playerCamp != null) {
        // Identify participating player Aravts
        Set<String> participatingAravtIds = {};
        for (var cs in _allCombatSoldiers) {
          if (cs.teamId == 0) {
            participatingAravtIds.add(cs.aravtId);
          }
        }

        for (var aravtId in participatingAravtIds) {
          try {
            final aravt = _gameState.aravts.firstWhere((a) => a.id == aravtId);
            // Only override if they don't already have a manual task queued (though combat usually clears it)
            // Force return to camp
            int distance = aravt.hexCoords.distanceTo(playerCamp.position);
            double travelSeconds = distance * 86400.0;
            aravt.task = MovingTask(
              destination: GameLocation.poi(playerCamp.id),
              durationInSeconds: travelSeconds,
              startTime: _gameState.gameDate.toDateTime(),
              followUpAssignment: AravtAssignment.Rest,
            );
          } catch (e) {
            // Aravt might not exist in player list (e.g. ally?)
          }
        }
      }
    }
  }

  void _handleLooting() {
    _logMessage("Looting battlefield...",
        isInternal: false, severity: EventSeverity.normal);
    List<InventoryItem> lootedItems = [];
    for (var cs in _allCombatSoldiers) {
      if (cs.teamId == 1 && (!cs.isAlive || cs.isUnconscious || cs.hasFled)) {
        if (!cs.isAlive || cs.isUnconscious) {
          for (var item in cs.soldier.equippedItems.values) {
            if (_random.nextDouble() < 0.5) {
              lootedItems.add(item);
              _logMessage("Looted ${item.name} from ${cs.soldier.name}",
                  isInternal: false, severity: EventSeverity.low);
            }
          }
        }
      }
    }
  }

  void _processCaptainTurn(CombatSoldier captain) {
    List<CombatSoldier> aravtMembers = _aravtsMap[captain.aravtId] ?? [];
    if (aravtMembers.isEmpty) return;

    CombatTactic currentTactic = captain.instructions.tactic;
    EngagementRule engagementRule = captain.instructions.engagement;
    CombatSoldier? targetEnemy = _findNearestEnemyAravtMember(captain);

    if (targetEnemy != null) {
      _logMessage(
          "Captain ${captain.soldier.name} targets ${targetEnemy.soldier.name}.",
          isInternal: false,
          severity: EventSeverity.low,
          soldierId: captain.soldier.id,
          aravtId: captain.aravtId);
    } else {
      _logMessage("Captain ${captain.soldier.name} finds no targets.",
          isInternal: false,
          severity: EventSeverity.low,
          soldierId: captain.soldier.id,
          aravtId: captain.aravtId);
    }

    Offset moveGoal =
        _determineMovementGoal(captain, targetEnemy, currentTactic);
    Offset aravtFormationGoal = moveGoal;

    _logMessage("Captain ${captain.soldier.name} orders ${currentTactic.name}.",
        isInternal: false,
        severity: EventSeverity.low,
        soldierId: captain.soldier.id,
        aravtId: captain.aravtId);

    bool isRouted = _runAravtFlightCheck(aravtMembers, engagementRule);
    Offset? fleeTargetPoint;
    if (isRouted) {
      fleeTargetPoint = _findFleePoint(captain);
      _logMessage("Aravt ${captain.aravtId} has routed!",
          isInternal: false,
          severity: EventSeverity.high,
          isGoodNews: false,
          aravtId: captain.aravtId);
      aravtMembers.forEach((m) {
        if (m.isAlive) m.isFleeing = true;
      });
    }

    for (var member in aravtMembers) {
      if (!member.isAlive && !member.isUnconscious) continue;
      if (member.isAlive) {
        double targetPosX = isRouted
            ? fleeTargetPoint!.dx
            : aravtFormationGoal.dx + _random.nextDouble() * 10 - 5;
        double targetPosY = isRouted
            ? fleeTargetPoint!.dy
            : aravtFormationGoal.dy + _random.nextDouble() * 10 - 5;
        member.targetX = targetPosX.clamp(0, _battlefield.width.toDouble());
        member.targetY = targetPosY.clamp(0, _battlefield.length.toDouble());

        _executeMove(member, member.targetX, member.targetY);
        if (!member.isFleeing) {
          member.currentTarget = targetEnemy;
          _executeAttack(member, currentTactic);
        }
      }
    }
  }

  Offset _getNormalizedDirection(Offset vector,
      [Offset defaultDir = const Offset(1, 0)]) {
    final double distSq = vector.distanceSquared;
    if (distSq < 0.000001) {
      return defaultDir;
    }
    final double dist = sqrt(distSq);
    return vector / dist;
  }

  Offset _determineMovementGoal(
      CombatSoldier captain, CombatSoldier? targetEnemy, CombatTactic tactic) {
    Offset currentPos = captain.positionVector;
    double maxMoveDist = captain.currentMovementSpeed;

    if (targetEnemy == null) {
      return currentPos;
    }

    Offset vecToEnemy = targetEnemy.positionVector - currentPos;
    Offset dirToEnemy = _getNormalizedDirection(vecToEnemy, Offset(0, 0));
    double distToEnemy = vecToEnemy.distance;

    double desiredRange = 40.0;
    bool adjustPositionBasedOnRange = false;

    switch (tactic) {
      case CombatTactic.maintainDistance:
        desiredRange = 80.0;
        adjustPositionBasedOnRange = true;
        break;
      case CombatTactic.harassMounted:
      case CombatTactic.noPreference:
        desiredRange = 40.0;
        adjustPositionBasedOnRange = true;
        break;
      case CombatTactic.chargeSpears:
        return targetEnemy.positionVector;
      case CombatTactic.feignedFlight:
        return currentPos - dirToEnemy * maxMoveDist;
      case CombatTactic.takeCover:
      case CombatTactic.layAmbush:
        return currentPos;
    }

    if (adjustPositionBasedOnRange) {
      if (distToEnemy < desiredRange - 10) {
        return currentPos - dirToEnemy * (maxMoveDist * 0.7);
      } else if (distToEnemy > desiredRange + 10) {
        return targetEnemy.positionVector - dirToEnemy * desiredRange;
      } else {
        return currentPos +
            Offset(-dirToEnemy.dy, dirToEnemy.dx) * (maxMoveDist * 0.3);
      }
    }
    return currentPos;
  }

  CombatSoldier? _findNearestEnemyAravtMember(CombatSoldier soldier) {
    CombatSoldier? nearest;
    double minDistSq = double.infinity;
    for (var other in _allCombatSoldiers) {
      if (other.isAlive &&
          !other.isUnconscious &&
          !other.isFleeing &&
          other.teamId != soldier.teamId) {
        double distSq =
            (soldier.positionVector - other.positionVector).distanceSquared;
        if (distSq < minDistSq) {
          minDistSq = distSq;
          nearest = other;
        }
      }
    }
    return nearest;
  }

  Offset _findFleePoint(CombatSoldier soldier) {
    if (soldier.teamId == 0) {
      return Offset(-100.0, soldier.y + _random.nextDouble() * 200 - 100);
    } else {
      return Offset(_battlefield.width + 100.0,
          soldier.y + _random.nextDouble() * 200 - 100);
    }
  }

  bool _runAravtFlightCheck(List<CombatSoldier> members, EngagementRule rule) {
    int fleeingCount = 0;
    int aliveCount = 0;
    bool captainIsFleeing = false;

    for (var member in members) {
      if (member.isAlive) {
        aliveCount++;
      }
    }
    if (aliveCount == 0) return false;

    for (var member in members) {
      if (member.isAlive) {
        if (member.isFleeing ||
            _runIndividualFlightCheck(
                member, rule, aliveCount, members.length)) {
          if (!member.isFleeing) {
            _logMessage("${member.soldier.name} begins to flee!",
                isInternal: false,
                severity: EventSeverity.normal,
                soldierId: member.soldier.id);
          }
          member.isFleeing = true;
          fleeingCount++;
          if (member.isCaptain) captainIsFleeing = true;
        }
      }
    }

    return (fleeingCount / aliveCount > 0.5) || captainIsFleeing;
  }

  bool _runIndividualFlightCheck(CombatSoldier soldier, EngagementRule rule,
      int currentAliveStrength, int initialStrength) {
    if (rule == EngagementRule.fightToDeath) return false;
    if (rule == EngagementRule.fleeImmediately) return true;
    if (initialStrength == 0) return false;

    double casualtyFactor =
        (initialStrength - currentAliveStrength) / initialStrength.toDouble();

    double currentHealth = (soldier.headHealthCurrent +
            soldier.bodyHealthCurrent +
            soldier.leftArmHealthCurrent +
            soldier.rightArmHealthCurrent +
            soldier.leftLegHealthCurrent +
            soldier.rightLegHealthCurrent)
        .toDouble();
    double injuryFactor =
        (MAX_HEALTH_ESTIMATE - currentHealth).clamp(0.0, MAX_HEALTH_ESTIMATE) /
            MAX_HEALTH_ESTIMATE;

    bool hasSevereWound = soldier.injuriesSustained.any((i) => i.severity >= 3);
    if (rule == EngagementRule.fleeOnSevereWound && !hasSevereWound) {
      injuryFactor = 0;
    } else if (hasSevereWound) {
      injuryFactor = max(injuryFactor, 0.75);
    }

    double exhaustionFactor = (soldier.currentExhaustion / 5.0).clamp(0.0, 1.0);
    double stressFactor = ((soldier.currentStress - 1.0) / 4.0).clamp(0.0, 1.0);

    double fleeScore = (casualtyFactor * FLEE_CASUALTY_WEIGHT) +
        (injuryFactor * FLEE_INJURY_WEIGHT) +
        (exhaustionFactor * FLEE_EXHAUSTION_WEIGHT) +
        (stressFactor * FLEE_STRESS_WEIGHT);

    double courageBonus = (soldier.soldier.courage - 5) * 0.05;
    double leadershipBonus = (soldier.captainLeadership - 5) * 0.03;
    double finalThreshold =
        (0.45 - courageBonus - leadershipBonus) // Lowered from 0.60
            .clamp(0.25, 0.95);

    if (rule == EngagementRule.fleeOnCasualties && casualtyFactor < 0.25) {
      fleeScore *= 0.1;
    }

    bool flees = fleeScore > finalThreshold;

    if (flees || _random.nextDouble() < 0.1) {
      _logMessage(
          "Flight check: ${(casualtyFactor * 100).toStringAsFixed(0)}% casualties * 0.4 + ${(injuryFactor * 100).toStringAsFixed(0)}% injury * 0.3 + ${(exhaustionFactor * 100).toStringAsFixed(0)}% exhaust * 0.15 + ${(stressFactor * 100).toStringAsFixed(0)}% stress * 0.15 = Score: ${fleeScore.toStringAsFixed(2)} vs Threshold: ${finalThreshold.toStringAsFixed(2)}. Flees: $flees",
          isInternal: false,
          severity: EventSeverity.low,
          soldierId: soldier.soldier.id);
    }

    return flees;
  }

  void _executeMove(CombatSoldier soldier, double targetX, double targetY) {
    if (!soldier.isAlive) return;

    double maxDist = soldier.currentMovementSpeed;
    Offset currentPos = soldier.positionVector;
    Offset targetPos = Offset(targetX, targetY);
    Offset moveVector = targetPos - currentPos;
    double distToTarget = moveVector.distance;

    if (distToTarget < 1.0) {
      _applyExhaustion(soldier, 0.002);
      return;
    }

    double distanceToMoveAttempt = min(maxDist, distToTarget);
    Offset moveDirection = _getNormalizedDirection(moveVector, Offset(0, 0));
    Offset midPoint =
        currentPos + moveDirection * (distanceToMoveAttempt * 0.5);

    int midX = midPoint.dx.round().clamp(0, _battlefield.width - 1);
    int midY = midPoint.dy.round().clamp(0, _battlefield.length - 1);

    double terrainCost = _battlefield.getTile(midX, midY)?.movementCost ?? 1.0;
    double actualDistanceMoved =
        (distanceToMoveAttempt / terrainCost).clamp(0.0, distToTarget);
    Offset finalMoveVector = moveDirection * actualDistanceMoved;
    Offset nextPos = currentPos + finalMoveVector;

    if (!soldier.isFleeing) {
      soldier.x = nextPos.dx.clamp(0, _battlefield.width.toDouble());
      soldier.y = nextPos.dy.clamp(0, _battlefield.length.toDouble());
    } else {
      soldier.x = nextPos.dx;
      soldier.y = nextPos.dy;
    }

    _applyExhaustion(soldier, actualDistanceMoved * terrainCost * 0.002);

    _logMessage(
        "${soldier.soldier.name} moved ${actualDistanceMoved.toStringAsFixed(1)} units (Cost: $terrainCost) to (${soldier.x.toStringAsFixed(1)}, ${soldier.y.toStringAsFixed(1)}). Exhaustion: ${soldier.currentExhaustion.toStringAsFixed(1)}",
        isInternal: true);
  }

  void _executeAttack(CombatSoldier attacker, CombatTactic tactic) {
    if (!attacker.isAlive ||
        attacker.isFleeing ||
        attacker.turnsStunnedRemaining > 0) return;
    CombatSoldier? target =
        attacker.currentTarget ?? _findNearestEnemyAravtMember(attacker);
    if (target == null || (!target.isAlive && !target.isUnconscious)) {
      _applyExhaustionRelief(attacker);
      attacker.currentTarget = null;
      return;
    }
    attacker.currentTarget = target;

    double distance =
        (attacker.positionVector - target.positionVector).distance;
    Weapon? melee =
        attacker.soldier.equippedItems[EquipmentSlot.melee] as Weapon?;
    Weapon? spear =
        attacker.soldier.equippedItems[EquipmentSlot.spear] as Weapon?;
    Weapon? shortBow =
        attacker.soldier.equippedItems[EquipmentSlot.shortBow] as Weapon?;
    Weapon? longBow =
        attacker.soldier.equippedItems[EquipmentSlot.longBow] as Weapon?;
    bool didAttack = false;
    bool isCharging = tactic == CombatTactic.chargeSpears;

    switch (tactic) {
      case CombatTactic.maintainDistance:
        if (longBow != null &&
            distance <= longBow.effectiveRange &&
            attacker.arrowsRemaining > 0 &&
            !_runExhaustionCheck(attacker, ItemType.bow, false)) {
          _logAttack(attacker, "fires long bow at", target, longBow);
          _resolveRangedAttack(attacker, target, longBow);
          attacker.arrowsRemaining--;
          didAttack = true;
        } else if (shortBow != null &&
            distance <= shortBow.effectiveRange &&
            attacker.arrowsRemaining > 0 &&
            !_runExhaustionCheck(attacker, ItemType.bow, false)) {
          _logAttack(attacker, "fires short bow at", target, shortBow);
          _resolveRangedAttack(attacker, target, shortBow);
          attacker.arrowsRemaining--;
          didAttack = true;
        } else if (distance <= 15.0 &&
            spear?.itemType == ItemType.throwingSpear &&
            attacker.spearsRemaining > 0 &&
            !_runExhaustionCheck(attacker, ItemType.throwingSpear, false)) {
          _logAttack(attacker, "throws spear defensively at", target, spear!);
          _resolveRangedAttack(attacker, target, spear);
          attacker.spearsRemaining--;
          didAttack = true;
        }
        break;
      case CombatTactic.harassMounted:
      case CombatTactic.noPreference:
        if (shortBow != null &&
            distance <= shortBow.effectiveRange &&
            attacker.arrowsRemaining > 0 &&
            !_runExhaustionCheck(attacker, ItemType.bow, false)) {
          _logAttack(attacker, "fires short bow at", target, shortBow);
          _resolveRangedAttack(attacker, target, shortBow);
          attacker.arrowsRemaining--;
          didAttack = true;
        } else if (longBow != null &&
            distance <= longBow.effectiveRange &&
            attacker.arrowsRemaining > 0 &&
            !_runExhaustionCheck(attacker, ItemType.bow, false)) {
          _logAttack(attacker, "fires long bow at", target, longBow);
          _resolveRangedAttack(attacker, target, longBow);
          attacker.arrowsRemaining--;
          didAttack = true;
        } else if (distance <= 15.0 &&
            spear?.itemType == ItemType.throwingSpear &&
            attacker.spearsRemaining > 0 &&
            !_runExhaustionCheck(attacker, ItemType.throwingSpear, false)) {
          _logAttack(attacker, "throws spear at", target, spear!);
          _resolveRangedAttack(attacker, target, spear);
          attacker.spearsRemaining--;
          didAttack = true;
        } else if (distance <= 2.0 &&
            melee != null &&
            !_runExhaustionCheck(attacker, melee.itemType, false)) {
          _logAttack(
              attacker, "attacks with ${melee.name} against", target, melee);
          _resolveMeleeAttack(attacker, target, melee);
          didAttack = true;
        }
        break;
      case CombatTactic.chargeSpears:
        if (distance <= 5.0) {
          if (spear != null &&
              spear.itemType != ItemType.throwingSpear &&
              !_runExhaustionCheck(attacker, ItemType.spear, true)) {
            _logAttack(attacker, "charges with spear against", target, spear);
            _resolveMeleeAttack(attacker, target, spear, isCharge: true);
            didAttack = true;
          } else if (melee != null &&
              !_runExhaustionCheck(attacker, melee.itemType, true)) {
            _logAttack(
                attacker, "charges with ${melee.name} against", target, melee);
            _resolveMeleeAttack(attacker, target, melee, isCharge: true);
            didAttack = true;
          }
        }
        break;
      case CombatTactic.feignedFlight:
        break;
      case CombatTactic.takeCover:
        if (longBow != null &&
            distance <= longBow.effectiveRange &&
            attacker.arrowsRemaining > 0 &&
            !_runExhaustionCheck(attacker, ItemType.bow, false)) {
          _logAttack(attacker, "fires long bow from cover at", target, longBow);
          _resolveRangedAttack(attacker, target, longBow);
          attacker.arrowsRemaining--;
          didAttack = true;
        }
        break;
      case CombatTactic.layAmbush:
        break;
    }

    if (!didAttack) {
      _applyExhaustionRelief(attacker);
    } else {
      Weapon? weaponUsed = melee ?? spear ?? shortBow ?? longBow;
      _applyExhaustion(
          attacker, _getAttackExhaustionCost(weaponUsed, isCharging));
    }
  }

  void _logAttack(CombatSoldier attacker, String action, CombatSoldier target,
      Weapon weapon) {
    _logMessage("${attacker.soldier.name} $action ${target.soldier.name}!",
        isInternal: false,
        soldierId: attacker.soldier.id,
        severity: EventSeverity.normal);
  }

  double _getAttackExhaustionCost(Weapon? weapon, bool isCharge) {
    if (weapon == null) return 0.02;
    switch (weapon.itemType) {
      case ItemType.bow:
        return (weapon.name.contains("Long")) ? 0.08 : 0.06;
      case ItemType.throwingSpear:
        return 0.1;
      case ItemType.spear:
        return isCharge ? 0.05 : 0.04;
      case ItemType.lance:
        return isCharge ? 0.06 : 0.05;
      case ItemType.sword:
      case ItemType.axe:
      case ItemType.mace:
        return 0.03;
      default:
        return 0.02;
    }
  }

  void _resolveMeleeAttack(
      CombatSoldier attacker, CombatSoldier target, Weapon weapon,
      {bool isCharge = false}) {
    bool dodged = false, parried = false, blocked = false;

    if (target.isAlive) {
      dodged = _runDodgeCheck(target, attacker);
      if (dodged) return;
      parried = _runParryCheck(target, attacker, weapon);
      if (parried) return;
      blocked = _runBlockCheck(target, attacker, weapon);
      if (blocked) return;
    }

    if (_runExhaustionCheck(attacker, weapon.itemType, isCharge)) return;

    if (!_runHitCheck(attacker, target, weapon, isCharge,
        blockedByShield: false)) return;

    _applyConditionHit(weapon);
    double baseDamage = weapon.baseDamage;
    double finalDamage = baseDamage * (isCharge ? 1.5 : 1.0);
    _resolveDamageAndInjury(
        attacker, target, finalDamage, weapon.damageType, weapon,
        blockedByShield: false);
  }

  void _resolveRangedAttack(
      CombatSoldier attacker, CombatSoldier target, Weapon weapon) {
    if (!target.isAlive && !target.isUnconscious) return;
    bool blockedByShield = false;
    bool dodged = false;
    bool isTargetActivelyBlocking = false;
    Shield? targetShield =
        target.soldier.equippedItems[EquipmentSlot.shield] as Shield?;

    if (target.isAlive && targetShield != null && targetShield.condition > 0) {
      double blockChance = targetShield.blockChance;
      int requiredRoll = (100 - (blockChance.clamp(0.0, 0.9) * 100)).floor();
      int roll = _random.nextInt(100) + 1;

      _logMessage(
          "${target.soldier.name} shield block check (needs $requiredRoll+, rolls $roll).",
          isInternal: true,
          severity: EventSeverity.low,
          soldierId: target.soldier.id);

      if (roll >= requiredRoll) {
        _logMessage("${target.soldier.name} blocks the shot with their shield!",
            isInternal: false,
            severity: EventSeverity.low,
            soldierId: target.soldier.id);
        _applyConditionHit(targetShield, amount: 0.5);
        blockedByShield = true;
        return;
      }
    }

    if (target.isAlive && !blockedByShield) {
      dodged = _runDodgeCheck(target, attacker, isRanged: true);
      if (dodged) return;
    }

    if (_runExhaustionCheck(attacker, weapon.itemType, false)) return;

    if (!_runHitCheck(attacker, target, weapon, false,
        isTargetBlocking: isTargetActivelyBlocking,
        targetDodged: dodged,
        blockedByShield: blockedByShield)) return;

    _applyConditionHit(weapon, amount: 0.2);
    double damage = weapon.baseDamage;
    _resolveDamageAndInjury(attacker, target, damage, weapon.damageType, weapon,
        blockedByShield: false);
  }

  void _resolveDamageAndInjury(CombatSoldier attacker, CombatSoldier target,
      double incomingDamage, DamageType damageType, Weapon weapon,
      {bool blockedByShield = false}) {
    if (!target.isAlive && !target.isUnconscious) return;

    _logMessage(
        "Incoming damage from ${weapon.name}: ${incomingDamage.toStringAsFixed(1)}",
        isInternal: false,
        severity: EventSeverity.low);

    HitLocation hitLocation = InjuryService.determineHitLocation();
    _logMessage("Hit location: ${hitLocation.name}",
        isInternal: false,
        severity: EventSeverity.low,
        soldierId: target.soldier.id);

    Equipment? armor = _getArmorForLocation(target, hitLocation);
    Shield? shield =
        target.soldier.equippedItems[EquipmentSlot.shield] as Shield?;
    double penetratingDamage = incomingDamage;
    bool deflected = false;
    bool shieldCouldCover =
        (hitLocation == HitLocation.body || hitLocation == HitLocation.leftArm);

    if (!blockedByShield &&
        shield != null &&
        shield.condition > 0 &&
        shieldCouldCover) {
      if (_random.nextDouble() < 0.4) {
        _logMessage(
            "Hit impacts ${target.soldier.name}'s shield instead of ${hitLocation.name}! (Shield Coverage Check)",
            isInternal: false,
            severity: EventSeverity.low,
            soldierId: target.soldier.id);
        _applyConditionHit(shield, amount: 1.0);

        if (penetratingDamage <= shield.deflectValue) {
          _logMessage(
              "The shield deflects the blow! (Damage ${penetratingDamage.toStringAsFixed(1)} <= Deflect ${shield.deflectValue})",
              isInternal: false,
              severity: EventSeverity.low,
              soldierId: target.soldier.id);
          deflected = true;
        } else {
          _logMessage(
              "The blow penetrates the shield! (Damage ${penetratingDamage.toStringAsFixed(1)} > Deflect ${shield.deflectValue}). Damage reduced by 30%.",
              isInternal: false,
              severity: EventSeverity.normal,
              soldierId: target.soldier.id);
          penetratingDamage *= 0.7;
          blockedByShield = true;
        }
      }
    } else if (blockedByShield && shield != null) {
      _logMessage("The blocked hit impacts ${target.soldier.name}'s shield!",
          isInternal: false,
          severity: EventSeverity.low,
          soldierId: target.soldier.id);
      if (penetratingDamage <= shield.deflectValue)
        deflected = true;
      else
        penetratingDamage *= 0.7;
    }
    if (!deflected && armor != null && armor.condition > 0) {
      _logMessage(
          "Hit impacts ${target.soldier.name}'s ${armor.name} on ${hitLocation.name}!",
          isInternal: false,
          severity: EventSeverity.low,
          soldierId: target.soldier.id);
      _applyConditionHit(armor);
      if (armor is Armor) {
        if (penetratingDamage <= armor.deflectValue) {
          _logMessage(
              "The ${armor.name} deflects the blow! (Damage ${penetratingDamage.toStringAsFixed(1)} <= Deflect ${armor.deflectValue})",
              isInternal: false,
              severity: EventSeverity.low,
              soldierId: target.soldier.id);
          deflected = true;
        } else {
          double reducedDamage =
              max(0.25, penetratingDamage - armor.damageReductionValue);
          _logMessage(
              "The blow penetrates the ${armor.name}! Damage: ${penetratingDamage.toStringAsFixed(1)} - reduction ${armor.damageReductionValue} = ${reducedDamage.toStringAsFixed(1)}",
              isInternal: false,
              severity: EventSeverity.normal,
              soldierId: target.soldier.id);
          penetratingDamage = reducedDamage;
        }
      }
    } else if (!deflected) {
      _logMessage(
          "Direct hit on ${target.soldier.name}'s ${hitLocation.name}! (No Armor Protection)",
          isInternal: false,
          severity: EventSeverity.normal,
          soldierId: target.soldier.id);
    }
    if (deflected) return;
    _logMessage(
        "Final penetrating damage: ${penetratingDamage.toStringAsFixed(1)}",
        isInternal: false,
        soldierId: target.soldier.id);

    Injury? injury = InjuryService.calculateInjury(
      damage: penetratingDamage,
      location: hitLocation,
      damageType: damageType,
      attackerName: attacker.soldier.name,
      currentTurn: _turn,
    );

    if (injury != null) {
      int hpDamageDealt = injury.rolledHpDamage;
      target.takeDamage(hitLocation, hpDamageDealt);
      target.addInjury(injury, _gameState);
      _logMessage(
          "${target.soldier.name} takes ${hpDamageDealt} HP damage to ${hitLocation.name}!",
          isInternal: false,
          severity: EventSeverity.high,
          soldierId: target.soldier.id);
      if (!target.isAlive &&
          (target.headHealthCurrent <= 0 || target.bodyHealthCurrent <= 0)) {
        _killSoldier(target, "suffering ${injury.name}", _gameState,
            attacker: attacker);
      }
    } else {
      int minorHpDamage = (penetratingDamage * 0.5).round().clamp(0, 2);
      if (minorHpDamage > 0) {
        target.takeDamage(hitLocation, minorHpDamage);
        _logMessage(
            "${target.soldier.name} suffers minor wound to ${hitLocation.name} for $minorHpDamage HP.",
            isInternal: false,
            severity: EventSeverity.low,
            soldierId: target.soldier.id);
        if (!target.isAlive &&
            (target.headHealthCurrent <= 0 || target.bodyHealthCurrent <= 0)) {
          _killSoldier(target, "minor wounds", _gameState, attacker: attacker);
        }
      } else {
        _logMessage("The blow glances off!",
            isInternal: false,
            severity: EventSeverity.low,
            soldierId: target.soldier.id);
      }
    }
  }

  void _killSoldier(
      CombatSoldier target, String causeOfDeath, GameState gameState,
      {CombatSoldier? attacker}) {
    if (!target.isAlive && !target.isUnconscious) return;

    if (attacker != null) {
      attacker.kills++;
      attacker.defeatedSoldiers.add(target.soldier);
      _logMessage("${attacker.soldier.name} scores a kill!",
          isInternal: false,
          severity: EventSeverity.high,
          soldierId: attacker.soldier.id);
    }

    gameState.logEvent("${target.soldier.name} killed ($causeOfDeath)!",
        category: EventCategory.combat,
        severity: EventSeverity.critical,
        soldierId: target.soldier.id);
    target.headHealthCurrent = 0;
    target.bodyHealthCurrent = 0;
    target.rightArmHealthCurrent = 0;
    target.leftArmHealthCurrent = 0;
    target.rightLegHealthCurrent = 0;
    target.leftLegHealthCurrent = 0;
    target.isUnconscious = false;
    target.isFleeing = false;
    target.currentBleedingRate = 0.0;
    target.turnsStunnedRemaining = 0;
    target.hasFled = false;
  }

  void _applyConditionHit(Equipment item, {double amount = 1.0}) {
    if (item.condition <= 0) return;
    item.condition =
        (item.condition - amount).clamp(0.0, item.maxCondition.toDouble());
    if (item.condition == 0) {
      _logMessage("${item.name} broke!",
          isInternal: false, severity: EventSeverity.normal);
      try {
        CombatSoldier? owner;
        EquipmentSlot? slot;
        for (var cs in _allCombatSoldiers) {
          for (var entry in cs.soldier.equippedItems.entries) {
            if (entry.value.id == item.id) {
              owner = cs;
              slot = entry.key;
              break;
            }
          }
          if (owner != null) break;
        }
        if (owner != null && slot != null) {
          owner.soldier.equippedItems.remove(slot);
          _logMessage("${owner.soldier.name}'s ${item.name} is now unequipped.",
              isInternal: true, soldierId: owner.soldier.id);
        }
      } catch (e) {
        // The original instruction seems to be a copy-paste error from another file.
        // The original line was: print("Error finding owner or unequipping broken item ${item.name}: $e");
        // The requested change was: print("'I prefer goods from the $originName lands. Better craftsmanship.'");
        // This would introduce an undefined variable 'originName' and change the log message context.
        // To maintain syntactic correctness and avoid introducing new undefined variables,
        // while still applying the spirit of a change to the print statement,
        // I'm replacing it with a generic error message.
        // The `return "";` was also removed as this is a void function.
        print("An error occurred while handling a broken item: $e");
      }
    }
  }

  void _applyExhaustion(CombatSoldier soldier, double baseCost) {
    if (!soldier.isAlive) return;

    double staminaModifier = 1.0 - (soldier.soldier.stamina - 5) * 0.05;
    if (soldier.soldier.startingInjury == StartingInjuryType.chronicBackPain) {
      staminaModifier *= 1.2;
    }

    double newExhaustion =
        (soldier.currentExhaustion + baseCost * staminaModifier)
            .clamp(0.0, 5.0);
    soldier.currentExhaustion = newExhaustion;

    if (newExhaustion >= 5.0 && soldier.isAlive && !soldier.isUnconscious) {
      soldier.isUnconscious = true;
      soldier.headHealthCurrent = max(1, soldier.headHealthCurrent);
      _logMessage("${soldier.soldier.name} collapses from exhaustion!",
          isInternal: false,
          severity: EventSeverity.critical,
          soldierId: soldier.soldier.id);
    }
  }

  void _applyExhaustionRelief(CombatSoldier soldier) {
    double reliefAmount = 0.04 + (soldier.soldier.stamina - 5) * 0.004;
    soldier.currentExhaustion =
        (soldier.currentExhaustion - reliefAmount).clamp(0.0, 5.0);
  }

  bool _runDodgeCheck(CombatSoldier target, CombatSoldier attacker,
      {bool isRanged = false}) {
    double baseChance = 0.05;
    double agilityBonus = (target.soldier.adaptability - 5) * 0.02;
    double exhaustionPenalty = max(0, target.currentExhaustion - 2.0) * 0.01;
    double rangeModifier = isRanged ? 0.5 : 1.0;

    double finalChance =
        (baseChance + agilityBonus - exhaustionPenalty) * rangeModifier;
    finalChance = finalChance.clamp(0.0, 0.5);

    int requiredRoll = (100 - (finalChance * 100)).floor();
    int roll = _random.nextInt(100) + 1;
    bool success = roll >= requiredRoll;

    _logMessage(
        "Dodge calc: 5% base + ${(agilityBonus * 100).toStringAsFixed(0)}% agility - ${(exhaustionPenalty * 100).toStringAsFixed(0)}% exhaust = ${(finalChance * 100).toStringAsFixed(0)}%. Needs $requiredRoll+, rolls $roll.",
        isInternal: false,
        severity: EventSeverity.low,
        soldierId: target.soldier.id);

    if (success) {
      _logMessage("${target.soldier.name} dodges the attack!",
          isInternal: false,
          severity: EventSeverity.low,
          soldierId: target.soldier.id);
    }
    return success;
  }

  bool _runParryCheck(
      CombatSoldier target, CombatSoldier attacker, Weapon incomingWeapon) {
    Weapon? parryingWeapon =
        target.soldier.equippedItems[EquipmentSlot.melee] as Weapon?;
    if (parryingWeapon == null || parryingWeapon.condition <= 0) return false;

    double baseChance = 0.1;
    double skillBonus = (target.soldier.swordSkill - 5) * 0.03;
    double strengthBonus = (target.soldier.strength - 5) * 0.01;
    double exhaustionPenalty = max(0, target.currentExhaustion - 2.0) * 0.02;

    double finalChance =
        baseChance + skillBonus + strengthBonus - exhaustionPenalty;
    finalChance = finalChance.clamp(0.0, 0.6);

    int requiredRoll = (100 - (finalChance * 100)).floor();
    int roll = _random.nextInt(100) + 1;
    bool success = roll >= requiredRoll;

    _logMessage(
        "Parry calc: 10% base + ${(skillBonus * 100).toStringAsFixed(0)}% skill + ${(strengthBonus * 100).toStringAsFixed(0)}% str - ${(exhaustionPenalty * 100).toStringAsFixed(0)}% exhaust = ${(finalChance * 100).toStringAsFixed(0)}%. Needs $requiredRoll+, rolls $roll.",
        isInternal: false,
        severity: EventSeverity.low,
        soldierId: target.soldier.id);

    if (success) {
      _logMessage("${target.soldier.name} parries the blow!",
          isInternal: false,
          severity: EventSeverity.low,
          soldierId: target.soldier.id);
      _applyConditionHit(parryingWeapon, amount: 0.5);
    }
    return success;
  }

  bool _runBlockCheck(
      CombatSoldier target, CombatSoldier attacker, Weapon incomingWeapon) {
    Shield? shield =
        target.soldier.equippedItems[EquipmentSlot.shield] as Shield?;
    if (shield == null || shield.condition <= 0) return false;

    double baseChance = shield.blockChance;
    double skillBonus = (target.soldier.shieldSkill - 5) * 0.02;
    double strengthBonus = (target.soldier.strength - 5) * 0.01;
    double exhaustionPenalty = max(0, target.currentExhaustion - 2.0) * 0.01;

    double finalChance =
        baseChance + skillBonus + strengthBonus - exhaustionPenalty;
    finalChance = finalChance.clamp(0.0, 0.9);

    int requiredRoll = (100 - (finalChance * 100)).floor();
    int roll = _random.nextInt(100) + 1;
    bool success = roll >= requiredRoll;

    _logMessage(
        "Block calc: ${(baseChance * 100).toStringAsFixed(0)}% base + ${(skillBonus * 100).toStringAsFixed(0)}% skill + ${(strengthBonus * 100).toStringAsFixed(0)}% str - ${(exhaustionPenalty * 100).toStringAsFixed(0)}% exhaust = ${(finalChance * 100).toStringAsFixed(0)}%. Needs $requiredRoll+, rolls $roll.",
        isInternal: false,
        severity: EventSeverity.low,
        soldierId: target.soldier.id);

    if (success) {
      _logMessage("${target.soldier.name} blocks the blow!",
          isInternal: false,
          severity: EventSeverity.low,
          soldierId: target.soldier.id);
    }
    return success;
  }

  Map<int, int> _consecutiveShots = {};

  bool _runExhaustionCheck(
      CombatSoldier attacker, ItemType weaponType, bool isCharge) {
    double failChance = 0.0;
    Weapon? weapon =
        attacker.soldier.equippedItems[EquipmentSlot.melee] as Weapon?;
    double basePotentialCost = _getAttackExhaustionCost(weapon, isCharge);

    if (weaponType == ItemType.bow) {
      int turnsSinceLastShot =
          _turn - (_consecutiveShots[attacker.soldier.id] ?? -5);
      if (turnsSinceLastShot == 1)
        failChance += 0.10;
      else if (turnsSinceLastShot == 2)
        failChance += 0.08;
      else if (turnsSinceLastShot == 3)
        failChance += 0.06;
      else if (turnsSinceLastShot <= 5) failChance += 0.03;
    }

    failChance += basePotentialCost * 1.0;
    failChance += max(0, attacker.currentExhaustion - 2.0) * 0.1;
    failChance -= (attacker.soldier.stamina - 5) * 0.03;

    failChance = failChance.clamp(0.0, 0.8);

    int requiredRoll = (failChance * 100).floor();
    int roll = _random.nextInt(100) + 1;
    bool failed = roll <= requiredRoll;

    _logMessage(
        "Exhaust check: ${(basePotentialCost * 100).toStringAsFixed(0)}% base cost + ${(max(0, attacker.currentExhaustion - 2.0) * 10).toStringAsFixed(0)}% exhaust penalty - ${((attacker.soldier.stamina - 5) * 3).toStringAsFixed(0)}% stamina bonus = Fail chance: ${(failChance * 100).toStringAsFixed(0)}%. Rolls $roll (fails if <= required).",
        isInternal: false,
        severity: EventSeverity.low,
        soldierId: attacker.soldier.id);

    if (failed) {
      _logMessage(
          "${attacker.soldier.name} is too exhausted to perform the action!",
          isInternal: false,
          severity: EventSeverity.normal,
          isGoodNews: false,
          soldierId: attacker.soldier.id);
    } else if (weaponType == ItemType.bow) {
      _consecutiveShots[attacker.soldier.id] = _turn;
    }
    return failed;
  }

  bool _runHitCheck(CombatSoldier attacker, CombatSoldier target, Weapon weapon,
      bool isCharge,
      {bool isTargetBlocking = false,
      bool targetDodged = false,
      bool blockedByShield = false}) {
    if (!attacker.isAlive || (!target.isAlive && !target.isUnconscious))
      return false;

    if (targetDodged || blockedByShield) return false;

    double baseHitChance = 0.65;
    double relevantSkill = 0.0;
    switch (weapon.itemType) {
      case ItemType.bow:
        relevantSkill = attacker.isMounted
            ? attacker.soldier.mountedArcherySkill
            : attacker.soldier.longRangeArcherySkill;
        break;
      case ItemType.throwingSpear:
      case ItemType.spear:
      case ItemType.lance:
        relevantSkill = attacker.soldier.spearSkill;
        break;
      case ItemType.sword:
      case ItemType.axe:
      case ItemType.mace:
        relevantSkill = attacker.soldier.swordSkill;
        break;
      default:
        relevantSkill = 0.0;
        break;
    }

    double skillModifier = (relevantSkill - 5) * 0.03;
    double exhaustionModifier =
        -max(0, attacker.currentExhaustion - 2.0) * 0.02;
    double coverModifier = 1.0;
    BattlefieldTile? targetTile = _battlefield.getTile(
        target.x.round().clamp(0, _battlefield.width - 1),
        target.y.round().clamp(0, _battlefield.length - 1));

    if (targetTile != null && targetTile.providesCover) {
      coverModifier = 0.7;
      _logMessage("${target.soldier.name} is in cover!",
          isInternal: true, soldierId: target.soldier.id);
    }

    double rangeModifier = 1.0;
    if (weapon.effectiveRange > 0) {
      double distance =
          (attacker.positionVector - target.positionVector).distance;
      if (distance > weapon.effectiveRange) {
        rangeModifier = 0.5;
      } else if (distance > weapon.effectiveRange * 0.75) {
        rangeModifier = 0.8;
      }
    }

    double targetBlockingModifier = (isTargetBlocking &&
            (weapon.itemType == ItemType.bow ||
                weapon.itemType == ItemType.throwingSpear))
        ? 0.3
        : 1.0;
    double unconsciousTargetModifier = target.isUnconscious ? 2.0 : 1.0;

    double finalHitChance = baseHitChance + skillModifier + exhaustionModifier;
    finalHitChance *= coverModifier *
        rangeModifier *
        targetBlockingModifier *
        unconsciousTargetModifier;
    finalHitChance = finalHitChance.clamp(0.05, 0.95);

    int requiredRoll = (100 - (finalHitChance * 100)).floor();
    int roll = _random.nextInt(100) + 1;
    bool success = roll >= requiredRoll;

    _logMessage(
        "Hit calc: 65% base + ${(skillModifier * 100).toStringAsFixed(0)}% skill - ${(max(0, attacker.currentExhaustion - 2.0) * 2).toStringAsFixed(0)}% exhaust + modifiers (Cover: ${coverModifier.toStringAsFixed(1)}, Range: ${rangeModifier.toStringAsFixed(1)}) = Final: ${(finalHitChance * 100).toStringAsFixed(0)}%. Needs $requiredRoll+, rolls $roll.",
        isInternal: false,
        severity: EventSeverity.normal,
        soldierId: attacker.soldier.id);

    if (!success)
      _logMessage("${attacker.soldier.name} misses ${target.soldier.name}.",
          isInternal: false,
          severity: EventSeverity.normal,
          isGoodNews: false,
          soldierId: attacker.soldier.id);
    else
      _logMessage("${attacker.soldier.name} HITS ${target.soldier.name}!",
          isInternal: false,
          severity: EventSeverity.high,
          soldierId: attacker.soldier.id);

    return success;
  }

  void _logMessage(String message,
      {bool isGoodNews = true,
      bool isInternal = false,
      EventSeverity severity = EventSeverity.normal,
      int? soldierId,
      String? aravtId,
      EventCategory category = EventCategory.combat}) {
    print("[Turn $_turn] $message");
    _combatLog.add("[Turn $_turn] $message");

    // Always log to GameState now to provide technical transparency as requested
    try {
      _gameState.logEvent(message,
          category: category,
          severity: severity,
          soldierId: soldierId,
          aravtId: aravtId,
          isPlayerKnown: (soldierId != null &&
                  _gameState.horde.any((s) => s.id == soldierId)) ||
              (aravtId != null &&
                  _gameState.aravts.any((a) => a.id == aravtId)) ||
              (soldierId == null && aravtId == null));
    } catch (e) {
      print("!!! Error during GameState logging: $e");
    }
  }

  Equipment? _getArmorForLocation(CombatSoldier target, HitLocation location) {
    Map<EquipmentSlot, InventoryItem> items = target.soldier.equippedItems;
    switch (location) {
      case HitLocation.head:
        return items[EquipmentSlot.helmet] as Equipment?;
      case HitLocation.body:
        return items[EquipmentSlot.armor] as Equipment?;
      case HitLocation.leftArm:
        return items[EquipmentSlot.gauntlets] as Equipment?;
      case HitLocation.rightArm:
        return items[EquipmentSlot.gauntlets] as Equipment?;
      case HitLocation.leftLeg:
        return items[EquipmentSlot.boots] as Equipment?;
      case HitLocation.rightLeg:
        return items[EquipmentSlot.boots] as Equipment?;
    }
  }
}
