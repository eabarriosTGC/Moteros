import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bloc = File('lib/features/refugios/presentation/bloc/motoposadas_bloc.dart').readAsStringSync();
  final ui = File('lib/features/refugios/presentation/screens/my_motoposada_screen.dart').readAsStringSync();
  test('cliente usa v2 sin enviar identidad ni rol', () {
    final start = bloc.indexOf("'submit_motoposada_review_v2'");
    final body = bloc.substring(start, bloc.indexOf('emit(const ReviewSubmitted())', start));
    expect(body, contains("'p_request_id'"));
    expect(body, contains("'p_rating'"));
    expect(body, isNot(contains("'p_to_user_id'")));
    expect(body, isNot(contains("'p_type'")));
  });
  test('UI solo ofrece evaluar estancias completadas y evita duplicado', () {
    expect(ui, contains("req.status == 'completed'"));
    expect(ui, contains('!req.hasReviewed'));
    expect(ui, contains('EVALUAR HUÉSPED'));
    expect(ui, contains('EVALUAR ANFITRIÓN'));
    expect(ui, contains('maxLength: 500'));
  });
}
