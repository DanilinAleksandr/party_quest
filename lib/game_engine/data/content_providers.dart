import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/adventure_catalog.dart';
import '../logic/biome_catalog.dart';
import '../logic/effect_catalog.dart';
import '../logic/item_catalog.dart';
import '../logic/origin_catalog.dart';
import '../models/models.dart';
import 'adventure_repository.dart';
import 'biome_repository.dart';
import 'card_repository.dart';
import 'content_validator.dart';
import 'effect_repository.dart';
import 'item_repository.dart';
import 'origin_repository.dart';

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => const CardRepository(),
);

final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => const ItemRepository(),
);

final effectRepositoryProvider = Provider<EffectRepository>(
  (ref) => const EffectRepository(),
);

final adventureRepositoryProvider = Provider<AdventureRepository>(
  (ref) => const AdventureRepository(),
);

final biomeRepositoryProvider = Provider<BiomeRepository>(
  (ref) => const BiomeRepository(),
);

final originRepositoryProvider = Provider<OriginRepository>(
  (ref) => const OriginRepository(),
);

/// Loaded once and cached for the app's lifetime — every screen that needs
/// content reads the same resolved value instead of re-parsing JSON.
final cardsProvider = FutureProvider<List<GameCard>>((ref) {
  return ref.watch(cardRepositoryProvider).loadCards();
});

final itemCatalogProvider = FutureProvider<ItemCatalog>((ref) {
  return ref.watch(itemRepositoryProvider).loadCatalog();
});

final effectCatalogProvider = FutureProvider<EffectCatalog>((ref) {
  return ref.watch(effectRepositoryProvider).loadCatalog();
});

final adventureCatalogProvider = FutureProvider<AdventureCatalog>((ref) {
  return ref.watch(adventureRepositoryProvider).loadCatalog();
});

final biomeCatalogProvider = FutureProvider<BiomeCatalog>((ref) {
  return ref.watch(biomeRepositoryProvider).loadCatalog();
});

final originCatalogProvider = FutureProvider<OriginCatalog>((ref) {
  return ref.watch(originRepositoryProvider).loadCatalog();
});

/// Depends on all six catalogs and cross-checks every id they reference
/// against each other, throwing [ContentValidationException] if anything is
/// broken. `BootstrapScreen` surfaces a failure here the same way it surfaces
/// a load failure — a content mistake should never reach a player as an
/// in-game crash.
final contentValidationProvider = FutureProvider<void>((ref) async {
  final cards = await ref.watch(cardsProvider.future);
  final itemCatalog = await ref.watch(itemCatalogProvider.future);
  final effectCatalog = await ref.watch(effectCatalogProvider.future);
  final adventureCatalog = await ref.watch(adventureCatalogProvider.future);
  final biomeCatalog = await ref.watch(biomeCatalogProvider.future);
  final originCatalog = await ref.watch(originCatalogProvider.future);

  const validator = ContentValidator();
  final errors = validator.validate(
    cards: cards,
    itemCatalog: itemCatalog,
    effectCatalog: effectCatalog,
    adventureCatalog: adventureCatalog,
    biomeCatalog: biomeCatalog,
    originCatalog: originCatalog,
  );
  if (errors.isNotEmpty) {
    throw ContentValidationException(errors);
  }
});
