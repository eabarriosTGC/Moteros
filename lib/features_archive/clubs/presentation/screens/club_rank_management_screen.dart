/// Club Rank Management Screen — Presidente-only rank editor with CRUD.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/club_bloc.dart';
import '../bloc/club_event.dart';
import '../bloc/club_state.dart';

class ClubRankManagementScreen extends StatefulWidget {
  final int clubId;
  const ClubRankManagementScreen({super.key, required this.clubId});

  @override
  State<ClubRankManagementScreen> createState() => _ClubRankManagementScreenState();
}

class _ClubRankManagementScreenState extends State<ClubRankManagementScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ClubBloc>().add(LoadClubRanks(clubId: widget.clubId));
  }

  void _showAddEditDialog({Map<String, dynamic>? existingRank}) {
    final nameController = TextEditingController(text: existingRank?['name'] as String? ?? '');
    final levelController = TextEditingController(text: '${existingRank?['level'] ?? 1}');
    final minKmController = TextEditingController(text: '${existingRank?['requirements']?['min_km'] ?? 0}');
    final minPuntosController = TextEditingController(text: '${existingRank?['requirements']?['min_puntos'] ?? 0}');
    final minChallengesController = TextEditingController(text: '${existingRank?['requirements']?['min_challenges'] ?? 0}');
    final maxSlotsController = TextEditingController(text: '${existingRank?['max_slots'] ?? ''}');
    String selectedName = existingRank?['name'] as String? ?? 'aspirante';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          existingRank != null ? 'EDITAR RANGO' : 'NUEVO RANGO',
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('Nombre del rango', controller: nameController, readOnly: existingRank != null),
              const SizedBox(height: AppSpacing.sm),
              if (existingRank == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedName,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'aspirante', child: Text('Aspirante')),
                        DropdownMenuItem(value: 'honorable', child: Text('Honorable')),
                        DropdownMenuItem(value: 'oficial', child: Text('Oficial')),
                      ],
                      onChanged: (v) {
                        Navigator.pop(ctx);
                        if (v != null) {
                          nameController.text = v;
                          _showAddEditDialog(existingRank: {
                            ...?existingRank,
                            'name': v,
                          });
                        }
                      },
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              _dialogField('Nivel', controller: levelController, keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              Text('REQUISITOS', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
              const SizedBox(height: AppSpacing.sm),
              _dialogField('Min KM', controller: minKmController, keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              _dialogField('Min Puntos', controller: minPuntosController, keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              _dialogField('Min Challenges', controller: minChallengesController, keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              _dialogField('Max Slots (opcional)', controller: maxSlotsController, keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final level = int.tryParse(levelController.text) ?? 1;
              final maxSlots = int.tryParse(maxSlotsController.text);
              final requirements = {
                'min_km': double.tryParse(minKmController.text) ?? 0,
                'min_puntos': int.tryParse(minPuntosController.text) ?? 0,
                'min_challenges': int.tryParse(minChallengesController.text) ?? 0,
              };

              if (existingRank != null) {
                context.read<ClubBloc>().add(UpdateClubRank(
                      rankId: existingRank['id'] as int,
                      name: nameController.text.trim(),
                      requirements: requirements,
                      maxSlots: maxSlots,
                    ));
              } else {
                context.read<ClubBloc>().add(CreateClubRank(
                      clubId: widget.clubId,
                      name: nameController.text.trim(),
                      level: level,
                      requirements: requirements,
                      maxSlots: maxSlots,
                    ));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
            ),
            child: Text(existingRank != null ? 'ACTUALIZAR' : 'CREAR'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(String label, {required TextEditingController controller, bool readOnly = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.input,
        border: OutlineInputBorder(
          borderRadius: AppRadius.smCircular,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smCircular,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smCircular,
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        isDense: true,
      ),
    );
  }

  void _confirmDelete(int rankId, String rankName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar rango?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('¿Eliminar "$rankName"?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              context.read<ClubBloc>().add(DeleteClubRank(rankId: rankId));
              Navigator.pop(ctx);
            },
            child: const Text('ELIMINAR', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClubBloc, ClubState>(
      listener: (context, state) {
        if (state is ClubRanksLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Rangos actualizados'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 1),
            ),
          );
        }
        if (state is ClubError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}'), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Gestión de Rangos', style: TextStyle(color: AppColors.textPrimary)),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              onPressed: () => _showAddEditDialog(),
            ),
          ],
        ),
        body: BlocBuilder<ClubBloc, ClubState>(
          builder: (context, state) {
            if (state is ClubLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (state is ClubRanksLoaded) {
              final ranks = state.ranks;
              if (ranks.isEmpty) {
                return _buildEmptyState();
              }
              return RefreshIndicator(
                onRefresh: () async => context.read<ClubBloc>().add(LoadClubRanks(clubId: widget.clubId)),
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: ranks.length,
                  itemBuilder: (_, i) => _buildRankCard(ranks[i]),
                ),
              );
            }
            if (state is ClubError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Text(state.message, style: AppTypography.body.copyWith(color: AppColors.error)),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddEditDialog(),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add_rounded, color: AppColors.textOnAmber),
        ),
      ),
    );
  }

  Widget _buildRankCard(Map<String, dynamic> rank) {
    final name = rank['name'] as String? ?? 'Sin nombre';
    final level = rank['level'] as int? ?? 0;
    final reqs = rank['requirements'] as Map<String, dynamic>? ?? {};
    final maxSlots = rank['max_slots'] as int?;
    final isLeader = rank['is_leader'] as bool? ?? false;

    final rankColors = switch (name) {
      'aspirante' => AppColors.textMuted,
      'honorable' => AppColors.secondary,
      'oficial' => AppColors.primary,
      _ => AppColors.textMuted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: rankColors.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: rankColors.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: rankColors.withAlpha(60)),
                ),
                child: Center(
                  child: Text('$level',
                    style: AppTypography.h3.copyWith(color: rankColors, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name[0].toUpperCase() + name.substring(1),
                      style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                    ),
                    Row(
                      children: [
                        if (isLeader)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('LÍDER',
                              style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (maxSlots != null) ...[
                          if (isLeader) const SizedBox(width: 6),
                          Text('Máx $maxSlots slots',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Edit / Delete
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                onSelected: (v) {
                  if (v == 'edit') _showAddEditDialog(existingRank: rank);
                  if (v == 'delete') _confirmDelete(rank['id'] as int, name);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(
                    children: [Icon(Icons.edit, size: 18, color: AppColors.primary), SizedBox(width: 8), Text('Editar')],
                  )),
                  const PopupMenuItem(value: 'delete', child: Row(
                    children: [Icon(Icons.delete, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Eliminar')],
                  )),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Requirements
          Text('REQUISITOS', style: AppTypography.caption.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _reqChip('${(reqs['min_km'] as num?)?.toInt() ?? 0} KM', AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              _reqChip('${reqs['min_puntos'] ?? 0} PTS', AppColors.secondary),
              const SizedBox(width: AppSpacing.sm),
              _reqChip('${reqs['min_challenges'] ?? 0} RETOS', AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reqChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Text(label,
        style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 10),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, size: 64, color: AppColors.textMuted.withAlpha(60)),
          const SizedBox(height: AppSpacing.md),
          Text('Sin rangos', style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Crea el primer rango para tu club',
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add_rounded, size: AppSpacing.iconSm),
            label: const Text('CREAR RANGO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
            ),
          ),
        ],
      ),
    );
  }
}
