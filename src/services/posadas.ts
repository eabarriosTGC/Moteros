import { supabase } from './supabase';

export interface Posada {
  id: string;
  name: string;
  description: string;
  location: string;
  latitude: number;
  longitude: number;
  start_date: string;
  end_date: string;
  capacity?: number;
  image_url?: string;
  organizer_id: string;
  created_at: string;
  updated_at: string;
}

export interface CreatePosadaInput {
  name: string;
  description: string;
  location: string;
  latitude: number;
  longitude: number;
  start_date: string;
  end_date: string;
  capacity?: number;
  image_url?: string;
}

export interface UpdatePosadaInput extends Partial<CreatePosadaInput> {
  id: string;
}

export async function getPosadas(options?: {
  upcoming?: boolean;
  limit?: number;
  offset?: number;
}): Promise<Posada[]> {
  let query = supabase.from('posadas').select('*').order('start_date', { ascending: true });

  if (options?.upcoming) {
    query = query.gte('start_date', new Date().toISOString());
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

  return (data || []) as Posada[];
}

export async function getPosadaById(id: string): Promise<Posada | null> {
  const { data, error } = await supabase
    .from('posadas')
    .select('*')
    .eq('id', id)
    .single();

  if (error) {
    return null;
  }

  return data as Posada;
}

export async function createPosada(
  input: CreatePosadaInput,
  organizerId: string,
): Promise<Posada | null> {
  const { data, error } = await supabase
    .from('posadas')
    .insert({
      ...input,
      organizer_id: organizerId,
    })
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data as Posada;
}

export async function updatePosada({ id, ...input }: UpdatePosadaInput): Promise<Posada | null> {
  const { data, error } = await supabase
    .from('posadas')
    .update(input)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data as Posada;
}
