/**
 * App constants used throughout the application.
 */

// App info
export const APP_NAME = 'Moteros';
export const APP_VERSION = '1.0.0';
export const APP_DESCRIPTION = 'Motorcycle community app';

// File and image settings
export const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
export const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
export const MAX_IMAGE_WIDTH = 1920;
export const MAX_IMAGE_HEIGHT = 1920;
export const IMAGE_QUALITY = 0.8;

// Pagination
export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;

// Distance settings
export const DEFAULT_SEARCH_RADIUS = 50; // km
export const MAX_SEARCH_RADIUS = 500; // km

// Map settings
export const DEFAULT_ZOOM = 12;
export const MIN_ZOOM = 3;
export const MAX_ZOOM = 18;

// Membership plans
export const MEMBERSHIP_PLANS = {
  basic: { name: 'Basic', price: 9.99, duration: 30 },
  premium: { name: 'Premium', price: 19.99, duration: 30 },
  vip: { name: 'VIP', price: 29.99, duration: 30 },
} as const;

// Place categories
export const PLACE_CATEGORIES = [
  'restaurant',
  'gas_station',
  'workshop',
  'scenic_route',
  'meeting_point',
  'hotel',
  'attraction',
  'other',
] as const;

// Suggestion categories
export const SUGGESTION_CATEGORIES = [
  'feature_request',
  'bug_report',
  'place_suggestion',
  'general',
] as const;

// Rate limiting
export const MAX_REQUESTS_PER_MINUTE = 60;
export const MAX_UPLOADS_PER_DAY = 50;

// QR code settings
export const QR_CODE_PREFIX = 'MOTEROS:';
export const QR_CODE_VERSION = '1.0';

// Cache settings
export const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes
export const MAX_CACHE_SIZE = 100;
