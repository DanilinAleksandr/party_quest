import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/app_logo.dart';
import '../features/main_menu/presentation/main_menu_screen.dart';
import '../game_engine/data/content_providers.dart';
import '../game_engine/data/content_validator.dart';

/// Loads card/item/effect/adventure/biome content once at startup,
/// validates every cross-reference between them, and only then shows the
/// main menu — so every later screen can assume the catalogs are already
/// resolved *and* internally consistent, instead of handling loading/error
/// states or broken content references of its own.
class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider);
    final items = ref.watch(itemCatalogProvider);
    final effects = ref.watch(effectCatalogProvider);
    final adventures = ref.watch(adventureCatalogProvider);
    final biomes = ref.watch(biomeCatalogProvider);
    final origins = ref.watch(originCatalogProvider);
    final validation = ref.watch(contentValidationProvider);

    final hasError =
        cards.hasError ||
        items.hasError ||
        effects.hasError ||
        adventures.hasError ||
        biomes.hasError ||
        origins.hasError ||
        validation.hasError;

    if (hasError) {
      final validationError = validation.error;
      final message = validationError is ContentValidationException
          ? validationError.toString()
          : 'Не удалось загрузить игровые данные.';

      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(message, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(cardsProvider);
                    ref.invalidate(itemCatalogProvider);
                    ref.invalidate(effectCatalogProvider);
                    ref.invalidate(adventureCatalogProvider);
                    ref.invalidate(biomeCatalogProvider);
                    ref.invalidate(originCatalogProvider);
                    ref.invalidate(contentValidationProvider);
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final allLoaded =
        cards.hasValue &&
        items.hasValue &&
        effects.hasValue &&
        adventures.hasValue &&
        biomes.hasValue &&
        origins.hasValue &&
        validation.hasValue;

    if (!allLoaded) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLogo(),
              SizedBox(height: 32),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return const MainMenuScreen();
  }
}
