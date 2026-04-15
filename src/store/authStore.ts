import { create } from 'zustand';
import { supabase } from '../services/supabase';
import { User } from '@supabase/supabase-js';

interface AuthState {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  checkAuth: () => Promise<void>;
  signIn: (email: string, password: string) => Promise<{ error: any }>;
  signUp: (email: string, password: string, fullName: string) => Promise<{ error: any }>;
  signOut: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isLoading: true,
  isAuthenticated: false,

  checkAuth: async () => {
    const {  { session } } = await supabase.auth.getSession();
    set({ 
      user: session?.user ?? null, 
      isAuthenticated: !!session, 
      isLoading: false 
    });
  },

  signIn: async (email, password) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (!error) {
      await useAuthStore.getState().checkAuth();
    }
    return { error };
  },

  signUp: async (email, password, fullName) => {
    const { error } = await supabase.auth.signUp({ 
      email, 
      password,
      options: {  { full_name: fullName } }
    });
    return { error };
  },

  signOut: async () => {
    await supabase.auth.signOut();
    set({ user: null, isAuthenticated: false });
  },
}));
