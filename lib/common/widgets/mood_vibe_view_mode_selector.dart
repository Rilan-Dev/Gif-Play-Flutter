import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/view_mode.dart';
import '../providers/mood_vibe_view_mode_provider.dart';

/// A widget for selecting the view mode in the MoodVibe screen.
///
/// This widget displays a popup menu for selecting the view mode,
/// with support for different view modes like grid, list, card, and masonry.
class MoodVibeViewModeSelector extends StatelessWidget {
  const MoodVibeViewModeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MoodVibeViewModeProvider>(
      builder: (context, provider, child) {
        if (provider == null) {
          return const Icon(Icons.grid_view); // Default icon if provider is null
        }
        
        return PopupMenuButton<ViewMode>(
          icon: Icon(provider.currentViewMode.icon),
          tooltip: 'Change view mode',
          onSelected: (ViewMode mode) {
            provider.setViewMode(mode);
          },
          itemBuilder: (BuildContext context) {
            return ViewMode.values.map((ViewMode mode) {
              return PopupMenuItem<ViewMode>(
                value: mode,
                child: Row(
                  children: [
                    Icon(
                      mode.icon,
                      color: provider.currentViewMode == mode
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      mode.name,
                      style: TextStyle(
                        fontWeight: provider.currentViewMode == mode
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: provider.currentViewMode == mode
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }
}

