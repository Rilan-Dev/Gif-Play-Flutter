import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/utils/download_and_share.dart';
import '../data/cache/collection_share_controller.dart';
import '../data/local/models/collection.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({Key? key}) : super(key: key);

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final _share = DownloadAndShare();

  Future<void> _prepareAndShare() async {
    final controller = context.read<CollectionShareController>();
    await controller.prepareSelected();
    if (!mounted || !controller.isReadyToShare) return;

    await _share.sharePreparedCollections(context, controller.preparations);
    if (mounted) {
      await controller.refreshReadiness();
    }
  }

  Widget _statusFor(
    CollectionShareController controller,
    GifCollection collection,
  ) {
    final readiness = controller.readiness[collection.id];
    if (readiness == null) {
      return const Text('Not prepared');
    }

    final parts = <String>[
      'ready ${readiness.ready}',
      'downloading ${readiness.downloading}',
      'not cached ${readiness.notCached}',
    ];
    if (readiness.expired > 0) parts.add('expired ${readiness.expired}');
    if (readiness.failed > 0) parts.add('failed ${readiness.failed}');
    return Text(parts.join(' · '));
  }

  String _itemStatus(CollectionCacheState state) {
    switch (state) {
      case CollectionCacheState.ready:
        return 'Ready';
      case CollectionCacheState.downloading:
        return 'Downloading';
      case CollectionCacheState.notCached:
        return 'Not cached';
      case CollectionCacheState.failed:
        return 'Failed';
      case CollectionCacheState.expired:
        return 'Expired';
    }
  }

  Widget _itemList(
    BuildContext context,
    CollectionShareController controller,
    String collectionId,
  ) {
    final items = controller.itemsForCollection(collectionId);
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No collection items'),
      );
    }

    return Column(
      children: items.map((item) {
        final media = controller.mediaForItem(item.mediaId);
        final retryable = item.cacheState == CollectionCacheState.failed ||
            item.cacheState == CollectionCacheState.expired;

        return ListTile(
          dense: true,
          leading: Icon(
            item.cacheState == CollectionCacheState.ready
                ? Icons.check_circle_outline
                : Icons.gif_box_outlined,
          ),
          title: Text(
            media?.title.isNotEmpty == true ? media!.title : item.mediaId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${_itemStatus(item.cacheState)} · ${item.shareState.name}',
          ),
          trailing: retryable
              ? IconButton(
                  tooltip: 'Retry',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => controller.retryItem(
                    collectionId,
                    item.mediaId,
                  ),
                )
              : null,
        );
      }).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          Consumer<CollectionShareController>(
            builder: (context, controller, _) => TextButton(
              onPressed: controller.collections.isEmpty
                  ? null
                  : controller.selectAll,
              child: const Text('Select all'),
            ),
          ),
        ],
      ),
      body: Consumer<CollectionShareController>(
        builder: (context, controller, _) {
          if (controller.collections.isEmpty) {
            return const Center(child: Text('No collections yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: controller.collections.length,
            itemBuilder: (context, index) {
              final collection = controller.collections[index];
              final selected =
                  controller.selectedCollectionIds.contains(collection.id);

              return ExpansionTile(
                initiallyExpanded: selected,
                onExpansionChanged: (expanded) {
                  if (expanded) {
                    controller.loadCollectionItems(collection.id);
                  }
                },
                leading: Checkbox(
                  value: selected,
                  onChanged: (_) =>
                      controller.toggleCollection(collection.id),
                ),
                title: Text(collection.name),
                subtitle: _statusFor(controller, collection),
                trailing: IconButton(
                  tooltip: 'Retry failed or expired items',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      controller.retryFailedOrExpired(collection.id),
                ),
                children: [
                  _itemList(context, controller, collection.id),
                ],
              );
            },
          );
        },
      ),
      bottomSheet: Consumer<CollectionShareController>(
        builder: (context, controller, _) {
          if (!controller.hasSelection) return const SizedBox.shrink();

          final progress = controller.progress;
          final preparing =
              controller.status == CollectionShareStatus.preparing;

          return Material(
            elevation: 8,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (preparing)
                      LinearProgressIndicator(value: progress),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preparing
                                ? 'Preparing ${controller.completedCollections}/${controller.selectedCount}'
                                : '${controller.selectedCount} collection${controller.selectedCount == 1 ? '' : 's'} selected',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: preparing ? null : _prepareAndShare,
                          icon: Icon(
                            controller.status == CollectionShareStatus.failed
                                ? Icons.refresh
                                : Icons.share,
                          ),
                          label: Text(
                            controller.status == CollectionShareStatus.failed
                                ? 'Retry'
                                : 'Prepare & Share',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
