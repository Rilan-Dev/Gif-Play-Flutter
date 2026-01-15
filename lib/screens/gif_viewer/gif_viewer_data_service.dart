import 'package:flutter/material.dart';
import 'dart:io';

import '../../common/models/gif_item.dart';

/// Service class for handling data operations in the GIF viewer screen
class GifViewerDataService {
  /// Builds the GIF content widget
  static Widget buildGifContent(GifItem gifItem, int index) {
    final isLocalFile = gifItem.url != null && gifItem.url!.startsWith('/');
    
    return Hero(
      tag: isLocalFile ? 'saved_gif_${gifItem.id}' : 'gif_${gifItem.id}',
      child: isLocalFile
          ? Image.file(
              File(gifItem.url!),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error,
                        color: Theme.of(context).colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load GIF',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            )
          : Image.network(
              gifItem.url ?? gifItem.imageUrl ?? '',
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error,
                      color: Theme.of(context).colorScheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load GIF',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

