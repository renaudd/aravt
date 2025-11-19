import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math';


import '../providers/game_state.dart';
import '../models/area_data.dart'; // For GameArea and HexCoordinates
import '../widgets/persistent_menu_widget.dart';
// [GEMINI-FIX] Added missing imports for new features
import '../services/ui_assignment_service.dart';
import '../models/assignment_data.dart';
import '../models/horde_data.dart';
import '../widgets/aravt_map_icon.dart';
import '../models/soldier_data.dart'; // Needed for SoldierRole
import '../widgets/hex_map_tile.dart';


class WorldMapScreen extends StatelessWidget {
 const WorldMapScreen({super.key});


 UiAssignmentService get _uiService => UiAssignmentService();


 @override
 Widget build(BuildContext context) {
   return Scaffold(
     backgroundColor: const Color(0xFF1a1a1a),
     appBar: AppBar(
       title: Text('World Map', style: GoogleFonts.cinzel()),
       backgroundColor: Colors.black.withAlpha((255 * 0.5).round()),
       leading: IconButton(
         icon: const Icon(Icons.arrow_back),
         onPressed: () {
           if (Navigator.of(context).canPop()) {
             Navigator.of(context).pop();
           } else {
             Navigator.pushReplacementNamed(context, '/region');
           }
         },
       ),
     ),
     body: Stack(
       children: [
         _buildWorldMap(context),
         const PersistentMenuWidget(),
       ],
     ),
   );
 }


 IconData _getPoiIcon(PoiType type) {
   switch (type) {
     case PoiType.settlement:
       return Icons.fort;
     case PoiType.camp:
       return Icons.fireplace;
     case PoiType.resourceNode:
       return Icons.circle_outlined;
     case PoiType.landmark:
       return Icons.star_border;
     case PoiType.enemyCamp:
       return Icons.priority_high;
     case PoiType.questGiver:
       return Icons.person_pin;
     case PoiType.specialEncounter:
       return Icons.help_outline;
     default:
       return Icons.circle;
   }
 }


 List<Widget> _buildPoiIcons(
     GameArea hexArea, double hexRadius, GameState gameState) {
   List<Widget> poiWidgets = [];


   final bool canSeePois = gameState.isOmniscientMode || hexArea.isExplored;
   if (!canSeePois) return [];


   final poiList = hexArea.pointsOfInterest
       .where((p) => p.isDiscovered || gameState.isOmniscientMode);


   for (var poi in poiList) {
     if (poi.type == PoiType.camp &&
         (hexArea.type == AreaType.PlayerCamp ||
             hexArea.type == AreaType.NpcCamp)) {
       continue;
     }


     // Pointy-top POI offset math
     final double poiX = (poi.relativeX - 0.5) * (hexRadius * sqrt(3));
     final double poiY = (poi.relativeY - 0.5) * (hexRadius * 1.5);


     poiWidgets.add(
       Transform.translate(
         offset: Offset(poiX, poiY),
         child: Tooltip(
           message: poi.name,
           child: Icon(
             _getPoiIcon(poi.type),
             color: Colors.white,
             size: hexRadius * 0.3, // Small icon
             shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
           ),
         ),
       ),
     );
   }
   return poiWidgets;
 }


 // [GEMINI-NEW] Helper to build animated Aravt icons
 List<Widget> _buildAravtIcons(
     GameArea hexArea, double hexRadius, GameState gameState) {
   List<Widget> aravtWidgets = [];


   // Find all player aravts in this specific hex
   final aravtsInHex = gameState.aravts
       .where((aravt) => aravt.hexCoords == hexArea.coordinates)
       .toList();


   int i = 0;
   for (var aravt in aravtsInHex) {
     // Simple offset logic to prevent stacking
     final double aravtX = (i * 0.1 - 0.2) * (hexRadius * sqrt(3));
     final double aravtY = (0.2) * (hexRadius * 1.5);
     i++;


     aravtWidgets.add(
       Transform.translate(
         offset: Offset(aravtX, aravtY),
         child: Tooltip(
           message:
               "Aravt: ${gameState.findSoldierById(aravt.captainId)?.name ?? 'Unknown'}",
           child: AravtMapIcon(
             color: 'blue', // TODO: randomize this based on captain/horde
             scale: 0.375, // 75% scale for world map view
           ),
         ),
       ),
     );
   }
   return aravtWidgets;
 }


 Widget _buildWorldMap(BuildContext context) {
   final gameState = context.watch<GameState>();
   final allAreas = gameState.worldMap.values.toList();
   final currentArea = gameState.currentArea;


   if (allAreas.isEmpty) {
     return Center(
       child: Text('World Map is empty.', style: GoogleFonts.cinzel()),
     );
   }


   int minQ = 0, maxQ = 0, minR = 0, maxR = 0;
   for (var area in allAreas) {
     minQ = min(minQ, area.coordinates.q);
     maxQ = max(maxQ, area.coordinates.q);
     minR = min(minR, area.coordinates.r);
     maxR = max(maxR, area.coordinates.r);
   }
   final int qRange = (maxQ - minQ).abs() + 1;
   final int rRange = (maxR - minR).abs() + 1;


   return LayoutBuilder(
     builder: (context, constraints) {
       // Pointy-top layout math
       final double mapHexWidth = qRange + (rRange / 2);
       final double mapHexHeight = rRange * 0.75;


       final double radiusFromWidth =
           constraints.maxWidth / (mapHexWidth * sqrt(3));
       final double radiusFromHeight =
           constraints.maxHeight / (mapHexHeight * 2);


       final double hexRadius = min(radiusFromWidth, radiusFromHeight);


       final double hexWidth = sqrt(3) * hexRadius;
       final double hexHeight = 2 * hexRadius;
       final Offset centerOffset =
           Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);


       return Stack(
         clipBehavior: Clip.hardEdge,
         children: allAreas.map((hexArea) {
           final HexCoordinates coords = hexArea.coordinates;


           // Pointy-top layout positions
           final double x =
               centerOffset.dx + hexWidth * (coords.q + coords.r / 2);
           final double y = centerOffset.dy + hexHeight * 3 / 4 * (coords.r);


           Color borderColor = Colors.white10;


           final bool isExplored =
               hexArea.isExplored || gameState.isOmniscientMode;


           if (currentArea != null &&
               hexArea.coordinates == currentArea.coordinates) {
             borderColor = Colors.yellowAccent;
           }


           return Positioned(
             left: x - (hexWidth / 2),
             top: y - (hexHeight / 2),
             width: hexWidth,
             height: hexHeight,
             child: GestureDetector(
               // [GEMINI-UPDATED] Single tap -> Enter Region
               onTap: () {
                 if (!isExplored) return;
                 gameState.setCurrentArea(hexArea.coordinates);
                 Navigator.pushReplacementNamed(context, '/region');
               },
               // [GEMINI-UPDATED] Long press / secondary tap -> Assignments
               onLongPress: () {
                 _showAreaAssignmentDialog(context, hexArea, gameState);
               },
               onSecondaryTap: () {
                 _showAreaAssignmentDialog(context, hexArea, gameState);
               },
               child: Tooltip(
                 message: isExplored
                     ? '${hexArea.name} (${hexArea.type.name})'
                     : 'Unexplored Area',
                 child: Stack(
                   alignment: Alignment.center,
                   children: [
                     Image.asset(
                       getTileImagePath(hexArea, isExplored: isExplored),
                       width: hexWidth,
                       height: hexHeight,
                       fit: BoxFit.fill,
                       errorBuilder: (context, error, stackTrace) {
                         return Container(
                           width: hexWidth,
                           height: hexHeight,
                           color: Colors.red.shade900,
                           child:
                               const Center(child: Icon(Icons.error_outline)),
                         );
                       },
                     ),
                     if (isExplored)
                       FittedBox(
                         fit: BoxFit.contain,
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             if (hexArea.icon != null)
                               Icon(hexArea.icon,
                                   color: Colors.white,
                                   size: hexRadius * 0.7,
                                   shadows: const [
                                     Shadow(blurRadius: 4, color: Colors.black)
                                   ])
                             else
                               Icon(Icons.terrain,
                                   color: Colors.white.withOpacity(0.7),
                                   size: hexRadius * 0.7,
                                   shadows: const [
                                     Shadow(blurRadius: 4, color: Colors.black)
                                   ]),
                           ],
                         ),
                       ),
                     ..._buildPoiIcons(hexArea, hexRadius, gameState),
                     // [GEMINI-NEW] Show animated aravts
                     ..._buildAravtIcons(hexArea, hexRadius, gameState),


                     if (currentArea != null &&
                         hexArea.coordinates == currentArea.coordinates)
                       CustomPaint(
                         size: Size(hexWidth, hexHeight),
                         painter:
                             HexBorderPainter(color: borderColor, width: 2.0),
                       ),
                   ],
                 ),
               ),
             ),
           );
         }).toList(),
       );
     },
   );
 }


 // [GEMINI-UPDATED] Assignment dialog with Leader role check
 void _showAreaAssignmentDialog(
     BuildContext context, GameArea area, GameState gameState) {
   // Role Check: Only Horde Leader can assign tasks
   if (gameState.player?.role != SoldierRole.hordeLeader) {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         backgroundColor: const Color(0xFF2a2a2a),
         title: Text("Restricted",
             style: GoogleFonts.cinzel(color: Colors.white)),
         content: Text(
             "Only the Horde Leader can assign tasks to explore new areas.",
             style: GoogleFonts.cinzel(color: Colors.white70)),
         actions: [
           TextButton(
               onPressed: () => Navigator.pop(context),
               child: Text("Close",
                   style: GoogleFonts.cinzel(color: Colors.white)))
         ],
       ),
     );
     return;
   }


   final List<Aravt> availableAravts =
       gameState.aravts.where((a) => a.task == null).toList();


   final ValueNotifier<Aravt?> selectedAravt = ValueNotifier(null);
   if (availableAravts.isNotEmpty) {
     selectedAravt.value = availableAravts.first;
   }


   showDialog(
     context: context,
     builder: (BuildContext dialogContext) {
       return AlertDialog(
         backgroundColor: const Color(0xFF2a2a2a),
         title: Text('Assign Aravt to ${area.name}',
             style: GoogleFonts.cinzel(color: Colors.white)),
         content: Container(
           width: double.maxFinite,
           child: ValueListenableBuilder<Aravt?>(
             valueListenable: selectedAravt,
             builder: (context, currentSelection, child) {
               return Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   if (availableAravts.isEmpty)
                     Text("No aravts available (all are busy).",
                         style: GoogleFonts.cinzel(color: Colors.grey))
                   else
                     DropdownButton<Aravt>(
                       value: currentSelection,
                       dropdownColor: const Color(0xFF2a2a2a),
                       style: GoogleFonts.cinzel(color: Colors.white),
                       isExpanded: true,
                       items: availableAravts.map((aravt) {
                         final captain =
                             gameState.findSoldierById(aravt.captainId);
                         return DropdownMenuItem<Aravt>(
                           value: aravt,
                           child: Text(
                               "Aravt (${captain?.name ?? 'Unknown'}) - ${aravt.soldierIds.length} soldiers",
                               overflow: TextOverflow.ellipsis),
                         );
                       }).toList(),
                       onChanged: (aravt) {
                         selectedAravt.value = aravt;
                       },
                     ),
                   const SizedBox(height: 20),
                   Text("Available Actions:",
                       style: GoogleFonts.cinzel(color: Colors.white)),


                   // ALWAYS show Scout
                   ElevatedButton(
                     child: const Text("Scout Area"),
                     onPressed: selectedAravt.value == null
                         ? null
                         : () {
                             _uiService.assignAreaTask(
                               aravt: selectedAravt.value!,
                               area: area,
                               assignment: AravtAssignment.Scout,
                               gameState: gameState,
                             );
                             Navigator.of(dialogContext).pop();
                           },
                   ),
                   // ONLY show Patrol if area is already explored
                   if (area.isExplored)
                     ElevatedButton(
                       child: const Text("Patrol Area"),
                       onPressed: selectedAravt.value == null
                           ? null
                           : () {
                               _uiService.assignAreaTask(
                                 aravt: selectedAravt.value!,
                                 area: area,
                                 assignment: AravtAssignment.Patrol,
                                 gameState: gameState,
                               );
                               Navigator.of(dialogContext).pop();
                             },
                     )
                 ],
               );
             },
           ),
         ),
         actions: [
           TextButton(
             child: const Text('Cancel'),
             onPressed: () {
               Navigator.of(dialogContext).pop();
             },
           ),
         ],
       );
     },
   );
 }
}


// --- Reusable Custom painter for the hex border ---
class HexBorderPainter extends CustomPainter {
 final Color color;
 final double width;
 HexBorderPainter({this.color = Colors.yellowAccent, this.width = 3.0});


 @override
 void paint(Canvas canvas, Size size) {
   final path = Path();
   final double w = size.width;
   final double h = size.height;
   final double centerX = w / 2;


   // Pointy-top hex vertices
   path.moveTo(centerX, 0); // Top center
   path.lineTo(w, h * 0.25); // Top-right
   path.lineTo(w, h * 0.75); // Bottom-right
   path.lineTo(centerX, h); // Bottom center
   path.lineTo(0, h * 0.75); // Bottom-left
   path.lineTo(0, h * 0.25); // Top-left
   path.close();


   final paint = Paint()
     ..color = color
     ..strokeWidth = width
     ..style = PaintingStyle.stroke;


   canvas.drawPath(path, paint);
 }


 @override
 bool shouldRepaint(CustomPainter oldDelegate) => false;
}

