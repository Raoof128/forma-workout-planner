import { STORAGE_KEY, readStore, validateData } from "./storage.js";
import { createId } from "./data.js";

const RECOVERY_ERROR =
  "Recovery could not be saved. Download your original data and free up browser storage first.";
const CONFLICT_ERROR =
  "Your saved data changed while reviewing this backup. Choose the file again before restoring.";

// Browser adapters are injectable so failure and concurrency paths can be tested
// without React, a browser profile, or real training data.
export function createWorkoutRepository({
  read = readStore,
  write = (key, raw) => localStorage.setItem(key, raw),
  getLocks = () => navigator.locks,
  now = () => Date.now(),
  makeId = createId,
  checkpoint = () => new Promise((resolve) => setTimeout(resolve, 0)),
} = {}) {
  let snapshot = read();
  const listeners = new Set();
  const publish = (next) => {
    snapshot = next;
    listeners.forEach((listener) => listener());
  };
  const unavailable = () => {
    // Invalid data must remain on the recovery screen even if access is lost.
    if (snapshot.issue !== "invalid")
      publish({ ...snapshot, issue: "unavailable" });
  };
  async function locked(action, fallback) {
    let locks;
    try {
      locks = getLocks();
    } catch {
      return fallback();
    }
    if (!locks?.request) return fallback();
    let entered = false;
    try {
      return await locks.request("forma-store-write", async () => {
        entered = true;
        // localStorage implementations can retain a task-local snapshot.
        // Start a fresh task before reading, and let writes checkpoint before
        // releasing the lock to another tab. Keep both boundaries inside it.
        await checkpoint();
        try {
          return action();
        } finally {
          await checkpoint();
        }
      });
    } catch (error) {
      // A rejected mutation is not a lock failure and must never be retried.
      if (entered) throw error;
      return fallback();
    }
  }
  const nextData = (base, update, revision = base.revision) => {
    try {
      return validateData({
        ...update(structuredClone(base)),
        revision: revision + 1,
      });
    } catch (error) {
      if (error.name === "ZodError")
        throw new Error(
          "This change contains invalid workout data. Check the entered values and try again.",
        );
      throw error;
    }
  };
  function temporary(update) {
    if (!snapshot.data)
      throw new Error("Saved data needs recovery before you can make changes.");
    const data = nextData(snapshot.data, update);
    publish({ ...snapshot, data, issue: "unavailable" });
    return { data, saved: false };
  }
  return {
    getSnapshot: () => snapshot,
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    sync() {
      if (snapshot.issue === "unavailable") return;
      const latest = read();
      if (latest.issue === "unavailable") unavailable();
      else publish(latest);
    },
    async initialize() {
      return locked(() => {
        // A queued initialization must not replace temporary edits.
        if (snapshot.issue === "unavailable") return;
        const latest = read();
        if (latest.issue === "unavailable") {
          unavailable();
          return;
        }
        if (!latest.issue && latest.raw === null) {
          try {
            const raw = JSON.stringify(latest.data);
            write(STORAGE_KEY, raw);
            latest.raw = raw;
          } catch {
            latest.issue = "unavailable";
          }
        }
        publish(latest);
      }, unavailable);
    },
    async commit(update, options = {}) {
      const { recover = false, expectedRevision } = options;
      if (!recover && snapshot.issue === "unavailable")
        return temporary(update);
      return locked(
        () => {
          const latest = read();
          if (recover) {
            if (latest.issue === "unavailable") throw new Error(RECOVERY_ERROR);
            if (
              (Object.hasOwn(options, "expectedRaw") &&
                latest.raw !== options.expectedRaw) ||
              (expectedRevision !== undefined &&
                snapshot.data?.revision !== expectedRevision) ||
              (expectedRevision !== undefined &&
                snapshot.issue !== "unavailable" &&
                latest.data?.revision !== expectedRevision)
            ) {
              if (snapshot.issue !== "unavailable") publish(latest);
              throw new Error(CONFLICT_ERROR);
            }
          } else {
            if (latest.issue === "invalid") {
              publish(latest);
              throw new Error(
                "Saved data needs recovery before you can make changes.",
              );
            }
            if (
              latest.issue === "unavailable" ||
              snapshot.issue === "unavailable"
            )
              return temporary(update);
          }
          const base = recover ? snapshot.data || latest.data : latest.data;
          // Corrupt-data recovery has no valid base; its updater replaces it.
          const safeBase = base || { revision: 0 };
          let data;
          try {
            data = nextData(
              safeBase,
              update,
              Math.max(safeBase.revision, latest.data?.revision || 0),
            );
          } catch (error) {
            if (!recover && !latest.issue) publish(latest);
            throw error;
          }
          const raw = JSON.stringify(data);
          try {
            if (recover) {
              // Preserve both disk and unsaved memory when temporary mode is active.
              const originals = new Set([latest.raw]);
              if (snapshot.issue === "unavailable" && snapshot.data)
                originals.add(JSON.stringify(snapshot.data));
              for (const original of originals)
                if (original !== null)
                  write(
                    `${STORAGE_KEY}-recovery-${now()}-${makeId()}`,
                    original,
                  );
            }
            write(STORAGE_KEY, raw);
          } catch {
            if (recover) throw new Error(RECOVERY_ERROR);
            publish({ ...snapshot, data, issue: "unavailable" });
            return { data, saved: false };
          }
          publish({ data, issue: null, raw });
          return { data, saved: true };
        },
        () => {
          unavailable();
          if (recover)
            throw new Error(
              "This browser cannot safely save data. Use an up-to-date browser.",
            );
          return temporary(update);
        },
      );
    },
  };
}
