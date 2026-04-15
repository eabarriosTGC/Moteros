import { supabase } from './supabase';
import type { User } from '@supabase/supabase-js';

export interface MembershipStatus {
  isActive: boolean;
  membershipType: string;
  startDate: string;
  endDate: string;
  isExpired: boolean;
}

export async function checkMembership(userId: string): Promise<MembershipStatus | null> {
  const { data, error } = await supabase
    .from('memberships')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (error || !data) {
    return null;
  }

  const endDate = new Date(data.end_date);
  const isExpired = endDate < new Date();

  return {
    isActive: data.is_active && !isExpired,
    membershipType: data.membership_type,
    startDate: data.start_date,
    endDate: data.end_date,
    isExpired,
  };
}

export async function getMembershipStatus(userId: string): Promise<MembershipStatus | null> {
  return checkMembership(userId);
}

export async function renewMembership(userId: string): Promise<{ success: boolean; error: string | null }> {
  const { data, error } = await supabase.rpc('renew_membership', {
    p_user_id: userId,
  });

  if (error) {
    return { success: false, error: error.message };
  }

  return { success: true, error: null };
}
