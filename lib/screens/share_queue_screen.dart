import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/models/gif_item.dart';
import '../common/models/media_item.dart';
import '../common/providers/share_queue_provider.dart';
import '../common/widgets/action_mode_bottom_bar.dart';
import '../common/widgets/empty_state.dart';
import '../common/widgets/media_view_switcher.dart';
import '../common/widgets/view_mode_selector.dart';
import '../common/utils/download_and_share.dart';
import 'gif_viewer/gif_viewer_screen.dart';

/// Full-screen management for GIFs collected for a later batch share.
///
/// The queue remains staged after invoking the platform share sheet because
/// dismissing that sheet does not reliably indicate that sharing completed.
class ShareQueueScreen extends StatefulWidget {
  const ShareQueueScreen({Key? key}) : super(key: key);

  @override
  State<ShareQueueScreen> createState() => _ShareQueueScreenState();
}

class _ShareQueueScreenState extends State<ShareQueueScreen> {
  final Set<String> _selectedKeys = <String>{};
  bool _selectionMode = false;
  bool _sharing = false;

  Set<int> _selectedIndices(ShareQueueProvider queue, List<GifItem> gifs) {
    return <int>{
      for (var index = 0; index < gifs.length; index++)
        if (_selectedKeys.contains(queue.keyFor(gifs[index]))) index,
    };
  }

  void _toggleSelection(ShareQueueProvider queue, GifItem gif) {
    final key = queue.keyFor(gif);
    setState(() {
      if (!_selectedKeys.add(key)) _selectedKeys.remove(key);
      if (_selectedKeys.isEmpty) _selectionMode = false;
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedKeys.clear();
    });
  }

  Future<void> _share(ShareQueueProvider queue, List<GifItem> gifs) async {
    final selected = _selectionMode
        ? gifs.where((gif) => _selectedKeys.contains(queue.keyFor(gif))).toList()
        : List<GifItem>.of(gifs);

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one GIF to share')),
      );
      return;
    }

    setState(() => _sharing = true);
    try {
      final shared = await DownloadAndShare().downloadAndShareGifs(
        context,
        selected,
        true,
      );
      if (!mounted || !shared) return;
      // Keep the queue intact: dismissing the native share sheet does not
      // prove the share succeeded, so automatic removal could lose GIFs.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Prepared ${selected.length} GIF${selected.length == 1 ? '' : 's'}. '
            'The queue has been kept.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share GIFs: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _removeSelected(ShareQueueProvider queue, List<GifItem> gifs) {
    final selected = gifs
        .where((gif) => _selectedKeys.contains(queue.keyFor(gif)))
        .toList(growable: false);
    if (selected.isEmpty) return;
    queue.removeGifs(selected);
    _cancelSelection();
  }

  List<MediaItem> _toMediaItems(List<GifItem> gifs) {
    return gifs
        .map((gif) => MediaItem(
              imageUrl: gif.imageUrl ?? gif.url ?? '',
              title: gif.title,
              href: gif.url ?? gif.imageUrl,
              timestamp: gif.timestamp,
            ))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShareQueueProvider>(
      builder: (context, queue, _) {
        final gifs = queue.queuedGifs;
        final mediaItems = _toMediaItems(gifs);
        final selectedIndices = _selectedIndices(queue, gifs);

        return Scaffold(
          appBar: AppBar(
            title: Text(_selectionMode
                ? '${selectedIndices.length} selected'
                : 'Share Queue (${gifs.length})'),
            leading: _selectionMode
                ? IconButton(
                    tooltip: 'Cancel selection',
                    icon: const Icon(Icons.close),
                    onPressed: _sharing ? null : _cancelSelection,
                  )
                : null,
            actions: [
              const ViewModeSelector(),
              IconButton(
                tooltip: _selectionMode ? 'Share selected' : 'Share all',
                icon: const Icon(Icons.share),
                onPressed: _sharing || gifs.isEmpty ? null : () => _share(queue, gifs),
              ),
              IconButton(
                tooltip: 'Clear queue',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: _sharing || gifs.isEmpty
                    ? null
                    : () {
                        queue.clear();
                        _cancelSelection();
                      },
              ),
            ],
          ),
          body: gifs.isEmpty
              ? const EmptyState(
                  icon: Icons.share,
                  title: 'No GIFs collected',
                  message: 'Collect GIFs from the feed or GIF viewer to share them later.',
                )
              : MediaViewSwitcher(
                  mediaItems: mediaItems,
                  selectedItems: selectedIndices,
                  isSelectionMode: _selectionMode,
                  onItemClick: (item, index) {
                    if (_selectionMode) {
                      _toggleSelection(queue, gifs[index]);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => GifViewerScreen(
                          gifItems: gifs,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  onItemLongPress: (item, index) {
                    if (_sharing) return;
                    final gif = gifs[index];
                    if (!_selectionMode) {
                      setState(() {
                        _selectionMode = true;
                        _selectedKeys.add(queue.keyFor(gif));
                      });
                    } else {
                      _toggleSelection(queue, gif);
                    }
                  },
                ),
          bottomNavigationBar: _selectionMode
              ? ActionModeBottomBar(
                  selectedCount: selectedIndices.length,
                  showLabels: true,
                  isDisabled: _sharing,
                  actions: [
                    ActionItem(
                      icon: Icons.delete_outline,
                      label: 'Remove',
                      color: Theme.of(context).colorScheme.onSurface,
                      onPressed: () => _removeSelected(queue, gifs),
                    ),
                    ActionItem(
                      icon: Icons.share,
                      label: 'Share',
                      color: Theme.of(context).colorScheme.onSurface,
                      onPressed: () => _share(queue, gifs),
                    ),
                  ],
                )
              : null,
          floatingActionButton: gifs.isEmpty
              ? null
              : FloatingActionButton.small(
                  tooltip: _selectionMode ? 'Cancel selection' : 'Select GIFs',
                  onPressed: _sharing
                      ? null
                      : () {
                          if (_selectionMode) {
                            _cancelSelection();
                          } else {
                            setState(() => _selectionMode = true);
                          }
                        },
                  child: Icon(_selectionMode ? Icons.close : Icons.checklist),
                ),
        );
      },
    );
  }
}
