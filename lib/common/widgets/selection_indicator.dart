import 'package:flutter/material.dart';

/// A widget for displaying a selection indicator.
///
/// This widget is used to indicate that an item is selected,
/// typically in a grid or list view with selection mode.
///
/// Example usage:
/// ```dart
/// Stack(
///   children: [
///     Image.network(item.imageUrl),
///     if (isSelected)
///       const SelectionIndicator(),
///   ],
/// )
/// ```
class SelectionIndicator extends StatelessWidget {
  /// The position of the indicator. Defaults to top right.
  final AlignmentGeometry alignment;
  
  /// The size of the indicator. Defaults to 24.
  final double size;
  
  /// The icon to display. Defaults to Icons.check.
  final IconData icon;
  
  /// The color of the indicator. Defaults to primary color.
  final Color? color;
  
  /// The icon color. Defaults to white.
  final Color iconColor;

  const SelectionIndicator({
    Key? key,
    this.alignment = Alignment.topRight,
    this.size = 24,
    this.icon = Icons.check,
    this.color,
    this.iconColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: effectiveColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: size * 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

