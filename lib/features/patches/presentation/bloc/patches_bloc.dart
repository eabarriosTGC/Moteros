/// Parches Digitales BLoC — conectado a Supabase.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

sealed class PatchesEvent {}

final class LoadPatches extends PatchesEvent {}

sealed class PatchesState {
  const PatchesState();
}

final class PatchesInitial extends PatchesState {}

final class PatchesLoading extends PatchesState {}

final class PatchesLoaded extends PatchesState {
  final List<PatchEntity> patches;
  final int earned;
  final int total;

  PatchesLoaded({
    required this.patches,
    required this.earned,
    required this.total,
  });
}

final class PatchesError extends PatchesState {
  final String msg;
  PatchesError(this.msg);
}

class PatchEntity {
  final int id;
  final String name;
  final String description;
  final bool earned;
  final String icon;
  final String colorHex;

  const PatchEntity({
    required this.id,
    required this.name,
    this.description = '',
    this.earned = false,
    this.icon = '🏍️',
    this.colorHex = 'FF8C00',
  });
}

class PatchesBloc extends Bloc<PatchesEvent, PatchesState> {
  PatchesBloc() : super(PatchesInitial()) {
    on<LoadPatches>(_onLoadPatches);
  }

  Future<void> _onLoadPatches(
    LoadPatches event,
    Emitter<PatchesState> emit,
  ) async {
    emit(PatchesLoading());
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      if (userId.isEmpty) {
        emit(PatchesError('Usuario no autenticado'));
        return;
      }

      // Load patches catalog
      final patchesResp = await Supabase.instance.client
          .from('patches')
          .select()
          .order('id', ascending: true);

      final patchesList =
          (patchesResp as List).cast<Map<String, dynamic>>();

      // Load user earned patches
      final userPatchesResp = await Supabase.instance.client
          .from('user_patches')
          .select()
          .eq('user_id', userId);

      final userPatches =
          (userPatchesResp as List).cast<Map<String, dynamic>>();
      final earnedIds =
          userPatches.map((up) => up['patch_id']).toSet();

      final entities = patchesList.map((p) {
        final pid = p['id'] as int;
        final isEarned = earnedIds.contains(pid);
        return PatchEntity(
          id: pid,
          name: p['name'] as String? ?? 'Sin nombre',
          description: p['description'] as String? ?? '',
          earned: isEarned,
          icon: p['icon'] as String? ?? '🏍️',
          colorHex: p['color_hex'] as String? ?? 'FF8C00',
        );
      }).toList();

      emit(PatchesLoaded(
        patches: entities,
        earned: earnedIds.length,
        total: patchesList.length,
      ));
    } catch (e) {
      emit(PatchesError(e.toString()));
    }
  }
}
