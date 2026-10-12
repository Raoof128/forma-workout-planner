import assert from "node:assert/strict";
import { test } from "node:test";
import type { AuthEmail } from "../email.js";
import { renderAuthEmail } from "../email-template.js";

const origin = "https://forma.example";

const examples: AuthEmail[] = [
  {
    kind: "verify-email",
    email: "member@example.test",
    url: `${origin}/api/auth/verify-email?token=verify-token&callbackURL=${encodeURIComponent(`${origin}/account`)}`,
  },
  {
    kind: "reset-password",
    email: "member@example.test",
    url: `${origin}/api/auth/reset-password/reset-token`,
  },
  {
    kind: "change-email",
    email: "member@example.test",
    detail: "new-address@example.test",
    url: `${origin}/api/auth/verify-email?token=change-token&callbackURL=${encodeURIComponent(`${origin}/account`)}`,
  },
  {
    kind: "delete-account",
    email: "member@example.test",
    url: `${origin}/api/auth/delete-user/callback?token=delete-token`,
  },
];

test("renders clear branded HTML and plain text for all four auth email actions", () => {
  const expected = [
    [
      "Confirm your FORMA email address",
      "Confirm email address",
      "complete an email change",
    ],
    ["Reset your FORMA password", "Reset password", "choose a new password"],
    [
      "Approve your FORMA email change",
      "Approve email change",
      "separate verification link",
    ],
    [
      "Confirm deletion of your FORMA account",
      "Permanently delete account",
      "cannot be undone",
    ],
  ];

  for (const [index, message] of examples.entries()) {
    const rendered = renderAuthEmail(message, origin);
    const [subject, action, bodyText] = expected[index]!;
    assert.equal(rendered.subject, subject);
    assert.match(
      rendered.html,
      /<meta name="viewport" content="width=device-width,initial-scale=1">/,
    );
    assert.match(rendered.html, /role="presentation" width="100%"/);
    assert.match(rendered.html, /max-width:600px/);
    assert.match(rendered.html, new RegExp(action));
    assert.match(rendered.html, new RegExp(bodyText, "i"));
    assert.match(rendered.html, /Button not working\?/);
    assert.match(rendered.text, new RegExp(action));
    assert.match(rendered.text, new RegExp(bodyText, "i"));
    assert.match(rendered.text, /https:\/\/forma\.example\/api\/auth\//);
    assert.doesNotMatch(
      rendered.html,
      /<script\b|<img\b|https?:\/\/(?!forma\.example)/i,
    );
  }
});

test("escapes email-change detail and action URL in HTML and preserves plain-text fallback", () => {
  const message: AuthEmail = {
    kind: "change-email",
    email: "member@example.test",
    detail: "new+tag&security@example.test",
    url: `${origin}/api/auth/verify-email?token=a%3Cb%26c'quote&callbackURL=${encodeURIComponent(`${origin}/account?step=verify&x=1`)}`,
  };
  const rendered = renderAuthEmail(message, origin);

  assert.match(rendered.html, /new\+tag&amp;security@example\.test/);
  assert.match(rendered.html, /a%3Cb%26c/);
  assert.match(rendered.html, /%27quote/);
  assert.match(rendered.html, /&amp;callbackURL=/);
  assert.doesNotMatch(rendered.html, /<b&c/);
  assert.match(
    rendered.text,
    /Requested new address: new\+tag&security@example\.test/,
  );
  assert.match(rendered.text, /callbackURL=/);
});

test("requires the configured app origin, environment-safe scheme, and action-specific route", () => {
  const verify = examples[0]!;
  assert.throws(
    () =>
      renderAuthEmail(
        {
          ...verify,
          url: "https://attacker.example/api/auth/verify-email?token=x",
        },
        origin,
      ),
    /expected FORMA auth origin and route/,
  );
  assert.throws(
    () =>
      renderAuthEmail(
        {
          ...verify,
          url: `${origin}/api/auth/verify-email?token=x&callbackURL=${encodeURIComponent("https://attacker.example")}`,
        },
        origin,
      ),
    /callback must use the FORMA app origin/,
  );
  assert.throws(
    () => renderAuthEmail({ ...verify, url: "javascript:alert(1)" }, origin),
    /expected FORMA auth origin and route/,
  );
  assert.throws(
    () =>
      renderAuthEmail(
        { ...verify, url: `${origin}/api/auth/delete-user/callback?token=x` },
        origin,
      ),
    /expected FORMA auth origin and route/,
  );
  assert.throws(
    () =>
      renderAuthEmail(
        {
          ...verify,
          url: "http://forma.example/api/auth/verify-email?token=x",
        },
        origin,
      ),
    /expected FORMA auth origin and route/,
  );
  assert.throws(
    () => renderAuthEmail(verify, "http://forma.example"),
    /HTTPS \(or loopback HTTP in development\)/,
  );

  const localOrigin = "http://localhost:3001";
  const local = renderAuthEmail(
    { ...verify, url: `${localOrigin}/api/auth/verify-email?token=local` },
    localOrigin,
  );
  assert.match(local.html, /http:\/\/localhost:3001\/api\/auth\/verify-email/);
});

test("email-change detail must be a bounded address", () => {
  const message = examples[2]!;
  for (const detail of [
    undefined,
    "<img src=x>@example.test",
    "a\nb@example.test",
    `${"a".repeat(320)}@example.test`,
  ]) {
    assert.throws(
      () => renderAuthEmail({ ...message, detail }, origin),
      /valid new email address/,
    );
  }
});

test("deletion email states irreversible data loss and safe ignore behavior", () => {
  const rendered = renderAuthEmail(examples[3]!, origin);
  assert.match(
    rendered.html,
    /permanently deletes your FORMA account and associated training data/i,
  );
  assert.match(rendered.html, /This action cannot be undone/);
  assert.match(
    rendered.text,
    /your account remains active unless you confirm/i,
  );
  assert.match(rendered.text, /associated training data will be deleted/i);
});
