import { supabase } from './supabase';

export interface AspirantApplication {
  id: string;
  user_id: string;
  status: 'pending' | 'approved' | 'rejected';
  submitted_at: string;
  updated_at: string;
}

export interface Challenge {
  id: string;
  title: string;
  description: string;
  order: number;
  required_for_membership: boolean;
}

export interface ChallengeSubmission {
  id: string;
  challenge_id: string;
  user_id: string;
  description: string;
  image_urls?: string[];
  status: 'pending' | 'approved' | 'rejected';
  submitted_at: string;
}

export async function applyAsAspirant(
  userId: string,
  additionalInfo?: Record<string, unknown>,
): Promise<{ success: boolean; error: string | null }> {
  const { error } = await supabase.from('aspirant_applications').insert({
    user_id: userId,
    status: 'pending',
    additional_info: additionalInfo,
  });

  if (error) {
    return { success: false, error: error.message };
  }

  return { success: true, error: null };
}

export async function getChallenges(): Promise<Challenge[]> {
  const { data, error } = await supabase
    .from('challenges')
    .select('*')
    .order('order', { ascending: true });

  if (error) {
    throw error;
  }

  return (data || []) as Challenge[];
}

export async function submitChallenge(
  challengeId: string,
  userId: string,
  description: string,
  imageUrls?: string[],
): Promise<ChallengeSubmission | null> {
  const { data, error } = await supabase
    .from('challenge_submissions')
    .insert({
      challenge_id: challengeId,
      user_id: userId,
      description,
      image_urls: imageUrls,
      status: 'pending',
    })
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data as ChallengeSubmission;
}

export async function getApplicationStatus(
  userId: string,
): Promise<AspirantApplication | null> {
  const { data, error } = await supabase
    .from('aspirant_applications')
    .select('*')
    .eq('user_id', userId)
    .order('submitted_at', { ascending: false })
    .limit(1)
    .single();

  if (error) {
    return null;
  }

  return data as AspirantApplication;
}
