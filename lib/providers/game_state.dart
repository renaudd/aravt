import 'dart:async';
import 'dart:convert';
import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/combat_flow_state.dart';
import 'package:aravt/models/game_date.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/soldier_data.dart';
import 'package:aravt/models/yurt_data.dart';
import 'package:aravt/models/settlement_data.dart';
import 'package:aravt/models/assignment_data.dart'; // Keep this as the primary source for AravtAssignment
import 'package:aravt/models/game_turn.dart';
import 'package:flutter/foundation.dart';
import 'package:aravt/services/game_setup_service.dart' as setup_service;
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/inventory_item.dart';
import 'package:aravt/models/combat_report.dart';
import 'package:aravt/models/combat_models.dart';
import 'package:aravt/services/combat_service.dart';
import 'dart:math';


import 'package:aravt/models/location_data.dart';
import 'package:aravt/services/next_turn_service.dart';
import 'package:aravt/services/save_load_service.dart';
import 'package:aravt/models/save_file_info.dart';
import 'package:aravt/models/prisoner_action.dart';
import 'package:aravt/models/tournament_data.dart';
import 'package:aravt/models/hunting_report.dart';
import 'package:aravt/models/fishing_report.dart';
import 'package:aravt/models/herd_data.dart';
// [GEMINI-NEW] Import for ResourceTripReport
import 'package:aravt/models/resource_report.dart';


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
 List<Yurt> yurts = [];
 List<CombatReport> combatReports = [];


 List<TournamentResult> tournamentHistory = [];
 List<FutureTournament> upcomingTournaments = [];

 List<double> wealthHistory = [];
 List<ResourceReport> resourceReports = [];

 // Hunting, Fishing, & Resource History
 List<HuntingTripReport> huntingReports = [];
 List<FishingTripReport> fishingReports = [];
 // [GEMINI-NEW] Resource reports (wood/mining)


 // Narrative Event State
 NarrativeEvent? activeNarrativeEvent;
 bool hasDay5TradeOccurred = false;


 String difficulty = 'medium';


 // Game Over State
 bool isGameOver = false;
 String? gameOverReason;


 // Automation flag for player's horde (before they are leader)
 bool isPlayerHordeAutomated = true;


 GameArea? currentArea;
 Soldier? player;
 GameDate? currentDate;
 int? tutorialCaptainId;


 Map<String, GameArea> worldMap = {};


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
 bool isOmniscienceAllowed = false;


 List<Soldier> npcHorde1 = [];
 List<Aravt> npcAravts1 = [];
 List<Soldier> npcHorde2 = [];
 List<Aravt> npcAravts2 = [];
 List<Soldier> garrisonSoldiers = [];
 List<Aravt> garrisonAravts = [];


 List<InventoryItem> _playerInventory = [];
 List<InventoryItem> get playerInventory => _playerInventory;


 Map<EquipmentSlot, InventoryItem> _playerEquippedItems = {};
 Map<EquipmentSlot, InventoryItem> get playerEquippedItems =>
     _playerEquippedItems;


 // --- COMMUNAL RESOURCES ---
 double _communalMeat = 100.0;
 double get communalMeat => _communalMeat;


 double _communalRice = 50.0;
 double get communalRice => _communalRice;


 double _communalIronOre = 0.0;
 double get communalIronOre => _communalIronOre;


 double _communalWood = 0.0;
 double get communalWood => _communalWood;


 double _communalScrap = 50.0;
 double get communalScrap => _communalScrap;


 int _communalArrows = 100;
 int get communalArrows => _communalArrows;


 // Communal Stash for individual items (pelts, etc.)
 List<InventoryItem> communalStash = [];


 // Resource depletion tracking (POI ID -> Richness 0.0-1.0)
 Map<String, double> _locationResourceLevels = {};


 // Horses
 List<Mount> _communalHerd = [];
 List<Mount> get communalHerd => _communalHerd;


 // Cattle Herd for shepherding
 late Herd communalCattle;


 @protected
 CombatSimulator? currentCombat;
 @protected
 ActiveCombatState? activeCombat;
 final Random _random = Random();


 CombatFlowState _combatFlowState = CombatFlowState.none;
 CombatFlowState get combatFlowState => _combatFlowState;


 @protected
 ActiveCombatState? pendingCombat;
 @protected
 CombatReport? lastCombatReport;


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


 void addCombatReport(CombatReport report) {
   combatReports.add(report);
   notifyListeners();
 }


  // Call this whenever turns change to track wealth
  void recordWealthHistory() {
    // Assuming you have a way to calculate total liquid wealth
    double currentWealth = (player?.treasureWealth ?? 0) + communalScrap * 5.0; // Example valuation
    wealthHistory.add(currentWealth);
     // keep only last 30 turns for the chart to avoid overcrowding
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


 // [GEMINI-NEW] Add Resource Report
 void addResourceReport(ResourceReport report) {
   resourceReports.add(report);
   notifyListeners();
 }


 // --- RESOURCE MANAGEMENT METHODS ---
 void addCommunalMeat(double amount) {
   _communalMeat += amount;
   notifyListeners();
 }


 void addCommunalIronOre(double amount) {
   _communalIronOre += amount;
   notifyListeners();
 }


 void addCommunalWood(double amount) {
   _communalWood += amount;
   notifyListeners();
 }


 void addCommunalScrap(double amount) {
   _communalScrap += amount;
   notifyListeners();
 }


 void removeCommunalScrap(double amount) {
   _communalScrap = max(0, _communalScrap - amount);
   notifyListeners();
 }


 void addCommunalArrows(int amount) {
   _communalArrows += amount;
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
   eventLog.insert(0, newEvent);
   if (eventLog.length > 1000) {
     eventLog.removeLast();
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
     Aravt aravt, PointOfInterest poi, AravtAssignment assignment) {
   clearAravtAssignment(aravt);


   if (!poi.assignedAravtIds.contains(aravt.id)) {
     poi.assignedAravtIds.add(aravt.id);
   }


   aravt.task = AssignedTask(
     poiId: poi.id,
     assignment: assignment,
     durationInSeconds: 3600,
     startTime: currentDate != null
         ? DateTime(currentDate!.year, currentDate!.month, currentDate!.day)
         : DateTime.now(),
   );


   print("Assigned ${aravt.id} to ${poi.name} for ${assignment.name}");
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


   final gameService = setup_service.GameSetupService();
   final setup_service.GameState initialStateContainer =
       gameService.createNewGame(
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


   // Initialize Communal Cattle Herd with individual animals
   communalCattle =
       Herd.createDefault(AnimalType.Cattle, females: 25, males: 5, young: 10);


   if (player != null) {
     _playerInventory = List<InventoryItem>.from(player!.personalInventory);
     _playerEquippedItems =
         Map<EquipmentSlot, InventoryItem>.from(player!.equippedItems);
     print("Player inventory initialized: ${_playerInventory.length} items.");
     print(
         "Player equipment initialized: ${_playerEquippedItems.length} items.");
   } else {
     print("CRITICAL WARNING: Player object is null after game setup!");
   }


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
     "The horde gathers on the steppe. A new story begins.",
     category: EventCategory.general,
     severity: EventSeverity.high,
   );


   print("[GameState Provider] New game created successfully.");
   notifyListeners();
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
   // [GEMINI-NEW] Clear resource reports
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
   _playerInventory = [];
   _playerEquippedItems = {};
   _communalHerd = [];
   communalCattle = Herd(type: AnimalType.Cattle);
   _combatFlowState = CombatFlowState.none;
   eventLog = [];
   _interactionTokensRemaining = 10;
 }


 void equipItem(InventoryItem item) {
   final slot = item.equippableSlot;
   if (slot == null) return;
   if (_playerEquippedItems.containsKey(slot)) unequipItem(slot);
   _playerInventory.remove(item);
   _playerEquippedItems[slot] = item;
   logEvent("Equipped ${item.name}.",
       category: EventCategory.general, severity: EventSeverity.low);
   notifyListeners();
 }


 void unequipItem(EquipmentSlot slot) {
   final item = _playerEquippedItems[slot];
   if (item == null) return;
   _playerEquippedItems.remove(slot);
   _playerInventory.add(item);
   logEvent("Unequipped ${item.name}.",
       category: EventCategory.general, severity: EventSeverity.low);
   notifyListeners();
 }


 void consumeItem(Consumable item) {
   print("Consumed ${item.name}. Effect: ${item.effect}");
   _playerInventory.remove(item);
   logEvent("Consumed ${item.name}.",
       category: EventCategory.food, severity: EventSeverity.low);
   notifyListeners();
 }


 void addItemToInventory(InventoryItem item) {
   _playerInventory.add(item);
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
     print("Warning: Cannot initiate combat, a combat flow is already active.");
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
     ...garrisonSoldiers
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
     'worldMap':
         worldMap.map((key, value) => MapEntry(key, value.toJson())),
     'interactionTokensRemaining': _interactionTokensRemaining,
     'playerId': player?.id,
     'horde': horde.map((s) => s.toJson()).toList(),
     'aravts': aravts.map((a) => a.toJson()).toList(),
     'yurts': yurts.map((y) => y.toJson()).toList(),
     'npcHorde1': npcHorde1.map((s) => s.toJson()).toList(),
     'npcAravts1': npcAravts1.map((a) => a.toJson()).toList(),
     'npcHorde2': npcHorde2.map((s) => s.toJson()).toList(),
     'npcAravts2': npcAravts2.map((a) => a.toJson()).toList(),
     'garrisonSoldiers':
         garrisonSoldiers.map((s) => s.toJson()).toList(),
     'garrisonAravts': garrisonAravts.map((a) => a.toJson()).toList(),
     'settlements': settlements.map((s) => s.toJson()).toList(),
     'playerInventory': _playerInventory.map((i) => i.toJson()).toList(),
     'playerEquippedItems': _playerEquippedItems
         .map((key, value) => MapEntry(key.name, value.toJson())),
     'communalMeat': _communalMeat,
     'communalRice': _communalRice,
     'communalIronOre': _communalIronOre,
     'communalWood': _communalWood,
     'communalScrap': _communalScrap,
     'communalArrows': _communalArrows,
     'locationResourceLevels': _locationResourceLevels,
     'communalHerd': _communalHerd.map((m) => m.toJson()).toList(),
     'communalCattle': communalCattle.toJson(),
     'communalStash': communalStash.map((i) => i.toJson()).toList(),
     'combatReports': combatReports.map((r) => r.toJson()).toList(),
     'eventLog': eventLog.map((e) => e.toJson()).toList(),
     'tournamentHistory':
         tournamentHistory.map((t) => t.toJson()).toList(),
     'upcomingTournaments':
         upcomingTournaments.map((t) => t.toJson()).toList(),
     'activeNarrativeEvent': activeNarrativeEvent?.toJson(),
     'hasDay5TradeOccurred': hasDay5TradeOccurred,
     'difficulty': difficulty,
     'isGameOver': isGameOver,
     'gameOverReason': gameOverReason,
     'isPlayerHordeAutomated': isPlayerHordeAutomated,
     'huntingReports': huntingReports.map((r) => r.toJson()).toList(),
     'fishingReports': fishingReports.map((r) => r.toJson()).toList(),
     // [GEMINI-NEW] Save resource reports
     'resourceReports': resourceReports.map((r) => r.toJson()).toList(),
   };
 }


 void _fromJson(Map<String, dynamic> json) {
   final List<Soldier> allPlayerSoldiers = (json['horde'] as List? ?? [])
       .map((s) => Soldier.fromJson(s))
       .toList();
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


   _interactionTokensRemaining =
       json['interactionTokensRemaining'] ?? 10;


   horde = allPlayerSoldiers;
   aravts = (json['aravts'] as List? ?? [])
       .map((a) => Aravt.fromJson(a))
       .toList();
   yurts = (json['yurts'] as List? ?? [])
       .map((y) => Yurt.fromJson(y))
       .toList();
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


   _playerInventory = (json['playerInventory'] as List? ?? [])
       .map((i) => InventoryItem.fromJson(i))
       .toList();
   _playerEquippedItems =
       (json['playerEquippedItems'] as Map<String, dynamic>? ?? {})
           .map((key, value) => MapEntry(
               equipmentSlotFromName(key)!, InventoryItem.fromJson(value)));
   _communalMeat = json['communalMeat'] ?? 0.0;
   _communalRice = json['communalRice'] ?? 0.0;
   _communalIronOre = json['communalIronOre'] ?? 0.0;
   _communalWood = json['communalWood'] ?? 0.0;
   _communalScrap = json['communalScrap'] ?? 50.0;
   _communalArrows = json['communalArrows'] ?? 100;
   _locationResourceLevels = (json['locationResourceLevels']
               as Map<String, dynamic>?)
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
   // [GEMINI-NEW] Load resource reports
   if (json['resourceReports'] != null) {
     resourceReports = (json['resourceReports'] as List)
         .map((r) => ResourceReport.fromJson(r))
         .toList();
   }


   _isLoading = false;
   _combatFlowState = CombatFlowState.none;
   currentCombat = null;
   activeCombat = null;
   pendingCombat = null;
   lastCombatReport = null;
 }
}


enum NarrativeEventType { day5Trade }


class NarrativeEvent {
 final NarrativeEventType type;
 final int instigatorId; // Captain ID
 final int targetId; // "Useless" Soldier ID


 NarrativeEvent({
   required this.type,
   required this.instigatorId,
   required this.targetId,
 });


 Map<String, dynamic> toJson() => {
       'type': type.name,
       'instigatorId': instigatorId,
       'targetId': targetId,
     };


 factory NarrativeEvent.fromJson(Map<String, dynamic> json) {
   return NarrativeEvent(
     type: NarrativeEventType.values
         .firstWhere((e) => e.name == json['type']),
     instigatorId: json['instigatorId'],
     targetId: json['targetId'],
   );
 }
}

