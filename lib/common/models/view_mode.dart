import 'package:flutter/material.dart';

/// Enum representing different view modes for displaying media.
enum ViewMode {
  grid,
  list,
  card,
  masonry
}

/// Extension on ViewMode to provide additional properties and methods.
extension ViewModeExtension on ViewMode {
  /// Get the display name of the view mode.
  String get name {
    switch (this) {
      case ViewMode.grid:
        return 'Grid';
      case ViewMode.list:
        return 'List';
      case ViewMode.card:
        return 'Card';
      case ViewMode.masonry:
        return 'Masonry';
    }
  }

  /// Get the icon for the view mode.
  IconData get icon {
    switch (this) {
      case ViewMode.grid:
        return Icons.grid_view;
      case ViewMode.list:
        return Icons.view_list;
      case ViewMode.card:
        return Icons.view_module;
      case ViewMode.masonry:
        return Icons.dashboard;
    }
  }
}

