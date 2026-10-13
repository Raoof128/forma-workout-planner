/** Runs independently of the Droplet; does not receive member data. */
export async function inspectHealth(env, request = globalThis.fetch) {
  const signals = [];
  try {
    const response = await request(env.APP_ORIGIN + "/api/health", {
      redirect: "manual",
      signal: globalThis.AbortSignal.timeout(15000),
    });
    if (!response.ok) signals.push("public_account_gateway_unhealthy");
  } catch {
    signals.push("public_account_gateway_unreachable");
  }
  try {
    const latest = await env.BACKUPS.get("latest.json");
    if (!latest) signals.push("off_host_backup_missing");
    else {
      const manifest = await latest.json();
      const stamp = manifest.createdAt;
      const match = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/.exec(
        stamp ?? "",
      );
      const timestamp = match
        ? Date.UTC(
            +match[1],
            +match[2] - 1,
            +match[3],
            +match[4],
            +match[5],
            +match[6],
          )
        : NaN;
      if (!Number.isFinite(timestamp) || Date.now() - timestamp > 26 * 3600000)
        signals.push("off_host_backup_overdue");
    }
  } catch {
    signals.push("off_host_backup_unavailable");
  }
  return signals;
}

export default {
  fetch() {
    return new globalThis.Response("Not found", { status: 404 });
  },
  async scheduled(_controller, env) {
    const signals = await inspectHealth(env);
    // A separate KV namespace keeps alert suppression available during R2 failure.
    const previous = (await env.STATE.get("edge-state", "json")) ?? {
      failures: 0,
      alertedAt: 0,
    };
    const state = {
      ...previous,
      failures: signals.length ? previous.failures + 1 : 0,
      checkedAt: new Date().toISOString(),
      signals,
    };
    if (state.failures >= 2 && Date.now() - state.alertedAt > 3600000) {
      const text =
        "FORMA needs attention: " +
        signals.join(", ") +
        ". Check the private operations runbook. No member data is included.";
      const response = await globalThis.fetch(
        `https://api.cloudflare.com/client/v4/accounts/${env.CLOUDFLARE_ACCOUNT_ID}/email/sending/send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${env.EMAIL_TOKEN}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: { name: "FORMA Operations", address: env.EMAIL_FROM },
            to: env.ALERT_TO,
            subject: "[FORMA OPERATIONS] Public accounts require attention",
            text,
          }),
          signal: globalThis.AbortSignal.timeout(15000),
        },
      );
      const result = await response.json();
      if (
        !response.ok ||
        !result.success ||
        !(result.result?.queued ?? [])
          .concat(result.result?.delivered ?? [])
          .includes(env.ALERT_TO)
      )
        throw new Error("Operations alert delivery was not accepted");
      state.alertedAt = Date.now();
    }
    state.journal = [
      {
        at: state.checkedAt,
        event: signals.length ? "attention" : "healthy",
        signals,
        alertSent: state.alertedAt !== previous.alertedAt,
      },
      ...(Array.isArray(previous.journal) ? previous.journal : []),
    ].slice(0, 40);
    await env.STATE.put("edge-state", JSON.stringify(state));
    globalThis.console.log(
      JSON.stringify({
        event: "forma_health_check",
        signals,
        consecutiveFailures: state.failures,
      }),
    );
  },
};
