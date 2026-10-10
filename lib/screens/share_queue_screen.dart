import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/models/gif_item.dart';
import '../common/models/media_item.dart';
import '../common/providers/share_queue_provider.dart';
import '../common/providers/viewed_gifs_provider.dart';
import '../common/widgets/action_mode_bottom_bar.dart';
import '../common/widgets/empty_state.dart';
import '../common/widgets/media_view_switcher.dart';
import '../common/widgets/view_mode_selector.dart';
import '../common/utils/download_and_share.dart';
import 'gif_viewer_screen.dart';

class ShareQueueScreen extends StatefulWidget {
  const ShareQueueScreen({Key? key}) : super(key: key);

  @override
  State<ShareQueueScreen> createState() => _ShareQueueScreenState();
}

class _ShareQueueScreenState extends State<ShareQueueScreen> {
  final Set<int> _selectedItems = {};
  bool _isSelectionMode = false;
  bool _isProcessing = false;

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleItemSelection(int index) {
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

  List<MediaItem> _toMediaItems(List<GifItem> gifs) {
    return gifs
        .map(
          (gif) => MediaItem(
            imageUrl: gif.imageUrl ?? gif.url ?? '',
            title: gif.title,
            href: gif.url ?? gif.imageUrl,
            timestamp: gif.timestamp,
          ),
        )
        .toList();
  }

  Future<void> _shareGifs(
    ShareQueueProvider shareQueue,
    List<GifItem> gifsToShare,
  ) async {
    if (gifsToShare.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No GIFs to share')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final downloadAndShare = DownloadAndShare();
      await downloadAndShare.downloadAndShareGifs(context, gifsToShare, true);
      if (!mounted) return;

      final viewedProvider =
          Provider.of<ViewedGifsProvider>(context, listen: false);
      for (final gif in gifsToShare) {
        await viewedProvider.addViewedGif(gif);
      }

      shareQueue.removeGifs(gifsToShare);
      if (!mounted) return;

      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing GIFs: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _removeSelected(ShareQueueProvider shareQueue, List<GifItem> gifs) {
    if (_selectedItems.isEmpty) return;
    final gifsToRemove =
        _selectedItems.map((index) => gifs[index]).toList();
    shareQueue.removeGifs(gifsToRemove);
    setState(() {
      _selectedItems.clear();
      _isSelectionMode = false;
    });
  }

  void _clearAll(ShareQueueProvider shareQueue) {
    shareQueue.clear();
    setState(() {
      _selectedItems.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShareQueueProvider>(
      builder: (context, shareQueue, child) {
        final gifs = shareQueue.queuedGifs;
        final mediaItems = _toMediaItems(gifs);

        return Scaffold(
          appBar: AppBar(
            title: _isSelectionMode
                ? Text('${_selectedItems.length} selected')
                : const Text('Share Queue'),
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSelectionMode,
                    tooltip: 'Cancel selection',
                  )
                : null,
            actions: [
              if (!_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _isProcessing
                      ? null
                      : () => _shareGifs(shareQueue, gifs),
                  tooltip: 'Share all',
                ),
              if (!_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed:
                      _isProcessing ? null : () => _clearAll(shareQueue),
                  tooltip: 'Clear list',
                ),
              const ViewModeSelector(),
            ],
          ),
          body: gifs.isEmpty
              ? const EmptyState(
                  icon: Icons.share,
                  title: 'No GIFs collected',
                  message: 'Collect GIFs to share them later.',
                )
              : MediaViewSwitcher(
                  mediaItems: mediaItems,
                  onItemClick: (item, index) {
                    if (_isSelectionMode) {
                      _toggleItemSelection(index);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GifViewerScreen(
                          gifItems: gifs,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  onItemLongPress: (item, index) {
                    if (!_isSelectionMode) {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedItems.add(index);
                      });
                    } else {
                      _toggleItemSelection(index);
                    }
                  },
                  selectedItems: _selectedItems,
                  isSelectionMode: _isSelectionMode,
                ),
          bottomNavigationBar: _isSelectionMode
              ? ActionModeBottomBar(
                  selectedCount: _selectedItems.length,
                  actions: [
                    ActionItem(
                      icon: Icons.delete,
                      label: 'Remove',
                      onPressed: _isProcessing
                          ? () {}
                          : () => _removeSelected(shareQueue, gifs),
                    ),
                    ActionItem(
                      icon: Icons.share,
                      label: 'Share',
                      onPressed: _isProcessing
                          ? () {}
                          : () => _shareSelected(shareQueue, gifs),
                    ),
                  ],
                  isDisabled: _isProcessing,
                )
              : null,
        );
      },
    );
  }

  void _shareSelected(ShareQueueProvider shareQueue, List<GifItem> gifs) {
    final gifsToShare = _selectedItems.map((index) => gifs[index]).toList();
    _shareGifs(shareQueue, gifsToShare);
  }
}
