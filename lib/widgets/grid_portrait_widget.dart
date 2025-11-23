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
    // Grid layout:
    // 0 1 2
    // 3 4 5
    // 6 7 8
    int row = gridIndex ~/ 3; // 0, 1, or 2
    int col = gridIndex % 3; // 0, 1, or 2

    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: 340,
          height: 340,
          child: ClipRect(
            child: Transform.translate(
              // Offset to show the correct cell
              // Each cell is 340x340, so offset by -340 * col horizontally and -340 * row vertically
              offset: Offset(-col * 340.0, -row * 340.0),
              child: Image.asset(
                imagePath,
                width: 1020.0, // Full grid width (3 * 340)
                height: 1020.0, // Full grid height (3 * 340)
                fit: BoxFit.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
