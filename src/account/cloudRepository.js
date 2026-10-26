import { createId } from "../data.js";
import { downloadData } from "../storage.js";
import { validateData, freshData } from "../storage.js";

const RETRYABLE = new Set([502, 503, 504]);

function decodeWorkspace(value) {
  if (!value || typeof value !== "object" || !Number.isInteger(value.revision))
    throw new Error("The cloud workspace response was incomplete.");
  return {
    data: validateData(value.data),
    revision: value.revision,
    updatedAt: value.updatedAt ?? null,
  };
}

async function jsonResponse(response) {
  let body;
  try {
    body = await response.json();
  } catch {
    body = null;
  }
  return body;
}

function httpError(response, body) {
  const message =
    body?.message ||
    body?.error?.message ||
    `Cloud save failed (${response.status}).`;
  const error = new Error(message);
  error.status = response.status;
  error.body = body;
  return error;
}

export function createCloudRepository({
  fetchImpl = fetch,
  endpoint = "/api/workspace",
  makeId = createId,
  memberId,
  onUnauthorized = () => {},
  onAccountChanged = onUnauthorized,
} = {}) {
  let snapshot = {
    status: "loading",
    data: null,
    revision: null,
    updatedAt: null,
    issue: null,
    conflict: null,
  };
  let disposed = false;
  let generation = 0;
  let writeEpoch = 0;
  let queue = Promise.resolve();
  const listeners = new Set();
  const requests = new Set();
  const memberHeaders = () => (memberId ? { "X-Forma-Member": memberId } : {});
  const accountChanged = (body) => body?.error === "account_changed";
  const clearForAccountChange = (error, requestGeneration) => {
    error.accountChanged = true;
    publish(
      {
        status: "loading",
        data: null,
        revision: null,
        updatedAt: null,
        issue: error,
        conflict: null,
        retryPayload: null,
      },
      requestGeneration,
    );
    onAccountChanged();
  };
  const assertActive = (requestGeneration) => {
    if (disposed || requestGeneration !== generation) {
      const error = new Error(
        "The account workspace changed before this request completed.",
      );
      error.name = "AbortError";
      throw error;
    }
  };
  const publish = (next, requestGeneration = generation) => {
    if (disposed || requestGeneration !== generation) return;
    snapshot = next;
    listeners.forEach((listener) => listener());
  };

  async function request(url, options, requestGeneration) {
    assertActive(requestGeneration);
    const controller = new AbortController();
    requests.add(controller);
    try {
      const response = await fetchImpl(url, {
        ...options,
        signal: controller.signal,
      });
      assertActive(requestGeneration);
      return response;
    } catch (error) {
      assertActive(requestGeneration);
      throw error;
    } finally {
      requests.delete(controller);
    }
  }

  async function read(requestGeneration) {
    const response = await request(
      endpoint,
      {
        method: "GET",
        credentials: "same-origin",
        cache: "no-store",
        headers: { Accept: "application/json", ...memberHeaders() },
      },
      requestGeneration,
    );
    const body = await jsonResponse(response);
    assertActive(requestGeneration);
    if (response.status === 401) {
      onUnauthorized();
      const error = httpError(response, body);
      error.unauthorized = true;
      throw error;
    }
    if (accountChanged(body)) {
      const error = httpError(response, body);
      clearForAccountChange(error, requestGeneration);
      throw error;
    }
    if (!response.ok) throw httpError(response, body);
    return decodeWorkspace(body);
  }

  async function refresh({ resolveConflict = false } = {}) {
    if (disposed) return snapshot;
    if (
      snapshot.status === "saving" ||
      snapshot.retryPayload ||
      (snapshot.conflict && !resolveConflict)
    )
      return snapshot;
    const requestGeneration = generation;
    const readWriteEpoch = writeEpoch;
    const before = snapshot;
    publish(
      {
        ...snapshot,
        status: snapshot.data ? "refreshing" : "loading",
        issue: null,
      },
      requestGeneration,
    );
    try {
      const latest = await read(requestGeneration);
      assertActive(requestGeneration);
      // A write owns its acknowledgement, retry payload or conflict. Even a
      // matching-revision poll must not clear that state after the write starts.
      if (readWriteEpoch !== writeEpoch) return snapshot;
      // A focus/poll read that began before a write must not roll the client
      // back to an older server revision after the write is acknowledged.
      if (
        snapshot.status !== "saving" &&
        (snapshot.revision == null || latest.revision >= snapshot.revision)
      ) {
        publish(
          { status: "ready", ...latest, issue: null, conflict: null },
          requestGeneration,
        );
      } else if (
        snapshot.status === "refreshing" &&
        before.status !== "saving"
      ) {
        publish({ ...snapshot, status: "ready" }, requestGeneration);
      }
      return snapshot;
    } catch (error) {
      if (error.name === "AbortError") throw error;
      // Session failures still hide private data; an obsolete network failure
      // must not turn a newer successful save into an offline workspace.
      if (
        readWriteEpoch !== writeEpoch &&
        !error.unauthorized &&
        !error.accountChanged
      )
        return snapshot;
      if (error.unauthorized) {
        publish(
          {
            status: "guest",
            data: null,
            revision: null,
            updatedAt: null,
            issue: error,
            conflict: null,
          },
          requestGeneration,
        );
      } else {
        publish(
          {
            ...snapshot,
            status: snapshot.data ? "offline" : "error",
            issue: error,
          },
          requestGeneration,
        );
      }
      throw error;
    }
  }

  async function put(payload, requestGeneration) {
    const send = () =>
      request(
        endpoint,
        {
          method: "PUT",
          credentials: "same-origin",
          cache: "no-store",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            ...memberHeaders(),
          },
          body: JSON.stringify(payload),
        },
        requestGeneration,
      );
    let response;
    try {
      response = await send();
    } catch {
      assertActive(requestGeneration);
      // The server may have committed before the connection failed. Retrying
      // the identical body and operation ID makes this safe and idempotent.
      response = await send();
    }
    assertActive(requestGeneration);
    if (RETRYABLE.has(response.status)) response = await send();
    const body = await jsonResponse(response);
    assertActive(requestGeneration);
    if (response.status === 401) {
      onUnauthorized();
      const error = httpError(response, body);
      error.unauthorized = true;
      throw error;
    }
    if (response.status === 409) {
      if (accountChanged(body)) {
        const error = httpError(response, body);
        clearForAccountChange(error, requestGeneration);
        throw error;
      }
      const latestValue = body?.latest ?? body?.workspace ?? body;
      let latest = null;
      try {
        latest = decodeWorkspace(latestValue);
      } catch {
        // Keep the local candidate until a fresh read can replace it.
      }
      const error = httpError(response, body);
      error.conflict = true;
      error.latest = latest;
      throw error;
    }
    if (!response.ok) throw httpError(response, body);
    return decodeWorkspace(body?.workspace ?? body);
  }

  function enqueue(task, requestGeneration) {
    const execute = () => {
      assertActive(requestGeneration);
      return task(requestGeneration);
    };
    const operation = queue.then(execute, execute);
    queue = operation.catch(() => {});
    return operation;
  }

  return {
    getSnapshot: () => snapshot,
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    initialize() {
      // React StrictMode replays mount effects in development; re-activate the
      // same repository after its first cleanup. Each activation gets a new
      // generation, so its aborted requests can never publish into this one.
      disposed = false;
      generation += 1;
      return refresh();
    },
    refresh,
    async reloadConflict() {
      if (!snapshot.conflict)
        throw new Error("There is no cloud conflict to reload.");
      return refresh({ resolveConflict: true });
    },
    dispose() {
      disposed = true;
      generation += 1;
      requests.forEach((controller) => controller.abort());
      requests.clear();
      listeners.clear();
    },
    async commit(update, { operationId = makeId(), expectedRevision } = {}) {
      const requestGeneration = generation;
      return enqueue(async (activeGeneration) => {
        if (!snapshot.data || snapshot.status === "guest")
          throw new Error("Your private workspace is not ready to save.");
        // Whole-workspace replacements (restore/import) are pinned to the
        // revision the member reviewed, so newer cloud work from another
        // device is never silently overwritten.
        if (
          Number.isInteger(expectedRevision) &&
          expectedRevision !== snapshot.revision
        ) {
          const error = new Error(
            "Your cloud workspace changed after you reviewed this backup. Review it again before replacing your data.",
          );
          error.conflict = true;
          error.staleReview = true;
          throw error;
        }
        if (snapshot.conflict)
          throw new Error(
            "Resolve the cloud conflict before saving more changes.",
          );
        if (snapshot.retryPayload)
          throw new Error(
            "Retry the pending cloud save before making another change.",
          );
        const base = snapshot.data;
        const candidate = validateData({
          ...update(structuredClone(base)),
          revision: base.revision + 1,
        });
        const payload = {
          data: candidate,
          expectedRevision: snapshot.revision,
          operationId,
        };
        writeEpoch += 1;
        publish(
          { ...snapshot, status: "saving", issue: null, conflict: null },
          activeGeneration,
        );
        try {
          const saved = await put(payload, activeGeneration);
          publish(
            {
              status: "ready",
              ...saved,
              issue: null,
              conflict: null,
              retryPayload: null,
            },
            activeGeneration,
          );
          return { ...saved, saved: true, operationId };
        } catch (error) {
          if (error.name === "AbortError") throw error;
          if (error.unauthorized) {
            publish(
              {
                status: "guest",
                data: null,
                revision: null,
                updatedAt: null,
                issue: error,
                conflict: null,
              },
              activeGeneration,
            );
          } else if (error.accountChanged) {
            // Do not retain or offer the stale member's attempted payload for retry.
          } else if (error.conflict) {
            const latest = error.latest;
            publish(
              {
                status: "conflict",
                data: latest?.data ?? base,
                revision: latest?.revision ?? snapshot.revision,
                updatedAt: latest?.updatedAt ?? snapshot.updatedAt,
                issue: error,
                conflict: { attempted: candidate, operationId },
                retryPayload: null,
              },
              activeGeneration,
            );
          } else {
            publish(
              {
                ...snapshot,
                status: "offline",
                issue: error,
                retryPayload: payload,
              },
              activeGeneration,
            );
          }
          throw error;
        }
      }, requestGeneration);
    },
    async retry() {
      const requestGeneration = generation;
      return enqueue(async (activeGeneration) => {
        const payload = snapshot.retryPayload;
        if (!payload)
          throw new Error("There is no pending cloud save to retry.");
        writeEpoch += 1;
        publish(
          { ...snapshot, status: "saving", issue: null },
          activeGeneration,
        );
        try {
          const saved = await put(payload, activeGeneration);
          publish(
            {
              status: "ready",
              ...saved,
              issue: null,
              conflict: null,
              retryPayload: null,
            },
            activeGeneration,
          );
          return { ...saved, saved: true, operationId: payload.operationId };
        } catch (error) {
          if (error.name === "AbortError") throw error;
          if (error.unauthorized) {
            publish(
              {
                status: "guest",
                data: null,
                revision: null,
                updatedAt: null,
                issue: error,
                conflict: null,
                retryPayload: null,
              },
              activeGeneration,
            );
          } else if (error.accountChanged) {
            // The original member binding is no longer current; never retry this payload.
          } else if (error.conflict) {
            const latest = error.latest;
            publish(
              {
                status: "conflict",
                data: latest?.data ?? snapshot.data,
                revision: latest?.revision ?? snapshot.revision,
                updatedAt: latest?.updatedAt ?? snapshot.updatedAt,
                issue: error,
                conflict: {
                  attempted: payload.data,
                  operationId: payload.operationId,
                },
                retryPayload: null,
              },
              activeGeneration,
            );
          } else {
            publish(
              {
                ...snapshot,
                status: "offline",
                issue: error,
                retryPayload: payload,
              },
              activeGeneration,
            );
          }
          throw error;
        }
      }, requestGeneration);
    },
    async exportData() {
      const requestGeneration = generation;
      const response = await request(
        `${endpoint}/export`,
        {
          credentials: "same-origin",
          cache: "no-store",
          headers: { Accept: "application/json", ...memberHeaders() },
        },
        requestGeneration,
      );
      const body = await jsonResponse(response);
      assertActive(requestGeneration);
      if (accountChanged(body)) {
        const error = httpError(response, body);
        clearForAccountChange(error, requestGeneration);
        throw error;
      }
      if (!response.ok) throw httpError(response, body);
      if (typeof document !== "undefined")
        downloadData(body, "forma-account-export", false, false);
      return body;
    },
    async importLegacy(backup, { expectedRevision } = {}) {
      const safeBackup = validateData(backup);
      return this.commit(() => safeBackup, { expectedRevision });
    },
  };
}

export function emptyGuestWorkspace() {
  return freshData();
}
