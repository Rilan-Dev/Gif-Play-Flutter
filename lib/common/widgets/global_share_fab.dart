import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gif_item.dart';
import '../providers/share_queue_provider.dart';
import '../utils/download_and_share.dart';
import '../../screens/share_queue_screen.dart';

class GlobalShareFab extends StatelessWidget {
  final bool mini;
  final String heroTag;

  const GlobalShareFab({
    Key? key,
    this.mini = true,
    this.heroTag = 'global_share_fab',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ShareQueueProvider>(
      builder: (context, shareQueue, child) {
        return FloatingActionButton(
          heroTag: heroTag,
          mini: mini,
          onPressed: () => _openSheet(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Align(
                alignment: Alignment.center,
                child: Icon(Icons.share),
              ),
              if (shareQueue.count > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${shareQueue.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _GlobalShareSheet(),
    );
  }
}

class _GlobalShareSheet extends StatefulWidget {
  const _GlobalShareSheet();

  @override
  State<_GlobalShareSheet> createState() => _GlobalShareSheetState();
}

class _GlobalShareSheetState extends State<_GlobalShareSheet> {
  final Set<String> _selectedKeys = {};
  bool _selectionMode = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final shareQueue = context.watch<ShareQueueProvider>();
    final items = shareQueue.queuedGifs;

    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, shareQueue.count),
            const Divider(),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No GIFs collected yet.'),
              )
            else
              SizedBox(
                height: maxHeight,
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final gif = items[index];
                    final key = shareQueue.keyFor(gif);
                    final isSelected = _selectedKeys.contains(key);
                    return ListTile(
                      leading: _buildThumbnail(gif),
                      title: Text(
                        gif.title.isNotEmpty ? gif.title : 'Untitled GIF',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        gif.url ?? gif.imageUrl ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: _selectionMode
                          ? () => _toggleSelected(key)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectionMode)
                            Checkbox(
                              value: isSelected,
                              onChanged: _isProcessing
                                  ? null
                                  : (_) => _toggleSelected(key),
                            ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _isProcessing
                                ? null
                                : () => _removeItem(shareQueue, gif, key),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildActions(context, shareQueue, items),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Row(
      children: [
        Text(
          'Share Queue',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Spacer(),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: _isProcessing ? null : () => _openFullView(context),
          tooltip: 'Open full view',
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    ShareQueueProvider shareQueue,
    List<GifItem> items,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            icon: Icon(
              _selectionMode
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            label: Text(_selectionMode ? 'Cancel Select' : 'Select'),
            onPressed: _isProcessing
                ? null
                : () {
                    setState(() {
                      if (_selectionMode) {
                        _selectedKeys.clear();
                      }
                      _selectionMode = !_selectionMode;
                    });
                  },
          ),
        ),
        Expanded(
          child: TextButton.icon(
            icon: const Icon(Icons.share),
            label: Text(_selectionMode ? 'Share Selected' : 'Share All'),
            onPressed: _isProcessing
                ? null
                : () => _shareItems(context, shareQueue, items),
          ),
        ),
        Expanded(
          child: TextButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear'),
            onPressed: _isProcessing
                ? null
                : () {
                    shareQueue.clear();
                    setState(() {
                      _selectionMode = false;
                      _selectedKeys.clear();
                    });
                  },
          ),
        ),
      ],
    );
  }

  void _toggleSelected(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _openFullView(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ShareQueueScreen(),
      ),
    );
  }

  void _removeItem(ShareQueueProvider shareQueue, GifItem gif, String key) {
    shareQueue.removeGif(gif);
    setState(() {
      _selectedKeys.remove(key);
      if (shareQueue.count == 0) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _shareItems(
    BuildContext context,
    ShareQueueProvider shareQueue,
    List<GifItem> items,
  ) async {
    List<GifItem> gifsToShare;
    if (_selectionMode) {
      if (_selectedKeys.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select GIFs to share')),
        );
        return;
      }
      gifsToShare = items
          .where((gif) => _selectedKeys.contains(shareQueue.keyFor(gif)))
          .toList();
    } else {
      gifsToShare = items;
    }

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

      // Keep the queue intact until the user explicitly removes or clears it.
      // DownloadAndShare currently reports failures through the UI rather than
      // a return value, so automatic removal here could lose unsent GIFs.
      if (!mounted) return;

      setState(() {
        _selectedKeys.removeWhere(
          (key) => !shareQueue.queuedGifs
              .any((gif) => shareQueue.keyFor(gif) == key),
        );
        if (shareQueue.count == 0) {
          _selectionMode = false;
          _selectedKeys.clear();
        }
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

  Widget _buildThumbnail(GifItem gif) {
    final imagePath = gif.imageUrl ?? gif.url ?? '';
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.image),
      );
    }
    if (imagePath.startsWith('/')) {
      return Image.file(
        File(imagePath),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.image),
      );
    }
    return const Icon(Icons.image);
  }
}
