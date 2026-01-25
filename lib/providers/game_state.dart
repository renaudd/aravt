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
import 'package:aravt/models/assignment_data.dart'; // Keep this as the primary source for AravtAssignment
import 'package:aravt/models/game_turn.dart';
import 'package:flutter/foundation.dart';
import 'package:aravt/services/game_setup_service.dart' as setup_service;
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/combat_report.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/services/combat_service.dart';
import 'dart:math';

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
//  Import for ResourceTripReport
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

// Wealth status for dynamic scrap-to-rupee conversion (7-level gradual spectrum)
enum WealthStatus {
  destitution, // < 5§ per soldier (3:1 conversion)
  poverty, // 5-15§ per soldier (2:1 conversion)
  subsistence, // 15-30§ per soldier (3:2 conversion)
  sufficiency, // 30-60§ per soldier (1:1 conversion)
  comfort, // 60-90§ per soldier (2:3 conversion)
  abundance, // 90-120§ per soldier (1:2 conversion)
  excess // > 120§ per soldier (1:3 conversion)
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
  ActiveTournament? activeTournament; //  Track ongoing tournament
  Map<TournamentEventType, int> currentChampions = {};

  List<double> wealthHistory = [];
  List<ResourceReport> resourceReports = [];

  // Hunting, Fishing, & Resource History
  List<HuntingTripReport> huntingReports = [];
  List<FishingTripReport> fishingReports = [];
  List<ShepherdingReport> shepherdingReports = [];
  List<FletchingReport> fletchingReports = [];
  List<TrainingReport> trainingReports = [];
  List<PillageReport> pillageReports = [];
  //  Resource reports (wood/mining)

  // --- HISTORY / TIMELINES ---
  final HistoryService historyService = HistoryService();
  // Proxy getter for UI
  List<DailySnapshot> get history => historyService.history;

  // Narrative Event State
  NarrativeEvent? activeNarrativeEvent;
  bool hasDay5TradeOccurred = false;

  //  Notification Badge Tracking
  Set<String> viewedReportTabs = {};

  //  Tutorial Persistence
  bool tutorialCompleted = false;
  bool tutorialPermanentlyDismissed = false;
  int tutorialDismissalCount = 0;
  int tutorialStepIndex = 0;

  String difficulty = 'medium';
  String hordeName = "Player Horde";

  // Game Over State
  bool isGameOver = false;
  String? gameOverReason;

  // Automation flag for player's horde (before they are leader)
  bool isPlayerHordeAutomated = true;
  bool get isPlayerLeader => player?.role == SoldierRole.hordeLeader;

  GameArea? currentArea;
  Soldier? player;

  /// The current leader of the horde (Noyan).
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

  //  Method to update player reference (e.g. on death)
  void setPlayer(Soldier newPlayer) {
    player = newPlayer;
    notifyListeners();
  }

  Map<String, GameArea> worldMap = {};

  // --- Caravan / Pack State ---
  bool isCaravanMode = false;
  double packingProgress = 0.0; // 0.0 to 1.0
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

    // Find current camp area and revert it to Wilderness/Plains
    for (var area in worldMap.values) {
      if (area.type == AreaType.PlayerCamp) {
        area.type = AreaType.Neutral; // Revert to Neutral
        caravanPosition = area.coordinates;
        // Also remove the "Player Camp" POI if it exists
        area.pointsOfInterest.removeWhere((p) => p.id == 'camp-player');
      }
    }

    // Fallback if no camp area found
    if (caravanPosition == null && currentArea != null) {
      caravanPosition = currentArea!.coordinates;
    }

    notifyListeners();
  }

  void establishCamp(HexCoordinates position) {
    isCaravanMode = false;
    packingProgress = 0.0;
    caravanPosition = null;

    // Find area at position and make it PlayerCamp
    for (var area in worldMap.values) {
      if (area.coordinates == position) {
        area.type = AreaType.PlayerCamp;
        // Add Camp POI
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
    if (distance != 1) return; // Only 1 tile move allowed

    caravanPosition = newPos;

    logEvent(
      "The caravan moves to a new location.",
      category: EventCategory.general,
      severity: EventSeverity.normal,
    );

    notifyListeners();

    // Advance turn (1 day)
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

  //  UI State for Horde Panel
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

  bool isOmniscienceAllowed = false;
  bool isGameInitialized = false;
  int _soldierIdCounter =
      10000; // Start high to avoid collisions with setup IDs

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

  // --- COMMUNAL RESOURCES ---
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

  int _communalArrows = 1500; // Deprecated
  int get communalArrows => _communalArrows;

  int _communalShortArrows = 1000;
  int get communalShortArrows => _communalShortArrows;

  int _communalLongArrows = 500;
  int get communalLongArrows => _communalLongArrows;

  double _communalRupees = 0.0;
  double get communalRupees => _communalRupees;

  // --- CUMULATIVE PRODUCTION (For Industry Reports) ---
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

  // Communal Stash for individual items (pelts, etc.)
  List<InventoryItem> communalStash = [];

  // Resource depletion tracking (POI ID -> Richness 0.0-1.0)
  Map<String, double> _locationResourceLevels = {};

  // Horses
  List<Mount> _communalHerd = [];
  List<Mount> get communalHerd => _communalHerd;

  // Cattle Herd for shepherding
  late Herd communalCattle;

  // --- FOOD MANAGEMENT ---
  double _communalMilk = 0.0;
  double get communalMilk => _communalMilk;

  double _communalCheese = 0.0;
  double get communalCheese => _communalCheese;

  double _communalGrain = 0.0;
  double get communalGrain => _communalGrain;

  List<int> butcheringQueue = []; // Animal IDs in order

  // Food parameters
  double butcheringRate = 1.0; // Animals per week
  bool allowAlcohol = true;
  bool vegetarianDiet = false;

  // --- FINANCE TRACKING ---
  List<TradeReport> tradeReports = [];
  List<WealthEvent> wealthEvents = [];

  // --- INDUSTRY PARAMETERS ---
  Map<String, FabricationTarget> fabricationTargets = {};
  List<MaterialFlowEntry> materialFlowHistory = [];

  // --- CULINARY NEWS ---
  List<CulinaryNews> culinaryNews = [];

  // --- PERSISTENT UI STATE ---
  Map<String, Map<String, double>> campLayout = {}; // Building Name -> {x, y}

  CombatSimulator? currentCombat;
  ActiveCombatState? activeCombat;
  final Random _random = Random();

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

  // Audio Settings placeholders
  bool musicEnabled = true;
  double musicVolume = 0.5;
  bool sfxEnabled = true;
  double sfxVolume = 0.5;

  GameState() {
    // Initialize with default empty herd to avoid late initialization errors before game start
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

  // --- DYNAMIC SCRAP-TO-RUPEE CONVERSION (7-LEVEL SPECTRUM) ---

  /// Calculate current wealth status based on per-capita supply wealth
  WealthStatus get currentWealthStatus {
    double totalSupply = _calculateTotalSupplyWealth();
    int hordeSize = horde.length;
    double perCapita = hordeSize > 0 ? totalSupply / hordeSize : 0;

    // Per-capita thresholds (§ per soldier) - 7 levels for gradual progression
    if (perCapita < 5) return WealthStatus.destitution; // < 5§ per soldier
    if (perCapita < 15) return WealthStatus.poverty; // 5-15§ per soldier
    if (perCapita < 30) return WealthStatus.subsistence; // 15-30§ per soldier
    if (perCapita < 60) return WealthStatus.sufficiency; // 30-60§ per soldier
    if (perCapita < 90) return WealthStatus.comfort; // 60-90§ per soldier
    if (perCapita < 120) return WealthStatus.abundance; // 90-120§ per soldier
    return WealthStatus.excess; // > 120§ per soldier
  }

  /// Get dynamic scrap-to-rupee conversion rate based on wealth status
  double get scrapToRupeeConversion {
    switch (currentWealthStatus) {
      case WealthStatus.destitution:
        return 3.0; // 3:1 - Scrap highly valued
      case WealthStatus.poverty:
        return 2.0; // 2:1
      case WealthStatus.subsistence:
        return 1.5; // 3:2
      case WealthStatus.sufficiency:
        return 1.0; // 1:1 - Equal value
      case WealthStatus.comfort:
        return 0.67; // 2:3
      case WealthStatus.abundance:
        return 0.5; // 1:2
      case WealthStatus.excess:
        return 0.33; // 1:3 - Scrap devalued
    }
  }

  /// Calculate total supply wealth (excluding equipped gear)
  double _calculateTotalSupplyWealth() {
    double total = 0.0;

    // Raw resources (estimated scrap values)
    total += _communalWood * 0.5;
    total += _communalIronOre * 1.0;
    total += _communalScrap * 1.0;
    total += _communalShortArrows * 0.5;
    total += _communalLongArrows * 0.7; // Long arrows slightly more valuable
    total += _communalMeat * 2.0;
    total += _communalRice * 1.0;
    total += _communalMilk * 1.5;
    total += _communalCheese * 2.0;
    total += _communalGrain * 1.0;

    // Communal stash (unequipped items with scrap value)
    for (var item in communalStash) {
      if (item.valueType == ValueType.Supply) {
        total += item.baseValue;
      }
    }

    // Livestock
    total += communalCattle.totalPopulation * 200.0;
    total += _communalHerd.length * 300.0;

    return total;
  }

  Soldier? findSoldierById(int id) {
    try {
      return horde.firstWhere((s) => s.id == id);
    } catch (e) {
      try {
        return npcHorde1.firstWhere((s) => s.id == id);
      } catch (e2) {
        try {
          return npcHorde2.firstWhere((s) => s.id == id);
        } catch (e3) {
          try {
            return garrisonSoldiers.firstWhere((s) => s.id == id);
          } catch (e4) {
            return null;
          }
        }
      }
    }
  }

  Aravt? findAravtById(String id) {
    try {
      return aravts.firstWhere((a) => a.id == id);
    } catch (e) {
      try {
        return npcAravts1.firstWhere((a) => a.id == id);
      } catch (e2) {
        try {
          return npcAravts2.firstWhere((a) => a.id == id);
        } catch (e3) {
          try {
            return garrisonAravts.firstWhere((a) => a.id == id);
          } catch (e4) {
            return null;
          }
        }
      }
    }
  }

  PointOfInterest? findPoiByIdWorld(String id) {
    for (final area in worldMap.values) {
      final poi = area.findPoiById(id);
      if (poi != null) {
        return poi;
      }
    }
    return null;
  }

  Settlement? findSettlementById(String id) {
    try {
      return settlements.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  //  Notification Badge Tracking
  //  Map of Tab Name -> Unread Count
  Map<String, int> unreadReportCounts = {};

  //  Legacy set for migration (will be ignored/cleared)

  int getBadgeCountForFoodSubTab(String subTab) {
    // For specific sub-tabs, we might need granular tracking or just rely on main tab?
    // User only asked for general badges but implemented sub-tab logic exists.
    // Simplifying: If main Food tab is read, these should be 0.
    // If not, we might need to query the event log OR just return the main Food count if we can't distinguish?
    // But wait, the original logic filtered by sub-tab.
    // Let's stick to the new reliable counter for main tabs.
    // For sub-tabs, we can try to filter the "unread" events if we tracked them, but we are only tracking generic counts per tab.
    // Fallback: If map has count > 0, we can scan the top N events to see which sub-tab they belong to?
    // Or just simplify and say sub-badges are disabled/cleared for now to fix duplication?
    // Creating granular counters for sub-tabs effectively:
    return unreadReportCounts['Food_$subTab'] ?? 0;
  }

  int getBadgeCountForTab(String tabName) {
    // Simplified Categories
    if (tabName == 'Chronicle') {
      return (unreadReportCounts['Event Log'] ?? 0) +
          (unreadReportCounts['Combat'] ?? 0) +
          (unreadReportCounts['History'] ?? 0);
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
    // Highlight only the player's specific Aravt (Third Aravt)
    return event.relatedAravtId!.contains("Third") ||
        event.relatedAravtId!.contains("aravt_3");
  }

  int getReportsBadgeCount() {
    // Sum of all generic report tabs
    int total = 0;
    // We can just sum values of main tabs
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
    } else {
      unreadReportCounts[tabName] = 0;

      // Handle category clearings
      if (tabName == 'Chronicle') {
        unreadReportCounts['Event Log'] = 0;
        unreadReportCounts['Combat'] = 0;
        unreadReportCounts['History'] = 0;
      } else if (tabName == 'Logistics') {
        unreadReportCounts['Finance'] = 0;
        unreadReportCounts['Industry'] = 0;
        unreadReportCounts['Khan'] = 0;
        unreadReportCounts['Communal'] = 0;
        unreadReportCounts['Global'] = 0;
      } else if (tabName == 'Provisions') {
        unreadReportCounts['Food'] = 0;
        unreadReportCounts['Herds'] = 0;
        unreadReportCounts['Hunting'] = 0;
        unreadReportCounts['Fishing'] = 0;
      } else if (tabName == 'Military') {
        unreadReportCounts['Health'] = 0;
        unreadReportCounts['Training'] = 0;
        unreadReportCounts['Games'] = 0;
      } else if (tabName == 'World') {
        unreadReportCounts['Diplomacy'] = 0;
      }

      // Legacy sub-tabs
      if (tabName == 'Food') {
        unreadReportCounts['Food_Hunting'] = 0;
        unreadReportCounts['Food_Fishing'] = 0;
        unreadReportCounts['Food_Overview'] = 0;
      } else if (tabName == 'Commerce') {
        unreadReportCounts['Commerce_Industry'] = 0;
        unreadReportCounts['Commerce_Finance'] = 0;
      }
    }
    notifyListeners();
  }

  //  Soldier-specific badge tracking
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
        return 'Commerce';
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

  // Call this whenever turns change to track wealth
  void recordWealthHistory() {
    // Assuming you have a way to calculate total liquid wealth
    double currentWealth = (player?.treasureWealth ?? 0) +
        communalScrap * 5.0; // Example valuation
    wealthHistory.add(currentWealth);
    // keep only last 30 turns for the chart to avoid overcrowding
    if (wealthHistory.length > 30) {
      wealthHistory.removeAt(0);
    }
    notifyListeners();
  }

  void addTournamentResult(TournamentResult result) {
    print("DEBUG: Tournament result added: ${result.name}");
    tournamentHistory.add(result);
    upcomingTournaments.removeWhere((future) =>
        future.date.year == result.date.year &&
        future.date.month == result.date.month &&
        future.date.day == result.date.day);

    logEvent(
      "The ${result.name} has concluded! Check Global Reports for details.",
      category: EventCategory.general,
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

  //  Add Resource Report
  void addResourceReport(ResourceReport report) {
    resourceReports.add(report);
    notifyListeners();
  }

  // --- RESOURCE MANAGEMENT METHODS ---
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
    _communalScrap = max(0, _communalScrap - amount);
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
  // ------------------------------------

  double? getLocationResourceLevel(String locationId) {
    return _locationResourceLevels[locationId];
  }

  void updateLocationResourceLevel(String locationId, double level) {
    _locationResourceLevels[locationId] = level.clamp(0.0, 1.0);
  }

  // Narrative Event Methods
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
    print("GAME STATE: Game Over triggered due to: $reason");
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

    // Deduplication: Don't log the exact same message for the same soldier on the same day
    if (eventLog.isNotEmpty) {
      final lastEvent = eventLog.first;
      if (lastEvent.message == newEvent.message &&
          lastEvent.relatedSoldierId == newEvent.relatedSoldierId &&
          lastEvent.date.year == newEvent.date.year &&
          lastEvent.date.month == newEvent.date.month &&
          lastEvent.date.day == newEvent.date.day) {
        return; // Skip duplicate
      }
    }

    eventLog.insert(0, newEvent);
    if (eventLog.length > 1000) {
      eventLog.removeLast();
    }

    // so the badge reappears (e.g., tournament completion after viewing Games tab)
    if (severity == EventSeverity.critical || severity == EventSeverity.high) {
      final tabName = _getTabNameForCategory(category);
      viewedReportTabs.remove(tabName);
    }

    notifyListeners();
  }

  void setCurrentArea(HexCoordinates coordinates) {
    final newArea = worldMap[coordinates.toString()];
    if (newArea != null) {
      currentArea = newArea;
      notifyListeners();
    } else {
      print(
          "Warning: Attempted to set currentArea to non-existent hex: $coordinates");
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
      GameArea? areaWithPoi;
      PointOfInterest? previousPoi;
      for (final area in worldMap.values) {
        try {
          previousPoi = area.findPoiById(previousLocationId);
          if (previousPoi != null) {
            areaWithPoi = area;
            break;
          }
        } catch (e) {}
      }

      if (previousPoi != null) {
        previousPoi.assignedAravtIds.remove(aravt.id);
      } else {
        print(
            "Warning: Could not find previous POI $previousLocationId to clear assignment.");
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

    // Recover cargo and horses if cancelling a Trade task
    if (aravt.task is TradeTask) {
      final tradeTask = aravt.task as TradeTask;
      communalStash.addAll(tradeTask.cargo);
      _communalHerd.addAll(tradeTask.horses); // Return horses to herd

      // Recover resources
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

      print(
          "Recovered cargo, horses, and resources from cancelled Trade task for ${aravt.id}");
    }

    clearAravtAssignment(aravt);

    if (!poi.assignedAravtIds.contains(aravt.id)) {
      poi.assignedAravtIds.add(aravt.id);
    }

    // Check for travel requirement
    bool needsTravel = false;
    double travelSeconds = 0;
    if (aravt.hexCoords != null &&
        poi.position != null &&
        aravt.hexCoords != poi.position) {
      int distance = aravt.hexCoords!.distanceTo(poi.position!);
      if (distance > 0) {
        needsTravel = true;
        travelSeconds = distance * 86400.0; // 1 day per tile
      }
    }

    // Create tasks based on type
    if (assignment == AravtAssignment.Trade) {
      final cargo = <InventoryItem>[];
      final horses = <Mount>[];

      if (finalOption != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(finalOption);

          // Process Cargo
          final ids = List<String>.from(data['cargoItemIds'] ?? []);
          for (var id in ids) {
            final index = communalStash.indexWhere((i) => i.id == id);
            if (index != -1) {
              cargo.add(communalStash.removeAt(index));
            }
          }

          // Process Horses
          final horseIds = List<String>.from(data['horseIds'] ?? []);
          for (var id in horseIds) {
            final index = _communalHerd.indexWhere((h) => h.id == id);
            if (index != -1) {
              horses.add(_communalHerd.removeAt(index));
            }
          }
        } catch (e) {
          print("Error parsing Trade option: $e");
        }
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
              // Deduct from communal
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
        } catch (e) {
          print("Error parsing Trade resources: $e");
        }
      }

      aravt.task = TradeTask(
        targetPoiId: poi.id,
        cargo: cargo,
        horses: horses,
        resources: resources,
        movement: movingTask,
      );
      print(
          "Assigned ${aravt.id} to Trade at ${poi.name} with ${cargo.length} items and ${horses.length} horses");
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
        } catch (e) {
          print("Error parsing Emissary option: $e");
        }
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
      print(
          "Assigned ${aravt.id} to Emissary at ${poi.name} with ${terms.length} terms");
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
        print(
            "Assigned ${aravt.id} to travel to ${poi.name} for ${assignment.name} (Distance: ${travelSeconds / 86400} days)");
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
        print("Assigned ${aravt.id} to ${poi.name} for ${assignment.name}");
      }
    }

    // Also set persistent assignment option if possible, or just rely on task renewal
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
    print("[GameState Provider] Initializing new game...");
    try {
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
      isOmniscientMode = false;
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
          initialStateContainer._locationResourceLevels); // Deep copy map

      butcheringQueue = List.from(initialStateContainer.butcheringQueue);
      butcheringRate = initialStateContainer.butcheringRate;
      allowAlcohol = initialStateContainer.allowAlcohol;
      vegetarianDiet = initialStateContainer.vegetarianDiet;

      // Initialize Communal Cattle Herd with individual animals

      GameDate addDays(GameDate start, int days) {
        GameDate d = start.copy();
        for (int i = 0; i < days; i++) d.nextDay();
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

      logEvent(
        "The Great Downsizing Tournament has been announced! You have 7 days to prepare. The weakest Aravt will be exiled.",
        category: EventCategory.games,
        severity: EventSeverity.critical,
      );

      logEvent(
        "The horde gathers on the steppe. A new story begins.",
        category: EventCategory.general,
        severity: EventSeverity.normal,
      );

      print("[GameState Provider] New game created successfully.");
      notifyListeners();
    } catch (e, stackTrace) {
      print("ERROR initializing new game: $e");
      print(stackTrace);
    }
  }

  Future<void> advanceToNextTurn() async {
    if (_isLoading) return;
    await _nextTurnService.executeNextTurn(this);
  }

  void toggleOmniscientMode() {
    if (isOmniscienceAllowed) {
      isOmniscientMode = !isOmniscientMode;
      print("Omniscient Mode: $isOmniscientMode");
      logEvent(
        "Omniscient Mode ${isOmniscientMode ? 'Enabled' : 'Disabled'}.",
        category: EventCategory.general,
        severity: EventSeverity.low,
      );
      notifyListeners();
    } else {
      print("Omniscient Mode is not allowed for this save file.");
      logEvent(
        "Omniscient Mode is not allowed for this save file.",
        category: EventCategory.general,
        severity: EventSeverity.low,
      );
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
    if (soldier.isPlayer) {
      print("Player transfer logic not yet implemented.");
      return;
    }

    final oldAravt = findAravtById(soldier.aravt);

    if (oldAravt != null) {
      oldAravt.soldierIds.remove(soldier.id);
      if (oldAravt.captainId == soldier.id) {
        print(
            "WARNING: Captain transfer logic not implemented. Aravt ${oldAravt.id} is now leaderless.");
      }
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

    if (soldier.isImprisoned) {
      logEvent(
        "${soldier.name} has been imprisoned in the stockade.",
        category: EventCategory.general,
        severity: EventSeverity.high,
        soldierId: soldier.id,
      );
    } else {
      logEvent(
        "${soldier.name} has been released from the stockade.",
        category: EventCategory.general,
        severity: EventSeverity.normal,
        soldierId: soldier.id,
      );
    }
    notifyListeners();
  }

  void _removeSoldierFromHorde(Soldier soldier) {
    // Don't remove player, just let them be marked dead for the Game Over screen
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
    print("DEBUG: Expelling soldier ${soldier.name} (ID: ${soldier.id})");
    logEvent(
      "${soldier.name} has been expelled from the horde!",
      category: EventCategory.general,
      severity: EventSeverity.critical,
      soldierId: soldier.id,
    );

    _removeSoldierFromHorde(soldier);

    print("${soldier.name} has been permanently removed from the horde.");
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

    _applyDeathMoraleImpact(soldier);
    _removeSoldierFromHorde(soldier);

    print(
        "${soldier.name} has been permanently removed from the horde (Executed).");
    notifyListeners();
  }

  //  Public method to remove dead soldier without execution logic
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
    print("Save Game Pressed... processing.");
    if (_isLoading) {
      print("Cannot save while turn is processing.");
      return;
    }
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

      logEvent("Game Saved: $displayName",
          category: EventCategory.system, severity: EventSeverity.high);
    } catch (e) {
      print("Error during manual save: $e");
      logEvent("Failed to save game!",
          category: EventCategory.system, severity: EventSeverity.critical);
    } finally {
      setLoading(false);
    }
  }

  Future<bool> loadGame(String fileName) async {
    print("Load Game Pressed for $fileName... processing.");
    setLoading(true);
    try {
      final Map<String, dynamic>? data =
          await _saveLoadService.readSaveFile(fileName);
      if (data != null && data.containsKey('gameState')) {
        _clearAllState();
        _fromJson(data['gameState']);
        _validateAndFixHordeHierarchy();
        logEvent("Game Loaded: ${player?.name}",
            category: EventCategory.system, severity: EventSeverity.high);
        setLoading(false);
        return true;
      } else {
        throw Exception("Save file is corrupt or missing 'gameState' key.");
      }
    } catch (e) {
      print("Error during load: $e");
      logEvent("Failed to load game! $e",
          category: EventCategory.system, severity: EventSeverity.critical);
      setLoading(false);
      return false;
    }
  }

  void _validateAndFixHordeHierarchy() {
    print("Validating Horde Hierarchy...");
    for (var aravt in aravts) {
      // 1. Check if captain exists and is valid
      final captainIndex = horde.indexWhere((s) => s.id == aravt.captainId);
      bool captainNeedsReplacement = false;

      if (captainIndex == -1) {
        print("Aravt ${aravt.id} has invalid captain ID ${aravt.captainId}.");
        captainNeedsReplacement = true;
        // Try to move them back? Or pick new?
        // Let's pick new for safety, or move them if they are 'floating'.
        captainNeedsReplacement = true;
      }

      if (captainNeedsReplacement) {
        // Find best candidate
        final members = horde
            .where((s) =>
                aravt.soldierIds.contains(s.id) &&
                s.status == SoldierStatus.alive &&
                !s.isImprisoned &&
                !s.isExpelled)
            .toList();

        if (members.isNotEmpty) {
          // Sort by Leadership
          members.sort((a, b) => b.leadership.compareTo(a.leadership));
          final newCaptain = members.first;
          aravt.captainId = newCaptain.id;
          newCaptain.role = SoldierRole.aravtCaptain;
          print("Appointed ${newCaptain.name} as new captain of ${aravt.id}.");
          logEvent(
              "Hierarchy Restored: ${newCaptain.name} is now captain of ${aravt.id}.",
              category: EventCategory.system,
              severity: EventSeverity.low);
        } else {
          print("Aravt ${aravt.id} has no valid members for captaincy.");
          // Could disband? For now just warning.
        }
      }
    }
  }

  // --- PROMOTION SYSTEM ---

  bool canPromoteToCaptain(Soldier soldier) {
    if (soldier.role == SoldierRole.hordeLeader) return false;
    if (soldier.status != SoldierStatus.alive) return false;
    if (soldier.isImprisoned) return false;
    // Current captain can be promoted to new aravt? Maybe, but usually they just stay.
    return true;
  }

  bool canPromoteToGeneral(Soldier soldier) {
    if (soldier.role != SoldierRole.aravtCaptain) return false;
    if (aravts.length <= 10) return false;
    return true;
  }

  void promoteSoldierToCaptain(Soldier soldier) {
    if (!canPromoteToCaptain(soldier)) return;

    // 1. Generate new Aravt ID
    int nextNum = 1;
    while (aravts.any((a) => a.id == 'Aravt $nextNum')) {
      nextNum++;
    }
    final newAravtId = 'Aravt $nextNum';

    // 2. Create new Aravt
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

    // 3. Transfer Soldier
    transferSoldier(soldier, newAravt);

    // 4. Update Role (transferSoldier handles this if captainId matches, but let's be sure)
    soldier.role = SoldierRole.aravtCaptain;
    newAravt.captainId = soldier.id; // Ensure sync

    logEvent(
      "${soldier.name} has been promoted to Captain of the newly formed $newAravtId!",
      category: EventCategory.general,
      severity: EventSeverity.high,
      soldierId: soldier.id,
    );
    notifyListeners();
  }

  void promoteToGeneral(Soldier soldier) {
    if (!canPromoteToGeneral(soldier)) return;

    soldier.role = SoldierRole.general;
    logEvent(
      "${soldier.name} has been promoted to General!",
      category: EventCategory.general,
      severity: EventSeverity.critical,
      soldierId: soldier.id,
    );
    notifyListeners();
  }

  Future<List<SaveFileInfo>> getSaveFiles() {
    return _saveLoadService.getSaveFileList();
  }

  Future<void> autoSave() async {
    // Don't autosave if the game is already over to prevent scumming death
    if (isGameOver) {
      print("Autosave skipped (Game Over).");
      return;
    }
    if (!autoSaveEnabled) {
      print("Autosave skipped (disabled).");
      return;
    }
    print("Autosaving game...");
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

      logEvent("Game Autosaved",
          category: EventCategory.system, severity: EventSeverity.normal);
    } catch (e) {
      print("Error during autosave: $e");
      logEvent("Failed to autosave game!",
          category: EventCategory.system, severity: EventSeverity.critical);
    }
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
    //  Clear resource reports
    resourceReports = [];
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
    // _playerInventory = []; // Removed
    // _playerEquippedItems = {}; // Removed
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
    final Map<int, Soldier> soldierMap = {
      for (var s in horde) s.id: s,
      for (var s in npcHorde1) s.id: s,
      for (var s in npcHorde2) s.id: s,
      for (var s in garrisonSoldiers) s.id: s,
    };

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
      int distance = aravt.hexCoords?.distanceTo(area.coordinates) ?? 1;
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
