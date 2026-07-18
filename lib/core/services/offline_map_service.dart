/// Offline Map Service — FMTC tile caching + region download.
library;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

class OfflineMapService {
  static const _storeName = 'asfalto_club';

  /// Create an FMTCTileProvider with automatic caching.
  static TileProvider tileProvider() => FMTCTileProvider(
        stores: {_storeName: BrowseStoreStrategy.readUpdateCreate},
        loadingStrategy: BrowseLoadingStrategy.cacheFirst,
      );

  /// FMTC store for direct operations.
  static FMTCStore get _store => FMTCStore(_storeName);

  /// Get cached tile count and size as a record.
  static Future<({int tiles, double sizeMb})> stats() async {
    try {
      final s = await _store.stats.all;
      final mb = s.size / 1024;
      return (tiles: s.length, sizeMb: mb);
    } catch (_) {
      return (tiles: 0, sizeMb: 0.0);
    }
  }

  /// Get human-readable stats string.
  static Future<String> statsString() async {
    final s = await stats();
    return '${s.tiles} tiles · ${s.sizeMb.toStringAsFixed(1)}MB';
  }

  /// Clear all cached tiles.
  static Future<void> clearCache() async {
    try {
      await _store.manage.delete();
    } catch (_) {}
  }

  /// Colombia bounding box covering main moto routes.
  static RectangleRegion get _colombiaRegion => RectangleRegion(
        LatLngBounds(
          const LatLng(12.5, -79.0), // NW
          const LatLng(-4.2, -67.0), // SE
        ),
      );

  /// Count tiles in the Colombia region (preview before download).
  static Future<int> countColombiaTiles() {
    final region = _colombiaRegion.toDownloadable(
      minZoom: 5,
      maxZoom: 15,
      options: TileLayer(
        urlTemplate:
            'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
        subdomains: const ['a', 'b', 'c'],
      ),
    );
    return _store.download.countTiles(region);
  }

  /// Start downloading Colombia offline map.
  /// Returns two streams: downloadProgress and tileEvents.
  static ({Stream<DownloadProgress> progress, Stream<TileEvent> events})
      startColombiaDownload() {
    final region = _colombiaRegion.toDownloadable(
      minZoom: 5,
      maxZoom: 15,
      start: 1,
      options: TileLayer(
        urlTemplate:
            'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
        subdomains: const ['a', 'b', 'c'],
      ),
    );
    final result = _store.download.startForeground(
      region: region,
      parallelThreads: 5,
      skipSeaTiles: true,
      skipExistingTiles: true,
    );
    return (progress: result.downloadProgress, events: result.tileEvents);
  }

  /// Pause current download.
  static Future<void> pauseDownload() => _store.download.pause();

  /// Resume paused download.
  static bool? resumeDownload() => _store.download.resume();

  /// Cancel current download.
  static Future<void> cancelDownload() => _store.download.cancel();
}
