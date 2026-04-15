import { create } from 'zustand';

export type ThemeMode = 'light' | 'dark' | 'system';

interface UIState {
  theme: ThemeMode;
  isLoading: boolean;
  isRefreshing: boolean;
  activeModal: string | null;
  setTheme: (theme: ThemeMode) => void;
  setLoading: (loading: boolean) => void;
  setRefreshing: (refreshing: boolean) => void;
  openModal: (modalName: string) => void;
  closeModal: () => void;
  resetUI: () => void;
}

export const useUIStore = create<UIState>((set) => ({
  theme: 'system',
  isLoading: false,
  isRefreshing: false,
  activeModal: null,
  setTheme: (theme: ThemeMode) => set({ theme }),
  setLoading: (loading: boolean) => set({ isLoading: loading }),
  setRefreshing: (refreshing: boolean) => set({ isRefreshing: refreshing }),
  openModal: (modalName: string) => set({ activeModal: modalName }),
  closeModal: () => set({ activeModal: null }),
  resetUI: () =>
    set({
      isLoading: false,
      isRefreshing: false,
      activeModal: null,
    }),
}));
