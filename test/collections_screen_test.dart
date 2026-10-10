import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gif_play/data/cache/collection_share_controller.dart';
import 'package:gif_play/data/local/local_database.dart';
import 'package:gif_play/data/local/local_media_repository.dart';
import 'package:gif_play/screens/collections_screen.dart';

void main() {
  testWidgets('user can create a named collection from the Collections screen',
      (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    await database.initialize();
    final controller = CollectionShareController(
      LocalMediaRepository(database),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<CollectionShareController>.value(
        value: controller,
        child: const MaterialApp(home: CollectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Favorite reactions');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Favorite reactions'), findsOneWidget);
    expect(
      controller.collections.map((collection) => collection.name),
      contains('Favorite reactions'),
    );

    await database.close();
  });
}
