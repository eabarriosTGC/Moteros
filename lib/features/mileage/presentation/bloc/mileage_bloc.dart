/// Mileage BLoC.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mileage_event.dart';
import 'mileage_state.dart';

class MileageBloc extends Bloc<MileageEvent, MileageState> {
  MileageBloc() : super(MileageInitial()) {
    on<LoadMileage>(_onLoadMileage);
    on<SubmitManualEntry>(_onSubmitManualEntry);
    on<LoadPendingVerifications>(_onLoadPendingVerifications);
    on<VerifyManualEntry>(_onVerifyManualEntry);
  }

  Future<void> _onLoadMileage(LoadMileage event, Emitter<MileageState> emit) async {
    emit(MileageLoading());
    try {
      final mileageResp = await Supabase.instance.client
          .from('user_mileage')
          .select()
          .eq('user_id', event.userId)
          .maybeSingle();

      final entriesResp = await Supabase.instance.client
          .from('mileage_manual_entries')
          .select()
          .eq('user_id', event.userId)
          .order('created_at', ascending: false)
          .limit(20);

      emit(MileageLoaded(
        mileage: mileageResp as Map<String, dynamic>?,
        entries: (entriesResp as List?)?.cast<Map<String, dynamic>>() ?? [],
      ));
    } catch (e) {
      emit(MileageError(e.toString()));
    }
  }

  Future<void> _onSubmitManualEntry(SubmitManualEntry event, Emitter<MileageState> emit) async {
    emit(MileageLoading());
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

      // Fraud checks
      if (event.amountKm <= 0 || event.amountKm > 1000) {
        throw Exception('El KM debe ser entre 1 y 1000');
      }

      // Daily cap
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final todayEntries = await Supabase.instance.client
          .from('mileage_manual_entries')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', today);

      if ((todayEntries as List).isNotEmpty) {
        throw Exception('Ya ingresaste KM hoy (máx 1/día)');
      }

      // Weekly cap
      final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
      final weekEntries = await Supabase.instance.client
          .from('mileage_manual_entries')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', weekAgo);

      if ((weekEntries as List).length >= 3) {
        throw Exception('Límite semanal de 3 entradas alcanzado');
      }

      await Supabase.instance.client.from('mileage_manual_entries').insert({
        'user_id': userId,
        'amount_km': event.amountKm,
        'odometer_photo_url': event.odometerPhotoUrl,
        'photo_lat': event.photoLat,
        'photo_lng': event.photoLng,
        'notes': event.notes,
      });

      emit(ManualEntrySubmitted());
    } catch (e) {
      emit(MileageError(e.toString()));
    }
  }

  Future<void> _onLoadPendingVerifications(
      LoadPendingVerifications event, Emitter<MileageState> emit) async {
    emit(MileageLoading());
    try {
      final response = await Supabase.instance.client
          .from('mileage_pending_verification')
          .select();
      emit(PendingVerificationsLoaded(
        entries: (response as List).cast<Map<String, dynamic>>(),
      ));
    } catch (e) {
      emit(MileageError(e.toString()));
    }
  }

  Future<void> _onVerifyManualEntry(
      VerifyManualEntry event, Emitter<MileageState> emit) async {
    try {
      if (event.approved) {
        await Supabase.instance.client.from('mileage_manual_entries').update({
          'is_verified': true,
          'verified_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', event.entryId);
      } else {
        await Supabase.instance.client.from('mileage_manual_entries').update({
          'is_verified': false,
          'rejection_reason': event.rejectionReason ?? 'Rechazado',
          'verified_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', event.entryId);
      }
      add(const LoadPendingVerifications());
    } catch (e) {
      emit(MileageError(e.toString()));
    }
  }
}
