import type { AppConfig } from "./config.js";
import { renderAuthEmail } from "./email-template.js";

export type AuthEmailKind =
  "verify-email" | "reset-password" | "change-email" | "delete-account";

export interface AuthEmail {
  kind: AuthEmailKind;
  email: string;
  url: string;
  detail?: string;
}

const sink: AuthEmail[] = [];

export function inspectEmailSink(): readonly AuthEmail[] {
  return sink;
}

export function clearEmailSink(): void {
  sink.length = 0;
}

interface CloudflareSendResult {
  delivered: string[];
  queued: string[];
  permanent_bounces: string[];
}

function isStringArray(value: unknown): value is string[] {
  return (
    Array.isArray(value) && value.every((item) => typeof item === "string")
  );
}

function parseSendResult(payload: unknown): CloudflareSendResult | null {
  if (!payload || typeof payload !== "object") return null;
  const envelope = payload as {
    success?: unknown;
    errors?: unknown;
    messages?: unknown;
    result?: unknown;
  };
  if (
    envelope.success !== true ||
    !Array.isArray(envelope.errors) ||
    envelope.errors.length !== 0 ||
    !Array.isArray(envelope.messages) ||
    !envelope.result ||
    typeof envelope.result !== "object"
  ) {
    return null;
  }
  const result = envelope.result as Record<string, unknown>;
  if (
    !isStringArray(result.delivered) ||
    !isStringArray(result.queued) ||
    !isStringArray(result.permanent_bounces)
  ) {
    return null;
  }
  return {
    delivered: result.delivered,
    queued: result.queued,
    permanent_bounces: result.permanent_bounces,
  };
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const reader = response.body?.getReader();
  if (!reader)
    throw new Error("Cloudflare Email Service returned no response body");

  const maxBytes = 64 * 1024;
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel();
        throw new Error(
          "Cloudflare Email Service response exceeded its size limit",
        );
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const body = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return JSON.parse(
    new TextDecoder("utf-8", { fatal: true }).decode(body),
  ) as unknown;
}

function normalized(email: string): string {
  return email.trim().toLowerCase();
}

function cloudflareSender(
  value: string,
): string | { address: string; name: string } {
  const namedAddress = value.match(/^\s*(.+?)\s*<([^<>]+)>\s*$/);
  if (namedAddress) {
    const name = namedAddress[1]!.trim();
    const address = namedAddress[2]!.trim();
    if (name) return { address, name };
    return address;
  }
  return value.trim();
}

function isAcceptedForRecipient(
  result: CloudflareSendResult,
  email: string,
): boolean {
  const recipient = normalized(email);
  if (
    result.permanent_bounces.some(
      (address) => normalized(address) === recipient,
    )
  ) {
    return false;
  }
  return [...result.delivered, ...result.queued].some(
    (address) => normalized(address) === recipient,
  );
}

export function createEmailSender(
  config: AppConfig,
  fetchImplementation: typeof fetch = fetch,
): (message: AuthEmail) => Promise<void> {
  return async (message) => {
    const rendered = renderAuthEmail(message, config.appOrigin);
    if (config.emailSinkEnabled) {
      if (config.environment === "production") {
        throw new Error("The email test sink is unavailable in production");
      }
      sink.push({ ...message });
      return;
    }

    if (!config.cloudflareEmailApiToken || !config.cloudflareAccountId) {
      throw new Error("Cloudflare Email Service is not configured");
    }

    const endpoint = `https://api.cloudflare.com/client/v4/accounts/${config.cloudflareAccountId}/email/sending/send`;
    let response: Response;
    try {
      response = await fetchImplementation(endpoint, {
        method: "POST",
        headers: {
          authorization: `Bearer ${config.cloudflareEmailApiToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          from: cloudflareSender(config.emailFrom),
          to: message.email,
          subject: rendered.subject,
          html: rendered.html,
          text: rendered.text,
        }),
        redirect: "error",
        signal: AbortSignal.timeout(10_000),
      });
    } catch {
      throw new Error("Cloudflare Email Service request failed");
    }

    if (!response.ok) {
      throw new Error(
        `Cloudflare Email Service rejected the message (${response.status})`,
      );
    }

    let payload: unknown;
    try {
      payload = await readBoundedJson(response);
    } catch {
      throw new Error("Cloudflare Email Service returned an invalid response");
    }
    const result = parseSendResult(payload);
    if (!result) {
      throw new Error("Cloudflare Email Service returned an invalid response");
    }
    if (!isAcceptedForRecipient(result, message.email)) {
      throw new Error(
        "Cloudflare Email Service did not accept the intended recipient",
      );
    }
  };
}
