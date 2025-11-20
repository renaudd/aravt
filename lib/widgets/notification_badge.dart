import 'package:flutter/material.dart';

/// A red circular notification badge that displays a count
/// Positioned in the top-right corner of its parent widget
class NotificationBadge extends StatelessWidget {
  final int count;
  final double size;

  const NotificationBadge({
    super.key,
    required this.count,
    this.size = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        constraints: BoxConstraints(
          minWidth: size,
          minHeight: size,
        ),
        child: Center(
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
