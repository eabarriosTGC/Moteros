/**
 * Supabase configuration.
 * Configuration for connecting to Supabase backend.
 */

export const supabaseConfig = {
  // Supabase URL and anon key (public, safe for client)
  url: process.env.EXPO_PUBLIC_SUPABASE_URL || 'https://your-project.supabase.co',
  anonKey: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || 'your-anon-key',

  // Database schema
  schema: 'public',

  // Tables
  tables: {
    users: 'users',
    places: 'places',
    visits: 'visits',
    recommendations: 'recommendations',
    posadas: 'posadas',
    aspirants: 'aspirants',
    memberships: 'memberships',
    suggestions: 'suggestions',
  } as const,

  // Storage buckets
  storage: {
    avatars: 'avatars',
    placeImages: 'place-images',
    visitImages: 'visit-images',
    recommendationImages: 'recommendation-images',
    posadaImages: 'posada-images',
  } as const,

  // Realtime channels
  realtime: {
    places: 'places:channel',
    recommendations: 'recommendations:channel',
  } as const,

  // RPC functions
  functions: {
    getNearbyPlaces: 'get_nearby_places',
    recordVisit: 'record_visit',
    updateMembership: 'update_membership',
  } as const,

  // Configuration options
  options: {
    autoRefreshToken: true,
    detectSessionInUrl: true,
    persistSession: true,
    storageKey: 'moteros-auth',
  },
};

export default supabaseConfig;
