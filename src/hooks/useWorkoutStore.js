import {
  useCallback,
  useEffect,
  useRef,
  useState,
  useSyncExternalStore,
} from "react";
import { STORAGE_KEY } from "../storage";
import { createWorkoutRepository } from "../persistence";

export function useWorkoutStore() {
  const [repository] = useState(createWorkoutRepository);
  const snapshot = useSyncExternalStore(
    repository.subscribe,
    repository.getSnapshot,
  );
  const pendingRef = useRef(0);
  const [pending, setPending] = useState(0);
  useEffect(() => {
    const warn = (event) => {
      if (pendingRef.current > 0) {
        event.preventDefault();
        event.returnValue = "";
      }
    };
    const sync = (event) => {
      if (event.key === STORAGE_KEY || event.key === null) repository.sync();
    };
    window.addEventListener("beforeunload", warn);
    window.addEventListener("storage", sync);
    void repository.initialize();
    return () => {
      window.removeEventListener("beforeunload", warn);
      window.removeEventListener("storage", sync);
    };
  }, [repository]);
  const commit = useCallback(
    async (update, options) => {
      pendingRef.current += 1;
      setPending(pendingRef.current);
      try {
        return await repository.commit(update, options);
      } finally {
        pendingRef.current -= 1;
        setPending(pendingRef.current);
      }
    },
    [repository],
  );
  return { ...snapshot, commit, saving: pending > 0 };
}
