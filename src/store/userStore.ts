import { create } from 'zustand';

export interface UserProfile {
  id: string;
  name: string;
  email: string;
  avatar_url?: string;
  phone?: string;
  bio?: string;
  motorcycle_model?: string;
  joined_date: string;
  updated_at: string;
}

interface UserState {
  profile: UserProfile | null;
  isLoading: boolean;
  error: string | null;
  updateProfile: (profile: Partial<UserProfile>) => Promise<void>;
  setProfile: (profile: UserProfile | null) => void;
  resetProfile: () => void;
}

export const useUserStore = create<UserState>((set) => ({
  profile: null,
  isLoading: false,
  error: null,
  updateProfile: async (profile: Partial<UserProfile>) => {
    set({ isLoading: true, error: null });
    try {
      // TODO: Implement Supabase profile update
      set((state) => ({
        profile: state.profile ? { ...state.profile, ...profile } : null,
        isLoading: false,
      }));
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Unknown error',
        isLoading: false,
      });
    }
  },
  setProfile: (profile: UserProfile | null) => set({ profile, error: null }),
  resetProfile: () => set({ profile: null, isLoading: false, error: null }),
}));
