/**
 * API response types for communicating with backend services.
 */

export interface ApiResponse<T = unknown> {
  success: boolean;
  data: T;
  message?: string;
  error?: ApiError;
}

export interface PaginatedResponse<T = unknown> {
  data: T[];
  total: number;
  page: number;
  perPage: number;
  totalPages: number;
  hasMore: boolean;
}

export interface ApiError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
  statusCode?: number;
}

export interface ApiRequestConfig {
  headers?: Record<string, string>;
  timeout?: number;
  retries?: number;
  cache?: boolean;
}

export interface QueryParams {
  page?: number;
  limit?: number;
  sort?: string;
  order?: SortOrder;
  filter?: Record<string, unknown>;
  search?: string;
}

export type SortOrder = 'asc' | 'desc';
