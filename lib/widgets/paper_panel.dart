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
import 'package:flutter/material.dart';

class PaperPanel extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double irregularity;
  final double elevation;
  final EdgeInsets padding;
  final double? width;
  final double? height;

  const PaperPanel({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFFF2ECD8),
    this.borderColor = const Color(0xFFA68B5B),
    this.borderWidth = 1.5,
    this.irregularity = 4.0,
    this.elevation = 4.0,
    this.padding = const EdgeInsets.all(16.0),
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _PaperPainter(
          color: backgroundColor,
          borderColor: borderColor,
          borderWidth: borderWidth,
          irregularity: irregularity,
          elevation: elevation,
        ),
        child: ClipPath(
          clipper: _PaperClipper(irregularity: irregularity),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PaperClipper extends CustomClipper<Path> {
  final double irregularity;

  _PaperClipper({required this.irregularity});

  @override
  Path getClip(Size size) {
    return _generatePaperPath(size, irregularity);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class _PaperPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double irregularity;
  final double elevation;

  _PaperPainter({
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    required this.irregularity,
    required this.elevation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _generatePaperPath(size, irregularity);

    // Draw shadow
    if (elevation > 0) {
      canvas.drawShadow(path, Colors.black, elevation, true);
    }

    // Draw background
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Draw border
    if (borderWidth > 0) {
      final borderPaint = Paint()
        ..color = borderColor.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Path _generatePaperPath(Size size, double irregularity) {
  final path = Path();
  final random = Random(42); // Seeded for consistency

  const int segmentsPerSide = 20;

  // Top edge
  path.moveTo(0, 0);
  for (int i = 1; i <= segmentsPerSide; i++) {
    double x = (size.width / segmentsPerSide) * i;
    double y = (random.nextDouble() - 0.5) * irregularity;
    path.lineTo(x, y);
  }

  // Right edge
  for (int i = 1; i <= segmentsPerSide; i++) {
    double y = (size.height / segmentsPerSide) * i;
    double x = size.width + (random.nextDouble() - 0.5) * irregularity;
    path.lineTo(x, y);
  }

  // Bottom edge
  for (int i = 1; i <= segmentsPerSide; i++) {
    double x = size.width - (size.width / segmentsPerSide) * i;
    double y = size.height + (random.nextDouble() - 0.5) * irregularity;
    path.lineTo(x, y);
  }

  // Left edge
  for (int i = 1; i <= segmentsPerSide; i++) {
    double y = size.height - (size.height / segmentsPerSide) * i;
    double x = (random.nextDouble() - 0.5) * irregularity;
    path.lineTo(x, y);
  }

  path.close();
  return path;
}
