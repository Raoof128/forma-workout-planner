import {
  useCallback,
  useEffect,
  useRef,
  useState,
  useMemo,
  useSyncExternalStore,
} from "react";
import { STORAGE_KEY } from "../storage";
import { createWorkoutRepository } from "../persistence";
import { createCloudRepository } from "../account/cloudRepository.js";

export function useWorkoutStore(account) {
  const accountStatus = account.status;
  const accountUserId = account.user?.id;
  const refreshAccount = account.refresh;
  const [guestRepository] = useState(createWorkoutRepository);
  const cloudRepository = useMemo(
    () =>
      accountStatus === "authenticated" && accountUserId
        ? createCloudRepository({
            memberId: accountUserId,
            onUnauthorized: () => refreshAccount(),
            onAccountChanged: () => refreshAccount(),
          })
        : null,
    [accountStatus, accountUserId, refreshAccount],
  );
  const repository =
    accountStatus === "authenticated" ? cloudRepository : guestRepository;
  const snapshot = useSyncExternalStore(
    repository?.subscribe || guestRepository.subscribe,
    repository?.getSnapshot || guestRepository.getSnapshot,
  );
  const pendingRef = useRef(0);
  const [pending, setPending] = useState(0);
  useEffect(() => {
    if (accountStatus === "loading" || accountStatus === "error") return;
    if (accountStatus === "authenticated") {
      void cloudRepository?.initialize().catch(() => {});
      const warn = (event) => {
        const state = cloudRepository?.getSnapshot();
        if (pendingRef.current > 0 || state?.retryPayload || state?.conflict) {
          event.preventDefault();
          event.returnValue = "";
        }
      };
      window.addEventListener("beforeunload", warn);
      return () => {
        window.removeEventListener("beforeunload", warn);
        cloudRepository?.dispose();
      };
    }
    if (accountStatus !== "guest") return;
    const warn = (event) => {
      if (pendingRef.current > 0) {
        event.preventDefault();
        event.returnValue = "";
      }
    };
    const sync = (event) => {
      if (event.key === STORAGE_KEY || event.key === null)
        guestRepository.sync();
    };
    window.addEventListener("beforeunload", warn);
    window.addEventListener("storage", sync);
    void guestRepository.initialize();
    return () => {
      window.removeEventListener("beforeunload", warn);
      window.removeEventListener("storage", sync);
    };
  }, [accountStatus, cloudRepository, guestRepository]);
  useEffect(() => {
    if (accountStatus !== "authenticated" || !cloudRepository) return;
    const sync = () => void cloudRepository.refresh().catch(() => {});
    const timer = window.setInterval(sync, 30_000);
    window.addEventListener("focus", sync);
    return () => {
      window.clearInterval(timer);
      window.removeEventListener("focus", sync);
    };
  }, [accountStatus, cloudRepository]);
  const commit = useCallback(
    async (update, options) => {
      if (accountStatus === "loading" || accountStatus === "error")
        throw new Error("Your account session could not be verified.");
      if (accountStatus === "authenticated" && !cloudRepository)
        throw new Error("Your private workspace is still loading.");
      pendingRef.current += 1;
      setPending(pendingRef.current);
      try {
        return await (accountStatus === "authenticated"
          ? cloudRepository.commit(update, options)
          : guestRepository.commit(update, options));
      } finally {
        pendingRef.current -= 1;
        setPending(pendingRef.current);
      }
    },
    [accountStatus, cloudRepository, guestRepository],
  );
  if (accountStatus === "loading" || accountStatus === "error")
    return {
      data: null,
      issue: accountStatus === "error" ? "auth-error" : "loading",
      raw: null,
      commit,
      saving: false,
      status: accountStatus,
      repository: null,
    };
  if (accountStatus === "authenticated")
    return {
      ...snapshot,
      issue: snapshot.issue,
      raw: null,
      commit,
      saving: pending > 0 || snapshot.status === "saving",
      status: snapshot.status,
      repository: cloudRepository,
    };
  return {
    ...snapshot,
    commit,
    saving: pending > 0,
    status: snapshot.issue ? "offline" : "ready",
    repository: guestRepository,
  };
}
