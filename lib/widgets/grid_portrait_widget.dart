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

/// Displays a specific cell from a 3x3 grid image
/// Used for tutorial captain portraits (happy_captain.png / angry_captain.png)
class GridPortraitWidget extends StatelessWidget {
  final String imagePath;
  final int gridIndex; // 0-8 (row-major order)
  final double size;

  const GridPortraitWidget({
    super.key,
    required this.imagePath,
    required this.gridIndex,
    this.size = 340,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate which cell we want (0-8 in row-major order)
    int row = gridIndex ~/ 3; // 0, 1, or 2
    int col = gridIndex % 3; // 0, 1, or 2

    print(
        "[GRID PORTRAIT] Rendering: $imagePath, index: $gridIndex (row: $row, col: $col), size: $size");

    // Source cell size
    const double cellSize = 340.0;

    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: cellSize,
          height: cellSize,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: -col * cellSize,
                  top: -row * cellSize,
                  child: Image.asset(
                    imagePath,
                    width: cellSize * 3, // 1020
                    height: cellSize * 3, // 1020
                    fit: BoxFit.none,
                    alignment: Alignment.topLeft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
