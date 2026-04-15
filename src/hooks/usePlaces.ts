import { useCallback, useEffect, useState } from 'react';
import { placesService } from '../services/placesService';
import type { Place } from '../types/database';

interface UsePlacesOptions {
  region?: string;
  category?: string;
  searchQuery?: string;
  limit?: number;
}

interface UsePlacesReturn {
  places: Place[];
  isLoading: boolean;
  hasMore: boolean;
  error: string | null;
  fetchPlaces: (options?: UsePlacesOptions) => Promise<void>;
  fetchPlaceById: (id: string) => Promise<Place | null>;
  searchPlaces: (query: string, options?: UsePlacesOptions) => Promise<Place[]>;
  refresh: () => Promise<void>;
}

/**
 * Hook that wraps the places service for fetching and searching places.
 */
export function usePlaces(): UsePlacesReturn {
  const [places, setPlaces] = useState<Place[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchPlaces = useCallback(async (options?: UsePlacesOptions) => {
    setIsLoading(true);
    setError(null);
    try {
      const result = await placesService.getAll(options);
      setPlaces(result.data);
      setHasMore(result.hasMore);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to fetch places';
      setError(message);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const fetchPlaceById = useCallback(async (id: string): Promise<Place | null> => {
    setIsLoading(true);
    setError(null);
    try {
      const place = await placesService.getById(id);
      return place;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to fetch place';
      setError(message);
      return null;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const searchPlaces = useCallback(
    async (query: string, options?: UsePlacesOptions): Promise<Place[]> => {
      setIsLoading(true);
      setError(null);
      try {
        const results = await placesService.search(query, options);
        return results;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to search places';
        setError(message);
        return [];
      } finally {
        setIsLoading(false);
      }
    },
    []
  );

  const refresh = useCallback(async () => {
    setPlaces([]);
    setHasMore(true);
    await fetchPlaces();
  }, [fetchPlaces]);

  useEffect(() => {
    fetchPlaces();
  }, [fetchPlaces]);

  return {
    places,
    isLoading,
    hasMore,
    error,
    fetchPlaces,
    fetchPlaceById,
    searchPlaces,
    refresh,
  };
}
