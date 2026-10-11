import { useCallback, useEffect, useRef, useState } from "react";
import { STORAGE_KEY, freshData, readStore, validateData } from "../storage";

// Every mutation reads the latest snapshot while holding the shared origin lock.
// No render effect writes a stale component-state snapshot back to storage.
export function useWorkoutStore() {
  const [snapshot, setSnapshot] = useState(readStore);
  const snapshotRef = useRef(snapshot);
  const pendingRef = useRef(0);
  const [pending, setPending] = useState(0);
  useEffect(() => {
    const warn = (event) => {
      if (pendingRef.current > 0) {
        event.preventDefault();
        event.returnValue = "";
      }
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, []);
  const adopt = useCallback((next) => {
    snapshotRef.current = next;
    setSnapshot(next);
  }, []);
  useEffect(() => {
    const sync = (event) => {
      if (
        (event.key === STORAGE_KEY || event.key === null) &&
        snapshotRef.current.issue !== "unavailable"
      ) {
        const latest = readStore();
        adopt(
          latest.issue === "unavailable"
            ? { ...snapshotRef.current, issue: "unavailable" }
            : latest,
        );
      }
    };
    window.addEventListener("storage", sync);
    return () => window.removeEventListener("storage", sync);
  }, [adopt]);
  useEffect(() => {
    let mounted = true;
    async function initialize() {
      if (!navigator.locks?.request) {
        if (mounted && snapshotRef.current.issue !== "invalid")
          adopt({ ...snapshotRef.current, issue: "unavailable" });
        return;
      }
      await navigator.locks.request("forma-store-write", () => {
        if (!mounted) return;
        const latest = readStore();
        if (!latest.issue && latest.raw === null) {
          try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(latest.data));
          } catch {
            latest.issue = "unavailable";
          }
        }
        adopt(latest);
      });
    }
    void initialize();
    return () => {
      mounted = false;
    };
  }, [adopt]);
  const commit = useCallback(
    async (update, { recover = false } = {}) => {
      pendingRef.current += 1;
      setPending(pendingRef.current);
      try {
        if (!recover && snapshotRef.current.issue === "unavailable") {
          const data = validateData(update(snapshotRef.current.data));
          adopt({ data, issue: "unavailable", raw: null });
          return { data, saved: false };
        }
        async function apply() {
          const latest = readStore();
          if (latest.issue === "invalid" && !recover) {
            adopt(latest);
            throw new Error(
              "Saved data needs recovery before you can make changes.",
            );
          }
          if (
            !recover &&
            (latest.issue === "unavailable" ||
              snapshotRef.current.issue === "unavailable")
          ) {
            const data = validateData(update(snapshotRef.current.data));
            adopt({ data, issue: "unavailable", raw: null });
            return { data, saved: false };
          }
          const base = recover
            ? latest.data || freshData()
            : snapshotRef.current.issue === "unavailable"
              ? snapshotRef.current.data
              : latest.data;
          let data;
          try {
            data = validateData({
              ...update(base),
              revision: (base.revision || 0) + 1,
            });
          } catch (error) {
            if (!latest.issue) adopt(latest);
            throw error;
          }
          try {
            if (recover && latest.raw !== null)
              localStorage.setItem(
                `${STORAGE_KEY}-recovery-${Date.now()}`,
                latest.raw,
              );
            localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
            adopt({ data, issue: null, raw: null });
            return { data, saved: true };
          } catch {
            if (recover)
              throw new Error(
                "Recovery could not be saved. Download your original data and free up browser storage first.",
              );
            adopt({ data, issue: "unavailable", raw: null });
            return { data, saved: false };
          }
        }
        if (navigator.locks?.request)
          return await navigator.locks.request("forma-store-write", apply);
        // Do not risk concurrent writes in browsers without a shared locking API.
        if (!recover && snapshotRef.current.data) {
          const data = validateData(update(snapshotRef.current.data));
          adopt({ data, issue: "unavailable", raw: null });
          return { data, saved: false };
        }
        throw new Error(
          "This browser cannot safely save data. Use an up-to-date browser.",
        );
      } finally {
        pendingRef.current -= 1;
        setPending(pendingRef.current);
      }
    },
    [adopt],
  );
  return { ...snapshot, commit, saving: pending > 0 };
}
