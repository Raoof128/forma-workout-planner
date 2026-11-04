import { initialData } from "../src/data.js";

export function deferred() {
  let resolve;
  const promise = new Promise((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

export function fixtureState() {
  const data = structuredClone(initialData);
  data.profile = { ...data.profile, name: "Web Audit Member", goal: 4 };
  data.history = [
    {
      id: "web-audit-workout",
      name: "Morning strength",
      date: "2026-11-03T22:00:00.000Z",
      startedAt: Date.parse("2026-11-03T21:20:00.000Z"),
      duration: 2400,
      notes: "Synthetic audit fixture",
      restSeconds: 90,
      restEnd: null,
      restPaused: null,
      exercises: [
        {
          exerciseId: "bench",
          sets: [
            { weight: 50, reps: 8, done: true },
            { weight: 50, reps: 8, done: true },
          ],
        },
      ],
    },
  ];
  return {
    signedIn: true,
    failWorkspace: false,
    putFailure: 0,
    revision: 0,
    data,
    user: {
      id: "mem_web-audit-member",
      name: "Web Audit Member",
      email: "web-audit@example.test",
      emailVerified: true,
      createdAt: "2026-10-01T00:00:00.000Z",
      twoFactorEnabled: false,
    },
    requests: [],
    puts: [],
  };
}

// Intercept every API path: race fixtures must never reach a live account API.
// The configured origin also lets the same cases exercise production previews.
export async function installAccountRoutes(page, state, baseURL) {
  const origin = new URL(baseURL).origin;
  await page.route("**/api/**", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (url.origin !== origin) return route.abort();
    const path = url.pathname;
    state.requests.push({ path, method: request.method() });
    const json = (body) => route.fulfill({ json: body });
    if (path === "/api/auth/get-session")
      return json(
        state.signedIn
          ? {
              user: state.user,
              session: {
                userId: state.user.id,
                expiresAt: "2026-12-01T00:00:00.000Z",
                createdAt: "2026-11-04T09:00:00.000Z",
              },
            }
          : null,
      );
    if (path === "/api/workspace" && request.method() === "GET") {
      await state.getGate?.();
      return state.failWorkspace
        ? route.fulfill({
            status: 503,
            json: { error: "workspace_unavailable" },
          })
        : json({
            data: state.data,
            revision: state.revision,
            updatedAt: "2026-11-04T09:00:00.000Z",
          });
    }
    if (path === "/api/workspace" && request.method() === "PUT") {
      const payload = request.postDataJSON();
      state.puts.push(payload);
      state.onPut?.(payload);
      await state.putGate?.(payload);
      if (state.conflictData) {
        state.revision += 1;
        state.data = {
          ...structuredClone(state.conflictData),
          revision: state.revision,
        };
        return route.fulfill({
          status: 409,
          json: {
            error: "stale_revision",
            message: "Training data changed on another device.",
            data: state.data,
            revision: state.revision,
            updatedAt: "2026-11-04T09:01:00.000Z",
          },
        });
      }
      if (state.putFailure === true || state.putFailure > 0) {
        if (typeof state.putFailure === "number") state.putFailure -= 1;
        return route.fulfill({
          status: 503,
          json: { error: "workspace_unavailable" },
        });
      }
      state.revision += 1;
      state.data = { ...payload.data, revision: state.revision };
      return json({
        data: state.data,
        revision: state.revision,
        updatedAt: "2026-11-04T09:01:00.000Z",
      });
    }
    if (path === "/api/auth/update-user") {
      await state.profileGate?.();
      state.user = { ...state.user, ...request.postDataJSON() };
      return json({ status: true });
    }
    if (path === "/api/workspace/export") return json(state.data);
    return route.fulfill({
      status: 404,
      json: { error: "Unexpected isolated fixture request" },
    });
  });
}
