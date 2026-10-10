import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
