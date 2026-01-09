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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aravt/providers/game_state.dart';
import 'package:aravt/models/history_models.dart';

import 'dart:math' as math;

class TimelinesScreen extends StatefulWidget {
  const TimelinesScreen({Key? key}) : super(key: key);

  @override
  State<TimelinesScreen> createState() => _TimelinesScreenState();
}

enum TimelineLevel { horde, aravt, soldier }

class _TimelinesScreenState extends State<TimelinesScreen> {
  TimelineLevel _currentLevel = TimelineLevel.horde;
  String? _selectedEntityId; // If null, show all at current level
  MetricCategory? _selectedCategory; // Null = Show All (Overview Mode)
  MetricType? _focusedMetric; // The specific thread currently selected/hovered

  // Graph State
  double _zoomLevel = 1.0;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final history = gameState.history;

    // Safety check: Needs history to render
    if (history.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: Center(
          child: Text(
            "No historical data yet.\nAdvance a turn to begin tracking.",
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Stack(
        children: [
          // MAIN GRAPH
          Positioned.fill(
            child: GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  _zoomLevel = (_zoomLevel * details.scale).clamp(0.5, 4.0);
                  // Basic scrolling via horizontal drag handled here if needed,
                  // or use SingleChildScrollView wrapping the Painter
                });
              },
              onTapUp: (details) {
                // Handle tap to select metric
                _handleTap(details.localPosition, history, context);
              },
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * _zoomLevel,
                  height: MediaQuery.of(context).size.height,
                  child: CustomPaint(
                    painter: TimelineGraphPainter(
                      history: history,
                      gameState: gameState,
                      category: _selectedCategory,
                      level: _currentLevel,
                      selectedEntityId: _selectedEntityId,
                      zoom: _zoomLevel,
                      focusedMetric: _focusedMetric,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // OVERLAYS
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar: Level & Category Navigation
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black.withOpacity(0.8),
                  child: Column(
                    children: [
                      // Breadcrumb / Level Selector
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          _buildLevelSelector(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Categories
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // "ALL" Option
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(
                                  "ALL",
                                  style: GoogleFonts.cinzel(
                                    fontSize: 12,
                                    color: _selectedCategory == null
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: _selectedCategory == null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                selected: _selectedCategory == null,
                                onSelected: (_) => setState(() {
                                  _selectedCategory = null;
                                  _focusedMetric =
                                      null; // Clear focus on category change
                                }),
                                backgroundColor: Colors.black54,
                                selectedColor: Colors.white,
                                checkmarkColor: Colors.black,
                                side: const BorderSide(
                                    color: Colors.white, width: 1),
                              ),
                            ),
                            ...MetricCategory.values.map((cat) {
                              final isSelected = cat == _selectedCategory;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text(
                                    cat.label,
                                    style: GoogleFonts.cinzel(
                                      fontSize: 12,
                                      color:
                                          isSelected ? Colors.black : cat.color,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() {
                                    _selectedCategory = cat;
                                    _focusedMetric = null; // Clear focus
                                  }),
                                  backgroundColor: Colors.black54,
                                  selectedColor: cat.color,
                                  checkmarkColor: Colors.black,
                                  side: BorderSide(color: cat.color, width: 1),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom Tooltip Area
                if (_focusedMetric != null)
                  _buildFocusedMetricOverlay(history, gameState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector() {
    return Row(
      children: [
        InkWell(
          onTap: () => setState(() {
            _currentLevel = TimelineLevel.horde;
            _selectedEntityId = null;
            _focusedMetric = null;
          }),
          child: Text(
            "HORDE",
            style: GoogleFonts.cinzel(
              color: _currentLevel == TimelineLevel.horde
                  ? Colors.white
                  : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        if (_currentLevel != TimelineLevel.horde) ...[
          Text(" > ", style: GoogleFonts.cinzel(color: Colors.white54)),
          DropdownButton<String>(
            dropdownColor: Colors.grey[900],
            value: _currentLevel == TimelineLevel.aravt &&
                    _selectedEntityId != null &&
                    _selectedEntityId!.startsWith("aravt")
                ? _selectedEntityId
                : null,
            hint: Text("Select Aravt",
                style: GoogleFonts.cinzel(color: Colors.white70)),
            items: context.read<GameState>().aravts.map((a) {
              return DropdownMenuItem(
                value: a.id,
                child: Text("Aravt ${a.id}",
                    style: GoogleFonts.cinzel(color: Colors.white)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _currentLevel = TimelineLevel.aravt;
                  _selectedEntityId = val;
                  _focusedMetric = null;
                });
              }
            },
          ),
        ],
        // TODO: Drill down to Soldier logic
      ],
    );
  }

  void _handleTap(
      Offset localPosition, List<DailySnapshot> history, BuildContext context) {
    // Simple hit test: Find metric closest to Y at the tapped X
    final marginLeft = 50.0;
    final marginBottom = 40.0;
    final size = MediaQuery.of(context).size;
    final graphWidth = (size.width * _zoomLevel) - marginLeft - 20;
    final graphHeight = size.height - marginBottom - 60;
    final xStep = graphWidth / math.max(history.length, 30);

    // Find Index from X
    int index = ((localPosition.dx - marginLeft) / xStep).round();
    if (index < 0 || index >= history.length) return;

    final snap = history[index];

    double minDiff = 50.0; // Hit radius
    MetricType? found;

    final categoriesToPlot = _selectedCategory == null
        ? MetricCategory.values
        : [_selectedCategory!];

    // Recalculate Max Values locally for hit testing (could be optimized)
    final Map<MetricType, double> maxValues = {};
    for (var cat in categoriesToPlot) {
      final types = MetricType.values.where((m) => m.category == cat);
      for (var type in types) {
        double maxVal = 0.0;
        for (var s in history) {
          for (var e in s.entities) {
            if (_currentLevel == TimelineLevel.horde && e.entityId != 'horde')
              continue;
            if (_currentLevel == TimelineLevel.aravt &&
                _selectedEntityId != null &&
                e.entityId != _selectedEntityId) continue;

            final val = e.metrics[type]?.perceivedMax ?? 0;
            if (val > maxVal) maxVal = val;
          }
        }
        if (maxVal == 0) {
          if (cat == MetricCategory.fear ||
              cat == MetricCategory.loyalty ||
              cat == MetricCategory.stats)
            maxVal = 10.0;
          else
            maxVal = 100.0;
        } else {
          maxVal *= 1.1; // Padding
        }
        maxValues[type] = maxVal;
      }
    }

    for (var cat in categoriesToPlot) {
      final types = MetricType.values.where((m) => m.category == cat);
      for (var type in types) {
        MetricValue? val;
        // Get value at this index/entity
        final e = snap.entities.firstWhere((e) {
          if (_currentLevel == TimelineLevel.horde)
            return e.entityId == 'horde';
          if (_selectedEntityId != null) return e.entityId == _selectedEntityId;
          return false;
        }, orElse: () => EntitySnapshot(entityId: 'none', metrics: {}));
        val = e.metrics[type];

        if (val != null) {
          final maxVal = maxValues[type]!;
          final yVal = context.read<GameState>().isOmniscientMode
              ? val.trueValue
              : val.perceivedValue;
          final y =
              (size.height - marginBottom) - ((yVal / maxVal) * graphHeight);

          final diff = (y - localPosition.dy).abs();
          if (diff < minDiff) {
            minDiff = diff;
            found = type;
          }
        }
      }
    }

    if (found != null && found != _focusedMetric) {
      setState(() {
        _focusedMetric = found;
      });
    }
  }

  Widget _buildFocusedMetricOverlay(
      List<DailySnapshot> history, GameState gameState) {
    if (history.isEmpty || _focusedMetric == null) return const SizedBox();
    final snap = history.last;

    MetricValue? val;
    final e = snap.entities.firstWhere((e) {
      if (_currentLevel == TimelineLevel.horde) return e.entityId == 'horde';
      if (_selectedEntityId != null) return e.entityId == _selectedEntityId;
      return false;
    }, orElse: () => EntitySnapshot(entityId: 'none', metrics: {}));
    val = e.metrics[_focusedMetric];

    if (val == null) return const SizedBox();

    final displayVal =
        gameState.isOmniscientMode ? val.trueValue : val.perceivedValue;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        border: Border.all(color: _focusedMetric!.category.color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_focusedMetric!.name.toUpperCase(),
              style: GoogleFonts.cinzel(
                  color: _focusedMetric!.category.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text("Current: ",
                  style: GoogleFonts.cinzel(color: Colors.white70)),
              Text(displayVal.toStringAsFixed(1),
                  style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          Text("Scale: Independent (Normalized)",
              style: GoogleFonts.cinzel(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class TimelineGraphPainter extends CustomPainter {
  final List<DailySnapshot> history;
  final GameState gameState;
  final MetricCategory? category;
  final TimelineLevel level;
  final String? selectedEntityId;
  final double zoom;
  final MetricType? focusedMetric;

  TimelineGraphPainter({
    required this.history,
    required this.gameState,
    required this.category,
    required this.level,
    required this.selectedEntityId,
    required this.zoom,
    this.focusedMetric,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final Paint axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    final Paint gridPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke;

    final double marginLeft = 50.0;
    final double marginBottom = 40.0;
    final double graphWidth = size.width - marginLeft - 20;
    final double graphHeight = size.height - marginBottom - 60;

    // 1. Draw Axes
    canvas.drawLine(Offset(marginLeft, 10),
        Offset(marginLeft, size.height - marginBottom), axisPaint); // Y-Axis
    canvas.drawLine(Offset(marginLeft, size.height - marginBottom),
        Offset(size.width, size.height - marginBottom), axisPaint); // X-Axis

    // 2. Identify Metrics to Plot
    final List<MetricCategory> categoriesToPlot =
        category == null ? MetricCategory.values : [category!];

    // 3. Determine Scales (Independently per Metric Type)
    final Map<MetricType, double> maxValues = {};

    for (var cat in categoriesToPlot) {
      final metricTypes = MetricType.values.where((m) => m.category == cat);

      for (var type in metricTypes) {
        double maxVal = 0.0;
        for (var snap in history) {
          for (var entity in snap.entities) {
            if (level == TimelineLevel.horde && entity.entityId != 'horde')
              continue;
            if (level == TimelineLevel.aravt &&
                selectedEntityId != null &&
                entity.entityId != selectedEntityId) continue;

            final val = entity.metrics[type]?.perceivedMax ?? 0;
            if (val > maxVal) maxVal = val;
          }
        }
        if (maxVal == 0) {
          if (cat == MetricCategory.fear ||
              cat == MetricCategory.loyalty ||
              cat == MetricCategory.stats)
            maxVal = 10.0;
          else
            maxVal = 100.0;
        } else {
          maxVal *= 1.1; // 10% Padding
        }
        maxValues[type] = maxVal;
      }
    }

    // 4. Draw Grid Lines
    // Basic 0-100% lines since multiple scales coexist
    for (int i = 0; i <= 5; i++) {
      double y = (size.height - marginBottom) - (i / 5) * graphHeight;
      canvas.drawLine(Offset(marginLeft, y), Offset(size.width, y), gridPaint);
    }

    // 5. Draw Data Lines
    final double xStep =
        graphWidth / math.max(history.length, 30); // Min 30 days width

    for (var cat in categoriesToPlot) {
      final metricTypes = MetricType.values.where((m) => m.category == cat);

      for (var type in metricTypes) {
        final double maxVal = maxValues[type]!;

        // Dim others if one is focused, unless this is the focused one
        bool isFocused = (focusedMetric == type);
        bool anyFocused = focusedMetric != null;

        Color baseColor = cat.color;
        double strokeWidth = 2.0;
        double opacity = 0.8;

        if (anyFocused) {
          if (isFocused) {
            strokeWidth = 4.0;
            opacity = 1.0;
          } else {
            strokeWidth = 1.0;
            opacity = 0.2; // Fade out others
          }
        } else if (category == null) {
          // Overview mode, regular lines
          strokeWidth = 1.5;
        }

        final Path path = Path();
        bool isFirst = true;

        Offset? lastPoint;

        for (int i = 0; i < history.length; i++) {
          final snap = history[i];
          final x = marginLeft + (i * xStep);

          MetricValue? val;
          if (level == TimelineLevel.horde) {
            final e = snap.entities.firstWhere((e) => e.entityId == 'horde',
                orElse: () => EntitySnapshot(entityId: 'none', metrics: {}));
            val = e.metrics[type];
          } else if (level == TimelineLevel.aravt && selectedEntityId != null) {
            final e = snap.entities.firstWhere(
                (e) => e.entityId == selectedEntityId,
                orElse: () => EntitySnapshot(entityId: 'none', metrics: {}));
            val = e.metrics[type];
          }

          if (val != null) {
            double yVal =
                gameState.isOmniscientMode ? val.trueValue : val.perceivedValue;
            double y =
                (size.height - marginBottom) - ((yVal / maxVal) * graphHeight);

            lastPoint = Offset(x, y);

            if (isFirst) {
              path.moveTo(x, y);
              isFirst = false;
            } else {
              path.lineTo(x, y);
            }
          }
        }

        canvas.drawPath(
            path,
            Paint()
              ..color = baseColor.withOpacity(opacity)
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth);

        // Draw Vertical Scale Indicator for Present Value (Last Point)
        if (lastPoint != null) {
          // Only draw scale indicator if focused or if viewing specific category (to reduce clutter in overview)
          if (isFocused || (category != null && !anyFocused)) {
            final indicatorPaint = Paint()
              ..color = baseColor.withOpacity(isFocused ? 0.8 : 0.5)
              ..strokeWidth = 1.0;

            // Vertical line
            canvas.drawLine(Offset(lastPoint.dx, size.height - marginBottom),
                lastPoint, indicatorPaint);

            // Notches
            double tickSpacing = graphHeight / 5; // Fixed 5 ticks for now
            for (int t = 1; t <= 5; t++) {
              double ty = (size.height - marginBottom) - (t * tickSpacing);
              // Only draw if below the point
              if (ty >= lastPoint.dy) {
                canvas.drawLine(Offset(lastPoint.dx - 3, ty),
                    Offset(lastPoint.dx + 3, ty), indicatorPaint);
              }
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TimelineGraphPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.zoom != zoom ||
        oldDelegate.category != category ||
        oldDelegate.selectedEntityId != selectedEntityId ||
        oldDelegate.focusedMetric != focusedMetric;
  }
}
