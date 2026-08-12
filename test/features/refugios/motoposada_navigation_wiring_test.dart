import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Explorar opens a real motoposada detail with its model', () {
    final source = File(
      'lib/features/explorar/presentation/screens/explorar_screen.dart',
    ).readAsStringSync();
    expect(source, contains('MotoposadaDetailScreen('));
    expect(source, contains('initialMotoposada: mp'));
    expect(source, isNot(contains('Navigate to detail — placeholder')));
  });

  test('featured card has a visible fallback for legacy empty titles', () {
    final source = File(
      'lib/features/explorar/presentation/widgets/featured_motoposada_card.dart',
    ).readAsStringSync();
    expect(source, contains('motoposada.title.trim().isEmpty'));
    expect(source, contains('Motoposada\${'));
  });

  test('public casa card requests before exposing approved contact', () {
    final source = File(
      'lib/features/refugios/presentation/widgets/casa_motero_card.dart',
    ).readAsStringSync();
    expect(source, contains('VER Y SOLICITAR'));
    expect(source, contains('MotoposadaDetailScreen('));
    expect(source, isNot(contains("label: const Text('Contactar'")));
  });

  test('Progreso does not race listing and eligibility states', () {
    final source = File(
      'lib/features/progression/presentation/screens/progreso_screen.dart',
    ).readAsStringSync();
    expect(source, contains('LoadMyMotoposadas'));
    expect(source, isNot(contains('CheckCasaMoteroEligibility')));
    expect(source, contains("actionLabel: 'GESTIONAR'"));
  });

  test('management exposes stays, sanctions and server-gated moderation', () {
    final source = File(
      'lib/features/refugios/presentation/screens/my_motoposada_screen.dart',
    ).readAsStringSync();
    expect(source, contains("Tab(text: 'RECIBIDAS')"));
    expect(source, contains("Tab(text: 'MIS ESTANCIAS')"));
    expect(source, contains('MyMotoposadaAppealsScreen'));
    expect(source, contains('get_motoposada_moderation_queue'));
    expect(source, contains('if (_canModerate)'));
    expect(source, contains('_openListingEdit'));
    expect(source, contains('initialMotoposada: mp'));
    expect(source, contains('_receivedError'));
    expect(source, contains('_myStaysError'));
  });

  test('standard listing edit updates instead of creating a duplicate', () {
    final source = File(
      'lib/features/refugios/presentation/screens/create_motoposada_screen.dart',
    ).readAsStringSync();
    expect(source, contains('UpdateMotoposada('));
    expect(source, contains("'EDITAR \${_type.toUpperCase()}'"));
    expect(source, contains('this.existing'));
  });

  test('request inbox queries have a finite timeout', () {
    final source = File(
      'lib/features/refugios/presentation/bloc/motoposadas_bloc.dart',
    ).readAsStringSync();
    expect(
      RegExp(r'timeout\(const Duration\(seconds: 12\)\)')
          .allMatches(source)
          .length,
      greaterThanOrEqualTo(2),
    );
    expect(source, contains('guests:users!motoposada_requests_guest_id_fkey'));
    expect(
      source,
      contains('motoposadas!motoposada_requests_motoposada_id_fkey'),
    );
    expect(source, isNot(contains('guests!inner')));
  });

  test('Rodar has a motoposada filter and opens the safe request flow', () {
    final source = File(
      'lib/features/dashboard/presentation/screens/rodar_screen.dart',
    ).readAsStringSync();
    expect(source, contains("label: const Text('Motoposadas')"));
    expect(source, contains('_showMotoposadas'));
    expect(source, contains("label: const Text('VER Y SOLICITAR')"));
    expect(source, contains('initialMotoposada: mp'));
  });

  test('Rodar place count includes active motoposadas', () {
    final source = File(
      'lib/features/dashboard/presentation/screens/rodar_screen.dart',
    ).readAsStringSync();
    expect(source, contains('activeMotoposadas'));
    expect(source, contains('state.placesVisited + activeMotoposadas'));
  });

  test('detail never renders public coordinates or exact address', () {
    final source = File(
      'lib/features/refugios/presentation/screens/motoposada_detail_screen.dart',
    ).readAsStringSync();
    expect(source, contains('reverseGeocodeLocality'));
    expect(source, contains('ADMINISTRAR MOTOPOSADA'));
    expect(source, isNot(contains('mp.lat.toStringAsFixed')));
    expect(source, isNot(contains('mp.lng.toStringAsFixed')));
    expect(source, isNot(contains("Text(\n                          mp.address")));
  });

  test('public locality resolver has no coordinate fallback', () {
    final source = File(
      'lib/core/services/geocoding_service.dart',
    ).readAsStringSync();
    final method = source.split('reverseGeocodeLocality').last;
    expect(method, contains('return null'));
    expect(method, isNot(contains('toStringAsFixed')));
    expect(method, isNot(contains('p.street')));
  });
}
