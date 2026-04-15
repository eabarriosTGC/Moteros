import { useState, useCallback, useEffect } from 'react';
import * as Location from 'expo-location';
import type { LocationObject, LocationAccuracy } from 'expo-location';

interface UseLocationReturn {
  location: LocationObject | null;
  isLoading: boolean;
  error: string | null;
  hasPermission: boolean | null;
  getLocation: () => Promise<LocationObject | null>;
  watchLocation: (accuracy?: LocationAccuracy) => Promise<void>;
  stopWatching: () => void;
  calculateDistance: (
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
  ) => number;
}

/**
 * Hook for GPS location functionality using expo-location.
 */
export function useLocation(): UseLocationReturn {
  const [location, setLocation] = useState<LocationObject | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [locationSubscription, setLocationSubscription] =
    useState<Location.LocationSubscription | null>(null);

  const requestPermission = useCallback(async () => {
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      const granted = status === 'granted';
      setHasPermission(granted);
      return granted;
    } catch (err) {
      console.error('Location permission error:', err);
      setHasPermission(false);
      return false;
    }
  }, []);

  const getLocation = useCallback(async (): Promise<LocationObject | null> => {
    setIsLoading(true);
    setError(null);
    try {
      const granted = await requestPermission();
      if (!granted) {
        setError('Location permission denied');
        return null;
      }

      const currentLocation = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Balanced,
      });
      setLocation(currentLocation);
      return currentLocation;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to get location';
      setError(message);
      return null;
    } finally {
      setIsLoading(false);
    }
  }, [requestPermission]);

  const watchLocation = useCallback(async (accuracy?: LocationAccuracy) => {
    const granted = await requestPermission();
    if (!granted) {
      setError('Location permission denied');
      return;
    }

    const subscription = await Location.watchPositionAsync(
      {
        accuracy: accuracy || Location.Accuracy.Balanced,
        distanceInterval: 10,
      },
      (newLocation) => {
        setLocation(newLocation);
      }
    );
    setLocationSubscription(subscription);
  }, [requestPermission]);

  const stopWatching = useCallback(() => {
    if (locationSubscription) {
      locationSubscription.remove();
      setLocationSubscription(null);
    }
  }, [locationSubscription]);

  const calculateDistance = useCallback(
    (lat1: number, lon1: number, lat2: number, lon2: number): number => {
      const R = 6371000; // Earth's radius in meters
      const dLat = ((lat2 - lat1) * Math.PI) / 180;
      const dLon = ((lon2 - lon1) * Math.PI) / 180;
      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((lat1 * Math.PI) / 180) *
          Math.cos((lat2 * Math.PI) / 180) *
          Math.sin(dLon / 2) *
          Math.sin(dLon / 2);
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      return R * c; // Distance in meters
    },
    []
  );

  useEffect(() => {
    return () => {
      if (locationSubscription) {
        locationSubscription.remove();
      }
    };
  }, [locationSubscription]);

  return {
    location,
    isLoading,
    error,
    hasPermission,
    getLocation,
    watchLocation,
    stopWatching,
    calculateDistance,
  };
}
