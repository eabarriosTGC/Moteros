import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;
  setUpAll(() => sql = File('supabase/migrations/045_fix_auto_create_default_ranks.sql').readAsStringSync());

  test('auto_create_default_ranks califica club_ranks y fija search_path', () {
    expect(sql, contains('CREATE OR REPLACE FUNCTION public.auto_create_default_ranks'));
    expect(sql, contains("SET search_path = ''"));
    expect(sql, contains('INSERT INTO public.club_ranks'));
    expect(sql, isNot(contains('INSERT INTO club_ranks')), reason: 'sin refs sin calificar');
  });

  test('enforce_single_presidente califica club_members', () {
    expect(sql, contains('CREATE OR REPLACE FUNCTION public.enforce_single_presidente'));
    expect(sql, contains('SELECT 1 FROM public.club_members'));
    expect(sql, isNot(contains('FROM club_members')), reason: 'sin refs sin calificar');
  });
}
