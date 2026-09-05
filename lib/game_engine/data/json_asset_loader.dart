import 'dart:convert';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;

/// Discovers and loads every JSON file under a given asset directory,
/// concatenating their top-level arrays.
///
/// This is what lets content scale to a thousand cards without a thousand
/// entries anywhere in Dart code: a repository declares *where* its content
/// lives (a directory), not an enumerated list of files, so dropping a new
/// pack into that directory (and rebuilding, which regenerates Flutter's
/// asset manifest) is the entire integration step.
final class JsonAssetLoader {
  const JsonAssetLoader();

  Future<List<dynamic>> loadArraysUnder(String directoryPrefix) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths =
        manifest
            .listAssets()
            .where(
              (path) =>
                  path.startsWith(directoryPrefix) && path.endsWith('.json'),
            )
            .toList()
          ..sort();

    final items = <dynamic>[];
    for (final path in paths) {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw) as List<dynamic>;
      items.addAll(decoded);
    }
    return items;
  }
}
