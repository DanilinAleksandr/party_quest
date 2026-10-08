import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/theme/adventure_icons.dart';
import 'package:drinking_quest/core/theme/app_colors.dart';
import 'package:drinking_quest/core/theme/steel_palette.dart';
import 'package:drinking_quest/features/game/presentation/widgets/adventure_node_dialog.dart';
import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every adventure has a mark, and every mark is shipped', () async {
    final adventures = await const AdventureRepository().loadCatalog();
    final missing = [
      for (final id in adventures.all.map((a) => a.id))
        if (adventureIconAsset(id) == null) id,
    ];
    expect(missing, isEmpty, reason: 'still on the book: $missing');
    for (final id in adventures.all.map((a) => a.id)) {
      final svg = await rootBundle.loadString(adventureIconAsset(id)!);
      expect(svg, startsWith('<svg'), reason: id);
      // Cleaned like the origins' marks: no black square behind the shape.
      expect(svg, isNot(contains('M0 0h512v512H0z')), reason: id);
    }
  });

  testWidgets('an adventure is headed by its name and its mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAdventureNodeDialog(
              context: context,
              node: const AdventureNode(
                id: 'gate',
                text: 'У ворот стоит часовой.',
                choices: [
                  AdventureChoice(
                    label: 'Подойти',
                    onSuccess: NodeTransition(to: EndAdventure()),
                  ),
                ],
              ),
              participants: null,
              onChoice: (_) {},
              title: 'Застава ордена',
              iconAsset: adventureIconAsset('paladin_outpost'),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Застава ордена'), findsOneWidget);
    expect(find.text('Приключение'), findsNothing);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(kAdventureFallbackIcon), findsNothing);
  });

  testWidgets('the mark is steel, and gold only for a legendary way in', (
    tester,
  ) async {
    for (final (rarity, color) in [
      (null, SteelPalette.steel),
      (Rarity.epic, SteelPalette.steel),
      (Rarity.legendary, AppColors.rarityColor(Rarity.legendary)),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAdventureNodeDialog(
                context: context,
                node: const AdventureNode(
                  id: 'n',
                  text: 't',
                  choices: [
                    AdventureChoice(
                      label: 'Дальше',
                      onSuccess: NodeTransition(to: EndAdventure()),
                    ),
                  ],
                ),
                participants: null,
                onChoice: (_) {},
                title: 'Мавзолей',
                iconAsset: adventureIconAsset('king_of_the_dead'),
                rarity: rarity,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        svg.colorFilter,
        ColorFilter.mode(color, BlendMode.srcIn),
        reason: '$rarity',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });
}
