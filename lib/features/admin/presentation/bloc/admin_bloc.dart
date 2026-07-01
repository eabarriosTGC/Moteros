import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/manage_allies.dart';
import 'admin_event.dart';
import 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final ManageAlliesUseCase _manageAllies;

  AdminBloc({required ManageAlliesUseCase manageAllies})
      : _manageAllies = manageAllies,
        super(AdminInitial()) {
    on<LoadAllies>(_onLoadAllies);
    on<CreateAlly>(_onCreateAlly);
  }

  Future<void> _onLoadAllies(
    LoadAllies event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final allies = await _manageAllies.getAllies();
      emit(AlliesLoaded(allies));
    } catch (e) {
      emit(const AdminError('Error al cargar aliados'));
    }
  }

  Future<void> _onCreateAlly(
    CreateAlly event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final ally = await _manageAllies.create(
        businessName: event.businessName,
        category: event.category,
        description: event.description,
        benefit: event.benefit,
        address: event.address,
        phone: event.phone,
        website: event.website,
        latitude: event.latitude,
        longitude: event.longitude,
      );
      emit(AllyCreated(ally));
    } catch (e) {
      emit(const AdminError('Error al crear aliado'));
    }
  }
}
