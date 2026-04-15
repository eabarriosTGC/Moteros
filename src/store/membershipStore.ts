import { create } from 'zustand';
import { getMembershipStatus, checkMembership, type MembershipStatus } from '../services/membership';

interface MembershipState {
  membership: MembershipStatus | null;
  isLoading: boolean;
  error: string | null;
  checkMembership: (userId: string) => Promise<void>;
  resetMembership: () => void;
}

export const useMembershipStore = create<MembershipState>((set) => ({
  membership: null,
  isLoading: false,
  error: null,
  checkMembership: async (userId: string) => {
    set({ isLoading: true, error: null });
    try {
      const status = await getMembershipStatus(userId);
      set({ membership: status, isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Unknown error',
        isLoading: false,
      });
    }
  },
  resetMembership: () => set({ membership: null, isLoading: false, error: null }),
}));
