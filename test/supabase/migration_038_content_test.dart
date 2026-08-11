import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/038_fix_check_achievements.sql')
      .readAsStringSync();

  group('038_fix_check_achievements.sql', () {
    test('califica public.* en las funciones de la cadena de logros', () {
      expect(sql, contains('FOR v_ach IN SELECT * FROM public.achievements'));
      expect(sql, contains('FROM public.user_achievements'));
      expect(sql, contains('UPDATE public.user_xp'));
      expect(sql, contains('level = public.xp_to_level(total_xp)'));
      expect(sql, contains('SELECT COALESCE(xp_reward / 2, 10) INTO v_coins_reward'));
      expect(sql, contains('FROM public.achievements WHERE id = NEW.achievement_id'));
    });

    test('ninguna referencia a achievements/user_xp sin calificar', () {
      // Líneas de código indentadas (el código de las funciones usa 4
      // espacios); los comentarios de evidencia sí citan la query rota.
      expect(RegExp(r'^    FROM (achievements|user_xp|raid_participants)\b', multiLine: true)
          .allMatches(sql), isEmpty);
      expect(RegExp(r'^    UPDATE (user_xp|user_achievements|raid_participants)\b', multiLine: true)
          .allMatches(sql), isEmpty);
    });

    test('todas las funciones con SET search_path = \'\' explícito', () {
      final definers = RegExp(r'CREATE OR REPLACE FUNCTION public\.([a-z_]+)\(\)')
          .allMatches(sql)
          .length;
      // Los atributos de la función van a nivel 0 (los comentarios de
      // evidencia también mencionan search_path pero con contexto).
      final searchPaths = RegExp("^SET search_path = ''", multiLine: true)
          .allMatches(sql)
          .length;
      expect(definers, greaterThanOrEqualTo(6));
      expect(searchPaths, definers);
    });

    test('los triggers no cambian', () {
      expect(sql, isNot(contains('CREATE TRIGGER')));
      expect(sql, isNot(contains('DROP TRIGGER')));
    });

    test('sin cambios a verify_raid_arrival ni a la acreditación', () {
      // El nombre solo aparece en los comentarios de evidencia.
      expect(sql, isNot(contains('CREATE OR REPLACE FUNCTION public.verify_raid_arrival')));
      expect(RegExp(r'RAISE EXCEPTION').allMatches(sql), isEmpty);
      expect(sql, isNot(contains('INSERT INTO public.raid_arrivals')));
    });
  });
}
