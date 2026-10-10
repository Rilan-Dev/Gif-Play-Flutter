import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/models/gif_item.dart';
import '../common/providers/share_queue_provider.dart';
import '../common/utils/download_and_share.dart';

/// Full-screen management for the global share queue.
class ShareQueueScreen extends StatefulWidget {
  const ShareQueueScreen({Key? key}) : super(key: key);

  @override
  State<ShareQueueScreen> createState() => _ShareQueueScreenState();
}

class _ShareQueueScreenState extends State<ShareQueueScreen> {
  final Set<String> _selectedKeys = {};
  bool _selectionMode = false;
  bool _sharing = false;

  Future<void> _share(ShareQueueProvider queue) async {
    final items = queue.queuedGifs;
    final selected = _selectionMode
        ? items.where((gif) => _selectedKeys.contains(queue.keyFor(gif))).toList()
        : items;
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one GIF to share')),
      );
      return;
    }
    setState(() => _sharing = true);
    try {
      // DownloadAndShare uses the app's canonical MediaCacheManager path.
      // Keep queued items staged after sharing so a dismissed/failed native
      // share sheet cannot silently discard the user's selection.
      await DownloadAndShare().downloadAndShareGifs(context, selected, true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _thumbnail(GifItem gif) {
    final source = (gif.imageUrl ?? gif.url ?? '').trim();
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return Image.network(source, width: 56, height: 56, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported));
    }
    if (source.startsWith('/')) {
      return Image.file(File(source), width: 56, height: 56, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported));
    }
    return const SizedBox(width: 56, height: 56,
      child: Icon(Icons.image_not_supported));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShareQueueProvider>(
      builder: (context, queue, _) {
        final items = queue.queuedGifs;
        return Scaffold(
          appBar: AppBar(
            title: Text(_selectionMode ? '${selectedIndices.length} selected' : 'Share Queue'),
            leading: _selectionMode
                ? IconButton(
                    tooltip: 'Cancel selection',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _selectionMode = false;
                      _selectedKeys.clear();
                    }),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: _selectionMode ? 'Share selected' : 'Share all',
                icon: const Icon(Icons.share),
                onPressed: _sharing || items.isEmpty ? null : () => _share(queue),
              ),
              IconButton(
                tooltip: 'Clear queue',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: _sharing || items.isEmpty
                    ? null
                    : () => setState(() {
                          queue.clear();
                          _selectedKeys.clear();
                          _selectionMode = false;
                        }),
              ),
            ],
          ),
          body: items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_outlined, size: 48),
                        SizedBox(height: 12),
                        Text('Your share queue is empty'),
                        SizedBox(height: 4),
                        Text('Add GIFs from the feed or a GIF detail screen.'),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final gif = items[index];
                    final key = queue.keyFor(gif);
                    final selected = _selectedKeys.contains(key);
                    return ListTile(
                      leading: _thumbnail(gif),
                      title: Text(gif.title.isNotEmpty ? gif.title : 'Untitled GIF',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(gif.url ?? gif.imageUrl ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onLongPress: () => setState(() {
                        _selectionMode = true;
                        _selectedKeys.add(key);
                      }),
                      onTap: _selectionMode
                          ? () => setState(() {
                                selected ? _selectedKeys.remove(key) : _selectedKeys.add(key);
                                if (_selectedKeys.isEmpty) _selectionMode = false;
                              })
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectionMode) Checkbox(
                            value: selected,
                            onChanged: _sharing ? null : (_) => setState(() {
                              selected ? _selectedKeys.remove(key) : _selectedKeys.add(key);
                              if (_selectedKeys.isEmpty) _selectionMode = false;
                            }),
                          ),
                          IconButton(
                            tooltip: 'Remove from queue',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _sharing ? null : () {
                              queue.removeGif(gif);
                              setState(() => _selectedKeys.remove(key));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
          bottomNavigationBar: items.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
                            label: Text(_selectionMode ? 'Cancel selection' : 'Select'),
                            onPressed: _sharing ? null : () => setState(() {
                              _selectionMode = !_selectionMode;
                              _selectedKeys.clear();
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.share),
                            label: Text(_selectionMode ? 'Share selected' : 'Share all'),
                            onPressed: _sharing ? null : () => _share(queue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
