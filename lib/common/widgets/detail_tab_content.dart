import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/models/gif_item.dart';
import '../../data/local/models/detail_tab.dart';
import '../../data/local/session_navigation_controller.dart';
import '../../screens/main_screen/main_screen_data_service.dart';

/// Restorable GIF detail surface for a persistent child tab.
class DetailTabContent extends StatefulWidget {
  const DetailTabContent({super.key, required this.tab, this.onMoreOptions});
  final DetailTab tab;
  final VoidCallback? onMoreOptions;

  @override
  State<DetailTabContent> createState() => _DetailTabContentState();
}

class _DetailTabContentState extends State<DetailTabContent> {
  List<GifItem> _suggestions = const [];
  bool _loadingSuggestions = false;
  String? _suggestionError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(covariant DetailTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab.id != widget.tab.id ||
        oldWidget.tab.canonicalUrl != widget.tab.canonicalUrl) {
      _loadSuggestions();
    }
  }

  Future<void> _loadSuggestions() async {
    final generation = ++_loadGeneration;
    final source = widget.tab.canonicalUrl?.trim() ?? '';
    if (source.isEmpty || !source.startsWith(RegExp(r'https?://'))) {
      if (mounted) {
        setState(() {
          _suggestions = const [];
          _loadingSuggestions = false;
          _suggestionError = null;
        });
      }
      return;
    }
    setState(() {
      _loadingSuggestions = true;
      _suggestionError = null;
    });
    try {
      final suggestions = await MainScreenDataService.fetchGifsFromUrl(source);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _suggestions = suggestions;
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _suggestionError = 'Suggestions could not be loaded.';
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _openSource() async {
    final raw = widget.tab.canonicalUrl?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This source URL is invalid.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this source.')),
      );
    }
  }

  Future<void> _openSuggestion(GifItem gif) async {
    final navigation = context.read<SessionNavigationController>();
    final spaceId = navigation.activeSpaceId;
    final imageUrl = (gif.imageUrl ?? gif.url ?? '').trim();
    if (spaceId == null || imageUrl.isEmpty) return;
    await navigation.openDetailTab(
      spaceId: spaceId,
      mediaId: imageUrl,
      canonicalUrl: widget.tab.canonicalUrl,
      title: gif.title?.trim().isNotEmpty == true ? gif.title!.trim() : 'GIF detail',
      thumbnailUrl: imageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = widget.tab.thumbnailUrl?.trim() ?? '';
    final title = widget.tab.title?.trim().isNotEmpty == true
        ? widget.tab.title!.trim()
        : 'GIF detail';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return CustomScrollView(
          key: PageStorageKey<String>('detail-tab-${widget.tab.id}'),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 16, compact ? 12 : 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        constraints: BoxConstraints(maxHeight: compact ? 330 : 480, minHeight: 180),
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: thumbnail.isEmpty
                            ? const Center(child: Icon(Icons.image_not_supported_outlined, size: 48))
                            : CachedNetworkImage(
                                imageUrl: thumbnail,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      widget.tab.canonicalUrl?.trim().isNotEmpty == true
                          ? widget.tab.canonicalUrl!
                          : 'No source page was saved for this GIF.',
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.onMoreOptions != null)
                          OutlinedButton.icon(
                            onPressed: widget.onMoreOptions,
                            icon: const Icon(Icons.tune),
                            label: const Text('GIF options'),
                          ),
                        if (widget.tab.canonicalUrl?.trim().isNotEmpty == true)
                          OutlinedButton.icon(
                            onPressed: _openSource,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open original source'),
                          ),
                        OutlinedButton.icon(
                          onPressed: _loadingSuggestions ? null : _loadSuggestions,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh suggestions'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Text('Suggestions', style: theme.textTheme.titleMedium)),
                        if (_loadingSuggestions)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 6),
                        Text('${_suggestions.length}', style: theme.textTheme.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Choose a GIF to open it in a new child tab in this Space.', style: theme.textTheme.bodySmall),
                    if (_suggestionError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_suggestionError!, style: TextStyle(color: theme.colorScheme.error)),
                      ),
                  ],
                ),
              ),
            ),
            if (_suggestions.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 8, compact ? 12 : 20, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: compact ? 2 : 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final gif = _suggestions[index];
                      final image = (gif.imageUrl ?? gif.url ?? '').trim();
                      final suggestionTitle = gif.title?.trim().isNotEmpty == true
                          ? gif.title!.trim()
                          : 'GIF ${index + 1}';
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openSuggestion(gif),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: image.isEmpty
                                    ? const Center(child: Icon(Icons.image_outlined))
                                    : CachedNetworkImage(
                                        imageUrl: image,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image_outlined)),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(suggestionTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _suggestions.length,
                  ),
                ),
              )
            else if (!_loadingSuggestions)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Text('No suggestions are available for this source page.'),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }
}
