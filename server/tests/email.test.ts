import assert from "node:assert/strict";
import { test } from "node:test";
import type { AppConfig } from "../config.js";
import { loadConfig } from "../config.js";
import {
  clearEmailSink,
  createEmailSender,
  inspectEmailSink,
  type AuthEmail,
} from "../email.js";

const message: AuthEmail = {
  kind: "verify-email",
  email: "member@example.test",
  url: "https://forma.example/api/auth/verify-email?token=opaque-test-token",
};

const cloudflareConfig: AppConfig = {
  environment: "production",
  appOrigin: "https://forma.example",
  authSecret: "a".repeat(32),
  workerSharedSecret: "b".repeat(32),
  cloudflareEmailApiToken: "test-token-must-not-leak",
  cloudflareAccountId: "0123456789abcdef0123456789abcdef",
  emailFrom: "FORMA <accounts@forma.example>",
  emailSinkEnabled: false,
};

function providerResponse(
  result: unknown,
  success = true,
  status = 200,
): Response {
  return Response.json(
    { success, errors: [], messages: [], result },
    { status },
  );
}

test("production config requires Cloudflare transactional email credentials", () => {
  const base = {
    NODE_ENV: "production",
    APP_ORIGIN: "https://forma.example",
    AUTH_SECRET: "a".repeat(32),
    ORIGIN_SHARED_SECRET: "b".repeat(32),
    EMAIL_FROM: "FORMA <accounts@forma.example>",
  };

  assert.throws(() => loadConfig(base), /CLOUDFLARE_EMAIL_API_TOKEN/);
  assert.throws(
    () =>
      loadConfig({
        ...base,
        CLOUDFLARE_EMAIL_API_TOKEN: "test-token",
      }),
    /CLOUDFLARE_ACCOUNT_ID/,
  );

  const parsed = loadConfig({
    ...base,
    CLOUDFLARE_EMAIL_API_TOKEN: "test-token",
    CLOUDFLARE_ACCOUNT_ID: "0123456789abcdef0123456789abcdef",
  });
  assert.equal(parsed.cloudflareAccountId, "0123456789abcdef0123456789abcdef");
  assert.equal(parsed.cloudflareEmailApiToken, "test-token");
  assert.equal(parsed.emailSinkEnabled, false);
});

test("Cloudflare adapter sends rendered transactional content and accepts queued mail", async () => {
  const requestCapture: { url?: URL; init?: RequestInit } = {};
  const sender = createEmailSender(cloudflareConfig, async (input, init) => {
    requestCapture.url = new URL(String(input));
    requestCapture.init = init;
    return providerResponse({
      delivered: [],
      queued: ["MEMBER@example.test"],
      permanent_bounces: [],
    });
  });

  await sender(message);

  assert.equal(
    requestCapture.url?.href,
    "https://api.cloudflare.com/client/v4/accounts/0123456789abcdef0123456789abcdef/email/sending/send",
  );
  assert.equal(requestCapture.init?.method, "POST");
  assert.equal(requestCapture.init?.redirect, "error");
  assert.ok(requestCapture.init?.signal);
  const headers = new Headers(requestCapture.init?.headers);
  assert.equal(headers.get("authorization"), "Bearer test-token-must-not-leak");
  const body = JSON.parse(String(requestCapture.init?.body)) as Record<
    string,
    string
  >;
  assert.equal(body.to, message.email);
  assert.deepEqual(body.from, {
    address: "accounts@forma.example",
    name: "FORMA",
  });
  assert.ok(body.subject);
  assert.ok(body.html);
  assert.ok(body.text);
});

test("Cloudflare adapter fails closed on provider errors, malformed envelopes, and recipient rejection", async (t) => {
  const cases: Array<{ name: string; response: () => Response }> = [
    {
      name: "HTTP errors",
      response: () =>
        new Response("contains recipient and secret", { status: 403 }),
    },
    {
      name: "false success envelope",
      response: () => providerResponse(null, false),
    },
    {
      name: "successful envelope containing provider errors",
      response: () =>
        Response.json({
          success: true,
          errors: [{ code: 10001, message: "secret-bearing provider error" }],
          messages: [],
          result: {
            delivered: [message.email],
            queued: [],
            permanent_bounces: [],
          },
        }),
    },
    {
      name: "oversized response",
      response: () =>
        Response.json({
          success: true,
          errors: [],
          messages: [],
          result: {
            delivered: [message.email],
            queued: [],
            permanent_bounces: [],
          },
          padding: "x".repeat(70 * 1024),
        }),
    },
    {
      name: "invalid JSON",
      response: () => new Response("not json", { status: 200 }),
    },
    {
      name: "missing recipient arrays",
      response: () => providerResponse({ delivered: [message.email] }),
    },
    {
      name: "recipient was not accepted",
      response: () =>
        providerResponse({
          delivered: [],
          queued: [],
          permanent_bounces: [],
        }),
    },
    {
      name: "recipient permanently bounced",
      response: () =>
        providerResponse({
          delivered: [message.email],
          queued: [],
          permanent_bounces: [message.email],
        }),
    },
  ];

  for (const scenario of cases) {
    await t.test(scenario.name, async () => {
      const sender = createEmailSender(cloudflareConfig, async () =>
        scenario.response(),
      );
      await assert.rejects(sender(message), (error: unknown) => {
        assert.ok(error instanceof Error);
        assert.ok(!error.message.includes(message.email));
        assert.ok(!error.message.includes("test-token-must-not-leak"));
        assert.ok(!error.message.includes("contains recipient and secret"));
        return true;
      });
    });
  }
});

test("Cloudflare adapter redacts transport failures and refuses missing credentials", async () => {
  const sender = createEmailSender(cloudflareConfig, async () => {
    throw new Error(
      `transport echoed ${message.email} and test-token-must-not-leak`,
    );
  });
  await assert.rejects(sender(message), (error: unknown) => {
    assert.deepEqual(
      (error as Error).message,
      "Cloudflare Email Service request failed",
    );
    return true;
  });

  const unconfigured = createEmailSender({
    ...cloudflareConfig,
    cloudflareEmailApiToken: undefined,
  });
  await assert.rejects(unconfigured(message), /not configured/);
});

test("email sink remains available only to non-production test fixtures", async () => {
  clearEmailSink();
  const testSender = createEmailSender({
    ...cloudflareConfig,
    environment: "test",
    emailSinkEnabled: true,
  });
  await testSender(message);
  assert.deepEqual(inspectEmailSink(), [message]);
  clearEmailSink();

  const productionSender = createEmailSender({
    ...cloudflareConfig,
    emailSinkEnabled: true,
  });
  await assert.rejects(productionSender(message), /unavailable in production/);
  assert.deepEqual(inspectEmailSink(), []);
});
