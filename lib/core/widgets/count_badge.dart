import 'package:flutter/material.dart';

/// شارة عدد حمراء (مفضلة، سلة، إلخ).
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.top = 6,
    this.right = 6,
  });

  final int count;
  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Positioned(
      right: right,
      top: top,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
