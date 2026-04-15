import '@testing-library/jest-native/extend-expect';

// Mock expo modules
jest.mock('expo-font', () => ({
  Font: {
    isLoaded: jest.fn(() => true),
    loadAsync: jest.fn(),
  },
}));

jest.mock('expo-location', () => ({
  requestForegroundPermissionsAsync: jest.fn(),
  getCurrentPositionAsync: jest.fn(),
}));

jest.mock('expo-camera', () => ({
  Camera: {
    requestPermissionsAsync: jest.fn(),
  },
}));
