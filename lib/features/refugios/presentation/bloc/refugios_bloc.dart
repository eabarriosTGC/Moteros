/// Refugios BLoC.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import 'refugios_event.dart';
import 'refugios_state.dart';

class RefugiosBloc extends Bloc<RefugiosEvent, RefugiosState> {
  RefugiosBloc() : super(RefugiosInitial()) {
    on<LoadRefugios>(_onLoad);
    on<SosRequested>(_onSos);
    on<ContactHost>(_onContact);
  }

  Future<void> _onLoad(LoadRefugios event, Emitter<RefugiosState> emit) async {
    emit(RefugiosLoading());
    try {
      emit(RefugiosLoaded(refugios: [
        RefugioEntity(id: 1, name: 'Moto-Posada El Viajero', type: 'moto_posada',
          description: 'Alojamiento para moteros con parqueadero seguro',
          benefit: '15% descuento para miembros', latitude: 4.72076, longitude: -73.96932,
          phone: '3115550101', address: 'Km 12 Vía La Calera', website: 'https://elviajero.com'),
        RefugioEntity(id: 2, name: 'Hotel Campestre La Ruta', type: 'hotel',
          description: 'Hotel con garaje cerrado para motos',
          benefit: '10% descuento en estadía', latitude: 4.65403, longitude: -74.05995,
          phone: '6015550202', address: 'Carrera 7 #72-50, Bogotá'),
        RefugioEntity(id: 3, name: 'Taller Moto-Auxilio 24h', type: 'taller',
          description: 'Taller mecánico con servicio de grúa 24/7',
          benefit: 'Asistencia gratuita para miembros', latitude: 4.63230, longitude: -74.07309,
          phone: '3005550303', address: 'Av. Caracas #45-20, Bogotá'),
        RefugioEntity(id: 4, name: 'Moto Posada El Parche', type: 'moto_posada',
          description: 'Hospedaje y punto de encuentro motero',
          benefit: 'Descuento especial del 20%', latitude: 4.72076, longitude: -73.96932,
          phone: '3105550404', address: 'Vía La Calera km 8'),
      ]));
    } catch (e) {
      emit(RefugiosError(e.toString()));
    }
  }

  void _onSos(SosRequested event, Emitter<RefugiosState> emit) {
    // Future: trigger SOS alert, send location to nearby members
    final current = state;
    if (current is RefugiosLoaded) {
      emit(RefugiosLoaded(refugios: current.refugios, selectedHostId: null));
    }
  }

  void _onContact(ContactHost event, Emitter<RefugiosState> emit) {
    final current = state;
    if (current is RefugiosLoaded) {
      emit(RefugiosLoaded(refugios: current.refugios, selectedHostId: event.hostId));
    }
  }
}
