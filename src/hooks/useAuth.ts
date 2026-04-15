import { useCallback, useEffect, useState } from 'react';
import { useAuthStore } from '../store/authStore';
import type { UserProfile } from '../types/models';

interface UseAuthReturn {
  user: UserProfile | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, name: string) => Promise<void>;
  signOut: () => Promise<void>;
  updateProfile: (data: Partial<UserProfile>) => Promise<void>;
  resetPassword: (email: string) => Promise<void>;
}

/**
 * Hook that wraps the authStore for authentication operations.
 * Provides signIn, signUp, signOut, updateProfile, and resetPassword.
 */
export function useAuth(): UseAuthReturn {
  const {
    user,
    isLoading,
    isAuthenticated,
    signIn,
    signUp,
    signOut,
    updateProfile,
    resetPassword,
    initialize,
  } = useAuthStore();

  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    const init = async () => {
      try {
        await initialize();
      } catch (error) {
        console.error('Failed to initialize auth:', error);
      } finally {
        setIsInitialized(true);
      }
    };
    init();
  }, [initialize]);

  const handleSignIn = useCallback(
    async (email: string, password: string) => {
      await signIn(email, password);
    },
    [signIn]
  );

  const handleSignUp = useCallback(
    async (email: string, password: string, name: string) => {
      await signUp(email, password, name);
    },
    [signUp]
  );

  const handleSignOut = useCallback(async () => {
    await signOut();
  }, [signOut]);

  const handleUpdateProfile = useCallback(
    async (data: Partial<UserProfile>) => {
      await updateProfile(data);
    },
    [updateProfile]
  );

  const handleResetPassword = useCallback(
    async (email: string) => {
      await resetPassword(email);
    },
    [resetPassword]
  );

  return {
    user: isInitialized ? user : null,
    isLoading: isLoading || !isInitialized,
    isAuthenticated: isInitialized && isAuthenticated,
    signIn: handleSignIn,
    signUp: handleSignUp,
    signOut: handleSignOut,
    updateProfile: handleUpdateProfile,
    resetPassword: handleResetPassword,
  };
}
