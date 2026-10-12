import type { AuthEmail } from "./email.js";

export interface RenderedAuthEmail {
  subject: string;
  html: string;
  text: string;
}

interface EmailContent {
  eyebrow: string;
  title: string;
  intro: string;
  action: string;
  ignore: string;
  caution?: string;
  detailLabel?: string;
}

const colors = {
  ink: "#202722",
  muted: "#657067",
  canvas: "#f3f5f1",
  line: "#dce2da",
  lime: "#dafa7f",
  darkLime: "#29351d",
} as const;

const contentByKind: Record<AuthEmail["kind"], EmailContent> = {
  "verify-email": {
    eyebrow: "ACCOUNT SECURITY",
    title: "Confirm your email address",
    intro:
      "Confirm this address to finish setting up your FORMA account or complete an email change.",
    action: "Confirm email address",
    ignore:
      "If you did not request this account or email change, you can ignore this message.",
  },
  "reset-password": {
    eyebrow: "ACCOUNT SECURITY",
    title: "Reset your password",
    intro:
      "Use this secure link to choose a new password for your FORMA account.",
    action: "Reset password",
    ignore:
      "If you did not request a password reset, you can ignore this message. Your password will not change.",
  },
  "change-email": {
    eyebrow: "ACCOUNT UPDATE",
    title: "Approve your email change",
    intro:
      "Approve this request from your current inbox. After approval, we will send a separate verification link to the new inbox.",
    action: "Approve email change",
    ignore:
      "If you did not request this change, ignore this message and secure your account. Your email address will not change unless you approve this request and verify the new address.",
    detailLabel: "Requested new address",
  },
  "delete-account": {
    eyebrow: "ACCOUNT DELETION",
    title: "Confirm account deletion",
    intro:
      "Confirming this request permanently deletes your FORMA account and associated training data. This action cannot be undone.",
    action: "Permanently delete account",
    ignore:
      "If you did not request deletion, ignore this message. Your account remains active unless you confirm using the button below.",
    caution:
      "Permanent action: your account and associated training data will be deleted.",
  },
};

const expectedPath: Record<AuthEmail["kind"], (pathname: string) => boolean> = {
  "verify-email": (pathname) => /(?:^|\/)verify-email\/?$/.test(pathname),
  "reset-password": (pathname) =>
    /(?:^|\/)reset-password(?:\/|$)/.test(pathname),
  "change-email": (pathname) => /(?:^|\/)verify-email\/?$/.test(pathname),
  "delete-account": (pathname) => /(?:^|\/)delete-user(?:\/|$)/.test(pathname),
};

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => {
    switch (character) {
      case "&":
        return "&amp;";
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case '"':
        return "&quot;";
      default:
        return "&#39;";
    }
  });
}

function validateAppOrigin(appOrigin: string): URL {
  let origin: URL;
  try {
    origin = new URL(appOrigin);
  } catch {
    throw new Error("Auth email app origin must be a valid HTTP(S) origin");
  }

  const loopbackHosts = new Set(["localhost", "127.0.0.1", "[::1]"]);
  const isDevHttp =
    origin.protocol === "http:" && loopbackHosts.has(origin.hostname);
  if (
    origin.username ||
    origin.password ||
    origin.pathname !== "/" ||
    origin.search ||
    origin.hash ||
    (origin.protocol !== "https:" && !isDevHttp)
  ) {
    throw new Error(
      "Auth email app origin must be HTTPS (or loopback HTTP in development)",
    );
  }
  return origin;
}

function validateActionUrl(message: AuthEmail, appOrigin: string): string {
  const origin = validateAppOrigin(appOrigin);
  let actionUrl: URL;
  try {
    actionUrl = new URL(message.url);
  } catch {
    throw new Error("Auth email action URL is invalid");
  }

  if (
    actionUrl.username ||
    actionUrl.password ||
    actionUrl.origin !== origin.origin ||
    actionUrl.protocol !== origin.protocol ||
    !expectedPath[message.kind](actionUrl.pathname)
  ) {
    throw new Error(
      "Auth email action URL must use the expected FORMA auth origin and route",
    );
  }
  for (const key of ["callbackURL", "redirectTo"]) {
    const destination = actionUrl.searchParams.get(key);
    if (!destination) continue;
    let callback: URL;
    try {
      callback = new URL(destination, origin);
    } catch {
      throw new Error("Auth email callback must use the FORMA app origin");
    }
    if (
      callback.origin !== origin.origin ||
      callback.protocol !== origin.protocol
    ) {
      throw new Error("Auth email callback must use the FORMA app origin");
    }
  }
  return actionUrl.href;
}

function validateChangeEmailDetail(message: AuthEmail): string {
  const detail = message.detail?.trim();
  if (
    !detail ||
    detail.length > 320 ||
    /[\r\n<>]/.test(detail) ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(detail)
  ) {
    throw new Error(
      "Email-change notification requires a valid new email address",
    );
  }
  return detail;
}

function makeHtml(
  content: EmailContent,
  actionUrl: string,
  detail: string | undefined,
): string {
  const escapedUrl = escapeHtml(actionUrl);
  const detailBlock = detail
    ? `<tr><td style="padding:0 32px 24px;"><p style="margin:0 0 6px;color:${colors.muted};font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:20px;">${escapeHtml(content.detailLabel ?? "Details")}</p><p style="margin:0;color:${colors.ink};font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:24px;overflow-wrap:anywhere;word-break:break-word;">${escapeHtml(detail)}</p></td></tr>`
    : "";
  const cautionBlock = content.caution
    ? `<tr><td style="padding:0 32px 24px;"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #e6cfaa;border-radius:8px;background:#fff8ea;"><tr><td style="padding:14px 16px;color:#634b2a;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:21px;">${escapeHtml(content.caution)}</td></tr></table></td></tr>`
    : "";

  return `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>${escapeHtml(content.title)} | FORMA</title></head>
<body style="margin:0;padding:0;background:${colors.canvas};">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;background:${colors.canvas};">
    <tr><td align="center" style="padding:28px 12px 36px;">
      <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="width:100%;max-width:600px;border:1px solid ${colors.line};border-radius:16px;background:#ffffff;">
        <tr><td style="padding:27px 32px 22px;border-bottom:1px solid ${colors.line};"><span style="color:${colors.ink};font-family:Arial,Helvetica,sans-serif;font-size:26px;font-weight:800;letter-spacing:-1px;">FORMA<span style="color:#71834a;">.</span></span></td></tr>
        <tr><td style="padding:32px 32px 8px;color:#71806d;font-family:Arial,Helvetica,sans-serif;font-size:12px;font-weight:700;letter-spacing:2px;line-height:18px;">${escapeHtml(content.eyebrow)}</td></tr>
        <tr><td style="padding:0 32px 12px;color:${colors.ink};font-family:Arial,Helvetica,sans-serif;font-size:30px;font-weight:800;letter-spacing:-.5px;line-height:36px;">${escapeHtml(content.title)}</td></tr>
        <tr><td style="padding:0 32px 24px;color:${colors.muted};font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:25px;">${escapeHtml(content.intro)}</td></tr>
        ${detailBlock}
        ${cautionBlock}
        <tr><td align="left" style="padding:0 32px 24px;"><table role="presentation" cellspacing="0" cellpadding="0" border="0"><tr><td align="center" bgcolor="${colors.lime}" style="border-radius:8px;"><a href="${escapedUrl}" style="display:inline-block;padding:15px 22px;border:1px solid ${colors.lime};border-radius:8px;color:${colors.darkLime};font-family:Arial,Helvetica,sans-serif;font-size:16px;font-weight:700;line-height:22px;text-decoration:none;">${escapeHtml(content.action)}</a></td></tr></table></td></tr>
        <tr><td style="padding:0 32px 25px;color:${colors.muted};font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:22px;">${escapeHtml(content.ignore)}</td></tr>
        <tr><td style="padding:20px 32px;border-top:1px solid ${colors.line};color:${colors.muted};font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:19px;">Button not working? Copy this address into your browser:<br><a href="${escapedUrl}" style="color:#4d6330;overflow-wrap:anywhere;word-break:break-word;">${escapedUrl}</a></td></tr>
      </table>
      <p style="margin:16px 0 0;color:${colors.muted};font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:18px;">FORMA · Train with intention.</p>
    </td></tr>
  </table>
</body>
</html>`;
}

function makeText(
  content: EmailContent,
  actionUrl: string,
  detail: string | undefined,
): string {
  const parts = [
    `FORMA. ${content.eyebrow}`,
    "",
    content.title,
    "",
    content.intro,
  ];
  if (detail) parts.push("", `${content.detailLabel ?? "Details"}: ${detail}`);
  if (content.caution) parts.push("", content.caution);
  parts.push(
    "",
    `${content.action}: ${actionUrl}`,
    "",
    content.ignore,
    "",
    "FORMA · Train with intention.",
  );
  return parts.join("\n");
}

export function renderAuthEmail(
  message: AuthEmail,
  appOrigin: string,
): RenderedAuthEmail {
  const actionUrl = validateActionUrl(message, appOrigin);
  const content = contentByKind[message.kind];
  const detail =
    message.kind === "change-email"
      ? validateChangeEmailDetail(message)
      : undefined;
  const subjectByKind: Record<AuthEmail["kind"], string> = {
    "verify-email": "Confirm your FORMA email address",
    "reset-password": "Reset your FORMA password",
    "change-email": "Approve your FORMA email change",
    "delete-account": "Confirm deletion of your FORMA account",
  };

  return {
    subject: subjectByKind[message.kind],
    html: makeHtml(content, actionUrl, detail),
    text: makeText(content, actionUrl, detail),
  };
}
