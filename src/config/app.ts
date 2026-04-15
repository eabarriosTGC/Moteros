/**
 * App configuration.
 * Central configuration for the Moteros application.
 */

export const appConfig = {
  // App info
  name: 'Moteros',
  displayName: 'Moteros',
  version: '1.0.0',
  buildNumber: 1,

  // Environment
  environment: (__DEV__ ? 'development' : 'production') as
    | 'development'
    | 'production'
    | 'staging',

  // API URLs
  apiUrl: process.env.EXPO_PUBLIC_API_URL || 'https://api.example.com',
  websocketUrl: process.env.EXPO_PUBLIC_WEBSOCKET_URL || 'wss://api.example.com/ws',

  // Feature flags
  features: {
    enableNotifications: true,
    enableMap: true,
    enableQRScanner: true,
    enableMembership: true,
    enablePosadas: true,
    enableRecommendations: true,
    enableSuggestions: true,
  },

  // Debug settings
  debug: {
    enabled: __DEV__,
    logLevel: __DEV__ ? 'debug' : 'error',
    showDevMenu: __DEV__,
  },

  // Analytics
  analytics: {
    enabled: !__DEV__,
    trackingId: process.env.EXPO_PUBLIC_ANALYTICS_ID || '',
  },
};

export default appConfig;
