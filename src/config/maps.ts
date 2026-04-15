/**
 * Maps configuration.
 * Settings for map display, markers, and navigation.
 */

export const mapsConfig = {
  // Default region coordinates (Spain - motorcycle-friendly region)
  defaultRegion: {
    latitude: 40.4168,
    longitude: -3.7038,
    latitudeDelta: 5,
    longitudeDelta: 5,
  },

  // Zoom levels
  zoom: {
    min: 3,
    max: 18,
    default: 12,
    street: 15,
    city: 12,
    region: 8,
    country: 5,
  },

  // Marker settings
  markers: {
    size: 40,
    pinColor: '#1E3A5F',
    selectedPinColor: '#D97706',
    clusterColor: '#2C5282',
    clusterTextColor: '#FFFFFF',
  },

  // Route settings
  route: {
    strokeColor: '#1E3A5F',
    strokeWidth: 4,
    strokeOpacity: 0.8,
    alternateStrokeColor: '#D97706',
  },

  // Location tracking
  tracking: {
    enabled: true,
    showUserLocation: true,
    followUserLocation: true,
    accuracyCircle: true,
    accuracyCircleColor: 'rgba(30, 58, 95, 0.2)',
    accuracyCircleStrokeColor: 'rgba(30, 58, 95, 0.5)',
  },

  // Map style
  style: {
    light: 'mapbox://styles/mapbox/light-v11',
    dark: 'mapbox://styles/mapbox/dark-v11',
    outdoor: 'mapbox://styles/mapbox/outdoors-v12',
    satellite: 'mapbox://styles/mapbox/satellite-streets-v12',
  },

  // Search settings
  search: {
    maxResults: 20,
    debounceMs: 300,
    types: ['address', 'poi', 'place'],
    countries: ['es', 'pt', 'fr'],
  },

  // Provider configuration
  provider: {
    // 'google' | 'apple' | 'mapbox' | 'openstreetmap'
    name: 'openstreetmap' as const,
    apiKey: process.env.EXPO_PUBLIC_MAPS_API_KEY || '',
  },
};

export default mapsConfig;
