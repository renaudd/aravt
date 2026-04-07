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
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0.0;
  final List<String> _logs = [];
  final Random _random = Random();
  late Timer _timer;

  final List<String> _flavorTexts = [
    "Taming wild horses.",
    "Interpreting sheep bones.",
    "Consulting shamans.",
    "Sharpening saber blades.",
    "Calculating steppe wind speed.",
    "Drafting yurt blueprints.",
    "Bribing mountain pass guards.",
    "Distilling kumis.",
    "Calming nervous pack camels.",
    "Testing composite bow tension.",
    "Scouting the horizon.",
    "Naming new foals.",
    "Polishing iron scale armor.",
    "Stacking dried dung fuel.",
    "Braiding horsehair reins.",
    "Counting hidden arrows.",
    "Watching for signal smoke.",
  ];

  final List<String> _systemTexts = [
    "Initializing item database...",
    "Loading world map...",
    "Spawning AI agents...",
    "Preparing nomadic horde...",
    "Authenticating with the Khan...",
    "Caching environmental shaders...",
    "Seeding procedural terrain...",
    "Syncing tactical formations...",
  ];

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    const totalSteps = 10;
    int currentStep = 0;

    _timer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _progress = (currentStep + 1) / (totalSteps + 2);
        
        // Add a log
        if (currentStep % 2 == 0 && _systemTexts.isNotEmpty) {
          _logs.add(_systemTexts.removeAt(0));
        } else if (_flavorTexts.isNotEmpty) {
          _logs.add(_flavorTexts.removeAt(_random.nextInt(_flavorTexts.length)));
        }

        if (_logs.length > 5) {
          _logs.removeAt(0);
        }

        currentStep++;

        if (currentStep >= totalSteps) {
          _progress = 1.0;
          timer.cancel();
          // Short delay then navigate
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/mainMenu');
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/loading_screen.jpg',
              fit: BoxFit.cover,
            ),
          ),
          
          // Dark overlay for legibility
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),

          // Bottom Content
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logs
                  SizedBox(
                    height: 120, // Enough for ~4-5 lines
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _logs.map((log) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            color: Colors.white70,
                            fontSize: 14,
                            shadows: [
                              const Shadow(
                                blurRadius: 4.0,
                                color: Colors.black,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 12,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEADBBE)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Percentage text (optional but helps feel alive)
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFEADBBE),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
