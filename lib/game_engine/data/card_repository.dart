import '../../core/constants/asset_paths.dart';
import '../models/models.dart';
import 'json_asset_loader.dart';

/// Loads every card pack under `assets/data/cards/`. Cards are content, not
/// code — adding more, or splitting them across more files, never touches
/// this class.
final class CardRepository {
  final JsonAssetLoader _loader;

  const CardRepository([this._loader = const JsonAssetLoader()]);

  Future<List<GameCard>> loadCards() async {
    final raw = await _loader.loadArraysUnder(AssetPaths.cardsDirectory);
    return raw
        .map((e) => GameCard.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
