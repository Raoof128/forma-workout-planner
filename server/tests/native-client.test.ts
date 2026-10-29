import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import { base32 } from "@better-auth/utils/base32";
import { createOTP } from "@better-auth/utils/otp";
import { createApp, isNativeClientRequest } from "../app.js";
import { clearEmailSink, inspectEmailSink } from "../email.js";
import type { AppConfig } from "../config.js";

// The iOS app has no Origin, so the origin accepts a request that names itself
// `X-Forma-Client: ios` and carries none of the headers a browser always adds,
// and the auth proxy vouches for it to Better Auth. Everything else is the
// ordinary account stack, exercised here on real PostgreSQL.

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_native_${suffix}`;
const appOrigin = "https://native.forma.test";
const workerSecret = `native-worker-secret-${suffix}`;
const config: AppConfig = {
  environment: "test",
  appOrigin,
  authSecret: `native-auth-secret-${suffix}`,
  workerSharedSecret: workerSecret,
  emailFrom: "FORMA <accounts@forma.test>",
  emailSinkEnabled: true,
};
const password = "a sufficiently long FORMA passphrase";
const iosAgent = "FORMA/1.0 CFNetwork/1568.200.51 Darwin/24.0.0";
const adminPool = databaseUrl
  ? new Pool({ connectionString: databaseUrl })
  : null;
const pool = databaseUrl
  ? new Pool({
      connectionString: databaseUrl,
      options: `-c search_path=${schema}`,
      max: 8,
    })
  : null;
let app: Awaited<ReturnType<typeof createApp>> | undefined;
let ipCounter = 0;

before(async () => {
  if (!databaseUrl || !adminPool || !pool)
    throw new Error(
      "TEST_DATABASE_URL is required; native client tests require real PostgreSQL.",
    );
  await adminPool.query(`CREATE SCHEMA ${schema}`);
  const migrationsDir = join(testDir, "..", "migrations");
  for (const name of (await readdir(migrationsDir))
    .filter((entry) => entry.endsWith(".sql"))
    .sort()) {
    await pool.query(await readFile(join(migrationsDir, name), "utf8"));
  }
  app = await createApp({ pool, config });
  await app.ready();
});

after(async () => {
  clearEmailSink();
  if (app) await app.close();
  if (pool) await pool.end();
  if (adminPool) {
    await adminPool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    await adminPool.end();
  }
});

/** What the app sends: the marker, a client IP from the Worker, no browser headers. */
function nativeHeaders(ip: string, extra: Record<string, string> = {}) {
  return {
    "x-forma-worker-secret": workerSecret,
    "x-forma-client-ip": ip,
    "x-forma-client": "ios",
    "user-agent": iosAgent,
    ...extra,
  };
}

/** A tiny cookie jar, like the app's: name=value pairs from Set-Cookie. */
class Jar {
  private cookies = new Map<string, string>();
  absorb(response: { headers: Record<string, unknown> }) {
    const raw = response.headers["set-cookie"];
    for (const line of (Array.isArray(raw) ? raw : [raw]) as unknown[]) {
      if (typeof line !== "string") continue;
      const pair = line.split(";", 1)[0];
      const name = pair.slice(0, pair.indexOf("="));
      const value = pair.slice(pair.indexOf("=") + 1);
      if (/max-age=0/i.test(line) || value === "") this.cookies.delete(name);
      else this.cookies.set(name, value);
    }
  }
  header() {
    return [...this.cookies]
      .map(([name, value]) => `${name}=${value}`)
      .join("; ");
  }
  has(pattern: RegExp) {
    return [...this.cookies.keys()].some((name) => pattern.test(name));
  }
  clear() {
    this.cookies.clear();
  }
}

type Json = Record<string, any>;

class NativeClient {
  readonly jar = new Jar();
  memberRef: string | undefined;
  readonly ip = `198.51.100.${(ipCounter += 1)}`;

  async call(
    method: string,
    url: string,
    body?: unknown,
    extra: Record<string, string> = {},
  ) {
    assert.ok(app);
    const headers: Record<string, string> = nativeHeaders(this.ip, extra);
    const cookie = this.jar.header();
    if (cookie) headers.cookie = cookie;
    if (this.memberRef && !("x-forma-member" in extra))
      headers["x-forma-member"] = this.memberRef;
    if (body !== undefined && !("content-type" in headers))
      headers["content-type"] = "application/json";
    const response = await app.inject({
      method: method as "GET",
      url,
      headers,
      ...(body === undefined ? {} : { payload: JSON.stringify(body) }),
    });
    this.jar.absorb(response);
    let json: Json | null = null;
    try {
      json = response.json();
    } catch {
      json = null;
    }
    return { response, json };
  }
}

async function registerAndVerify(client: NativeClient, name: string) {
  assert.ok(app);
  const email = `${name.toLowerCase()}-${suffix}@example.test`;
  const signUp = await client.call("POST", "/api/auth/sign-up/email", {
    name,
    email,
    password,
  });
  assert.ok(
    [200, 201].includes(signUp.response.statusCode),
    signUp.response.body,
  );
  assert.equal(signUp.json?.token, undefined);
  assert.match(signUp.json?.user?.id ?? "", /^mem_/);
  const message = inspectEmailSink()
    .filter((item) => item.kind === "verify-email" && item.email === email)
    .at(-1);
  assert.ok(message);
  const link = new URL(message.url);
  // The email link is opened in a browser, not by the app.
  const verified = await app.inject({
    method: "GET",
    url: `${link.pathname}${link.search}`,
    headers: {
      "x-forma-worker-secret": workerSecret,
      "x-forma-client-ip": client.ip,
    },
  });
  assert.ok([200, 302].includes(verified.statusCode), verified.body);
  return email;
}

async function signIn(client: NativeClient, email: string) {
  const result = await client.call("POST", "/api/auth/sign-in/email", {
    email,
    password,
    rememberMe: true,
  });
  return result;
}

async function signedInClient(name: string) {
  const client = new NativeClient();
  const email = await registerAndVerify(client, name);
  const signedIn = await signIn(client, email);
  assert.equal(signedIn.response.statusCode, 200, signedIn.response.body);
  assert.equal(
    signedIn.json?.token,
    undefined,
    "the session token stays out of JSON",
  );
  assert.ok(
    client.jar.has(/session_token$/),
    "Set-Cookie is returned as for browsers",
  );
  const session = await client.call("GET", "/api/auth/get-session");
  assert.equal(session.response.statusCode, 200, session.response.body);
  client.memberRef = session.json?.user?.id as string;
  assert.match(client.memberRef, /^mem_/);
  return { client, email };
}

test("the predicate needs the exact marker and none of the browser-only headers", () => {
  const native = (headers: Record<string, string>) =>
    isNativeClientRequest(headers);
  assert.equal(native({ "x-forma-client": "ios" }), true);
  assert.equal(native({ "x-forma-client": "ios", cookie: "a=b" }), true);
  assert.equal(native({}), false);
  assert.equal(native({ "x-forma-client": "IOS" }), false);
  assert.equal(native({ "x-forma-client": "ios, ios" }), false);
  assert.equal(native({ "x-forma-client": "android" }), false);
  for (const name of [
    "origin",
    "referer",
    "sec-fetch-site",
    "sec-fetch-mode",
    "sec-fetch-dest",
  ]) {
    for (const value of ["", "null", appOrigin, "https://attacker.example"])
      assert.equal(
        native({ "x-forma-client": "ios", [name]: value }),
        false,
        `${name}: ${value}`,
      );
  }
});

test("a native member signs up, verifies, signs in, reads the session and syncs the workspace with only a cookie jar", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const { client, email } = await signedInClient("Nova");

  const workspace = await client.call("GET", "/api/workspace");
  assert.equal(workspace.response.statusCode, 200, workspace.response.body);
  assert.equal(workspace.json?.revision, 0);

  const data = {
    ...workspace.json!.data,
    profile: { ...workspace.json!.data.profile, goal: 4 },
  };
  const saved = await client.call("PUT", "/api/workspace", {
    data,
    expectedRevision: 0,
    operationId: `native-${suffix}-1`,
  });
  assert.equal(saved.response.statusCode, 200, saved.response.body);
  assert.equal(saved.json?.revision, 1);

  const reread = await client.call("GET", "/api/workspace");
  assert.equal(reread.json?.data.profile.goal, 4);
  const exported = await client.call("GET", "/api/workspace/export");
  assert.equal(exported.response.statusCode, 200);
  assert.equal(exported.json?.profile.goal, 4);

  // A stale revision is still a conflict, not a silent overwrite.
  const stale = await client.call("PUT", "/api/workspace", {
    data,
    expectedRevision: 0,
    operationId: `native-${suffix}-2`,
  });
  assert.equal(stale.response.statusCode, 409);

  // The member binding still applies.
  const unbound = await client.call("GET", "/api/workspace", undefined, {
    "x-forma-member": "mem_someone-else",
  });
  assert.equal(unbound.response.statusCode, 409);
  assert.equal(unbound.json?.error, "account_changed");

  // The session belongs to the same user the website would see.
  const database = await pool.query<{ id: string }>(
    `SELECT id FROM "user" WHERE email = $1`,
    [email],
  );
  assert.equal(database.rowCount, 1);
});

test("the iPhone session appears in the sessions list with its user agent and can be revoked like any other", async () => {
  assert.ok(app);
  const { client } = await signedInClient("Orion");
  // A second, browser-style sign-in for the same member.
  const other = new NativeClient();
  const secondSignIn = await app.inject({
    method: "POST",
    url: "/api/auth/sign-in/email",
    headers: {
      "x-forma-worker-secret": workerSecret,
      "x-forma-client-ip": other.ip,
      origin: appOrigin,
      "content-type": "application/json",
      "user-agent": "Mozilla/5.0 (Macintosh) Safari/605.1.15",
    },
    payload: { email: `orion-${suffix}@example.test`, password },
  });
  assert.equal(secondSignIn.statusCode, 200, secondSignIn.body);

  const listed = await client.call("GET", "/api/account/sessions");
  assert.equal(listed.response.statusCode, 200, listed.response.body);
  const sessions = listed.response.json() as {
    id: string;
    userAgent: string | null;
    current: boolean;
  }[];
  assert.equal(sessions.length, 2);
  const mine = sessions.find((session) => session.current);
  assert.equal(mine?.userAgent, iosAgent);
  const browser = sessions.find((session) => !session.current);
  assert.ok(browser);

  const revoked = await client.call(
    "DELETE",
    `/api/account/sessions/${browser.id}/revoke`,
  );
  assert.equal(revoked.response.statusCode, 200, revoked.response.body);
  const after = await client.call("GET", "/api/account/sessions");
  assert.equal((after.response.json() as unknown[]).length, 1);

  const revokeOthers = await client.call(
    "POST",
    "/api/account/sessions/revoke-others",
    {},
  );
  assert.equal(
    revokeOthers.response.statusCode,
    200,
    revokeOthers.response.body,
  );
  const revokeBare = await client.call(
    "POST",
    "/api/account/sessions/revoke-others",
    {},
    { "x-forma-member": "mem_wrong-account" },
  );
  assert.equal(revokeBare.response.statusCode, 409);
});

test("native coach tokens can be listed, minted and revoked with the session cookie", async () => {
  const { client } = await signedInClient("Pavo");
  const minted = await client.call("POST", "/api/account/coach-tokens", {
    label: "Phone coach",
  });
  assert.equal(minted.response.statusCode, 201, minted.response.body);
  const listed = await client.call("GET", "/api/account/coach-tokens");
  assert.equal((listed.response.json() as unknown[]).length, 1);
  const revoked = await client.call(
    "DELETE",
    `/api/account/coach-tokens/${minted.json!.record.id}`,
  );
  assert.equal(revoked.response.statusCode, 200, revoked.response.body);
});

test("native sign-out ends the session, and the cookie stops working", async () => {
  const { client } = await signedInClient("Quill");
  const signedOut = await client.call("POST", "/api/auth/sign-out", {});
  assert.equal(signedOut.response.statusCode, 200, signedOut.response.body);
  // The server clears the cookie; the app keeps its own copy to prove the
  // session is gone server-side, not just forgotten.
  const stolen = client.jar.header();
  assert.equal(client.jar.has(/session_token$/), false);
  assert.ok(app);
  const replay = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: {
      ...nativeHeaders(client.ip),
      cookie: `${stolen}`,
      "x-forma-member": client.memberRef!,
    },
  });
  assert.equal(replay.statusCode, 401);
  const session = await client.call("GET", "/api/auth/get-session");
  assert.equal(session.response.statusCode, 200);
  assert.equal(session.json, null);
});

test("native two-factor sign-in completes with the two_factor cookie and a fresh TOTP code", async () => {
  assert.ok(app && pool);
  const { client, email } = await signedInClient("Rigel");
  const enroll = await client.call("POST", "/api/auth/two-factor/enable", {
    password,
  });
  assert.equal(enroll.response.statusCode, 200, enroll.response.body);
  const secret = new TextDecoder().decode(
    base32.decode(
      new URL(enroll.json!.totpURI).searchParams.get("secret") ?? "",
    ),
  );
  const enrolment = await client.call(
    "POST",
    "/api/auth/two-factor/verify-totp",
    {
      code: await createOTP(secret).totp(),
    },
  );
  assert.equal(enrolment.response.statusCode, 200, enrolment.response.body);

  // Sign out, then sign in again as a new device: password, then the code.
  const gone = await client.call("POST", "/api/auth/sign-out", {});
  assert.equal(gone.response.statusCode, 200, gone.response.body);
  client.jar.clear();
  client.memberRef = undefined;
  const challenge = await signIn(client, email);
  assert.equal(challenge.response.statusCode, 200, challenge.response.body);
  assert.equal(challenge.json?.twoFactorRedirect, true);
  assert.ok(client.jar.has(/two_factor$/), "the challenge cookie is returned");
  assert.equal(client.jar.has(/session_token$/), false);

  const user = await pool.query<{ id: string }>(
    `SELECT id FROM "user" WHERE email = $1`,
    [email],
  );
  // The enrolment used this window's code; the replay guard would refuse it.
  await pool.query(`DELETE FROM mfa_totp_replay WHERE "userId" = $1`, [
    user.rows[0].id,
  ]);
  const code = await createOTP(secret).totp();
  const verified = await client.call(
    "POST",
    "/api/auth/two-factor/verify-totp",
    {
      code,
    },
  );
  assert.equal(verified.response.statusCode, 200, verified.response.body);
  assert.equal(verified.json?.token, undefined);
  assert.ok(client.jar.has(/session_token$/));

  const session = await client.call("GET", "/api/auth/get-session");
  assert.equal(session.response.statusCode, 200);
  client.memberRef = session.json?.user?.id;
  assert.match(client.memberRef ?? "", /^mem_/);
  const workspace = await client.call("GET", "/api/workspace");
  assert.equal(workspace.response.statusCode, 200, workspace.response.body);

  // Replaying the same code on a fresh challenge is still refused.
  const second = new NativeClient();
  const secondChallenge = await signIn(second, email);
  assert.equal(secondChallenge.json?.twoFactorRedirect, true);
  const replay = await second.call("POST", "/api/auth/two-factor/verify-totp", {
    code,
  });
  assert.equal(replay.response.statusCode, 401);
  assert.equal(replay.json?.error, "invalid_code");
  assert.equal(second.jar.has(/session_token$/), false);
});

test("the proxy rules still apply to native requests", async () => {
  assert.ok(app);
  const { client } = await signedInClient("Sirius");
  // Routes outside the allowlist.
  const listAccounts = await client.call("GET", "/api/auth/list-accounts");
  assert.equal(listAccounts.response.statusCode, 404);
  const verifyPassword = await client.call(
    "POST",
    "/api/auth/verify-password",
    {
      password,
    },
  );
  assert.equal(verifyPassword.response.statusCode, 404);
  // JSON bodies only.
  const form = await client.call("POST", "/api/auth/sign-out", undefined, {
    "content-type": "application/x-www-form-urlencoded",
  });
  assert.equal(form.response.statusCode, 415);
  // Redirect parameters must stay same-origin.
  const redirect = await client.call("POST", "/api/auth/change-email", {
    newEmail: `other-${suffix}@example.test`,
    callbackURL: "https://attacker.example/",
  });
  assert.equal(redirect.response.statusCode, 400);
  assert.equal(redirect.json?.error, "invalid_redirect");
  // Member-bound routes need the member reference.
  const noMember = await client.call(
    "POST",
    "/api/auth/sign-out",
    {},
    {
      "x-forma-member": "mem_wrong",
    },
  );
  assert.equal(noMember.response.statusCode, 409);
  assert.equal(noMember.json?.error, "account_changed");
  // Password steps still go through the attempt throttle: a wrong password is
  // refused and the session survives.
  const wrongPassword = await client.call("POST", "/api/auth/change-password", {
    currentPassword: "not the right passphrase",
    newPassword: "another sufficiently long passphrase",
  });
  assert.ok(wrongPassword.response.statusCode >= 400);
  const stillThere = await client.call("GET", "/api/workspace");
  assert.equal(stillThere.response.statusCode, 200);
  // The Worker secret is still required.
  const noSecret = await app.inject({
    method: "POST",
    url: "/api/auth/sign-in/email",
    headers: {
      "x-forma-client": "ios",
      "x-forma-client-ip": client.ip,
      "content-type": "application/json",
    },
    payload: { email: "x@example.test", password },
  });
  assert.equal(noSecret.statusCode, 401);
});

test("requests that are not native keep being refused without an app Origin", async () => {
  assert.ok(app);
  const server = app;
  const { client } = await signedInClient("Tycho");
  const cookie = client.jar.header();
  const base = {
    "x-forma-worker-secret": workerSecret,
    "x-forma-client-ip": client.ip,
    "content-type": "application/json",
    cookie,
    "x-forma-member": client.memberRef!,
  };
  const workspace = await client.call("GET", "/api/workspace");
  const body = JSON.stringify({
    data: workspace.json!.data,
    expectedRevision: 0,
    operationId: `negatives-${suffix}`,
  });
  const attempts: [string, Record<string, string>][] = [
    ["no marker, no Origin", {}],
    ["wrong marker value", { "x-forma-client": "android" }],
    ["upper-case marker value", { "x-forma-client": "IOS" }],
    [
      "marker with a foreign Origin",
      { "x-forma-client": "ios", origin: "https://attacker.example" },
    ],
    ["marker with an empty Origin", { "x-forma-client": "ios", origin: "" }],
    ["marker with a null Origin", { "x-forma-client": "ios", origin: "null" }],
    [
      "marker with Sec-Fetch-Site",
      { "x-forma-client": "ios", "sec-fetch-site": "same-origin" },
    ],
    [
      "marker with cross-site Sec-Fetch-Site",
      { "x-forma-client": "ios", "sec-fetch-site": "cross-site" },
    ],
    [
      "marker with Sec-Fetch-Mode",
      { "x-forma-client": "ios", "sec-fetch-mode": "cors" },
    ],
    [
      "marker with Sec-Fetch-Dest",
      { "x-forma-client": "ios", "sec-fetch-dest": "empty" },
    ],
    [
      "marker with Referer",
      { "x-forma-client": "ios", referer: `${appOrigin}/` },
    ],
  ];
  const writes: ["PUT" | "POST", string, string][] = [
    ["PUT", "/api/workspace", body],
    ["POST", "/api/auth/sign-out", "{}"],
    ["POST", "/api/account/sessions/revoke-all", "{}"],
  ];
  for (const [label, extra] of attempts) {
    for (const [method, url, payload] of writes) {
      const response = await server.inject({
        method,
        url,
        headers: { ...base, ...extra },
        payload,
      });
      assert.equal(response.statusCode, 403, `${label}: ${method} ${url}`);
      assert.deepEqual(response.json(), { error: "forbidden" });
    }
  }
  // None of the refused attempts touched the session or the workspace.
  const intact = await client.call("GET", "/api/workspace");
  assert.equal(intact.response.statusCode, 200);
  assert.equal(intact.json?.revision, 0);

  // With the app's own Origin the marker changes nothing: an ordinary write.
  const sameOrigin = await server.inject({
    method: "PUT",
    url: "/api/workspace",
    headers: { ...base, "x-forma-client": "ios", origin: appOrigin },
    payload: body,
  });
  assert.equal(sameOrigin.statusCode, 200, sameOrigin.body);
});

test("a marker with a foreign Origin cannot borrow the proxy's vouching to sign in or out", async () => {
  assert.ok(app);
  const { client } = await signedInClient("Ursa");
  // Better Auth must see the real (foreign) Origin, so it refuses a request
  // that carries cookies. The onRequest rule refuses it first.
  const foreign = await app.inject({
    method: "POST",
    url: "/api/auth/sign-out",
    headers: {
      ...nativeHeaders(client.ip, { origin: "https://attacker.example" }),
      cookie: client.jar.header(),
      "x-forma-member": client.memberRef!,
      "content-type": "application/json",
    },
    payload: "{}",
  });
  assert.equal(foreign.statusCode, 403);
  const alive = await client.call("GET", "/api/workspace");
  assert.equal(alive.response.statusCode, 200);
});
