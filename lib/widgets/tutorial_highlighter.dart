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
import '../services/tutorial_service.dart';

class TutorialHighlighter extends StatefulWidget {
  final String highlightKey;
  final Widget child;
  final BoxShape shape;
  final EdgeInsets padding;

  const TutorialHighlighter({
    super.key,
    required this.highlightKey,
    required this.child,
    this.shape = BoxShape.rectangle,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<TutorialHighlighter> createState() => _TutorialHighlighterState();
}

class _TutorialHighlighterState extends State<TutorialHighlighter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacityAnimation =
        Tween<double>(begin: 0.2, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TutorialService>(
      builder: (context, tutorial, child) {
        final isActive = tutorial.isActive &&
            tutorial.currentStep?.highlightKey == widget.highlightKey;

        if (!isActive) return widget.child;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing Glow
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _opacityAnimation,
                builder: (context, child) {
                  return Container(
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      shape: widget.shape,
                      borderRadius: widget.shape == BoxShape.rectangle
                          ? BorderRadius.circular(8)
                          : null,
                      border: Border.all(
                        color:
                            Colors.amber.withOpacity(_opacityAnimation.value),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber
                              .withOpacity(_opacityAnimation.value * 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}
