import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/activate_membership.dart';
import 'membership_event.dart';
import 'membership_state.dart';

class MembershipBloc extends Bloc<MembershipEvent, MembershipState> {
  final ActivateMembershipUseCase _activateMembership;

  MembershipBloc({required this._activateMembership})
      : super(MembershipInitial()) {
    on<LoadMembership>(_onLoad);
    on<ActivateMembership>(_onActivate);
  }

  Future<void> _onLoad(
    LoadMembership event,
    Emitter<MembershipState> emit,
  ) async {
    emit(MembershipLoading());
    try {
      final membership = await _activateMembership.getCurrent();
      if (membership != null && membership.isActive) {
        emit(MembershipActive(membership));
      } else {
        emit(NoMembership());
      }
    } catch (e) {
      emit(const MembershipError('Error al cargar membresia'));
    }
  }

  Future<void> _onActivate(
    ActivateMembership event,
    Emitter<MembershipState> emit,
  ) async {
    emit(MembershipActivating());
    try {
      final paymentId = 'PAY-${DateTime.now().millisecondsSinceEpoch}';
      final membership = await _activateMembership.execute(
        paymentId: paymentId,
        plan: event.plan,
      );
      emit(MembershipActive(membership));
    } catch (e) {
      emit(MembershipError(e.toString()));
    }
  }
}
