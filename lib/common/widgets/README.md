# Reusable Widgets

This directory contains reusable UI components that can be used across the application.

## Available Widgets

- `shimmer_loading.dart`: Loading placeholder with shimmer effect
- `cached_gif.dart`: Widget for displaying cached GIFs with loading states
- `selection_indicator.dart`: Visual indicator for selected items
- `media_view_switcher.dart`: Switches between different media view modes
- `action_mode_bottom_bar.dart`: Bottom action bar for selection mode
- `empty_state.dart`: Displays empty state with icon and message
- `error_state.dart`: Displays error state with retry option

## Usage Example

```dart
import 'package:flutter_gif_play/common/widgets/shimmer_loading.dart';

// In your widget build method
return ShimmerLoading(
  height: 200,
  width: double.infinity,
  borderRadius: 8.0,
);

