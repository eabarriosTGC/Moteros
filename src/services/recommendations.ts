import { supabase } from './supabase';

export interface Recommendation {
  id: string;
  place_id: string;
  user_id: string;
  title: string;
  description: string;
  rating: number;
  image_urls?: string[];
  created_at: string;
  updated_at: string;
}

export interface CreateRecommendationInput {
  place_id: string;
  title: string;
  description: string;
  rating: number;
  image_urls?: string[];
}

export interface UpdateRecommendationInput extends Partial<CreateRecommendationInput> {
  id: string;
}

export async function getRecommendations(options?: {
  placeId?: string;
  userId?: string;
  limit?: number;
  offset?: number;
}): Promise<Recommendation[]> {
  let query = supabase
    .from('recommendations')
    .select('*')
    .order('created_at', { ascending: false });

  if (options?.placeId) {
    query = query.eq('place_id', options.placeId);
  }
  if (options?.userId) {
    query = query.eq('user_id', options.userId);
  }
  if (options?.limit) {
    query = query.limit(options.limit);
  }
  if (options?.offset) {
    query = query.range(options.offset, options.offset + (options.limit || 10) - 1);
  }

  const { data, error } = await query;

  if (error) {
    throw error;
  }

  return (data || []) as Recommendation[];
}

export async function getRecommendationById(id: string): Promise<Recommendation | null> {
  const { data, error } = await supabase
    .from('recommendations')
    .select('*')
    .eq('id', id)
    .single();

  if (error) {
    return null;
  }

  return data as Recommendation;
}

export async function createRecommendation(
  input: CreateRecommendationInput,
  userId: string,
): Promise<Recommendation | null> {
  const { data, error } = await supabase
    .from('recommendations')
    .insert({
      ...input,
      user_id: userId,
    })
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data as Recommendation;
}

export async function updateRecommendation({
  id,
  ...input
}: UpdateRecommendationInput): Promise<Recommendation | null> {
  const { data, error } = await supabase
    .from('recommendations')
    .update(input)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data as Recommendation;
}
