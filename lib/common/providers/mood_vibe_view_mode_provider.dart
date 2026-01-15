import 'package:flutter/foundation.dart';
import '../models/view_mode.dart';
import '../utils/shared_preferences_util.dart';

/// Provider for managing view mode state in the MoodVibe screen.
///
/// This class provides methods for getting and setting the current view mode,
/// with support for persistence using SharedPreferences.
class MoodVibeViewModeProvider with ChangeNotifier {
  ViewMode _currentViewMode = ViewMode.grid;
  static const String _viewModeKey = 'mood_vibe_view_mode';

  MoodVibeViewModeProvider() {
    loadViewMode();
  }

  /// Get the current view mode.
  ViewMode get currentViewMode => _currentViewMode;

  /// Load the view mode from SharedPreferences.
  void loadViewMode() {
    final savedMode = SharedPreferencesUtil.getInt(_viewModeKey);
    if (savedMode != null && savedMode >= 0 && savedMode < ViewMode.values.length) {
      _currentViewMode = ViewMode.values[savedMode];
    }
  }

  /// Set the view mode and save it to SharedPreferences.
  Future<void> setViewMode(ViewMode mode) async {
    if (_currentViewMode != mode) {
      _currentViewMode = mode;
      await SharedPreferencesUtil.setInt(_viewModeKey, mode.index);
      notifyListeners();
    }
  }

  /// Toggle to the next view mode in the sequence.
  Future<void> toggleNextViewMode() async {
    final values = ViewMode.values;
    final nextIndex = (_currentViewMode.index + 1) % values.length;
    await setViewMode(values[nextIndex]);
  }
}

