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
