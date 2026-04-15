import { supabase } from './supabase';

export interface Place {
  id: string;
  name: string;
  description: string;
  latitude: number;
  longitude: number;
  address: string;
  city: string;
  region: string;
  country: string;
  image_url?: string;
  created_at: string;
  updated_at: string;
  created_by: string;
}

export interface CreatePlaceInput {
  name: string;
  description: string;
  latitude: number;
  longitude: number;
  address: string;
  city: string;
  region: string;
  country: string;
  image_url?: string;
}

export interface UpdatePlaceInput extends Partial<CreatePlaceInput> {
  id: string;
}

export async function getPlaces(options?: {
  limit?: number;
  offset?: number;
  search?: string;
}): Promise<Place[]> {
  let query = supabase.from('places').select('*').order('created_at', { ascending: false });

  if (options?.limit) {
    query = query.limit(options.limit);
  }
  if (options?.offset) {
    query = query.range(options.offset, options.offset + (options.limit || 10) - 1);
  }
  if (options?.search) {
    query = query.ilike('name', `%${options.search}%`);
  }

  const { data, error } = await query;

  if (error) {
    throw error;
  }

  return (data || []) as Place[];
}

export async function getPlaceById(id: string): Promise<Place | null> {
  const { data, error } = await supabase
    .from('places')
    .select('*')
    .eq('id', id)
    .single();

  if (error) {
    return null;
  }

  return data as Place;
}

export async function createPlace(input: CreatePlaceInput, userId: string): Promise<Place | null> {
  const { data, error } = await supabase
    .from('places')
    .insert({
      ...input,
      created_by: userId,
    })
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data as Place;
}

export async function updatePlace({ id, ...input }: UpdatePlaceInput): Promise<Place | null> {
  const { data, error } = await supabase
    .from('places')
    .update(input)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data as Place;
}

export async function deletePlace(id: string): Promise<{ success: boolean; error: string | null }> {
  const { error } = await supabase.from('places').delete().eq('id', id);

  if (error) {
    return { success: false, error: error.message };
  }

  return { success: true, error: null };
}

export async function suggestPlace(
  input: CreatePlaceInput,
  userId: string,
): Promise<{ success: boolean; error: string | null }> {
  const { error } = await supabase.from('place_suggestions').insert({
    ...input,
    suggested_by: userId,
    status: 'pending',
  });

  if (error) {
    return { success: false, error: error.message };
  }

  return { success: true, error: null };
}
