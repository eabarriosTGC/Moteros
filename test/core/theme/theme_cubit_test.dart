/// ThemeCubit tests — verifies theme management with SharedPreferences persistence.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:moteros_app/core/theme/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeCubit', () {
    // ── Initial state ──

    test('initial state is ThemeMode.dark', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = ThemeCubit();
      // Wait for async _load to complete
      await Future.delayed(const Duration(milliseconds: 50));
      expect(cubit.state, equals(ThemeMode.dark));
    });

    // ── toggle() ──

    blocTest<ThemeCubit, ThemeMode>(
      'toggle() switches from dark to light',
      build: () {
        SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
        return ThemeCubit();
      },
      act: (cubit) async {
        await Future.delayed(const Duration(milliseconds: 50));
        await cubit.toggle();
      },
      // _load() emits dark first, then toggle() emits light
      expect: () => [ThemeMode.dark, ThemeMode.light],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'toggle() switches from light to dark',
      build: () {
        SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
        return ThemeCubit();
      },
      act: (cubit) async {
        await Future.delayed(const Duration(milliseconds: 50));
        await cubit.toggle();
      },
      // _load() emits light first, then toggle() emits dark
      expect: () => [ThemeMode.light, ThemeMode.dark],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'toggle() persists the value to SharedPreferences',
      build: () {
        SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
        return ThemeCubit();
      },
      act: (cubit) async {
        await Future.delayed(const Duration(milliseconds: 50));
        await cubit.toggle();
      },
      expect: () => [ThemeMode.dark, ThemeMode.light],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), equals('light'));
      },
    );

    // ── Persistence restoration ──

    blocTest<ThemeCubit, ThemeMode>(
      'restores light mode from SharedPreferences on startup',
      build: () {
        SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
        return ThemeCubit();
      },
      // After _load completes, the state should be light
      wait: const Duration(milliseconds: 100),
      expect: () => [ThemeMode.light],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'defaults to dark when no saved preference exists',
      build: () {
        SharedPreferences.setMockInitialValues({});
        return ThemeCubit();
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [ThemeMode.dark],
    );

    // ── setMode() ──

    blocTest<ThemeCubit, ThemeMode>(
      'setMode(ThemeMode.light) changes state and persists',
      build: () {
        SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
        return ThemeCubit();
      },
      act: (cubit) async {
        await Future.delayed(const Duration(milliseconds: 50));
        await cubit.setMode(ThemeMode.light);
      },
      // _load() emits dark first, then setMode() emits light
      expect: () => [ThemeMode.dark, ThemeMode.light],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), equals('light'));
      },
    );

    blocTest<ThemeCubit, ThemeMode>(
      'setMode(ThemeMode.dark) changes state and persists',
      build: () {
        SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
        return ThemeCubit();
      },
      act: (cubit) async {
        await Future.delayed(const Duration(milliseconds: 50));
        await cubit.setMode(ThemeMode.dark);
      },
      // _load() emits light first, then setMode() emits dark
      expect: () => [ThemeMode.light, ThemeMode.dark],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), equals('dark'));
      },
    );
  });
}
