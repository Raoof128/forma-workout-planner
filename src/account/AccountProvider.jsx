import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { authClient, unwrapAuthResult } from "./client.js";

const AccountContext = createContext(null);
const GUEST_MODE = import.meta.env.VITE_ACCOUNT_MODE === "guest";

function normalizeUser(user) {
  if (!user) return null;
  return {
    id: user.id,
    name: user.name || "FORMA member",
    email: user.email || "",
    emailVerified: Boolean(user.emailVerified),
    createdAt: user.createdAt ?? null,
    image: user.image ?? null,
    twoFactorEnabled: Boolean(user.twoFactorEnabled),
  };
}

async function accountApi(path, method = "GET", memberId) {
  const response = await fetch(path, {
    method,
    credentials: "same-origin",
    cache: "no-store",
    headers: {
      Accept: "application/json",
      ...(memberId ? { "X-Forma-Member": memberId } : {}),
    },
  });
  let body;
  try {
    body = await response.json();
  } catch {
    body = null;
  }
  if (!response.ok) {
    const error = new Error(
      body?.message || body?.error || "Account request failed.",
    );
    error.status = response.status;
    error.code = body?.error;
    throw error;
  }
  return body;
}

export function AccountProvider({ children }) {
  const epoch = useRef(0);
  const refreshSequence = useRef(0);
  const [accountState, setAccountState] = useState({
    status: GUEST_MODE ? "guest" : "loading",
    user: null,
    error: null,
  });
  const memberId = accountState.user?.id;
  const boundOptions = useCallback(
    (id = memberId) => ({
      fetchOptions: { headers: id ? { "X-Forma-Member": id } : {} },
    }),
    [memberId],
  );
  const boundAccountApi = useCallback(
    (path, method = "GET", id = memberId) => accountApi(path, method, id),
    [memberId],
  );

  const refresh = useCallback(async () => {
    if (GUEST_MODE) {
      setAccountState({ status: "guest", user: null, error: null });
      return;
    }
    const requestEpoch = epoch.current;
    const requestSequence = ++refreshSequence.current;
    try {
      const session = unwrapAuthResult(await authClient.getSession());
      if (
        requestEpoch !== epoch.current ||
        requestSequence !== refreshSequence.current
      )
        return;
      const user = normalizeUser(session?.user);
      setAccountState({
        status: user ? "authenticated" : "guest",
        user,
        error: null,
      });
    } catch (error) {
      if (
        requestEpoch !== epoch.current ||
        requestSequence !== refreshSequence.current
      )
        return;
      // A failed session check must never be interpreted as a guest session.
      setAccountState({ status: "error", user: null, error });
    }
  }, []);

  useEffect(() => {
    if (GUEST_MODE) return undefined;
    void refresh();
    const onFocus = () => void refresh();
    const onVisibility = () => {
      if (document.visibilityState === "visible") void refresh();
    };
    const timer = window.setInterval(() => void refresh(), 60_000);
    window.addEventListener("focus", onFocus);
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      epoch.current += 1;
      window.clearInterval(timer);
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, [refresh]);

  useEffect(() => {
    if (GUEST_MODE || typeof BroadcastChannel === "undefined") return undefined;
    const channel = new BroadcastChannel("forma-account-session");
    channel.onmessage = () => void refresh();
    return () => channel.close();
  }, [refresh]);

  const run = useCallback(
    async (request, { refreshAfter = false } = {}) => {
      let result;
      try {
        result = unwrapAuthResult(await request());
      } catch (error) {
        if (error.status === 401 || error.code === "account_changed")
          await refresh();
        throw error;
      }
      if (refreshAfter) await refresh();
      else if (result?.user) {
        setAccountState({
          status: "authenticated",
          user: normalizeUser(result.user),
          error: null,
        });
      }
      if (result?.user || refreshAfter) {
        try {
          const channel = new BroadcastChannel("forma-account-session");
          channel.postMessage({ changed: true });
          channel.close();
        } catch {
          // Session polling and focus refresh remain the fallback.
        }
      }
      return result;
    },
    [refresh],
  );

  const signUp = useCallback(
    ({ name, email, password }) =>
      run(() => authClient.signUp.email({ name, email, password }), {
        refreshAfter: true,
      }),
    [run],
  );
  const signIn = useCallback(
    ({ email, password, rememberMe = true }) =>
      run(() => authClient.signIn.email({ email, password, rememberMe }), {
        refreshAfter: true,
      }),
    [run],
  );
  const signOut = useCallback(async () => {
    // Clear the private UI immediately; a server/network failure remains an
    // error state after the follow-up session check rather than guest data.
    const signingOutMember = accountState.user?.id;
    epoch.current += 1;
    setAccountState({ status: "loading", user: null, error: null });
    try {
      await run(() => authClient.signOut(boundOptions(signingOutMember)));
      await refresh();
      if (typeof BroadcastChannel !== "undefined") {
        const channel = new BroadcastChannel("forma-account-session");
        channel.postMessage({ changed: true });
        channel.close();
      }
    } catch (error) {
      if (error.status === 401) return;
      setAccountState({ status: "error", user: null, error });
      throw error;
    }
  }, [accountState.user?.id, boundOptions, refresh, run]);

  const methods = useMemo(() => {
    const call =
      (fn, options) =>
      (...args) =>
        run(() => fn(...args), options);
    const bind = (args = {}) => ({ ...args, ...boundOptions() });
    return {
      signUp,
      signIn,
      signOut,
      refresh,
      sendVerificationEmail: call((input = {}) => {
        const args = typeof input === "string" ? { email: input } : input;
        const request = {
          email: args.email || accountState.user?.email,
          ...args,
          callbackURL: args?.callbackURL || window.location.origin,
        };
        return authClient.sendVerificationEmail(
          memberId ? bind(request) : request,
        );
      }),
      requestPasswordReset: call((input) => {
        const args = typeof input === "string" ? { email: input } : input;
        return authClient.requestPasswordReset({
          ...args,
          redirectTo: args?.redirectTo || `${window.location.origin}/#account`,
        });
      }),
      resetPassword: call((args) => authClient.resetPassword(args)),
      updateProfile: call((args) => authClient.updateUser(bind(args)), {
        refreshAfter: true,
      }),
      changeEmail: call(
        (args) =>
          authClient.changeEmail(
            bind({
              ...args,
              callbackURL:
                args?.callbackURL || `${window.location.origin}/#account`,
            }),
          ),
        { refreshAfter: true },
      ),
      changePassword: call(
        (args) =>
          authClient.changePassword(
            bind({
              ...args,
              revokeOtherSessions: true,
            }),
          ),
        { refreshAfter: true },
      ),
      listSessions: call(async () => {
        return boundAccountApi("/api/account/sessions");
      }),
      revokeSession: call(({ id }) =>
        boundAccountApi(
          `/api/account/sessions/${encodeURIComponent(id)}/revoke`,
          "DELETE",
        ),
      ),
      signOutOthers: call(() =>
        boundAccountApi("/api/account/sessions/revoke-others", "POST"),
      ),
      signOutEverywhere: call(async () => {
        const result = await boundAccountApi(
          "/api/account/sessions/revoke-all",
          "POST",
        );
        epoch.current += 1;
        refreshSequence.current += 1;
        setAccountState({ status: "guest", user: null, error: null });
        if (typeof BroadcastChannel !== "undefined") {
          const channel = new BroadcastChannel("forma-account-session");
          channel.postMessage({ changed: true });
          channel.close();
        }
        return result;
      }),
      enableMFA: call((args) => authClient.twoFactor.enable(bind(args))),
      disableMFA: call((args) => authClient.twoFactor.disable(bind(args)), {
        refreshAfter: true,
      }),
      verifyMFA: call(
        (args) =>
          authClient.twoFactor.verifyTotp(
            bind({ ...args, trustDevice: false }),
          ),
        { refreshAfter: true },
      ),
      verifySignInMFA: call(
        (args) =>
          authClient.twoFactor.verifyTotp({
            ...args,
            trustDevice: false,
            ...boundOptions(),
          }),
        { refreshAfter: true },
      ),
      verifySignInBackupCode: call(
        (args) =>
          authClient.twoFactor.verifyBackupCode({
            ...args,
            trustDevice: false,
            ...boundOptions(),
          }),
        { refreshAfter: true },
      ),
      recoveryCodes: call(async (args = {}) => {
        const result = unwrapAuthResult(
          await authClient.twoFactor.generateBackupCodes(bind(args)),
        );
        return result?.backupCodes ?? result;
      }),
      deleteAccount: call((args) => authClient.deleteUser(bind(args)), {
        refreshAfter: true,
      }),
    };
  }, [
    accountState.user?.email,
    memberId,
    boundOptions,
    boundAccountApi,
    refresh,
    run,
    signIn,
    signOut,
    signUp,
  ]);

  const value = useMemo(
    () => ({ ...accountState, ...methods }),
    [accountState, methods],
  );
  return (
    <AccountContext.Provider value={value}>{children}</AccountContext.Provider>
  );
}

export function useAccount() {
  const value = useContext(AccountContext);
  if (!value)
    throw new Error("useAccount must be used inside AccountProvider.");
  return value;
}
