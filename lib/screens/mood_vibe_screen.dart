import 'package:flutter/material.dart';
import 'mood_vibe/mood_vibe_screen.dart' as mood_vibe;
import '../common/models/media_item.dart';

// This file is a redirect to maintain backward compatibility
// with existing imports in the codebase

class MoodVibeScreen extends StatelessWidget {
  final String gifLink;
  final String imgLink;
  final List<dynamic>? homeItems;
  final int currentIndex;

  const MoodVibeScreen({
    Key? key,
    required this.gifLink,
    required this.imgLink,
    this.homeItems,
    this.currentIndex = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return mood_vibe.MoodVibeScreen(
      gifLink: gifLink,
      imgLink: imgLink,
      homeItems: homeItems?.cast<MediaItem>(),
      currentIndex: currentIndex,
    );
  }
}

