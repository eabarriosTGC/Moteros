import type { User, Place, Visit, Membership } from './database';

/**
 * App data models - derived types used throughout the application.
 * These are higher-level models built from the base database types.
 */

export interface UserProfile extends Omit<User, 'created_at' | 'updated_at'> {
  membership?: MembershipDetail;
  visitCount?: number;
  recommendationsCount?: number;
}

export interface PlaceDetail extends Place {
  distance?: number;
  isVisited?: boolean;
  lastVisitDate?: string;
  recommendationCount?: number;
  averageRating?: number;
}

export interface VisitRecord extends Omit<Visit, 'created_at'> {
  placeName?: string;
  placeImage?: string;
  placeAddress?: string;
}

export interface MembershipDetail extends Membership {
  daysRemaining: number;
  isExpiringSoon: boolean;
  planName: string;
}

export interface NotificationItem {
  id: string;
  title: string;
  message: string;
  type: 'info' | 'warning' | 'success' | 'error';
  read: boolean;
  createdAt: string;
  actionUrl?: string;
}

export interface SearchFilters {
  query: string;
  region: string | null;
  category: string | null;
  maxDistance: number | null;
  isVerified: boolean | null;
  sortBy: 'name' | 'distance' | 'rating' | 'recent';
}

export interface LocationCoordinates {
  latitude: number;
  longitude: number;
  accuracy?: number;
  altitude?: number;
  heading?: number;
  speed?: number;
}

export interface ImageAttachment {
  id: string;
  uri: string;
  url?: string;
  width?: number;
  height?: number;
  size?: number;
  mimeType?: string;
}
