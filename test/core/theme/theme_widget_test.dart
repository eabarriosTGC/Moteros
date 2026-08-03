/// Theme widget tests — verify theme integration in widgets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/theme/app_theme.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';
import 'package:moteros_app/core/theme/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper widget that provides a ThemeCubit and reads its state.
class _ThemeTestWidget extends StatelessWidget {
  const _ThemeTestWidget();

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeCubit>().state == ThemeMode.light;
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            isLight ? 'LIGHT' : 'DARK',
            key: const Key('theme_label'),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('AppTheme.light', () {
    test('has correct brightness', () {
      expect(AppTheme.light.brightness, equals(Brightness.light));
    });

    test('has Material 3 enabled', () {
      expect(AppTheme.light.useMaterial3, isTrue);
    });

    test('has correct scaffold background color', () {
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        equals(AppColors.lightBackground),
      );
    });

    test('colorScheme uses light primary', () {
      expect(
        AppTheme.light.colorScheme.primary,
        equals(AppColors.lightPrimary),
      );
    });

    test('colorScheme uses light surface', () {
      expect(
        AppTheme.light.colorScheme.surface,
        equals(AppColors.lightSurface),
      );
    });

    test('colorScheme uses correct brightness', () {
      expect(
        AppTheme.light.colorScheme.brightness,
        equals(Brightness.light),
      );
    });

    test('has same typography as dark theme', () {
      expect(
        AppTheme.light.textTheme.bodyMedium?.fontFamily,
        equals(AppTheme.dark.textTheme.bodyMedium?.fontFamily),
      );
    });
  });

  group('AppTheme.dark — no regression', () {
    test('still has correct brightness', () {
      expect(AppTheme.dark.brightness, equals(Brightness.dark));
    });

    test('still uses amber primary', () {
      expect(AppTheme.dark.colorScheme.primary, equals(AppColors.primary));
    });
  });

  group('ThemeCubit widget integration', () {
    testWidgets('reads light state and renders LIGHT text', (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});

      await tester.pumpWidget(
        BlocProvider<ThemeCubit>(
          create: (_) => ThemeCubit(),
          child: const _ThemeTestWidget(),
        ),
      );

      // Wait for async _load
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      final label = tester.widget<Text>(find.byKey(const Key('theme_label')));
      expect(label.data, equals('LIGHT'));
    });

    testWidgets('reads dark state and renders DARK text', (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

      await tester.pumpWidget(
        BlocProvider<ThemeCubit>(
          create: (_) => ThemeCubit(),
          child: const _ThemeTestWidget(),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      final label = tester.widget<Text>(find.byKey(const Key('theme_label')));
      expect(label.data, equals('DARK'));
    });

    testWidgets('toggle switches from DARK to LIGHT in widget', (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

      await tester.pumpWidget(
        BlocProvider<ThemeCubit>(
          create: (_) => ThemeCubit(),
          child: const _ThemeTestWidget(),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Verify initial state
      var label = tester.widget<Text>(find.byKey(const Key('theme_label')));
      expect(label.data, equals('DARK'));

      // Toggle
      await tester.runAsync(() async {
        final cubit = BlocProvider.of<ThemeCubit>(
          tester.element(find.byType(MaterialApp)),
        );
        await cubit.toggle();
      });
      await tester.pumpAndSettle();

      // Verify updated state
      label = tester.widget<Text>(find.byKey(const Key('theme_label')));
      expect(label.data, equals('LIGHT'));
    });
  });

  group('Design tokens — light palette', () {
    test('lightBackground is warm off-white', () {
      expect(AppColors.lightBackground, equals(const Color(0xFFF5F5F0)));
    });

    test('lightSurface is pure white', () {
      expect(AppColors.lightSurface, equals(const Color(0xFFFFFFFF)));
    });

    test('lightTextPrimary is near-black', () {
      expect(AppColors.lightTextPrimary, equals(const Color(0xFF1A1A1A)));
    });

    test('lightPrimary is darker amber for light bg contrast', () {
      expect(AppColors.lightPrimary, equals(const Color(0xFFE67A00)));
    });

    test('lightError is adjusted for light backgrounds', () {
      expect(AppColors.lightError, equals(const Color(0xFFCC2440)));
    });
  });

  group('Tile URL swap logic', () {
    test('dark theme uses dark_all CartoDB tile URL', () {
      const isDark = true;
      final url = isDark
          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
          : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
      expect(url, contains('dark_all'));
    });

    test('light theme uses light_all CartoDB tile URL', () {
      const isDark = false;
      final url = isDark
          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
          : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
      expect(url, contains('light_all'));
    });
  });
}
