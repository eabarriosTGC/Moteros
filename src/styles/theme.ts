/**
 * Theme constants - colors, spacing, typography, and shared styles.
 * Replaces NativeWind/Tailwind with native StyleSheet values.
 */
import { Platform } from 'react-native';

export const colors = {
  gray: {
    900: '#111827',
    800: '#1f2937',
    700: '#374151',
    600: '#4b5563',
    500: '#6b7280',
    400: '#9ca3af',
    300: '#d1d5db',
    200: '#e5e7eb',
  },
  amber: {
    500: '#f59e0b',
    600: '#d97706',
  },
  orange: {
    500: '#f97316',
    600: '#ea580c',
  },
  red: {
    500: '#ef4444',
    600: '#dc2626',
    700: '#b91c1c',
  },
  green: {
    500: '#22c55e',
  },
  blue: {
    500: '#3b82f6',
  },
  cyan: {
    500: '#06b6d4',
  },
  emerald: {
    500: '#10b981',
    600: '#059669',
  },
  yellow: {
    500: '#eab308',
  },
  pink: {
    500: '#ec4899',
  },
  purple: {
    500: '#a855f7',
    600: '#4f46e5',
  },
  white: '#ffffff',
  black: '#000000',
  transparent: 'transparent',
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  '2xl': 24,
  '3xl': 32,
  '4xl': 48,
  '5xl': 64,
};

export const fontSize = {
  xs: 10,
  sm: 12,
  base: 14,
  lg: 16,
  xl: 18,
  '2xl': 20,
  '3xl': 24,
  '4xl': 32,
};

export const borderRadius = {
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  '2xl': 24,
  full: 9999,
};

export const shadow = {
  sm: {
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 1,
  },
  md: {
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 3,
  },
  lg: {
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 5,
  },
};

export const safeAreaTop = Platform.OS === 'ios' ? 50 : 12;
export const safeAreaBottom = Platform.OS === 'ios' ? 34 : 8;
