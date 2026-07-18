/// Offline Maps Screen — download regions for offline use.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/services/offline_map_service.dart';

class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

enum _DownloadState { idle, downloading, paused, done }

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
  // Cache stats
  int _tiles = 0;
  double _sizeMb = 0;
  bool _loadingStats = true;

  // Download state
  _DownloadState _downloadState = _DownloadState.idle;
  double _progress = 0;
  int _tilesDone = 0;
  int _tilesTotal = 0;
  double _tilesPerSec = 0;
  StreamSubscription<DownloadProgress>? _progressSub;
  StreamSubscription<TileEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshStats() async {
    setState(() => _loadingStats = true);
    final s = await OfflineMapService.stats();
    if (mounted) setState(() {
      _tiles = s.tiles;
      _sizeMb = s.sizeMb;
      _loadingStats = false;
    });
  }

  Future<void> _startDownload() async {
    final result = OfflineMapService.startColombiaDownload();
    _progressSub = result.progress.listen((p) {
      if (!mounted) return;
      setState(() {
        _progress = p.percentageProgress / 100;
        _tilesDone = p.attemptedTilesCount;
        _tilesTotal = p.maxTilesCount;
        _tilesPerSec = p.tilesPerSecond;
        if (p.percentageProgress >= 100) {
          _downloadState = _DownloadState.done;
          _progress = 1.0;
        } else {
          _downloadState = _DownloadState.downloading;
        }
      });
    });
    _eventSub = result.events.listen((_) {});
    setState(() => _downloadState = _DownloadState.downloading);
  }

  void _pauseDownload() {
    OfflineMapService.pauseDownload();
    setState(() => _downloadState = _DownloadState.paused);
  }

  void _resumeDownload() {
    OfflineMapService.resumeDownload();
    setState(() => _downloadState = _DownloadState.downloading);
  }

  void _cancelDownload() async {
    await OfflineMapService.cancelDownload();
    _progressSub?.cancel();
    _eventSub?.cancel();
    if (mounted) setState(() => _downloadState = _DownloadState.idle);
  }

  Future<void> _clearCache() async {
    await OfflineMapService.clearCache();
    await _refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('MAPAS OFFLINE',
          style: TextStyle(color: AppColors.textPrimary, letterSpacing: 1.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildCacheCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildDownloadCard(),
        ],
      ),
    );
  }

  Widget _buildCacheCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('CACHÉ LOCAL'),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              if (_loadingStats)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCircle('$_tiles', 'TESELAS'),
                    _statCircle('${_sizeMb.toStringAsFixed(1)}', 'MB'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _tiles > 0 ? _clearCache : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('LIMPIAR CACHÉ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withAlpha(80)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('DESCARGAR REGIÓN'),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Region info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.map, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Colombia',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary, fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('Zoom 5–15 · CartoDB Dark',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Progress
              if (_downloadState != _DownloadState.idle) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: AppColors.input,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$_tilesDone / $_tilesTotal teselas',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                    Text('${_tilesPerSec.toStringAsFixed(0)} t/s',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Progress percentage
                Center(
                  child: Text('${(_progress * 100).toStringAsFixed(1)}%',
                    style: AppTypography.monoSmall.copyWith(
                      color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              // Action buttons
              _buildDownloadButtons(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButtons() {
    switch (_downloadState) {
      case _DownloadState.idle:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.download_rounded),
            label: const Text('DESCARGAR COLOMBIA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        );
      case _DownloadState.downloading:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pauseDownload,
                icon: const Icon(Icons.pause_rounded, size: 18),
                label: const Text('PAUSA'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: BorderSide(color: AppColors.warning.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _cancelDownload,
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('CANCELAR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      case _DownloadState.paused:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _resumeDownload,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('REANUDAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _cancelDownload,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('CANCELAR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      case _DownloadState.done:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _downloadState = _DownloadState.idle),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('COMPLETADO'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: BorderSide(color: AppColors.success.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('RE-DESCARGAR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
        style: AppTypography.label.copyWith(
          color: AppColors.textMuted, letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _statCircle(String value, String label) {
    return Column(
      children: [
        Text(value,
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700,
          ),
        ),
        Text(label,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
