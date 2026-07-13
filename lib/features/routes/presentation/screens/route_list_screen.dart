/// Route List Screen — browse and search routes by difficulty.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';
import '../bloc/route_state.dart';
import 'route_detail_screen.dart';
import 'route_create_screen.dart';

/// Difficulty filter options
enum RouteDifficulty {
  all('Todas', null),
  facil('Fácil', 'facil'),
  medio('Medio', 'medio'),
  dificil('Difícil', 'dificil'),
  experto('Experto', 'experto');

  final String label;
  final String? value;
  const RouteDifficulty(this.label, this.value);
}

class RouteListScreen extends StatefulWidget {
  final int? clubId;
  const RouteListScreen({super.key, this.clubId});

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  RouteDifficulty _activeDifficulty = RouteDifficulty.all;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  void _loadRoutes() {
    context.read<RouteBloc>().add(LoadRoutes(
          difficulty: _activeDifficulty.value,
          clubId: widget.clubId,
        ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('RUTAS', style: AppTypography.h2.copyWith(color: AppColors.primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textMuted),
            onPressed: () => _showSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RouteCreateScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Difficulty filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: RouteDifficulty.values.map((d) => _buildDifficultyChip(d)).toList(),
              ),
            ),
          ),
          // Route list
          Expanded(
            child: BlocBuilder<RouteBloc, RouteState>(
              builder: (context, state) {
                if (state is RouteLoading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (state is RoutesLoaded) {
                  final routes = state.routes;
                  if (routes.isEmpty) {
                    return _buildEmptyState();
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _loadRoutes(),
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      itemCount: routes.length,
                      itemBuilder: (_, i) => _buildRouteCard(routes[i]),
                    ),
                  );
                }
                if (state is RouteError) {
                  return _buildErrorState(state.message);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RouteCreateScreen()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: AppColors.textOnAmber),
      ),
    );
  }

  Widget _buildDifficultyChip(RouteDifficulty diff) {
    final selected = _activeDifficulty == diff;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: () {
          setState(() => _activeDifficulty = diff);
          _loadRoutes();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected ? AppColors.primaryLight : AppColors.border,
              width: 1,
            ),
            boxShadow: selected ? AppShadows.amberGlow : null,
          ),
          child: Text(
            diff.label,
            style: AppTypography.label.copyWith(
              color: selected ? AppColors.textOnAmber : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final title = route['title'] as String? ?? 'Ruta sin nombre';
    final difficulty = route['difficulty'] as String?;
    final totalKm = (route['total_km'] as num?)?.toDouble() ?? 0;
    final durationMin = (route['duration_min'] as int?) ?? 0;
    final rating = (route['rating'] as num?)?.toDouble() ?? 0;
    final waypoints = route['waypoints'] as List? ?? [];
    final isPublic = route['is_public'] as bool? ?? true;

    final difficultyColor = switch (difficulty) {
      'facil' => AppColors.success,
      'medio' => AppColors.warning,
      'dificil' => AppColors.error,
      'experto' => const Color(0xFFFF2D55),
      _ => AppColors.textMuted,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteDetailScreen(routeId: route['id'] as int),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdCircular,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                      style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isPublic)
                    const Padding(
                      padding: EdgeInsets.only(left: AppSpacing.xs),
                      child: Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Stats row
              Row(
                children: [
                  // Difficulty badge
                  if (difficulty != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: difficultyColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: difficultyColor.withAlpha(60)),
                      ),
                      child: Text(difficulty.toUpperCase(),
                        style: AppTypography.caption.copyWith(color: difficultyColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // KM
                  Icon(Icons.route_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${totalKm.toStringAsFixed(1)} km',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Duration
                  Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(_formatDuration(durationMin),
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Waypoints count + rating
              Row(
                children: [
                  Text('${waypoints.length} puntos',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  _buildRatingStars(rating),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.round();
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: 16,
          color: filled ? AppColors.primary : AppColors.textMuted,
        );
      }),
    );
  }

  String _formatDuration(int min) {
    if (min < 60) return '${min}min';
    final h = min ~/ 60;
    final m = min % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 64, color: AppColors.textMuted.withAlpha(60)),
          const SizedBox(height: AppSpacing.md),
          Text('Sin rutas', style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Crea la primera ruta para tu club',
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const RouteCreateScreen()),
            ),
            icon: const Icon(Icons.add_rounded, size: AppSpacing.iconSm),
            label: const Text('CREAR RUTA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              minimumSize: const Size(200, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error', style: AppTypography.h2.copyWith(color: AppColors.error)),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: AppTypography.body.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadRoutes,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              ),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _RouteSearchDelegate(),
    );
  }
}

/// Search delegate for routes
class _RouteSearchDelegate extends SearchDelegate<String?> {
  @override
  String get searchFieldLabel => 'Buscar rutas...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: AppColors.surface),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.textMuted),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: AppColors.textMuted),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchList(context);
  }

  Widget _buildSearchList(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Text('Escribe para buscar rutas', style: AppTypography.body.copyWith(color: AppColors.textMuted)),
      );
    }
    return BlocBuilder<RouteBloc, RouteState>(
      builder: (context, state) {
        if (state is RoutesLoaded) {
          final results = state.routes.where((r) {
            final title = (r['title'] as String? ?? '').toLowerCase();
            return title.contains(query.toLowerCase());
          }).toList();
          if (results.isEmpty) {
            return Center(
              child: Text('Sin resultados', style: AppTypography.body.copyWith(color: AppColors.textMuted)),
            );
          }
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.route_outlined, color: AppColors.primary),
              title: Text(results[i]['title'] as String? ?? '',
                style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              ),
              subtitle: Text('${results[i]['total_km'] ?? 0} km',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              onTap: () {
                close(context, null);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RouteDetailScreen(routeId: results[i]['id'] as int),
                  ),
                );
              },
            ),
          );
        }
        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      },
    );
  }
}
