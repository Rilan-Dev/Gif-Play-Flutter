import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/local/models/detail_tab.dart';

/// Lightweight, local-first content view for a selected persistent Detail Tab.
class DetailTabContent extends StatelessWidget {
  const DetailTabContent({super.key, required this.tab});

  final DetailTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = tab.canonicalUrl;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tab.thumbnailUrl != null && tab.thumbnailUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      tab.thumbnailUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, size: 48),
                ),
              const SizedBox(height: 18),
              Text(
                (tab.title?.trim().isNotEmpty ?? false)
                    ? tab.title!.trim()
                    : 'GIF detail',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                url?.isNotEmpty == true ? url! : 'No source URL saved for this tab.',
                style: theme.textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              if (url?.isNotEmpty == true)
                FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(url!);
                    if (uri == null ||
                        !(uri.scheme == 'http' || uri.scheme == 'https')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('This source URL is invalid.')),
                      );
                      return;
                    }
                    final opened = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open this source.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open original source'),
                ),
              const SizedBox(height: 8),
              Text(
                'This tab is saved locally. Its title and preview remain available '
                'after restarting the app; opening the original source requires a network connection.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
