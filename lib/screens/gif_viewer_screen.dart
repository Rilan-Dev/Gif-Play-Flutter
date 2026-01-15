import 'package:flutter/material.dart';
import 'gif_viewer/gif_viewer_screen.dart' as gif_viewer;
import '../common/models/gif_item.dart';
import '../common/models/media_item.dart';

// This file is a redirect to maintain backward compatibility
class GifViewerScreen extends StatelessWidget {
  final List<GifItem> gifItems;
  final int initialIndex;
  final List<dynamic>? homeItems;
  final int homeCurrentIndex;

  const GifViewerScreen({
    Key? key,
    required this.gifItems,
    required this.initialIndex,
    this.homeItems,
    this.homeCurrentIndex = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return gif_viewer.GifViewerScreen(
      gifItems: gifItems,
      initialIndex: initialIndex,
      homeItems: homeItems?.cast<MediaItem>(),
      homeCurrentIndex: homeCurrentIndex,
    );
  }
}

