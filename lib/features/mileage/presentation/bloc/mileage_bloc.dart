/// Mileage BLoC.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mileage_event.dart';
import 'mileage_state.dart';

class MileageBloc extends Bloc<MileageEvent, MileageState> {
  MileageBloc() : super(MileageInitial()) {
    on<LoadMileage>(_onLoadMileage);
  }

  Future<void> _onLoadMileage(LoadMileage event, Emitter<MileageState> emit) async {
    emit(MileageLoading());
    try {
      final mileageResp = await Supabase.instance.client
          .from('user_mileage')
          .select()
          .eq('user_id', event.userId)
          .maybeSingle();

      emit(MileageLoaded(
        mileage: mileageResp,
        entries: [],
      ));
    } catch (e) {
      emit(MileageError(e.toString()));
    }
  }
}
