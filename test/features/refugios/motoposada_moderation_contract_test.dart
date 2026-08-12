import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin UI delegates identity and sanction target to PostgreSQL', () {
    final dart = File('lib/features/refugios/presentation/screens/motoposada_moderation_screen.dart').readAsStringSync();
    expect(dart, contains("'decide_motoposada_incident'"));
    expect(dart, contains("'p_report_id'"));
    expect(dart, isNot(contains("'reported_id'")));
    expect(dart, isNot(contains("'moderator_id'")));
  });
}
