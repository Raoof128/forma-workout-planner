import type { AppConfig } from "./config.js";

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

export function createEmailSender(
  config: AppConfig,
): (message: AuthEmail) => Promise<void> {
  return async (message) => {
    if (config.emailSinkEnabled) {
      sink.push({ ...message });
      return;
    }
    if (!config.resendApiKey) {
      throw new Error("Email delivery is not configured");
    }

    const subjects: Record<AuthEmailKind, string> = {
      "verify-email": "Verify your FORMA account",
      "reset-password": "Reset your FORMA password",
      "change-email": "Approve your FORMA email change",
      "delete-account": "Confirm deletion of your FORMA account",
    };
    const actions: Record<AuthEmailKind, string> = {
      "verify-email": "Verify your email address",
      "reset-password": "Choose a new password",
      "change-email": `Approve the change of your account email to ${message.detail ?? "the requested address"}`,
      "delete-account": "Confirm deletion of your account",
    };
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        authorization: `Bearer ${config.resendApiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        from: config.emailFrom,
        to: [message.email],
        subject: subjects[message.kind],
        text: `${actions[message.kind]}: ${message.url}\n\nIf you did not request this, you can ignore this message.`,
      }),
    });
    if (!response.ok) {
      // Do not include provider response bodies: they may contain recipient or token data.
      throw new Error(`Email provider rejected message (${response.status})`);
    }
  };
}
