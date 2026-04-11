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

import 'dart:async';
import 'dart:math' as math;
import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/combat_flow_state.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/horde_data.dart';
// Added imports
import 'dart:convert';
import '../models/inventory_item.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/yurt_data.dart';
import 'package:aravt/models/mission_models.dart';
import 'package:aravt/models/settlement_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/game_turn.dart';
import 'package:flutter/foundation.dart';
import 'package:aravt/services/game_setup_service.dart' as setup_service;
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/combat_report.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/services/combat_service.dart';

import 'package:aravt/models/location_data.dart';
import 'package:aravt/services/next_turn_service.dart';
import 'package:aravt/services/save_load_service.dart';
import 'package:aravt/models/save_file_info.dart';
import 'package:aravt/models/prisoner_action.dart';
import 'package:aravt/services/training_service.dart';
import 'package:aravt/models/tournament_data.dart';
import 'package:aravt/models/hunting_report.dart';
import 'package:aravt/models/fishing_report.dart';
import 'package:aravt/models/herd_data.dart';
import 'package:aravt/models/resource_report.dart';
import 'package:aravt/models/narrative_models.dart';
import 'package:aravt/models/trade_report.dart';
import 'package:aravt/models/wealth_event.dart';
import 'package:aravt/models/culinary_news.dart';
import 'package:aravt/models/material_flow.dart';
import 'package:aravt/models/shepherding_report.dart';

import 'package:aravt/models/history_models.dart';
import 'package:aravt/services/history_service.dart';
import 'package:aravt/models/pillage_report.dart';
import 'package:aravt/models/fletching_report.dart';
import 'package:aravt/models/training_report.dart';

enum WealthStatus {
  destitution,
  poverty,
  subsistence,
  sufficiency,
  comfort,
  abundance,
  excess
}

enum MapLevel { area, region, world }

class ActiveCombatState {
  final List<Soldier> playerSoldiers;
  final List<Soldier> opponentSoldiers;
  final List<Aravt> playerAravts;
  final List<Aravt> opponentAravts;

  ActiveCombatState({
    required this.playerSoldiers,
    required this.opponentSoldiers,
    required this.playerAravts,
    required this.opponentAravts,
  });
}

class GameState with ChangeNotifier {
  List<Soldier> horde = [];
  List<Aravt> aravts = [];
  List<Mission> missions = [];
  List<Yurt> yurts = [];
  List<CombatReport> combatReports = [];

  List<TournamentResult> tournamentHistory = [];
  List<FutureTournament> upcomingTournaments = [];
  ActiveTournament? activeTournament;
  Map<TournamentEventType, int> currentChampions = {};

  List<double> wealthHistory = [];
  List<ResourceReport> resourceReports = [];

  List<HuntingTripReport> huntingReports = [];
  List<FishingTripReport> fishingReports = [];
  List<ShepherdingReport> shepherdingReports = [];
  List<FletchingReport> fletchingReports = [];
  List<TrainingReport> trainingReports = [];
  List<PillageReport> pillageReports = [];

  final HistoryService historyService = HistoryService();
  List<DailySnapshot> get history => historyService.history;

  NarrativeEvent? activeNarrativeEvent;
  bool hasDay5TradeOccurred = false;

  Set<String> viewedReportTabs = {};

  bool tutorialCompleted = false;
  bool tutorialPermanentlyDismissed = false;
  int tutorialDismissalCount = 0;
  int tutorialStepIndex = 0;

  String difficulty = 'medium';
  String hordeName = "Player Horde";
  double? hordePanelHeight;

  bool isGameOver = false;
  String? gameOverReason;
  bool isSimulatorCombat = false;

  bool isPlayerHordeAutomated = true;
  bool get isPlayerLeader => player?.role == SoldierRole.hordeLeader;

  GameArea? currentArea;
  Soldier? player;

  final Map<int, Soldier> _soldierCache = {};
  final Map<String, PointOfInterest> _poiCache = {};
  final Map<String, Aravt> _aravtCache = {};

  void rebuildCaches() {
    _soldierCache.clear();
    _aravtCache.clear();
    for (var s in horde) {
      _soldierCache[s.id] = s;
    }
    for (var a in aravts) {
      _aravtCache[a.id] = a;
    }
    for (var a in npcAravts1) {
      _aravtCache[a.id] = a;
    }
    for (var a in npcAravts2) {
      _aravtCache[a.id] = a;
    }
    for (var a in garrisonAravts) {
      _aravtCache[a.id] = a;
    }
    for (var s in npcHorde1) {
      _soldierCache[s.id] = s;
    }
    for (var s in npcHorde2) {
      _soldierCache[s.id] = s;
    }
    for (var s in garrisonSoldiers) {
      _soldierCache[s.id] = s;
    }

    _poiCache.clear();
    for (var area in worldMap.values) {
      for (var poi in area.pointsOfInterest) {
        _poiCache[poi.id] = poi;
      }
    }
  }

  Soldier? get khan => horde.cast<Soldier?>().firstWhere(
        (s) => s?.role == SoldierRole.hordeLeader,
        orElse: () => null,
      );

  GameDate? currentDate;
  int? tutorialCaptainId;

  MapLevel _lastMapLevel = MapLevel.area;
  MapLevel get lastMapLevel => _lastMapLevel;

  void setMapLevel(MapLevel level) {
    if (_lastMapLevel != level) {
      _lastMapLevel = level;
      notifyListeners();
    }
  }

  void setPlayer(Soldier newPlayer) {
    player = newPlayer;
    notifyListeners();
  }

  Map<String, GameArea> worldMap = {};
  HexCoordinates? _cachedPlayerCampPosition;
  HexCoordinates? get playerCampPosition {
    if (_cachedPlayerCampPosition != null) return _cachedPlayerCampPosition;
    for (var area in worldMap.values) {
      if (area.type == AreaType.PlayerCamp) {
        _cachedPlayerCampPosition = area.coordinates;
        return _cachedPlayerCampPosition;
      }
    }
    return null;
  }

  bool isCaravanMode = false;
  double packingProgress = 0.0;
  HexCoordinates? caravanPosition;

  void startPacking() {
    isCaravanMode = false;
    packingProgress = 0.0;
    notifyListeners();
  }

  void updatePackingProgress(double progress) {
    packingProgress = progress.clamp(0.0, 1.0);
    if (packingProgress >= 1.0) {
      finishPacking();
    } else {
      notifyListeners();
    }
  }

  void finishPacking() {
    isCaravanMode = true;
    packingProgress = 1.0;

    for (var area in worldMap.values) {
      if (area.type == AreaType.PlayerCamp) {
        area.type = AreaType.Neutral;
        caravanPosition = area.coordinates;
        area.pointsOfInterest.removeWhere((p) => p.id == 'camp-player');
      }
    }

    if (caravanPosition == null && currentArea != null) {
      caravanPosition = currentArea!.coordinates;
    }

    _cachedPlayerCampPosition = null;
    notifyListeners();
  }

  void establishCamp(HexCoordinates position) {
    isCaravanMode = false;
    packingProgress = 0.0;
    caravanPosition = null;
    _cachedPlayerCampPosition = position;

    for (var area in worldMap.values) {
      if (area.coordinates == position) {
        area.type = AreaType.PlayerCamp;
        if (!area.pointsOfInterest.any((p) => p.id == 'camp-player')) {
          area.pointsOfInterest.add(PointOfInterest(
            id: 'camp-player',
            name: 'My Camp',
            type: PoiType.camp,
            description: 'Your horde\'s current camp.',
            isDiscovered: true,
            position: position,
          ));
        }
        break;
      }
    }

    notifyListeners();
  }

  Future<void> moveCaravan(HexCoordinates newPos) async {
    if (caravanPosition == null) return;
    int distance = caravanPosition!.distanceTo(newPos);
    if (distance != 1) return;

    caravanPosition = newPos;

    logEvent(
      "The caravan moves to a new location.",
      category: EventCategory.general,
      severity: EventSeverity.normal,
    );

    notifyListeners();

    await advanceToNextTurn();
  }

  List<Settlement> settlements = [];

  final NextTurnService _nextTurnService = NextTurnService();
  GameTurn turn = GameTurn();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final SaveLoadService _saveLoadService = SaveLoadService();
  bool autoSaveEnabled = true;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  GameDate get gameDate {
    if (currentDate == null) {
      return GameDate(1206, 1, 1);
    }
    return currentDate!;
  }

  bool isOmniscientMode = false;

  int get totalListenCount {
    return horde.where((s) => s.queuedListenItem != null && !s.isPlayer).length;
  }

  bool isHordePanelOpen = false;
  void toggleHordePanel() {
    isHordePanelOpen = !isHordePanelOpen;
    notifyListeners();
  }

  void setHordePanelOpen(bool isOpen) {
    if (isHordePanelOpen != isOpen) {
      isHordePanelOpen = isOpen;
      notifyListeners();
    }
  }

  void setHordePanelHeight(double height) {
    if (hordePanelHeight != height) {
      hordePanelHeight = height;
      notifyListeners();
    }
  }

  bool isOmniscienceAllowed = false;
  bool isGameInitialized = false;
  int _soldierIdCounter = 10000;

  int getNextSoldierId() {
    return _soldierIdCounter++;
  }

  List<Soldier> npcHorde1 = [];
  List<Aravt> npcAravts1 = [];
  List<Soldier> npcHorde2 = [];
  List<Aravt> npcAravts2 = [];
  List<Soldier> garrisonSoldiers = [];
  List<Aravt> garrisonAravts = [];
  List<List<Soldier>> splinterHordes = [];
  List<List<Aravt>> splinterAravts = [];

  List<InventoryItem> get playerInventory => player?.personalInventory ?? [];

  Map<EquipmentSlot, InventoryItem> get playerEquippedItems =>
      player?.equippedItems ?? {};

  double _communalMeat = 100.0;
  double get communalMeat => _communalMeat;

  double _communalRice = 50.0;
  double get communalRice => _communalRice;

  double _communalIronOre = 0.0;
  double get communalIronOre => _communalIronOre;

  void addCommunalRupees(double amount) {
    _communalRupees += amount;
    notifyListeners();
  }

  void addCommunalScrap(double amount) {
    _communalScrap += amount;
    if (amount > 0) _cumulativeScrapScavenged += amount;
    notifyListeners();
  }

  double _communalWood = 50.0;
  double get communalWood => _communalWood;

  double _communalScrap = 50.0;
  double get communalScrap => _communalScrap;

  int _communalArrows = 1500;
  int get communalArrows => _communalArrows;

  int _communalShortArrows = 1000;
  int get communalShortArrows => _communalShortArrows;

  int _communalLongArrows = 500;
  int get communalLongArrows => _communalLongArrows;

  double _communalRupees = 0.0;
  double get communalRupees => _communalRupees;

  double _cumulativeMeatGathered = 0.0;
  double get cumulativeMeatGathered => _cumulativeMeatGathered;
  double _cumulativeWoodGathered = 0.0;
  double get cumulativeWoodGathered => _cumulativeWoodGathered;
  double _cumulativeIronMined = 0.0;
  double get cumulativeIronMined => _cumulativeIronMined;
  double _cumulativeScrapScavenged = 0.0;
  double get cumulativeScrapScavenged => _cumulativeScrapScavenged;
  int _cumulativeShortArrowsFletched = 0;
  int get cumulativeShortArrowsFletched => _cumulativeShortArrowsFletched;
  int _cumulativeLongArrowsFletched = 0;
  int get cumulativeLongArrowsFletched => _cumulativeLongArrowsFletched;

  List<InventoryItem> communalStash = [];

  Map<String, double> _locationResourceLevels = {};

  List<Mount> _communalHerd = [];
  List<Mount> get communalHerd => _communalHerd;

  late Herd communalCattle;

  double _communalMilk = 0.0;
  double get communalMilk => _communalMilk;

  double _communalCheese = 0.0;
  double get communalCheese => _communalCheese;

  double _communalGrain = 0.0;
  double get communalGrain => _communalGrain;

  List<int> butcheringQueue = [];

  double butcheringRate = 1.0;
  bool allowAlcohol = true;
  bool vegetarianDiet = false;

  List<TradeReport> tradeReports = [];
  List<WealthEvent> wealthEvents = [];

  Map<String, FabricationTarget> fabricationTargets = {};
  List<MaterialFlowEntry> materialFlowHistory = [];

  List<CulinaryNews> culinaryNews = [];

  Map<String, Map<String, double>> campLayout = {};

  CombatSimulator? currentCombat;
  ActiveCombatState? activeCombat;
  final math.Random _random = math.Random();

  CombatFlowState _combatFlowState = CombatFlowState.none;
  CombatFlowState get combatFlowState => _combatFlowState;

  @protected
  ActiveCombatState? pendingCombat;
  ActiveCombatState? get pendingCombatState => pendingCombat;
  @protected
  CombatReport? lastCombatReport;
  CombatReport? get latestCombatReport => lastCombatReport;

  double combatSpeedMultiplier = 1.0;
  bool isCombatPaused = true;

  List<GameEvent> eventLog = [];

  int _interactionTokensRemaining = 10;
  int get interactionTokensRemaining => _interactionTokensRemaining;

  bool musicEnabled = true;
  double musicVolume = 0.5;
  bool sfxEnabled = true;
  double sfxVolume = 0.5;

  GameState() {
    communalCattle = Herd(type: AnimalType.Cattle);
  }

  void setMusicEnabled(bool value) {
    musicEnabled = value;
    notifyListeners();
  }

  void setMusicVolume(double value) {
    musicVolume = value;
    notifyListeners();
  }

  void setSfxEnabled(bool value) {
    sfxEnabled = value;
    notifyListeners();
  }

  void setSfxVolume(double value) {
    sfxVolume = value;
    notifyListeners();
  }

  void setAutoSaveEnabled(bool value) {
    autoSaveEnabled = value;
    notifyListeners();
  }

  void triggerUpdate() {
    notifyListeners();
  }

  void addTrainingReport(TrainingReport report) {
    trainingReports.add(report);
    notifyListeners();
  }

  void addShepherdingReport(ShepherdingReport report) {
    shepherdingReports.add(report);
    notifyListeners();
  }

  void addFletchingReport(FletchingReport report) {
    fletchingReports.add(report);
    notifyListeners();
  }

  WealthStatus get currentWealthStatus {
    double totalSupply = _calculateTotalSupplyWealth();
    int hordeSize = horde.length;
    double perCapita = hordeSize > 0 ? totalSupply / hordeSize : 0;

    if (perCapita < 5) return WealthStatus.destitution;
    if (perCapita < 15) return WealthStatus.poverty;
    if (perCapita < 30) return WealthStatus.subsistence;
    if (perCapita < 60) return WealthStatus.sufficiency;
    if (perCapita < 90) return WealthStatus.comfort;
    if (perCapita < 120) return WealthStatus.abundance;
    return WealthStatus.excess;
  }

  double get scrapToRupeeConversion {
    switch (currentWealthStatus) {
      case WealthStatus.destitution:
        return 3.0;
      case WealthStatus.poverty:
        return 2.0;
      case WealthStatus.subsistence:
        return 1.5;
      case WealthStatus.sufficiency:
        return 1.0;
      case WealthStatus.comfort:
        return 0.67;
      case WealthStatus.abundance:
        return 0.5;
      case WealthStatus.excess:
        return 0.33;
    }
  }

  double _calculateTotalSupplyWealth() {
    double total = 0.0;

    total += _communalWood * 0.5;
    total += _communalIronOre * 1.0;
    total += _communalScrap * 1.0;
    total += _communalShortArrows * 0.5;
    total += _communalLongArrows * 0.7;
    total += _communalMeat * 2.0;
    total += _communalRice * 1.0;
    total += _communalMilk * 1.5;
    total += _communalCheese * 2.0;
    total += _communalGrain * 1.0;

    for (var item in communalStash) {
      if (item.valueType == ValueType.Supply) {
        total += item.baseValue;
      }
    }

    total += communalCattle.totalPopulation * 200.0;
    total += _communalHerd.length * 300.0;

    return total;
  }

  Soldier? findSoldierById(int id) {
    if (_soldierCache.containsKey(id)) return _soldierCache[id];
    for (var s in horde) {
      if (s.id == id) {
        _soldierCache[id] = s;
        return s;
      }
    }
    return null;
  }

  Aravt? findAravtById(String? id) {
    if (id == null) return null;
    if (_aravtCache.containsKey(id)) return _aravtCache[id];
    for (var a in aravts) {
      if (a.id == id) {
        _aravtCache[id] = a;
        return a;
      }
    }
    for (var a in npcAravts1) {
      if (a.id == id) {
        _aravtCache[id] = a;
        return a;
      }
    }
    for (var a in npcAravts2) {
      if (a.id == id) {
        _aravtCache[id] = a;
        return a;
      }
    }
    for (var a in garrisonAravts) {
      if (a.id == id) {
        _aravtCache[id] = a;
        return a;
      }
    }
    return null;
  }

  PointOfInterest? findPoiByIdWorld(String id) {
    if (_poiCache.containsKey(id)) return _poiCache[id];

    for (final area in worldMap.values) {
      final poi = area.findPoiById(id);
      if (poi != null) {
        _poiCache[id] = poi;
        return poi;
      }
    }
    return null;
  }

  Settlement? findSettlementById(String id) {
    for (var s in settlements) { if (s.id == id) return s; }
    return null;
  }

  Map<String, int> unreadReportCounts = {};

  int getBadgeCountForFoodSubTab(String subTab) {
    return unreadReportCounts['Food_$subTab'] ?? 0;
  }

  int getBadgeCountForTab(String tabName) {
    if (tabName == 'Chronicle') {
      return (unreadReportCounts['Event Log'] ?? 0) +
          (unreadReportCounts['Combat'] ?? 0) +
          (unreadReportCounts['Timeline'] ?? 0);
    }
    if (tabName == 'Logistics') {
      return (unreadReportCounts['Finance'] ?? 0) +
          (unreadReportCounts['Industry'] ?? 0) +
          (unreadReportCounts['Khan'] ?? 0) +
          (unreadReportCounts['Communal'] ?? 0) +
          (unreadReportCounts['Global'] ?? 0);
    }
    if (tabName == 'Provisions') {
      return (unreadReportCounts['Food'] ?? 0) +
          (unreadReportCounts['Herds'] ?? 0) +
          (unreadReportCounts['Hunting'] ?? 0) +
          (unreadReportCounts['Fishing'] ?? 0);
    }
    if (tabName == 'Military') {
      return (unreadReportCounts['Health'] ?? 0) +
          (unreadReportCounts['Training'] ?? 0) +
          (unreadReportCounts['Games'] ?? 0);
    }
    if (tabName == 'World') {
      return (unreadReportCounts['Diplomacy'] ?? 0);
    }

    return unreadReportCounts[tabName] ?? 0;
  }

  int getBadgeCountForCommerceSubTab(String subTab) {
    return unreadReportCounts['Commerce_$subTab'] ?? 0;
  }

  bool isPlayerAravtReport(GameEvent event) {
    if (turn.turnNumber > 7) return false;
    if (event.relatedAravtId == null) return false;
    return event.relatedAravtId!.contains("Third") ||
        event.relatedAravtId!.contains("aravt_3");
  }

  int getReportsBadgeCount() {
    int total = 0;
    final mainTabs = [
      'Event Log',
      'Combat',
      'History',
      'Health',
      'Commerce',
      'Inventory',
      'Herds',
      'Food',
      'Hunting',
      'Fishing',
      'Games',
      'Training',
      'Diplomacy'
    ];
    for (var tab in mainTabs) {
      total += getBadgeCountForTab(tab);
    }
    return total;
  }

  int getCampBadgeCount() {
    return 0;
  }

  void markReportTabViewed(String tabName, {String? subTab}) {
    if (subTab != null) {
      unreadReportCounts['${tabName}_$subTab'] = 0;
      unreadReportCounts[subTab] = 0; // Legacy support
      print("[BADGE] Cleared sub-tab badge: ${tabName}_$subTab");
    } else {
      unreadReportCounts[tabName] = 0;
      print("[BADGE] Cleared parent tab badge: $tabName");
      
      // Handle group clearings to avoid overcounting / stale badges
      if (tabName == 'Military') {
        // Preserving Health and Training badges for sub-tab viewing
        // Do NOT clear Games here - user wants that to persist until expansion
        print("[BADGE] Parent Military viewed. (Games/Health/Training preserved)");
      } else if (tabName == 'Chronicle') {
        unreadReportCounts['Event Log'] = 0;
        unreadReportCounts['Combat'] = 0;
        unreadReportCounts['Timeline'] = 0;
        print("[BADGE] Auto-cleared Chronicle sub-tabs");
      } else if (tabName == 'Logistics') {
        unreadReportCounts['Finance'] = 0;
        unreadReportCounts['Industry'] = 0;
        unreadReportCounts['Personal'] = 0;
        unreadReportCounts['Communal'] = 0;
        unreadReportCounts['Global'] = 0;
        print("[BADGE] Auto-cleared Logistics sub-tabs");
      } else if (tabName == 'Provisions') {
        unreadReportCounts['Food'] = 0;
        unreadReportCounts['Herds'] = 0;
        unreadReportCounts['Hunting'] = 0;
        unreadReportCounts['Fishing'] = 0;
        print("[BADGE] Auto-cleared Provisions sub-tabs");
      }
    }
    notifyListeners();
  }

  int getBadgeCountForTabAndSoldier(String tabName, int soldierId) {
    String soldierTabKey = '${tabName}_soldier_$soldierId';
    return unreadReportCounts[soldierTabKey] ?? 0;
  }

  void markReportTabViewedForSoldier(String tabName, int soldierId) {
    String soldierTabKey = '${tabName}_soldier_$soldierId';
    unreadReportCounts[soldierTabKey] = 0;
    notifyListeners();
  }

  String _getTabNameForCategory(EventCategory category) {
    switch (category) {
      case EventCategory.combat:
        return 'Combat';
      case EventCategory.games:
        return 'Games';
      case EventCategory.hunting:
        return 'Hunting';
      case EventCategory.food:
        return 'Food';
      case EventCategory.finance:
        return 'Finance';
      case EventCategory.industry:
        return 'Industry';
      case EventCategory.inventory:
        return 'Personal'; // Khan's Personal Inventory
      case EventCategory.global:
        return 'Global';
      case EventCategory.health:
        return 'Health';
      case EventCategory.herds:
      case EventCategory.horses:
        return 'Herds';
      case EventCategory.diplomacy:
        return 'Diplomacy';
      case EventCategory.training:
        return 'Training';
      default:
        return 'Event Log';
    }
  }

  void addCombatReport(CombatReport report) {
    combatReports.add(report);
    notifyListeners();
  }

  void recordWealthHistory() {
    double currentWealth = (player?.treasureWealth ?? 0) +
        communalScrap * 5.0;
    wealthHistory.add(currentWealth);
    if (wealthHistory.length > 30) {
      wealthHistory.removeAt(0);
    }
    notifyListeners();
  }

  void addTournamentResult(TournamentResult result) {
    tournamentHistory.add(result);
    upcomingTournaments.removeWhere((future) =>
        future.date.year == result.date.year &&
        future.date.month == result.date.month &&
        future.date.day == result.date.day);

    logEvent(
      "The ${result.name} has concluded! Check Global Reports for details.",
      category: EventCategory.games,
      severity: EventSeverity.high,
    );
    notifyListeners();
  }

  void addHuntingReport(HuntingTripReport report) {
    huntingReports.add(report);
    notifyListeners();
  }

  void addFishingReport(FishingTripReport report) {
    fishingReports.add(report);
    notifyListeners();
  }

  void addPillageReport(PillageReport report) {
    pillageReports.add(report);
    notifyListeners();
  }

  void addResourceReport(ResourceReport report) {
    resourceReports.add(report);
    notifyListeners();
  }

  void addCommunalMeat(double amount) {
    _communalMeat += amount;
    if (amount > 0) _cumulativeMeatGathered += amount;
    notifyListeners();
  }

  void addCommunalIronOre(double amount) {
    _communalIronOre += amount;
    if (amount > 0) _cumulativeIronMined += amount;
    notifyListeners();
  }

  void addCommunalWood(double amount) {
    _communalWood += amount;
    if (amount > 0) _cumulativeWoodGathered += amount;
    notifyListeners();
  }

  void removeCommunalScrap(double amount) {
    _communalScrap = math.max(0.0, _communalScrap - amount);
    notifyListeners();
  }

  void addCommunalArrows(int amount, {bool isLong = false}) {
    if (isLong) {
      _communalLongArrows += amount;
      if (amount > 0) _cumulativeLongArrowsFletched += amount;
    } else {
      _communalShortArrows += amount;
      if (amount > 0) _cumulativeShortArrowsFletched += amount;
    }
    notifyListeners();
  }

  void addItemToCommunalStash(InventoryItem item) {
    communalStash.add(item);
    notifyListeners();
  }

  double? getLocationResourceLevel(String locationId) {
    return _locationResourceLevels[locationId];
  }

  void updateLocationResourceLevel(String locationId, double level) {
    _locationResourceLevels[locationId] = level.clamp(0.0, 1.0);
  }

  void startNarrativeEvent(NarrativeEvent event) {
    activeNarrativeEvent = event;
    if (event.type == NarrativeEventType.day5Trade) {
      hasDay5TradeOccurred = true;
    }
    notifyListeners();
  }

  void dismissNarrativeEvent() {
    activeNarrativeEvent = null;
    notifyListeners();
  }

  void triggerGameOver(String reason) {
    if (isGameOver) return;
    isGameOver = true;
    gameOverReason = reason;
    notifyListeners();
  }

  void logEvent(
    String message, {
    bool isPlayerKnown = true,
    EventCategory category = EventCategory.general,
    EventSeverity severity = EventSeverity.normal,
    int? soldierId,
    String? aravtId,
  }) {
    if (currentDate == null) return;
    final newEvent = GameEvent(
      message: message,
      date: currentDate!.copy(),
      isPlayerKnown: isPlayerKnown,
      category: category,
      severity: severity,
      relatedSoldierId: soldierId,
      relatedAravtId: aravtId,
    );

    if (eventLog.isNotEmpty) {
      final lastEvent = eventLog.first;
      if (lastEvent.message == newEvent.message &&
          lastEvent.relatedSoldierId == newEvent.relatedSoldierId &&
          lastEvent.date.totalDays == newEvent.date.totalDays) { // Deduplicate within same day
        return;
      }
    }

    eventLog.insert(0, newEvent);
    
    // Only increment badges for non-low severity events to prevent flood
    final String tabId = _getTabNameForCategory(category);
    
    // Safety constraint: during first 10 turns, only tournament events should badge
    bool shouldSuppress = turn.turnNumber <= 10 && !message.contains("Tournament");
    if (severity != EventSeverity.low && !shouldSuppress) {
      if (turn.turnNumber <= 10) {
        unreadReportCounts[tabId] = 1; // Clamp to 1 during early game
      } else {
        unreadReportCounts[tabId] = (unreadReportCounts[tabId] ?? 0) + 1;
      }
      print("[BADGE_AUDIT] Incremented '$tabId' badge. (Turn ${turn.turnNumber})");
      print("  Severity: $severity");
      print("  Category: $category");
      print("  Reason/Message: ${message.length > 60 ? message.substring(0, 60) + "..." : message}");
      print("  New Count: ${unreadReportCounts[tabId]}");
    } else if (shouldSuppress) {
      print("[BADGE_AUDIT] Suppressed early game badge for turn ${turn.turnNumber}: $message");
    }
    if (eventLog.length > 1000) {
      eventLog.removeLast();
    }

    if (severity == EventSeverity.critical || severity == EventSeverity.high) {
      viewedReportTabs.remove(tabId);
    }

    notifyListeners();
  }

  void setCurrentArea(HexCoordinates coordinates) {
    final newArea = worldMap[coordinates.toString()];
    if (newArea != null) {
      currentArea = newArea;
      notifyListeners();
    }
  }

  List<GameArea> getNeighborsOf(HexCoordinates centerHex) {
    final List<GameArea> neighbors = [];
    final List<HexCoordinates> neighborCoordinatesList =
        centerHex.getNeighbors();
    for (final neighborCoords in neighborCoordinatesList) {
      final neighborArea = worldMap[neighborCoords.toString()];
      if (neighborArea != null) {
        neighbors.add(neighborArea);
      }
    }
    return neighbors;
  }

  void clearAravtAssignment(Aravt aravt) {
    final previousLocationId = aravt.assignmentLocationId;

    if (previousLocationId != null) {
      PointOfInterest? previousPoi;
      for (final area in worldMap.values) {
        previousPoi = area.findPoiById(previousLocationId);
        if (previousPoi != null) break;
      }

      if (previousPoi != null) {
        previousPoi.assignedAravtIds.remove(aravt.id);
      }
    }

    aravt.task = null;

    logEvent(
      "${aravt.id} has been set to Resting.",
      category: EventCategory.general,
      aravtId: aravt.id,
    );
    notifyListeners();
  }

  void assignAravtToPoi(
      Aravt aravt, PointOfInterest poi, AravtAssignment assignment,
      {String? option}) {
    String? finalOption = option;

    if (assignment == AravtAssignment.Train && finalOption == null) {
      final captain = findSoldierById(aravt.captainId);
      if (captain != null) {
        int skillType = TrainingService.getTrainingSkillType(captain);
        finalOption = TrainingService.getTrainingName(skillType);
      }
    }

    if (aravt.task is TradeTask) {
      final tradeTask = aravt.task as TradeTask;
      communalStash.addAll(tradeTask.cargo);
      _communalHerd.addAll(tradeTask.horses);

      tradeTask.resources.forEach((key, amount) {
        switch (key) {
          case 'scrap':
            addCommunalScrap(amount);
            break;
          case 'rupees':
            addCommunalRupees(amount);
            break;
          case 'wood':
            _communalWood += amount;
            break;
          case 'iron':
            _communalIronOre += amount;
            break;
          case 'meat':
            _communalMeat += amount;
            break;
          case 'rice':
            _communalRice += amount;
            break;
          case 'short_arrows':
            _communalShortArrows += amount.toInt();
            break;
          case 'long_arrows':
            _communalLongArrows += amount.toInt();
            break;
        }
      });
    }

    clearAravtAssignment(aravt);

    if (!poi.assignedAravtIds.contains(aravt.id)) {
      poi.assignedAravtIds.add(aravt.id);
    }

    bool needsTravel = false;
    double travelSeconds = 0;
    if (aravt.hexCoords != poi.position) {
      int distance = aravt.hexCoords.distanceTo(poi.position);
      if (distance > 0) {
        needsTravel = true;
        travelSeconds = distance * 86400.0;
      }
    }

    if (assignment == AravtAssignment.Trade) {
      final cargo = <InventoryItem>[];
      final horses = <Mount>[];

      if (finalOption != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(finalOption);
          final ids = List<String>.from(data['cargoItemIds'] ?? []);
          for (var id in ids) {
            final index = communalStash.indexWhere((i) => i.id == id);
            if (index != -1) {
              cargo.add(communalStash.removeAt(index));
            }
          }
          final horseIds = List<String>.from(data['horseIds'] ?? []);
          for (var id in horseIds) {
            final index = _communalHerd.indexWhere((h) => h.id == id);
            if (index != -1) {
              horses.add(_communalHerd.removeAt(index));
            }
          }
        } catch (e) {}
      }

      final movingTask = MovingTask(
        destination: GameLocation(id: poi.id, type: LocationType.poi),
        durationInSeconds: travelSeconds,
        startTime: currentDate != null
            ? DateTime(currentDate!.year, currentDate!.month, currentDate!.day)
            : DateTime.now(),
        option: finalOption,
      );

      final resources = <String, double>{};
      if (finalOption != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(finalOption);
          final resMap = Map<String, dynamic>.from(data['resources'] ?? {});
          resMap.forEach((key, val) {
            final amount = (val as num).toDouble();
            if (amount > 0) {
              resources[key] = amount;
              switch (key) {
                case 'scrap':
                  removeCommunalScrap(amount);
                  break;
                case 'rupees':
                  _communalRupees =
                      (_communalRupees - amount).clamp(0.0, double.infinity);
                  break;
                case 'wood':
                  _communalWood =
                      (_communalWood - amount).clamp(0.0, double.infinity);
                  break;
                case 'iron':
                  _communalIronOre =
                      (_communalIronOre - amount).clamp(0.0, double.infinity);
                  break;
                case 'meat':
                  _communalMeat =
                      (_communalMeat - amount).clamp(0.0, double.infinity);
                  break;
                case 'rice':
                  _communalRice =
                      (_communalRice - amount).clamp(0.0, double.infinity);
                  break;
                case 'short_arrows':
                  _communalShortArrows =
                      (_communalShortArrows - amount.toInt()).clamp(0, 999999);
                  break;
                case 'long_arrows':
                  _communalLongArrows =
                      (_communalLongArrows - amount.toInt()).clamp(0, 999999);
                  break;
              }
            }
          });
        } catch (e) {}
      }

      aravt.task = TradeTask(
        targetPoiId: poi.id,
        cargo: cargo,
        horses: horses,
        resources: resources,
        movement: movingTask,
      );
    } else if (assignment == AravtAssignment.Emissary) {
      final terms = <DiplomaticTerm>[];
      if (finalOption != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(finalOption);
          final termNames = List<String>.from(data['terms'] ?? []);
          for (var name in termNames) {
            try {
              terms
                  .add(DiplomaticTerm.values.firstWhere((e) => e.name == name));
            } catch (_) {}
          }
        } catch (e) {}
      }

      final movingTask = MovingTask(
        destination: GameLocation(id: poi.id, type: LocationType.poi),
        durationInSeconds: travelSeconds,
        startTime: currentDate != null
            ? DateTime(currentDate!.year, currentDate!.month, currentDate!.day)
            : DateTime.now(),
        option: finalOption,
      );

      aravt.task = EmissaryTask(
        targetPoiId: poi.id,
        terms: terms,
        movement: movingTask,
      );
    } else {
      if (needsTravel) {
        aravt.task = MovingTask(
          destination: GameLocation(id: poi.id, type: LocationType.poi),
          durationInSeconds: travelSeconds,
          startTime: currentDate != null
              ? DateTime(
                  currentDate!.year, currentDate!.month, currentDate!.day)
              : DateTime.now(),
          followUpAssignment: assignment,
          followUpPoiId: poi.id,
          option: finalOption,
        );
      } else {
        aravt.task = AssignedTask(
          poiId: poi.id,
          assignment: assignment,
          option: finalOption,
          durationInSeconds: 3600,
          startTime: currentDate != null
              ? DateTime(
                  currentDate!.year, currentDate!.month, currentDate!.day)
              : DateTime.now(),
        );
      }
    }

    aravt.persistentAssignment = assignment;

    logEvent(
      "${aravt.id} assigned to ${poi.name} (${assignment.name}).",
      category: EventCategory.general,
      aravtId: aravt.id,
    );
    notifyListeners();
  }

  void initializeNewGame(
      {required String difficulty,
      required bool allowOmniscience,
      required bool enableAutoSave}) {
    final gameService = setup_service.GameSetupService();
    final GameState initialStateContainer = gameService.createNewGame(
      difficulty: difficulty,
      allowOmniscience: allowOmniscience,
    );

    _clearAllState();

    this.difficulty = difficulty;
    horde = initialStateContainer.horde;
    aravts = initialStateContainer.aravts;
    yurts = initialStateContainer.yurts;
    worldMap = initialStateContainer.worldMap;
    currentArea = initialStateContainer.currentArea;
    player = initialStateContainer.player;
    currentDate = initialStateContainer.currentDate;
    isOmniscienceAllowed = allowOmniscience;
    settlements = initialStateContainer.settlements;
    autoSaveEnabled = enableAutoSave;

    npcHorde1 = initialStateContainer.npcHorde1;
    npcAravts1 = initialStateContainer.npcAravts1;
    npcHorde2 = initialStateContainer.npcHorde2;
    npcAravts2 = initialStateContainer.npcAravts2;
    garrisonSoldiers = initialStateContainer.garrisonSoldiers;
    garrisonAravts = initialStateContainer.garrisonAravts;

    communalCattle = initialStateContainer.communalCattle;
    _communalHerd = initialStateContainer.communalHerd;
    _communalMeat = initialStateContainer.communalMeat;
    _communalRice = initialStateContainer.communalRice;
    _communalIronOre = initialStateContainer.communalIronOre;
    _communalWood = initialStateContainer.communalWood;
    _communalScrap = initialStateContainer.communalScrap;
    _communalArrows = initialStateContainer.communalArrows;
    _communalMilk = initialStateContainer.communalMilk;
    _communalCheese = initialStateContainer.communalCheese;
    _communalGrain = initialStateContainer.communalGrain;

    communalStash = initialStateContainer.communalStash;
    _locationResourceLevels = Map.from(
        initialStateContainer._locationResourceLevels);

    butcheringQueue = List.from(initialStateContainer.butcheringQueue);
    butcheringRate = initialStateContainer.butcheringRate;
    allowAlcohol = initialStateContainer.allowAlcohol;
    vegetarianDiet = initialStateContainer.vegetarianDiet;

    GameDate addDays(GameDate start, int days) {
      GameDate d = start.copy();
      for (int i = 0; i < days; i++) {
        d.nextDay();
      }
      return d;
    }

    upcomingTournaments = [
      FutureTournament(
        name: "Great Downsizing Tournament",
        date: addDays(currentDate!, 7),
        description:
            "The Khan has ordered a culling of the weakest ranks. The lowest performing Aravt will be exiled.",
        events: TournamentEventType.values.toList(),
        isCritical: true,
      ),
      FutureTournament(
        name: "Summer Buzkashi League",
        date: addDays(currentDate!, 30),
        description: "A friendly but fierce competition between hordes.",
        events: [TournamentEventType.buzkashi],
      ),
      FutureTournament(
        name: "Annual Sharpshooter Contest",
        date: addDays(currentDate!, 360),
        description: "To find the keenest eyes on the steppe.",
        events: [
          TournamentEventType.archery,
          TournamentEventType.horseArchery
        ],
      ),
    ];

    // CRITICAL: We only log once to Games to avoid double-badge (2 instead of 1)
    logEvent(
      "The Great Downsizing Tournament has been announced! You have 7 days to prepare. The weakest Aravt will be exiled.",
      category: EventCategory.games,
      severity: EventSeverity.critical,
    );

    logEvent(
      "The horde gathers on the steppe. A new story begins.",
      category: EventCategory.general,
      severity: EventSeverity.low,
    );

    rebuildCaches();
    notifyListeners();
  }

  Future<void> advanceToNextTurn() async {
    if (_isLoading) return;
    await _nextTurnService.executeNextTurn(this);
  }

  void toggleOmniscientMode() {
    if (isOmniscienceAllowed) {
      isOmniscientMode = !isOmniscientMode;
      logEvent(
        "Omniscient Mode ${isOmniscientMode ? 'Enabled' : 'Disabled'}.",
        category: EventCategory.general,
        severity: EventSeverity.low,
      );
      notifyListeners();
    }
  }

  void useInteractionToken() {
    if (_interactionTokensRemaining > 0) {
      _interactionTokensRemaining--;
      notifyListeners();
    }
  }

  void resetInteractionTokens() {
    _interactionTokensRemaining = 10;
  }

  void transferSoldier(Soldier soldier, Aravt newAravt) {
    final oldAravt = findAravtById(soldier.aravt);
    if (oldAravt != null) {
      oldAravt.soldierIds.remove(soldier.id);
    }

    if (!newAravt.soldierIds.contains(soldier.id)) {
      newAravt.soldierIds.add(soldier.id);
    }
    soldier.aravt = newAravt.id;

    if (newAravt.captainId == soldier.id) {
      soldier.role = SoldierRole.aravtCaptain;
    } else if (soldier.role == SoldierRole.aravtCaptain) {
      soldier.role = SoldierRole.soldier;
    }

    if (soldier.isImprisoned) {
      soldier.isImprisoned = false;
    }

    logEvent(
      "${soldier.name} has been transferred to ${newAravt.id}.",
      category: EventCategory.general,
      severity: EventSeverity.normal,
      soldierId: soldier.id,
    );
    notifyListeners();
  }

  void imprisonSoldier(Soldier soldier) {
    if (soldier.isPlayer) return;
    soldier.isImprisoned = !soldier.isImprisoned;
    notifyListeners();
  }

  void _removeSoldierFromHorde(Soldier soldier) {
    if (soldier.isPlayer) return;
    horde.remove(soldier);
    final aravt = findAravtById(soldier.aravt);
    aravt?.soldierIds.remove(soldier.id);
    try {
      final yurt = yurts.firstWhere((y) => y.occupantIds.contains(soldier.id));
      yurt.occupantIds.remove(soldier.id);
    } catch (e) {}
  }

  void expelSoldier(Soldier soldier) {
    if (soldier.isPlayer) return;
    soldier.isExpelled = true;
    logEvent(
      "${soldier.name} has been expelled from the horde!",
      category: EventCategory.general,
      severity: EventSeverity.critical,
      soldierId: soldier.id,
    );
    _removeSoldierFromHorde(soldier);
    notifyListeners();
  }

  void executeSoldier(Soldier soldier) {
    if (soldier.isPlayer) return;
    logEvent(
      "${soldier.name} has been executed!",
      category: EventCategory.general,
      severity: EventSeverity.critical,
      soldierId: soldier.id,
    );
    _removeSoldierFromHorde(soldier);
    notifyListeners();
  }

  void removeDeadSoldier(Soldier soldier) {
    if (soldier.isPlayer) return;
    _removeSoldierFromHorde(soldier);
    notifyListeners();
  }

  String _generateSaveDisplayName() {
    final playerName = player?.name ?? "Khan";
    final dateStr = currentDate?.toShortString() ?? "Unknown Date";
    return "$playerName - $dateStr";
  }

  Future<void> saveGame() async {
    if (_isLoading) return;
    setLoading(true);
    try {
      final String fileName = await _saveLoadService.getNextAvailableSaveSlot();
      final String displayName = _generateSaveDisplayName();
      final Map<String, dynamic> stateJson = toJson();
      final Map<String, dynamic> saveData = _saveLoadService.createSaveData(
        displayName: displayName,
        saveDate: gameDate.copy(),
        gameStateJson: stateJson,
      );
      await _saveLoadService.writeSaveFile(fileName, saveData);
    } finally {
      setLoading(false);
    }
  }

  Future<bool> loadGame(String fileName) async {
    setLoading(true);
    try {
      final Map<String, dynamic>? data =
          await _saveLoadService.readSaveFile(fileName);
      if (data != null && data.containsKey('gameState')) {
        _clearAllState();
        _fromJson(data['gameState']);
        rebuildCaches();
        setLoading(false);
        return true;
      }
    } catch (e) {
      setLoading(false);
    }
    return false;
  }

  bool canPromoteToCaptain(Soldier soldier) {
    if (soldier.role == SoldierRole.hordeLeader) return false;
    if (soldier.status != SoldierStatus.alive) return false;
    if (soldier.isImprisoned) return false;
    return true;
  }

  bool canPromoteToGeneral(Soldier soldier) {
    if (soldier.role != SoldierRole.aravtCaptain) return false;
    if (aravts.length <= 10) return false;
    return true;
  }

  void promoteSoldierToCaptain(Soldier soldier) {
    if (!canPromoteToCaptain(soldier)) return;
    int nextNum = 1;
    while (aravts.any((a) => a.id == 'Aravt $nextNum')) {
      nextNum++;
    }
    final newAravtId = 'Aravt $nextNum';
    final newAravt = Aravt(
      id: newAravtId,
      captainId: soldier.id,
      soldierIds: [],
      currentLocationType: LocationType.poi,
      currentLocationId: findAravtById(soldier.aravt)?.currentLocationId ??
          "DEFAULT_CAMP_POI_ID",
      hexCoords:
          findAravtById(soldier.aravt)?.hexCoords ?? const HexCoordinates(0, 0),
    );
    aravts.add(newAravt);
    transferSoldier(soldier, newAravt);
    soldier.role = SoldierRole.aravtCaptain;
    notifyListeners();
  }

  void promoteToGeneral(Soldier soldier) {
    if (!canPromoteToGeneral(soldier)) return;
    soldier.role = SoldierRole.general;
    notifyListeners();
  }

  Future<List<SaveFileInfo>> getSaveFiles() {
    return _saveLoadService.getSaveFileList();
  }

  Future<void> autoSave() async {
    if (isGameOver || !autoSaveEnabled) return;
    try {
      final String fileName = await _saveLoadService.getNextAvailableSaveSlot();
      final String displayName = "AUTOSAVE - ${_generateSaveDisplayName()}";
      final Map<String, dynamic> stateJson = toJson();
      final Map<String, dynamic> saveData = _saveLoadService.createSaveData(
        displayName: displayName,
        saveDate: gameDate.copy(),
        gameStateJson: stateJson,
      );
      await _saveLoadService.writeSaveFile(fileName, saveData);
    } catch (e) {}
  }

  void _clearAllState() {
    horde = [];
    aravts = [];
    yurts = [];
    combatReports = [];
    tournamentHistory = [];
    upcomingTournaments = [];
    activeNarrativeEvent = null;
    hasDay5TradeOccurred = false;
    difficulty = 'medium';
    isGameOver = false;
    gameOverReason = null;
    isPlayerHordeAutomated = true;
    huntingReports = [];
    fishingReports = [];
    resourceReports = [];
    unreadReportCounts = {}; // Reset all badges
    // Explicitly ensure Turn 1 starts clean for Military sub-tabs
    unreadReportCounts['Health'] = 0;
    unreadReportCounts['Training'] = 0;
    unreadReportCounts['Games'] = 0;
    
    tutorialStepIndex = 0;      // Reset tutorial progress
    tutorialDismissalCount = 0;  // Reset dismissal count (otherwise captain appears angry in new game)
    tutorialCompleted = false;
    tutorialPermanentlyDismissed = false;
    tutorialCaptainId = null;    // Fresh captain assigned by new game setup
    _communalMeat = 100.0;
    _communalRice = 0.0;
    _communalIronOre = 0.0;
    _communalWood = 0.0;
    _communalScrap = 50.0;
    _communalArrows = 100;
    _locationResourceLevels = {};
    communalStash = [];
    currentArea = null;
    worldMap = {};
    player = null;
    currentDate = null;
    settlements = [];
    turn = GameTurn();
    isOmniscientMode = false;
    isOmniscienceAllowed = false;
    autoSaveEnabled = true;
    npcHorde1 = [];
    npcAravts1 = [];
    npcHorde2 = [];
    npcAravts2 = [];
    garrisonSoldiers = [];
    garrisonAravts = [];
    _communalHerd = [];
    communalCattle = Herd(type: AnimalType.Cattle);
    _combatFlowState = CombatFlowState.none;
    eventLog = [];
    _interactionTokensRemaining = 10;
  }

  void equipItem(InventoryItem item) {
    if (player == null) return;
    equipItemToSoldier(player!, item);
  }

  void equipItemToSoldier(Soldier soldier, InventoryItem item) {
    soldier.equip(item);
    logEvent("Equipped ${item.name} for ${soldier.name}.",
        category: EventCategory.general, severity: EventSeverity.low);
    notifyListeners();
  }

  void unequipItem(EquipmentSlot slot) {
    if (player == null) return;
    unequipItemFromSoldier(player!, slot);
  }

  void unequipItemFromSoldier(Soldier soldier, EquipmentSlot slot) {
    final item = soldier.equippedItems[slot];
    if (item == null) return;

    soldier.unequip(slot);
    logEvent("Unequipped ${item.name} from ${soldier.name}.",
        category: EventCategory.general, severity: EventSeverity.low);
    notifyListeners();
  }

  void consumeItem(Consumable item) {
    print("Consumed ${item.name}. Effect: ${item.effect}");
    player?.personalInventory.remove(item);
    logEvent("Consumed ${item.name}.",
        category: EventCategory.food, severity: EventSeverity.low);
    notifyListeners();
  }

  void addItemToInventory(InventoryItem item) {
    player?.personalInventory.add(item);
    logEvent("Obtained ${item.name}.",
        category: EventCategory.finance, severity: EventSeverity.low);
    notifyListeners();
  }

  void debugInitiateCombat() {
    print("DEBUG: Forcing combat initiation...");

    if (_combatFlowState != CombatFlowState.none) {
      print("DEBUG: Cannot force combat, one is already in progress.");
      return;
    }

    List<Aravt> playerCombatAravts = aravts
        .where((a) => a.currentAssignment == AravtAssignment.Rest)
        .toList();
    if (playerCombatAravts.isEmpty) {
      print("DEBUG: No idle/resting player aravts to start combat.");
      return;
    }
    playerCombatAravts.shuffle(_random);
    playerCombatAravts = playerCombatAravts.take(3).toList();

    if (npcHorde1.isEmpty) {
      print("DEBUG: No NPC aravts in horde 1 to fight.");
      return;
    }
    List<Aravt> npcCombatAravts = npcAravts1.toList();
    npcCombatAravts.shuffle(_random);
    npcCombatAravts = npcCombatAravts.take(3).toList();

    if (playerCombatAravts.isNotEmpty && npcCombatAravts.isNotEmpty) {
      initiateCombat(
        playerAravts: playerCombatAravts,
        opponentAravts: npcCombatAravts,
        allPlayerSoldiers: horde,
        allOpponentSoldiers: npcHorde1,
      );
    } else {
      print("DEBUG: Failed to get enough combatants.");
    }
  }

  void initiateCombat({
    required List<Aravt> playerAravts,
    required List<Aravt> opponentAravts,
    required List<Soldier> allPlayerSoldiers,
    required List<Soldier> allOpponentSoldiers,
  }) {
    if (_combatFlowState != CombatFlowState.none) {
      print(
          "Warning: Cannot initiate combat, a combat flow is already active.");
      return;
    }
    print("Initiating combat... setting state to preCombat.");

    List<Soldier> sideA = [];
    playerAravts.forEach((a) => a.soldierIds.forEach((id) {
          try {
            sideA.add(allPlayerSoldiers.firstWhere((s) => s.id == id));
          } catch (e) {
            print("Warn: Player Soldier $id not found.");
          }
        }));
    List<Soldier> sideB = [];
    opponentAravts.forEach((a) => a.soldierIds.forEach((id) {
          try {
            sideB.add(allOpponentSoldiers.firstWhere((s) => s.id == id));
          } catch (e) {
            print("Warn: Opponent Soldier $id not found.");
          }
        }));

    if (sideA.isEmpty || sideB.isEmpty) {
      print("Error: Empty combat sides.");
      logEvent("Combat failed: Empty sides.",
          category: EventCategory.combat, severity: EventSeverity.high);
      return;
    }

    pendingCombat = ActiveCombatState(
        playerSoldiers: sideA,
        opponentSoldiers: sideB,
        playerAravts: playerAravts,
        opponentAravts: opponentAravts);

    _combatFlowState = CombatFlowState.preCombat;

    logEvent(
      "Enemy sighted! ${playerAravts.length} vs ${opponentAravts.length} aravts prepare for battle.",
      category: EventCategory.combat,
      severity: EventSeverity.high,
    );
    notifyListeners();
  }

  void startSimulatorCombat(List<Soldier> teamA, List<Soldier> teamB) {
    print("Starting Simulator Combat...");
    isSimulatorCombat = true; // Mark that this is a simulator battle

    // 1. Create temporary Aravts
    final aravtA = Aravt(
      id: 'sim_aravt_a',
      name: 'Army A',
      captainId: teamA.isNotEmpty ? teamA.first.id : 0,
      soldierIds: teamA.map((s) => s.id).toList(),
      color: 'blue',
      currentLocationType: LocationType.poi,
      currentLocationId: 'simulator',
      hexCoords: const HexCoordinates(0, 0),
    );

    final aravtB = Aravt(
      id: 'sim_aravt_b',
      name: 'Army B',
      captainId: teamB.isNotEmpty ? teamB.first.id : 0,
      soldierIds: teamB.map((s) => s.id).toList(),
      color: 'red',
      currentLocationType: LocationType.poi,
      currentLocationId: 'simulator',
      hexCoords: const HexCoordinates(0, 0),
    );

    // 2. Setup ActiveCombatState
    activeCombat = ActiveCombatState(
      playerSoldiers: teamA,
      opponentSoldiers: teamB,
      playerAravts: [aravtA],
      opponentAravts: [aravtB],
    );

    // 3. Initialize CombatSimulator
    currentCombat = CombatSimulator();

    // 4. Start Combat
    currentCombat!.startCombat([aravtA], [aravtB], [...teamA, ...teamB], this);

    combatSpeedMultiplier = 1.0;
    isCombatPaused = false; // Start unpaused for simulator
    _combatFlowState = CombatFlowState.inCombat;

    notifyListeners();
  }

  void beginCombatFromPreScreen() {
    if (_combatFlowState != CombatFlowState.preCombat ||
        pendingCombat == null) {
      print("Error: Cannot begin combat, no pending combat found.");
      return;
    }
    print("Beginning combat... setting state to inCombat.");

    activeCombat = pendingCombat;
    pendingCombat = null;
    currentCombat = CombatSimulator();

    List<Soldier> combinedSoldierList = [
      ...horde,
      ...npcHorde1,
      ...npcHorde2,
      ...garrisonSoldiers,
      ...activeCombat!.playerSoldiers,
      ...activeCombat!.opponentSoldiers
    ];

    currentCombat!.startCombat(activeCombat!.playerAravts,
        activeCombat!.opponentAravts, combinedSoldierList, this);

    combatSpeedMultiplier = 1.0;
    isCombatPaused = true;
    _combatFlowState = CombatFlowState.inCombat;

    logEvent("The battle begins!",
        category: EventCategory.combat, severity: EventSeverity.high);
    notifyListeners();
  }

  void concludeCombat() {
    if (_combatFlowState != CombatFlowState.inCombat) {
      if (currentCombat == null || activeCombat == null) {
        print("Warning: No active combat to conclude.");
        return;
      }
    }
    print("Concluding combat... setting state to postCombat.");

    if (combatReports.isNotEmpty) {
      lastCombatReport = combatReports.last;
      logEvent(
          lastCombatReport!.result == CombatResult.playerVictory ||
                  lastCombatReport!.result == CombatResult.enemyRout
              ? "Victory!"
              : "Defeat!",
          category: EventCategory.combat,
          severity: EventSeverity.critical);
    } else {
      print("CRITICAL WARNING: Combat ended but no report was generated.");
      lastCombatReport = null;
      logEvent("Stalemate!",
          category: EventCategory.combat, severity: EventSeverity.critical);
    }

    currentCombat = null;
    activeCombat = null;
    _combatFlowState = CombatFlowState.postCombat;

    notifyListeners();
  }

  void processCombatReport(
      CombatReport report, Map<int, PrisonerAction> captiveDecisions) {
    if (_combatFlowState != CombatFlowState.postCombat) {
      print("Warning: Trying to process report when not in post-combat.");
    }

    final List<Soldier> playerCasualties = report.playerSoldiers
        .where((s) => s.finalStatus == SoldierStatus.killed)
        .map((s) => s.originalSoldier)
        .toList();

    for (final soldier in playerCasualties) {
      logEvent(
        "${soldier.name} has fallen in battle.",
        category: EventCategory.combat,
        severity: EventSeverity.critical,
        soldierId: soldier.id,
      );
      _applyDeathMoraleImpact(soldier);

      if (soldier.isPlayer) {
        triggerGameOver(
            "You fell in battle during the fight at ${currentArea?.name ?? 'Unknown Location'}.");
      } else {
        _removeSoldierFromHorde(soldier);
      }
    }

    captiveDecisions.forEach((soldierId, action) {
      final Soldier? captive = findSoldierById(soldierId);
      if (captive == null) return;
      _removeSoldierFromNpcHorde(captive);

      switch (action) {
        case PrisonerAction.recruit:
          logEvent("Attempting to recruit ${captive.name}...",
              category: EventCategory.general, soldierId: captive.id);
          captive.aravt = aravts.first.id;
          horde.add(captive);
          logEvent("${captive.name} has joined the horde!",
              category: EventCategory.general, soldierId: captive.id);
          break;
        case PrisonerAction.imprison:
          logEvent("${captive.name} has been taken prisoner.",
              category: EventCategory.general,
              soldierId: captive.id,
              severity: EventSeverity.high);
          captive.aravt = aravts.first.id;
          horde.add(captive);
          imprisonSoldier(captive);
          break;
        case PrisonerAction.release:
          logEvent("${captive.name} has been released.",
              category: EventCategory.general, soldierId: captive.id);
          break;
        case PrisonerAction.execute:
          logEvent("${captive.name} has been executed after the battle.",
              category: EventCategory.general,
              soldierId: captive.id,
              severity: EventSeverity.critical);
          break;
        case PrisonerAction.undecided:
          break;
      }
    });

    final List<Soldier> enemyCasualties = report.enemySoldiers
        .where((s) =>
            s.finalStatus == SoldierStatus.killed ||
            s.finalStatus == SoldierStatus.fled)
        .map((s) => s.originalSoldier)
        .toList();

    for (final soldier in enemyCasualties) {
      _removeSoldierFromNpcHorde(soldier);
    }

    dismissPostCombatReport();
  }

  void _removeSoldierFromNpcHorde(Soldier soldier) {
    List<Aravt>? aravtList;
    List<Soldier>? hordeList;

    if (npcHorde1.contains(soldier)) {
      hordeList = npcHorde1;
      aravtList = npcAravts1;
    } else if (npcHorde2.contains(soldier)) {
      hordeList = npcHorde2;
      aravtList = npcAravts2;
    }

    if (hordeList != null && aravtList != null) {
      hordeList.remove(soldier);
      final aravt = aravtList.firstWhere(
        (a) => a.soldierIds.contains(soldier.id),
        orElse: () => Aravt(
          id: 'temp',
          captainId: -1,
          soldierIds: [],
          currentLocationType: LocationType.poi,
          currentLocationId: "DEFAULT_CAMP_POI_ID",
          hexCoords: const HexCoordinates(0, 0),
        ),
      );
      aravt.soldierIds.remove(soldier.id);
      print("Removed ${soldier.name} from their horde");
    }
  }

  void _applyDeathMoraleImpact(Soldier deadSoldier) {
    logEvent("The horde mourns the loss of ${deadSoldier.name}.",
        category: EventCategory.general, severity: EventSeverity.high);

    for (final soldier in horde) {
      if (soldier.id == deadSoldier.id) continue;

      final relationship = soldier.getRelationship(deadSoldier.id);

      if (relationship.admiration > 3.5) {
        soldier.stress = (soldier.stress + 2).clamp(0, 10);
        relationship.loyalty = (relationship.loyalty - 0.5).clamp(0, 5);
        logEvent(
            "${soldier.name} is distraught by the death of ${deadSoldier.name}!",
            category: EventCategory.general,
            severity: EventSeverity.high,
            soldierId: soldier.id);
      } else if (relationship.admiration < 1.5) {
        soldier.stress = (soldier.stress - 1).clamp(0, 10);
        soldier.temperament = (soldier.temperament + 0.2).clamp(0, 10);
        logEvent(
            "${soldier.name} is quietly relieved by the death of ${deadSoldier.name}.",
            category: EventCategory.general,
            severity: EventSeverity.low,
            soldierId: soldier.id);
      }
    }
  }

  void dismissPostCombatReport() {
    if (_combatFlowState != CombatFlowState.postCombat &&
        _combatFlowState != CombatFlowState.preCombat) {
      print("Warning: No post-combat report or pending combat to dismiss.");
      return;
    }

    if (_combatFlowState == CombatFlowState.preCombat) {
      print("Dismissing pending combat... setting state to none.");
      logEvent("You avoided the enemy... for now.",
          category: EventCategory.combat, severity: EventSeverity.normal);
    } else {
      print("Dismissing report... setting state to none.");
      logEvent("You survey the aftermath and continue.",
          category: EventCategory.general, severity: EventSeverity.normal);
    }

    lastCombatReport = null;
    pendingCombat = null;

    _combatFlowState = CombatFlowState.none;

    notifyListeners();
  }

  void endCombat() {
    concludeCombat();
  }

  void setCombatSpeed(double speed) {
    if (speed == 1.0 || speed == 2.0 || speed == 4.0) {
      combatSpeedMultiplier = speed;
      print("Combat speed set to ${speed}x");
      logEvent("Combat speed set to ${speed}x.",
          category: EventCategory.combat, severity: EventSeverity.low);
      notifyListeners();
    }
  }

  void toggleCombatPause() {
    isCombatPaused = !isCombatPaused;
    print("Combat ${isCombatPaused ? 'paused' : 'resumed'}");
    logEvent("Combat ${isCombatPaused ? 'paused' : 'resumed'}.",
        category: EventCategory.combat, severity: EventSeverity.low);
    notifyListeners();
  }

  void skipCombatToEnd() {
    if (currentCombat == null) return;
    print("Skipping combat to end...");
    logEvent("Skipping combat to end.",
        category: EventCategory.combat, severity: EventSeverity.normal);

    if (!isCombatPaused) {
      isCombatPaused = true;
    }

    int safetyBreak = 0;
    while (currentCombat != null &&
        !currentCombat!.checkEndConditions() &&
        safetyBreak < 10000) {
      currentCombat!.processNextAction();
      safetyBreak++;
    }

    if (safetyBreak >= 10000) {
      print("Warning: Combat skip loop reached safety break limit.");
      logEvent("Warning: Combat skip took too long.",
          category: EventCategory.combat, severity: EventSeverity.high);
    }
    notifyListeners();
  }

  void advanceCombatRound() {
    if (currentCombat == null) return;
    print("Advancing to next round...");
    logEvent("Advancing to next round.",
        category: EventCategory.combat, severity: EventSeverity.low);

    if (!isCombatPaused) {
      isCombatPaused = true;
      notifyListeners();
    }

    currentCombat!.processNextRound();
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'autoSaveEnabled': autoSaveEnabled,
      'isOmniscientMode': isOmniscientMode,
      'isOmniscienceAllowed': isOmniscienceAllowed,
      'turn': turn.toJson(),
      'currentDate': currentDate?.toJson(),
      'currentArea': currentArea?.coordinates.toJson(),
      'worldMap': worldMap.map((key, value) => MapEntry(key, value.toJson())),
      'interactionTokensRemaining': _interactionTokensRemaining,
      'playerId': player?.id,
      'horde': horde.map((s) => s.toJson()).toList(),
      'aravts': aravts.map((a) => a.toJson()).toList(),
      'yurts': yurts.map((y) => y.toJson()).toList(),
      'npcHorde1': npcHorde1.map((s) => s.toJson()).toList(),
      'npcAravts1': npcAravts1.map((a) => a.toJson()).toList(),
      'npcHorde2': npcHorde2.map((s) => s.toJson()).toList(),
      'npcAravts2': npcAravts2.map((a) => a.toJson()).toList(),
      'garrisonSoldiers': garrisonSoldiers.map((s) => s.toJson()).toList(),
      'garrisonAravts': garrisonAravts.map((a) => a.toJson()).toList(),
      'settlements': settlements.map((s) => s.toJson()).toList(),
      'playerInventory':
          player?.personalInventory.map((i) => i.toJson()).toList() ?? [],
      'playerEquippedItems': player?.equippedItems
              .map((key, value) => MapEntry(key.name, value.toJson())) ??
          {},
      'communalMeat': _communalMeat,
      'communalRice': _communalRice,
      'communalIronOre': _communalIronOre,
      'communalWood': _communalWood,
      'communalScrap': _communalScrap,
      'communalArrows': _communalArrows,
      'locationResourceLevels': _locationResourceLevels,
      'communalHerd': _communalHerd.map((m) => m.toJson()).toList(),
      'isPlayerHordeAutomated': isPlayerHordeAutomated,
      'huntingReports': huntingReports.map((r) => r.toJson()).toList(),
      'fishingReports': fishingReports.map((r) => r.toJson()).toList(),
      //  Save resource reports
      'resourceReports': resourceReports.map((r) => r.toJson()).toList(),
      'viewedReportTabs': viewedReportTabs.toList(),
      'tutorialCompleted': tutorialCompleted,
      'tutorialPermanentlyDismissed': tutorialPermanentlyDismissed,
      'tutorialDismissalCount': tutorialDismissalCount,
      'tutorialStepIndex': tutorialStepIndex,
      'tutorialCaptainId': tutorialCaptainId, //  Persist tutorial captain
      //  Food management
      'communalMilk': _communalMilk,
      'communalCheese': _communalCheese,
      'communalGrain': _communalGrain,
      'butcheringQueue': butcheringQueue,
      'butcheringRate': butcheringRate,
      'allowAlcohol': allowAlcohol,
      'vegetarianDiet': vegetarianDiet,
      //  Finance tracking
      'tradeReports': tradeReports.map((r) => r.toJson()).toList(),
      'wealthEvents': wealthEvents.map((e) => e.toJson()).toList(),
      //  Industry parameters
      'fabricationTargets':
          fabricationTargets.map((key, value) => MapEntry(key, value.toJson())),
      'materialFlowHistory':
          materialFlowHistory.map((e) => e.toJson()).toList(),
      //  Culinary news
      'culinaryNews': culinaryNews.map((n) => n.toJson()).toList(),
      'campLayout': campLayout,
      'pillageReports': pillageReports.map((r) => r.toJson()).toList(),
    };
  }

  void _fromJson(Map<String, dynamic> json) {
    final List<Soldier> allPlayerSoldiers =
        (json['horde'] as List? ?? []).map((s) => Soldier.fromJson(s)).toList();
    final List<Soldier> allNpc1Soldiers = (json['npcHorde1'] as List? ?? [])
        .map((s) => Soldier.fromJson(s))
        .toList();
    final List<Soldier> allNpc2Soldiers = (json['npcHorde2'] as List? ?? [])
        .map((s) => Soldier.fromJson(s))
        .toList();
    final List<Soldier> allGarrisonSoldiers =
        (json['garrisonSoldiers'] as List? ?? [])
            .map((s) => Soldier.fromJson(s))
            .toList();

    final Map<int, Soldier> soldierMap = {
      for (var s in allPlayerSoldiers) s.id: s,
      for (var s in allNpc1Soldiers) s.id: s,
      for (var s in allNpc2Soldiers) s.id: s,
      for (var s in allGarrisonSoldiers) s.id: s,
    };

    autoSaveEnabled = json['autoSaveEnabled'] ?? true;
    isOmniscientMode = json['isOmniscientMode'] ?? false;
    isOmniscienceAllowed = json['isOmniscienceAllowed'] ?? false;
    turn = GameTurn.fromJson(json['turn']);
    currentDate = json['currentDate'] != null
        ? GameDate.fromJson(json['currentDate'])
        : null;

    worldMap = (json['worldMap'] as Map<String, dynamic>? ?? {})
        .map((key, value) => MapEntry(key, GameArea.fromJson(value)));

    if (json['currentArea'] != null) {
      final loadedCoords = HexCoordinates.fromJson(json['currentArea']);
      currentArea = worldMap[loadedCoords.toString()];
    } else {
      currentArea = null;
    }

    _interactionTokensRemaining = json['interactionTokensRemaining'] ?? 10;

    horde = allPlayerSoldiers;
    aravts =
        (json['aravts'] as List? ?? []).map((a) => Aravt.fromJson(a)).toList();
    yurts =
        (json['yurts'] as List? ?? []).map((y) => Yurt.fromJson(y)).toList();
    player = soldierMap[json['playerId']];

    npcHorde1 = allNpc1Soldiers;
    npcAravts1 = (json['npcAravts1'] as List? ?? [])
        .map((a) => Aravt.fromJson(a))
        .toList();
    npcHorde2 = allNpc2Soldiers;
    npcAravts2 = (json['npcAravts2'] as List? ?? [])
        .map((a) => Aravt.fromJson(a))
        .toList();
    garrisonSoldiers = allGarrisonSoldiers;
    garrisonAravts = (json['garrisonAravts'] as List? ?? [])
        .map((a) => Aravt.fromJson(a))
        .toList();

    settlements = (json['settlements'] as List? ?? [])
        .map((s) => Settlement.fromJson(s))
        .toList();

    // Player inventory is now loaded via the player object (which is in the horde)
    // We can ignore the legacy inventory fields in the JSON or use them for migration if needed.
    // For now, we just don't load them into separate fields.
    _communalMeat = json['communalMeat'] ?? 0.0;
    _communalRice = json['communalRice'] ?? 0.0;
    _communalIronOre = json['communalIronOre'] ?? 0.0;
    _communalWood = json['communalWood'] ?? 0.0;
    _communalScrap = json['communalScrap'] ?? 50.0;
    _communalArrows = json['communalArrows'] ?? 100;
    _locationResourceLevels =
        (json['locationResourceLevels'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {};
    _communalHerd = (json['communalHerd'] as List? ?? [])
        .map((m) => Mount.fromJson(m))
        .toList()
        .cast<Mount>();
    if (json['communalCattle'] != null) {
      communalCattle = Herd.fromJson(json['communalCattle']);
    } else {
      communalCattle = Herd(type: AnimalType.Cattle);
    }
    communalStash = (json['communalStash'] as List? ?? [])
        .map((i) => InventoryItem.fromJson(i))
        .toList();

    combatReports = (json['combatReports'] as List? ?? [])
        .map((r) => CombatReport.fromJson(r, soldierMap))
        .toList();
    eventLog = (json['eventLog'] as List? ?? [])
        .map((e) => GameEvent.fromJson(e))
        .toList();

    tournamentHistory = (json['tournamentHistory'] as List? ?? [])
        .map((t) => TournamentResult.fromJson(t))
        .toList();
    upcomingTournaments = (json['upcomingTournaments'] as List? ?? [])
        .map((t) => FutureTournament.fromJson(t))
        .toList();

    if (json['activeTournament'] != null) {
      activeTournament = ActiveTournament.fromJson(json['activeTournament']);
    }

    activeNarrativeEvent = json['activeNarrativeEvent'] != null
        ? NarrativeEvent.fromJson(json['activeNarrativeEvent'])
        : null;
    hasDay5TradeOccurred = json['hasDay5TradeOccurred'] ?? false;
    difficulty = json['difficulty'] ?? 'medium';

    isGameOver = json['isGameOver'] ?? false;
    gameOverReason = json['gameOverReason'];
    isPlayerHordeAutomated = json['isPlayerHordeAutomated'] ?? true;

    if (json['huntingReports'] != null) {
      huntingReports = (json['huntingReports'] as List)
          .map((r) => HuntingTripReport.fromJson(r))
          .toList();
    }
    if (json['fishingReports'] != null) {
      fishingReports = (json['fishingReports'] as List)
          .map((r) => FishingTripReport.fromJson(r))
          .toList();
    }
    //  Load resource reports
    if (json['resourceReports'] != null) {
      resourceReports = (json['resourceReports'] as List)
          .map((r) => ResourceReport.fromJson(r))
          .toList();
    }

    if (json['viewedReportTabs'] != null) {
      viewedReportTabs = Set<String>.from(json['viewedReportTabs']);
    }

    tutorialCompleted = json['tutorialCompleted'] ?? false;
    tutorialPermanentlyDismissed =
        json['tutorialPermanentlyDismissed'] ?? false;
    tutorialDismissalCount = json['tutorialDismissalCount'] ?? 0;
    tutorialStepIndex = json['tutorialStepIndex'] ?? 0;
    tutorialCaptainId = json['tutorialCaptainId']; //  Load tutorial captain

    //  Food management
    _communalMilk = (json['communalMilk'] as num?)?.toDouble() ?? 0.0;
    _communalCheese = (json['communalCheese'] as num?)?.toDouble() ?? 0.0;
    _communalGrain = (json['communalGrain'] as num?)?.toDouble() ?? 0.0;
    butcheringQueue = (json['butcheringQueue'] as List? ?? []).cast<int>();
    butcheringRate = (json['butcheringRate'] as num?)?.toDouble() ?? 1.0;
    allowAlcohol = json['allowAlcohol'] ?? true;
    vegetarianDiet = json['vegetarianDiet'] ?? false;

    //  Finance tracking
    tradeReports = (json['tradeReports'] as List? ?? [])
        .map((r) => TradeReport.fromJson(r))
        .toList();
    wealthEvents = (json['wealthEvents'] as List? ?? [])
        .map((e) => WealthEvent.fromJson(e))
        .toList();

    //  Industry parameters
    fabricationTargets = (json['fabricationTargets'] as Map<String, dynamic>? ??
            {})
        .map((key, value) => MapEntry(key, FabricationTarget.fromJson(value)));
    materialFlowHistory = (json['materialFlowHistory'] as List? ?? [])
        .map((e) => MaterialFlowEntry.fromJson(e))
        .toList();

    //  Culinary news
    culinaryNews = (json['culinaryNews'] as List? ?? [])
        .map((n) => CulinaryNews.fromJson(n))
        .toList();
    pillageReports = (json['pillageReports'] as List? ?? [])
        .map((r) => PillageReport.fromJson(r))
        .toList();

    _isLoading = false;
    _combatFlowState = CombatFlowState.none;
    currentCombat = null;
    activeCombat = null;
    pendingCombat = null;
    lastCombatReport = null;
  }

  void assignAravtToArea(Aravt aravt, String areaId, AravtAssignment assignment,
      {String? option}) {
    // 1. Validate Location
    final area = worldMap[areaId];
    if (area == null) {
      print("Error: Area $areaId not found.");
      return;
    }

    // 2. Check if Aravt is at the location
    if (aravt.hexCoords != area.coordinates) {
      // Create Moving Task
      int distance = aravt.hexCoords.distanceTo(area.coordinates);
      double travelSeconds = distance * 86400.0;

      aravt.task = MovingTask(
        destination: GameLocation.area(areaId),
        durationInSeconds: travelSeconds,
        startTime: gameDate.toDateTime(),
        followUpAssignment: assignment,
        followUpAreaId: areaId,
        option: option,
      );
    } else {
      // Assign immediately
      aravt.task = AssignedTask(
        areaId: areaId,
        assignment: assignment,
        durationInSeconds: 86400.0 * 30, // Default long duration
        startTime: gameDate.toDateTime(),
        option: option,
      );
    }
    notifyListeners();
  }
}
