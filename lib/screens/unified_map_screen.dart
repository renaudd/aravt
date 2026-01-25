// Copyright 2025 Google LLC
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../widgets/persistent_menu_widget.dart';
import 'area_screen.dart';
import 'region_screen.dart';
import 'world_map_screen.dart';

class UnifiedMapScreen extends StatefulWidget {
  const UnifiedMapScreen({super.key});

  @override
  State<UnifiedMapScreen> createState() => _UnifiedMapScreenState();
}

class _UnifiedMapScreenState extends State<UnifiedMapScreen> {
  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return Scaffold(
      body: Stack(
        children: [
          _buildActiveMap(gameState.lastMapLevel),

          // Custom Top Bar (Unified back button and Title)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top, bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getMapTitle(gameState),
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Level Selector Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: _buildLevelSelector(context, gameState),
          ),

          const PersistentMenuWidget(),
        ],
      ),
    );
  }

  Widget _buildActiveMap(MapLevel level) {
    switch (level) {
      case MapLevel.area:
        return const AreaMapView();
      case MapLevel.region:
        return const RegionMapView();
      case MapLevel.world:
        return const WorldMapView();
    }
  }

  String _getMapTitle(GameState state) {
    switch (state.lastMapLevel) {
      case MapLevel.area:
        return state.currentArea?.name ?? "Area Map";
      case MapLevel.region:
        return "Region Map";
      case MapLevel.world:
        return "World Map";
    }
  }

  Widget _buildLevelSelector(BuildContext context, GameState gameState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLevelButton(
            context, gameState, MapLevel.world, Icons.public, "World"),
        const SizedBox(height: 8),
        _buildLevelButton(context, gameState, MapLevel.region,
            Icons.travel_explore, "Region"),
        const SizedBox(height: 8),
        _buildLevelButton(
            context, gameState, MapLevel.area, Icons.map_outlined, "Area"),
      ],
    );
  }

  Widget _buildLevelButton(BuildContext context, GameState gameState,
      MapLevel level, IconData icon, String label) {
    final bool isActive = gameState.lastMapLevel == level;
    return GestureDetector(
      onTap: () => gameState.setMapLevel(level),
      child: Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.amber.withOpacity(0.9)
                : Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isActive ? Colors.amberAccent : Colors.white30,
                width: 1.5),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1)
                  ]
                : [],
          ),
          child: Icon(icon,
              color: isActive ? Colors.black : Colors.white70, size: 24),
        ),
      ),
    );
  }
}
