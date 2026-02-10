import type { ReactNode } from "react";

/*
  Minimal auth stub
  - Purpose: Provide a no-op AuthProvider + useAuth so existing imports continue to work.
  - Reason: Keeps app simple while preserving external API (signIn/signOut callbacks).
*/

// Simple local type describing the returned auth shape.
type AuthContextType = {
  user: string | null;
  signIn: (username: string, callback?: () => void) => void;
  signOut: (callback?: () => void) => void;
};

// AuthProvider: no-op wrapper so app structure stays the same.
export function AuthProvider({ children }: { children: ReactNode }) {
  return <>{children}</>;
}

// useAuth: returns a stubbed auth API.
// Note: callbacks are called immediately so calling code that passes callbacks keeps working.
export function useAuth(): AuthContextType {
  return {
    user: null,
    signIn: (_username: string, callback?: () => void) => {
      if (callback) callback(); // Immediately invoke callback to preserve previous flow
    },
    signOut: (callback?: () => void) => {
      if (callback) callback(); // Immediately invoke callback to preserve previous flow
    },
  };
}
