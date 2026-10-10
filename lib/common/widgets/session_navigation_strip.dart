import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/local/models/detail_tab.dart';
import '../../data/local/models/space.dart';
import '../../data/local/session_navigation_controller.dart';

/// Compact, persistent Space and nested Detail Tab strips for the home feed.
class SessionNavigationStrip extends StatelessWidget {
  const SessionNavigationStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionNavigationController>(
      builder: (context, navigation, _) {
        if (!navigation.isLoaded) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                children: [
                  for (final space in navigation.spaces)
                    _SpaceChip(
                      space: space,
                      selected: space.id == navigation.activeSpaceId,
                      onTap: () => navigation.activateSpace(space.id),
                      onClose: navigation.spaces.length > 1
                          ? () => navigation.closeSpace(space.id)
                          : null,
                    ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'New Space',
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => navigation.createSpace(
                        name: 'Space ${navigation.spaces.length + 1}',
                      ),
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            if (navigation.activeSpaceId != null &&
                navigation.tabsForSpace(navigation.activeSpaceId!).isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 2, 12, 6),
                  children: [
                    for (final tab
                        in navigation.tabsForSpace(navigation.activeSpaceId!))
                      _DetailTabChip(
                        tab: tab,
                        selected: tab.id == navigation.activeDetailTabId,
                        onTap: () => navigation.activateDetailTab(tab.id),
                        onClose: () => navigation.closeDetailTab(tab.id),
                      ),
                    Tooltip(
                      message: 'Show all GIF tabs',
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showDetailTabOverview(
                          context,
                          navigation,
                          navigation.activeSpaceId!,
                        ),
                        icon: const Icon(Icons.grid_view_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

/// Bottom browser-style tab control for quick access to the current Space
/// and a large overview of all saved child tabs.
class SessionTabBottomBar extends StatelessWidget {
  const SessionTabBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionNavigationController>(
      builder: (context, navigation, _) {
        if (!navigation.isLoaded) return const SizedBox.shrink();
        final activeTab = navigation.activeDetailTab;
        final title = activeTab?.title?.trim().isNotEmpty == true
            ? activeTab!.title!.trim()
            : 'Home feed';
        final tabs = navigation.activeSpaceId == null
            ? const <DetailTab>[]
            : navigation.tabsForSpace(navigation.activeSpaceId!);
        return Material(
          elevation: 10,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.grid_view_rounded, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            navigation.activeSpace?.name ?? 'Home',
                            style: Theme.of(context).textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text('${tabs.length}', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'Browse all GIF tabs',
                      onPressed: tabs.isEmpty
                          ? null
                          : () => _showDetailTabOverview(
                                context,
                                navigation,
                                navigation.activeSpaceId!,
                              ),
                      icon: const Icon(Icons.tab),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showDetailTabOverview(
  BuildContext context,
  SessionNavigationController navigation,
  String spaceId,
) async {
  final tabs = navigation.tabsForSpace(spaceId);
  if (tabs.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.of(dialogContext).size.height * 0.82,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                children: [
                  const Icon(Icons.tab),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'GIF tabs · ${tabs.length}',
                      style: Theme.of(dialogContext).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close overview',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: tabs.length,
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  final selected = tab.id == navigation.activeDetailTabId;
                  final title = tab.title?.trim().isNotEmpty == true
                      ? tab.title!.trim()
                      : 'GIF detail';
                  final thumbnail = tab.thumbnailUrl?.trim() ?? '';
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await navigation.activateDetailTab(tab.id);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: thumbnail.isEmpty
                                ? const Center(child: Icon(Icons.image_outlined, size: 36))
                                : CachedNetworkImage(
                                    imageUrl: thumbnail,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    errorWidget: (context, url, error) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(9),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SpaceChip extends StatelessWidget {
  const _SpaceChip({
    required this.space,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final BrowsingSpace space;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? colors.secondaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.grid_view_rounded,
                    size: 16,
                    color: selected
                        ? colors.onSecondaryContainer
                        : colors.onSurfaceVariant),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    space.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? colors.onSecondaryContainer : null,
                    ),
                  ),
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 2),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.close, size: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailTabChip extends StatelessWidget {
  const _DetailTabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final DetailTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = (tab.title?.trim().isNotEmpty ?? false)
        ? tab.title!.trim()
        : 'GIF detail';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined,
                    size: 15,
                    color: selected ? colors.onPrimaryContainer : null),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 3),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.close, size: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
