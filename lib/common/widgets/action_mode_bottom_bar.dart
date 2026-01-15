import 'package:flutter/material.dart';

/// A widget for displaying a bottom action bar in selection mode.
///
/// This widget is used to display actions for selected items,
/// such as share, delete, or save.
///
/// Example usage:
/// ```dart
/// ActionModeBottomBar(
///   selectedCount: selectedItems.length,
///   actions: [
///     ActionItem(
///       icon: Icons.delete,
///       label: 'Delete',
///       onPressed: deleteSelected,
///     ),
///     ActionItem(
///       icon: Icons.share,
///       label: 'Share',
///       onPressed: shareSelected,
///     ),
///   ],
/// )
/// ```
class ActionModeBottomBar extends StatelessWidget {
  /// The number of selected items.
  final int selectedCount;
  
  /// The actions to display.
  final List<ActionItem> actions;
  
  /// Whether to show labels for actions. Defaults to false.
  final bool showLabels;
  
  /// Whether the actions are disabled. Defaults to false.
  final bool isDisabled;
  
  /// Optional background color. Defaults to surface color with opacity.
  final Color? backgroundColor;

  const ActionModeBottomBar({
    Key? key,
    required this.selectedCount,
    required this.actions,
    this.showLabels = false,
    this.isDisabled = false,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? 
        Theme.of(context).colorScheme.surface.withOpacity(0.9);
    
    return Container(
      color: effectiveBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: SafeArea(
        child: Row(
          children: [
            if (selectedCount > 0) ...[
              Text(
                '$selectedCount selected',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
            ],
            ...actions.map((action) => showLabels
                ? _buildActionButtonWithLabel(context, action)
                : _buildActionButton(context, action)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, ActionItem action) {
    return IconButton(
      icon: Icon(action.icon, color: action.color),
      onPressed: isDisabled ? null : action.onPressed,
      tooltip: action.label,
    );
  }

  Widget _buildActionButtonWithLabel(BuildContext context, ActionItem action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(action.icon, color: action.color),
            onPressed: isDisabled ? null : action.onPressed,
          ),
          Text(
            action.label,
            style: TextStyle(
              color: action.color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A class representing an action item in the action bar.
class ActionItem {
  /// The icon to display.
  final IconData icon;
  
  /// The label for the action.
  final String label;
  
  /// The callback when the action is pressed.
  final VoidCallback onPressed;
  
  /// Optional color for the icon and label.
  final Color color;

  ActionItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = Colors.white,
  });
}

