/// SearchResultsList — scrollable list of place search results.
///
/// Shows at most 5 results. Each tile displays place name and type.
/// Tapping a result dispatches SelectPlace to center map on location.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';

class SearchResultsList extends StatelessWidget {
  const SearchResultsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        if (state is! SearchResultsLoaded) {
          return const SizedBox.shrink();
        }

        final results = state.results;

        if (results.isEmpty) {
          return _buildEmptyState();
        }

        // Show max 5 results
        final displayResults = results.take(5).toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withAlpha(245),
            borderRadius: AppRadius.mdCircular,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: displayResults.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final result = displayResults[index];
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.location_on_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                  title: Text(
                    result.displayName,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    result.osmType,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  onTap: () {
                    context.read<SearchBloc>().add(SelectPlace(result));
                    // Hide keyboard
                    FocusScope.of(context).unfocus();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(245),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Text(
        'Sin resultados',
        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        textAlign: TextAlign.center,
      ),
    );
  }
}
