import { useCallback, useEffect, useState } from 'react';
import { visitsService } from '../services/visitsService';
import type { Visit } from '../types/database';
import type { VisitRecord } from '../types/models';

interface UseVisitsOptions {
  placeId?: string;
  userId?: string;
  limit?: number;
  startDate?: Date;
  endDate?: Date;
}

interface UseVisitsReturn {
  visits: Visit[];
  visitHistory: VisitRecord[];
  isLoading: boolean;
  hasMore: boolean;
  error: string | null;
  fetchVisits: (options?: UseVisitsOptions) => Promise<void>;
  recordVisit: (placeId: string, notes?: string) => Promise<void>;
  deleteVisit: (visitId: string) => Promise<void>;
  getVisitStats: () => Promise<{ total: number; thisMonth: number }>;
  refresh: () => Promise<void>;
}

/**
 * Hook that wraps the visits service for managing visit records.
 */
export function useVisits(): UseVisitsReturn {
  const [visits, setVisits] = useState<Visit[]>([]);
  const [visitHistory, setVisitHistory] = useState<VisitRecord[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchVisits = useCallback(async (options?: UseVisitsOptions) => {
    setIsLoading(true);
    setError(null);
    try {
      const result = await visitsService.getAll(options);
      setVisits(result.data);
      setHasMore(result.hasMore);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to fetch visits';
      setError(message);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const recordVisit = useCallback(async (placeId: string, notes?: string) => {
    setIsLoading(true);
    setError(null);
    try {
      const newVisit = await visitsService.create(placeId, notes);
      setVisits((prev) => [newVisit, ...prev]);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to record visit';
      setError(message);
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const deleteVisit = useCallback(async (visitId: string) => {
    setIsLoading(true);
    setError(null);
    try {
      await visitsService.delete(visitId);
      setVisits((prev) => prev.filter((v) => v.id !== visitId));
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to delete visit';
      setError(message);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const getVisitStats = useCallback(async () => {
    try {
      return await visitsService.getStats();
    } catch (err) {
      console.error('Failed to get visit stats:', err);
      return { total: 0, thisMonth: 0 };
    }
  }, []);

  const refresh = useCallback(async () => {
    setVisits([]);
    setVisitHistory([]);
    setHasMore(true);
    await fetchVisits();
  }, [fetchVisits]);

  useEffect(() => {
    fetchVisits();
  }, [fetchVisits]);

  return {
    visits,
    visitHistory,
    isLoading,
    hasMore,
    error,
    fetchVisits,
    recordVisit,
    deleteVisit,
    getVisitStats,
    refresh,
  };
}
