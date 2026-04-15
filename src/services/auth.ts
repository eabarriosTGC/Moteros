import { supabase } from './supabase';
import type { User, Session } from '@supabase/supabase-js';

export interface SignUpCredentials {
  email: string;
  password: string;
  name?: string;
}

export interface SignInCredentials {
  email: string;
  password: string;
}

export async function signIn({
  email,
  password,
}: SignInCredentials): Promise<{ user: User | null; session: Session | null; error: Error | null }> {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  return { user: data.user, session: data.session, error };
}

export async function signUp({
  email,
  password,
  name,
}: SignUpCredentials): Promise<{ user: User | null; error: Error | null }> {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { name },
    },
  });

  return { user: data.user, error };
}

export async function signOut(): Promise<{ error: Error | null }> {
  const { error } = await supabase.auth.signOut();
  return { error };
}

export async function getCurrentUser(): Promise<User | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}

export async function resetPassword(email: string): Promise<{ error: Error | null }> {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${process.env.EXPO_PUBLIC_APP_URL}/reset-password`,
  });

  return { error };
}
