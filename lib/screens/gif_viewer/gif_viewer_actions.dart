import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/models/gif_item.dart';
import '../../common/providers/liked_gifs_provider.dart';
import '../../common/utils/download_and_share.dart';

/// Class for handling actions in the GIF viewer screen
class GifViewerActions {
  /// Toggles like status for a GIF
  static void toggleLike(BuildContext context, int index, List<GifItem> gifItems) {
    final likedProvider = Provider.of<LikedGifsProvider>(context, listen: false);
    final gif = gifItems[index];
    likedProvider.toggleLikedGif(gif);
    
    // Show feedback
    final isNowLiked = likedProvider.isGifLiked(gif.id ?? '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isNowLiked ? 'Added to favorites' : 'Removed from favorites'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shares selected GIFs
  static Future<void> shareSelectedGifs({
    required BuildContext context,
    required List<GifItem> gifItems,
    required int currentPage,
    required Set<int> selectedItems,
    required Function disableSelectionMode,
    required Function(bool) setProcessing,
  }) async {
    setProcessing(true);
    
    try {
      final List<GifItem> gifsToShare;
      
      if (selectedItems.isEmpty) {
        // If no items are explicitly selected, share the current item
        gifsToShare = [gifItems[currentPage]];
      } else {
        // Otherwise, share all selected items
        gifsToShare = selectedItems.map((index) => gifItems[index]).toList();
      }
      
      // Show a loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing GIFs for sharing...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      final downloadAndShare = DownloadAndShare();
      await downloadAndShare.downloadAndShareGifs(
        context, 
        gifsToShare, 
        true
      );
      
      // Exit selection mode after sharing
      if (selectedItems.isNotEmpty) {
        disableSelectionMode();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing GIFs: $e')),
        );
      }
    } finally {
      setProcessing(false);
    }
  }

  /// Saves selected GIFs
  static Future<void> saveSelectedGifs({
    required BuildContext context,
    required List<GifItem> gifItems,
    required int currentPage,
    required Set<int> selectedItems,
    required Function disableSelectionMode,
    required Function(bool) setProcessing,
  }) async {
    setProcessing(true);
    
    try {
      final List<GifItem> gifsToSave;
      
      if (selectedItems.isEmpty) {
        // If no items are explicitly selected, save the current item
        gifsToSave = [gifItems[currentPage]];
      } else {
        // Otherwise, save all selected items
        gifsToSave = selectedItems.map((index) => gifItems[index]).toList();
      }
      
      // Show a loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving GIFs...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      final downloadAndShare = DownloadAndShare();
      await downloadAndShare.downloadAndShareGifs(
        context, 
        gifsToSave, 
        false
      );
      
      // Exit selection mode after saving
      if (selectedItems.isNotEmpty) {
        disableSelectionMode();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving GIFs: $e')),
        );
      }
    } finally {
      setProcessing(false);
    }
  }

  /// Builds a quick action button
  static Widget buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.white,
    bool isDisabled = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: isDisabled ? null : onPressed,
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

