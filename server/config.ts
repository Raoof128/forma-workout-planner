import { z } from "zod";

const environmentSchema = z.enum(["development", "test", "production"]);

export interface AppConfig {
  environment: z.infer<typeof environmentSchema>;
  appOrigin: string;
  authSecret: string;
  workerSharedSecret: string;
  cloudflareEmailApiToken?: string;
  cloudflareAccountId?: string;
  emailFrom: string;
  emailSinkEnabled: boolean;
  /** Raises only per-auth-path limits in isolated test harnesses. */
  authRateLimitMax?: number;
}

function parseOrigin(value: string): string {
  const parsed = new URL(value);
  if (parsed.origin !== value.replace(/\/$/, "")) {
    throw new Error(
      "APP_ORIGIN must be an origin without a path or trailing slash",
    );
  }
  return parsed.origin;
}

// Template wording from .env.example and similar placeholders. The repository
// is public, so a copied example value is a known secret.
const PLACEHOLDER_SECRET =
  /replace|change[_-]?me|example|placeholder|your[_-]/i;

/** Refuse secrets that are copied templates, reused, or obviously low-entropy. */
function checkProductionSecrets(authSecret: string, workerSecret: string) {
  for (const [name, value] of [
    ["AUTH_SECRET", authSecret],
    ["ORIGIN_SHARED_SECRET", workerSecret],
  ] as const) {
    if (PLACEHOLDER_SECRET.test(value))
      throw new Error(`${name} still holds a placeholder value`);
    if (new Set(value).size < 12)
      throw new Error(`${name} must be a random value, not a repeated pattern`);
  }
  if (authSecret === workerSecret)
    throw new Error("AUTH_SECRET and ORIGIN_SHARED_SECRET must differ");
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  // Development is the default for local work, but an HTTPS origin with no
  // NODE_ENV is a deployment that forgot it: fail closed instead of silently
  // skipping every production check below.
  if (env.NODE_ENV === undefined && env.APP_ORIGIN?.startsWith("https://"))
    throw new Error("Set NODE_ENV explicitly for an HTTPS APP_ORIGIN");
  const environment = environmentSchema.parse(env.NODE_ENV ?? "development");
  const schema = z.object({
    APP_ORIGIN: z.string().url().transform(parseOrigin),
    AUTH_SECRET: z.string().min(32),
    ORIGIN_SHARED_SECRET: z.string().min(32),
    CLOUDFLARE_EMAIL_API_TOKEN: z.string().min(1).optional(),
    CLOUDFLARE_ACCOUNT_ID: z
      .string()
      .regex(/^[a-f0-9]{32}$/i)
      .optional(),
    EMAIL_FROM: z.string().min(3).default("FORMA <accounts@forma.test>"),
    EMAIL_SINK_ENABLED: z.enum(["true", "false"]).optional(),
  });
  const parsed = schema.parse(env);
  const emailSinkEnabled = parsed.EMAIL_SINK_ENABLED === "true";

  if (environment === "production") {
    if (!parsed.APP_ORIGIN.startsWith("https://")) {
      throw new Error("Production APP_ORIGIN must use HTTPS");
    }
    if (!parsed.CLOUDFLARE_EMAIL_API_TOKEN) {
      throw new Error(
        "Production requires CLOUDFLARE_EMAIL_API_TOKEN for account email delivery",
      );
    }
    if (!parsed.CLOUDFLARE_ACCOUNT_ID) {
      throw new Error(
        "Production requires CLOUDFLARE_ACCOUNT_ID for account email delivery",
      );
    }
    if (emailSinkEnabled) {
      throw new Error(
        "The in-memory email sink cannot be enabled in production",
      );
    }
    checkProductionSecrets(parsed.AUTH_SECRET, parsed.ORIGIN_SHARED_SECRET);
    const senderEmail =
      parsed.EMAIL_FROM.match(/<([^>]+)>/)?.[1] ?? parsed.EMAIL_FROM;
    if (
      !z.string().email().safeParse(senderEmail).success ||
      /@(localhost|forma\.test)$/i.test(senderEmail)
    ) {
      throw new Error(
        "Production EMAIL_FROM must use a verified sender domain",
      );
    }
  }

  return {
    environment,
    appOrigin: parsed.APP_ORIGIN,
    authSecret: parsed.AUTH_SECRET,
    workerSharedSecret: parsed.ORIGIN_SHARED_SECRET,
    cloudflareEmailApiToken: parsed.CLOUDFLARE_EMAIL_API_TOKEN,
    cloudflareAccountId: parsed.CLOUDFLARE_ACCOUNT_ID,
    emailFrom: parsed.EMAIL_FROM,
    emailSinkEnabled: environment !== "production" && emailSinkEnabled,
  };
}
