import { supabase } from './supabase';

export interface Visit {
  id: string;
  place_id: string;
  user_id: string;
  visit_date: string;
  notes?: string;
  rating?: number;
  image_urls?: string[];
  created_at: string;
  updated_at: string;
}

export interface CreateVisitInput {
  place_id: string;
  visit_date: string;
  notes?: string;
  rating?: number;
  image_urls?: string[];
}

export interface UpdateVisitInput extends Partial<CreateVisitInput> {
  id: string;
}

export async function registerVisit(
  input: CreateVisitInput,
  userId: string,
): Promise<Visit | null> {
  const { data, error } = await supabase
    .from('visits')
    .insert({
      ...input,
      user_id: userId,
    })
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data as Visit;
}

export async function getVisits(options?: {
  userId?: string;
  placeId?: string;
  limit?: number;
  offset?: number;
}): Promise<Visit[]> {
  let query = supabase.from('visits').select('*').order('visit_date', { ascending: false });

  if (options?.userId) {
    query = query.eq('user_id', options.userId);
  }
  if (options?.placeId) {
    query = query.eq('place_id', options.placeId);
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

  return (data || []) as Visit[];
}

export async function getVisitById(id: string): Promise<Visit | null> {
  const { data, error } = await supabase
    .from('visits')
    .select('*')
    .eq('id', id)
    .single();

  if (error) {
    return null;
  }

  return data as Visit;
}

export async function updateVisit({ id, ...input }: UpdateVisitInput): Promise<Visit | null> {
  const { data, error } = await supabase
    .from('visits')
    .update(input)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data as Visit;
}
