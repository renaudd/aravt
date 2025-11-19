import 'dart:math';
import 'package:aravt/models/area_data.dart';
import 'package:aravt/models/assignment_data.dart';
import 'package:aravt/models/game_event.dart';
import 'package:aravt/models/horde_data.dart';
import 'package:aravt/models/location_data.dart';
import 'package:aravt/providers/game_state.dart';


/// This service is called by the UI to create and assign new tasks to Aravts.
/// It performs checks, handles travel logistics, and translates UI actions into model data changes.
class UiAssignmentService {
 final Random _random = Random();


 /// Checks if an Aravt is free to receive a new task.
 bool canAssignNewTask(Aravt aravt) {
   return aravt.task == null;
 }


 /// Assigns a task at a specific POI (Hunt, Fish, Mine, etc.).
 /// Automatically handles travel if the Aravt is not currently at that POI.
 void assignPoiTask({
   required Aravt aravt,
   required PointOfInterest poi,
   required AravtAssignment assignment,
   required GameState gameState,
 }) {
   if (!canAssignNewTask(aravt)) {
     _logError(gameState, "Aravt ${aravt.id} is already busy.");
     return;
   }


   // Determine appropriate duration based on task type
   int duration = 7200; // Default 2 hours
   switch (assignment) {
     case AravtAssignment.Hunt:
     case AravtAssignment.Fish:
       duration = 14400; // 4 hours for better yields
       break;
     case AravtAssignment.Mine:
     case AravtAssignment.ChopWood:
       duration = 10800; // 3 hours
       break;
     default:
       duration = 3600; // 1 hour for simple tasks
       break;
   }


   if (aravt.currentLocationType == LocationType.poi &&
       aravt.currentLocationId == poi.id) {
     // Already there, start immediately
     _assignImmediateTask(
       aravt: aravt,
       areaId: null, // POI task doesn't strictly need areaId if it has poiId
       poiId: poi.id,
       assignment: assignment,
       duration: duration,
       gameState: gameState,
       locationName: poi.name,
     );
   } else {
     // Need to travel first
     _assignTravelThenTask(
       aravt: aravt,
       destination: GameLocation.poi(poi.id),
       followUpAssignment: assignment,
       followUpPoiId: poi.id,
       duration: duration,
       gameState: gameState,
       destinationName: poi.name,
     );
   }
 }


 /// Assigns an Area-Level task (Scout, Patrol).
 /// Automatically handles travel if the Aravt is not in that Area.
 void assignAreaTask({
   required Aravt aravt,
   required GameArea area,
   required AravtAssignment assignment,
   required GameState gameState,
 }) {
   if (!canAssignNewTask(aravt)) {
     _logError(gameState, "Aravt ${aravt.id} is already busy.");
     return;
   }


   // Find a valid entry point for travel calculations if needed
   PointOfInterest? entryPoi;
   try {
     entryPoi = area.pointsOfInterest.firstWhere((p) => p.isDiscovered);
   } catch (e) {
     if (area.pointsOfInterest.isNotEmpty) {
       entryPoi = area.pointsOfInterest.first;
     }
   }


   // If we are already in the area (based on hex coords), we can start immediately
   // regardless of whether we are at a specific POI.
   bool isAlreadyInArea = aravt.hexCoords == area.coordinates;


   if (isAlreadyInArea) {
     _assignImmediateTask(
       aravt: aravt,
       areaId: area.id,
       poiId: null,
       assignment: assignment,
       duration: 7200, // 2 hours standard for area tasks
       gameState: gameState,
       locationName: area.name,
     );
   } else {
     // Need to travel. We need *some* destination ID for the moving task.
     if (entryPoi == null) {
       _logError(gameState, "Cannot travel to ${area.name}: No known entry points.");
       return;
     }


     _assignTravelThenTask(
       aravt: aravt,
       destination: GameLocation.poi(entryPoi.id),
       followUpAssignment: assignment,
       followUpAreaId: area.id,
       duration: 7200,
       gameState: gameState,
       destinationName: area.name,
     );
   }
 }


 /// Assigns a simple Travel task with no follow-up.
 void assignTravelTask({
   required Aravt aravt,
   required GameLocation destination,
   required GameState gameState,
 }) {
   if (!canAssignNewTask(aravt)) return;


   _createMovingTask(
     aravt: aravt,
     destination: destination,
     gameState: gameState,
   );


   String destName = "destination";
   if (destination.type == LocationType.poi) {
       destName = gameState.findPoiByIdWorld(destination.id)?.name ?? "unknown POI";
   }


   gameState.logEvent(
     "Your aravt begins traveling to $destName.",
     category: EventCategory.travel,
     aravtId: aravt.id,
   );
   gameState.notifyListeners();
 }


 // --- PRIVATE HELPERS ---


 void _assignImmediateTask({
   required Aravt aravt,
   required String? areaId,
   required String? poiId,
   required AravtAssignment assignment,
   required int duration,
   required GameState gameState,
   required String locationName,
 }) {
   // Register at POI if applicable
   if (poiId != null) {
      final poi = gameState.findPoiByIdWorld(poiId);
      if (poi != null && !poi.assignedAravtIds.contains(aravt.id)) {
          poi.assignedAravtIds.add(aravt.id);
      }
   }


   aravt.task = AssignedTask(
     areaId: areaId,
     poiId: poiId,
     assignment: assignment,
     durationInSeconds: duration.toDouble(),
     startTime: gameState.currentDate?.toDateTime() ?? DateTime.now(),
   );


   gameState.logEvent(
     "Your aravt begins to ${assignment.name} at $locationName.",
     category: EventCategory.general,
     aravtId: aravt.id,
   );
   gameState.notifyListeners();
 }


 void _assignTravelThenTask({
   required Aravt aravt,
   required GameLocation destination,
   required AravtAssignment followUpAssignment,
   required int duration,
   required GameState gameState,
   required String destinationName,
   String? followUpAreaId,
   String? followUpPoiId,
 }) {
   // Deregister from current POI if any before leaving
   gameState.clearAravtAssignment(aravt);


   _createMovingTask(
     aravt: aravt,
     destination: destination,
     gameState: gameState,
     followUpAssignment: followUpAssignment,
     followUpAreaId: followUpAreaId,
     followUpPoiId: followUpPoiId,
     followUpDuration: duration,
   );


   gameState.logEvent(
     "Your aravt begins traveling to $destinationName to ${followUpAssignment.name}.",
     category: EventCategory.travel,
     aravtId: aravt.id,
   );
   gameState.notifyListeners();
 }


 void _createMovingTask({
     required Aravt aravt,
     required GameLocation destination,
     required GameState gameState,
     AravtAssignment? followUpAssignment,
     String? followUpAreaId,
     String? followUpPoiId,
     int? followUpDuration,
 }) {
     // Calculate travel time based on distance
     double travelSeconds = 3600; // Default 1 hour if calculation fails
    
     HexCoordinates? startCoords = aravt.hexCoords;
     HexCoordinates? endCoords;


     if (destination.type == LocationType.poi) {
         endCoords = gameState.findPoiByIdWorld(destination.id)?.position;
     } else if (destination.type == LocationType.settlement) {
         final settlement = gameState.findSettlementById(destination.id);
         if (settlement != null) {
             endCoords = gameState.findPoiByIdWorld(settlement.poiId)?.position;
         }
     }


     if (startCoords != null && endCoords != null) {
         int distance = startCoords.distanceTo(endCoords);
         // Arbitrary: 1 hex = 2 hours travel time (7200 seconds)
         // Adjust this multiplier to tune game pacing.
         travelSeconds = max(3600, distance * 7200.0);
     }


     aravt.task = MovingTask(
       destination: destination,
       durationInSeconds: travelSeconds,
       startTime: gameState.currentDate?.toDateTime() ?? DateTime.now(),
       followUpAssignment: followUpAssignment,
       followUpAreaId: followUpAreaId,
       followUpPoiId: followUpPoiId,
     );
 }


 void _logError(GameState gameState, String message) {
   print("UI ASSIGNMENT ERROR: $message");
   // Optionally push this to the in-game log too if it's relevant to the player
   // gameState.logEvent(message, category: EventCategory.system, severity: EventSeverity.high);
 }
}

