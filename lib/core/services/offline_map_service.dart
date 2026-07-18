/// Offline Map Service — FMTC tile caching.
/// Level 1: Automatic tile caching as user browses.
library;

import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_map/flutter_map.dart';

class OfflineMapService {
  static const _storeName = 'asfalto_club';

  /// Create an FMTCTileProvider with automatic caching.
  static TileProvider tileProvider() => FMTCTileProvider(
        stores: {_storeName: BrowseStoreStrategy.readUpdateCreate},
        loadingStrategy: BrowseLoadingStrategy.cacheFirst,
      );

  /// Get cached tile count and size in a human-readable string.
  static Future<String> statsString() async {
    try {
      final stats = await FMTCStore(_storeName).stats.all;
      final mb = (stats.size / 1024).toStringAsFixed(1);
      return '${stats.length} tiles · ${mb}MB';
    } catch (_) {
      return '0 tiles · 0MB';
    }
  }

  /// Clear all cached tiles.
  static Future<void> clearCache() async {
    try {
      await FMTCStore(_storeName).manage.delete();
    } catch (_) {}
  }
}
