import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bloc = File('lib/features/refugios/presentation/bloc/motoposadas_bloc.dart').readAsStringSync();
  final ui = File('lib/features/refugios/presentation/screens/my_motoposada_screen.dart').readAsStringSync();

  test('cliente reporta y bloquea solo por request_id', () {
    expect(bloc, contains("'report_motoposada_incident'"));
    expect(bloc, contains("'block_motoposada_participant'"));
    expect(bloc, contains("'p_request_id': event.requestId"));
    expect(bloc, isNot(contains("'p_reported_id'")));
    expect(bloc, isNot(contains("'p_blocked_id'")));
  });

  test('UI limita reporte y confirma bloqueo', () {
    expect(ui, contains('REPORTAR INCIDENTE'));
    expect(ui, contains('BLOQUEAR USUARIO'));
    expect(ui, contains('maxLength: 1000'));
    expect(ui, contains('description.length >= 10'));
    expect(ui, contains('_confirmBlock(req)'));
  });
}
