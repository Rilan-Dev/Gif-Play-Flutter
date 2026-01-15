import 'package:flutter/material.dart';

/// A mixin for managing selection state.
///
/// This mixin provides methods for managing selection state in a widget,
/// such as selecting and deselecting items, toggling selection mode, etc.
///
/// Example usage:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with SelectionStateMixin {
///   @override
///   Widget build(BuildContext context) {
///     return ListView.builder(
///       itemCount: items.length,
///       itemBuilder: (context, index) {
///         final isSelected = isItemSelected(index);
///         return ListTile(
///           title: Text(items[index].title),
///           selected: isSelected,
///           onTap: () => handleItemTap(index),
///           onLongPress: () => enableSelectionMode(index),
///         );
///       },
///     );
///   }
/// }
/// ```
mixin SelectionStateMixin<T extends StatefulWidget> on State<T> {
  /// Whether selection mode is enabled.
  bool _isSelectionMode = false;
  
  /// The set of selected item indices.
  final Set<int> _selectedItems = {};
  
  /// Whether selection mode is enabled.
  bool get isSelectionMode => _isSelectionMode;
  
  /// The set of selected item indices.
  Set<int> get selectedItems => Set.unmodifiable(_selectedItems);
  
  /// The number of selected items.
  int get selectedCount => _selectedItems.length;
  
  /// Whether an item is selected.
  bool isItemSelected(int index) => _selectedItems.contains(index);
  
  /// Enables selection mode and selects the given item.
  void enableSelectionMode(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedItems.add(index);
    });
  }
  
  /// Disables selection mode and clears selection.
  void disableSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }
  
  /// Toggles selection mode.
  void toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }
  
  /// Toggles selection of an item.
  void toggleItemSelection(int index) {
    setState(() {
      if (_selectedItems.contains(index)) {
        _selectedItems.remove(index);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(index);
      }
    });
  }
  
  /// Selects all items.
  void selectAllItems(int itemCount) {
    setState(() {
      _selectedItems.clear();
      _selectedItems.addAll(List<int>.generate(itemCount, (i) => i));
    });
  }
  
  /// Deselects all items.
  void deselectAllItems() {
    setState(() {
      _selectedItems.clear();
    });
  }
  
  /// Handles item tap based on selection mode.
  void handleItemTap(int index, VoidCallback onNormalTap) {
    if (_isSelectionMode) {
      toggleItemSelection(index);
    } else {
      onNormalTap();
    }
  }
}

