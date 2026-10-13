const labels = {
  public_account_gateway_unhealthy: "Account gateway needs attention",
  public_account_gateway_unreachable: "Account gateway could not be reached",
  off_host_backup_missing: "Remote backup is missing",
  off_host_backup_overdue: "Remote backup is overdue",
  off_host_backup_unavailable: "Remote backup could not be checked",
};
const get = (id) => document.getElementById(id);
const time = (value) =>
  new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
const date = (value) =>
  new Intl.DateTimeFormat(undefined, { day: "2-digit", month: "short" }).format(
    new Date(value),
  );
let busy = false;
async function refresh() {
  if (busy) return;
  busy = true;
  get("refresh").setAttribute("aria-busy", "true");
  get("journal").setAttribute("aria-busy", "true");
  try {
    const response = await fetch("/api/status", {
      cache: "no-store",
      credentials: "same-origin",
    });
    if (!response.ok) throw new Error("Recorded status could not be read");
    const value = await response.json();
    const stale =
      !value.checkedAt || Date.now() - Date.parse(value.checkedAt) > 11 * 60000;
    const attention = value.signals.length > 0;
    get("health").dataset.state = stale
      ? "unknown"
      : attention
        ? "attention"
        : "healthy";
    get("health-text").textContent = stale
      ? "Awaiting a fresh observation"
      : attention
        ? "A signal needs your attention"
        : "The training space is healthy";
    get("health-detail").textContent = stale
      ? "The next recorded check will appear here. Service state is not assumed while a check is missing or overdue."
      : attention
        ? value.signals.map((s) => labels[s]).join(" · ")
        : "Public accounts are reachable and the latest encrypted off-host backup is within its freshness window.";
    get("last-check").textContent = value.checkedAt
      ? time(value.checkedAt)
      : "Not recorded";
    get("last-check-detail").textContent = value.checkedAt
      ? date(value.checkedAt) + " · independent edge monitor"
      : "Waiting for the first scheduled observation";
    get("signal-count").textContent = String(value.signals.length);
    const fragment = document.createDocumentFragment();
    for (const row of value.journal) {
      const article = document.createElement("article");
      article.className = "event";
      const stamp = document.createElement("time");
      stamp.dateTime = row.at;
      stamp.textContent = time(row.at);
      const day = document.createElement("small");
      day.textContent = date(row.at);
      stamp.append(day);
      const content = document.createElement("div"),
        title = document.createElement("h3"),
        description = document.createElement("p");
      title.textContent =
        row.event === "healthy"
          ? "Health check passed"
          : "Check needs attention";
      description.textContent = row.signals.length
        ? row.signals.map((s) => labels[s]).join(" · ")
        : "Gateway available · remote backup current";
      if (row.alertSent) description.textContent += " · owner alert accepted";
      content.append(title, description);
      const badge = document.createElement("span");
      badge.className = "tag" + (row.event === "healthy" ? "" : " attention");
      badge.textContent = row.event === "healthy" ? "Healthy" : "Attention";
      article.append(stamp, content, badge);
      fragment.append(article);
    }
    if (!value.journal.length) {
      const empty = document.createElement("div");
      empty.className = "empty";
      empty.textContent =
        "The journal starts with the next scheduled observation. No sample events are shown.";
      fragment.append(empty);
    }
    get("journal").replaceChildren(fragment);
    get("event-count").textContent =
      value.journal.length + " recorded observations · latest first";
    get("announcement").textContent =
      "Recorded status refreshed. " +
      (stale
        ? "A fresh check is awaited."
        : attention
          ? "Attention is required."
          : "Services are healthy.");
  } catch {
    get("health").dataset.state = "unknown";
    get("health-text").textContent = "Status connection unavailable";
    get("health-detail").textContent =
      "Your training service may still be working. Refresh to retry reading the independent monitor.";
    get("announcement").textContent =
      "Status could not be refreshed. Use Refresh status to retry.";
  } finally {
    busy = false;
    get("refresh").setAttribute("aria-busy", "false");
    get("journal").setAttribute("aria-busy", "false");
  }
}
get("refresh").addEventListener("click", refresh);
void refresh();
