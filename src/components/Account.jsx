import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  ArrowDownToLine,
  ArrowLeft,
  ArrowRight,
  BadgeCheck,
  CalendarDays,
  Check,
  ChevronRight,
  CircleHelp,
  Cloud,
  Download,
  Dumbbell,
  KeyRound,
  LockKeyhole,
  Mail,
  RefreshCw,
  Shield,
  ShieldCheck,
  Smartphone,
  UserRound,
  Users,
  X,
} from "lucide-react";
import { exercises } from "../data";
import { readBackupFile } from "../storage";
import "../account.css";

const sections = [
  ["overview", "Overview", Activity],
  ["profile", "Profile", UserRound],
  ["security", "Security", Shield],
  ["training", "Training data", Dumbbell],
  ["privacy", "Privacy", LockKeyhole],
];

const initials = (name = "") =>
  name
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word[0].toUpperCase())
    .join("") || "F";
const dateLabel = (value) =>
  value
    ? new Intl.DateTimeFormat(undefined, {
        month: "long",
        day: "numeric",
        year: "numeric",
      }).format(new Date(value))
    : "Not available";
const getMetric = (workspace, key) => workspace?.data?.[key] ?? [];
const safeError = (error, fallback) => error?.message || fallback;

function AuthView({ account, notify, onNavigate }) {
  const token = new URLSearchParams(window.location.search).get("token");
  const [mode, setMode] = useState(token ? "reset" : "signin");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [mfaLoginCode, setMfaLoginCode] = useState("");
  const [useRecoveryCode, setUseRecoveryCode] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function submit(event) {
    event.preventDefault();
    setError("");
    setMessage("");
    setBusy(true);
    try {
      if (mode === "signup") {
        await account.signUp({
          name: name.trim(),
          email: email.trim(),
          password,
        });
        setMessage(
          "Your account is ready. Check your inbox for the verification link before signing in.",
        );
        setMode("signin");
      } else if (mode === "signin") {
        const result = await account.signIn({ email: email.trim(), password });
        if (result?.twoFactorRedirect) setMode("mfa");
        else notify?.("You’re signed in. Your training space is ready.");
      } else if (mode === "mfa") {
        if (useRecoveryCode) {
          await account.verifySignInBackupCode({ code: mfaLoginCode });
        } else {
          await account.verifySignInMFA({ code: mfaLoginCode });
        }
        notify?.("You’re signed in. Your training space is ready.");
      } else if (mode === "forgot") {
        await account.requestPasswordReset(email.trim());
        setMessage(
          "If an account uses this address, a reset link is on its way.",
        );
      } else if (mode === "reset") {
        await account.resetPassword({ token, newPassword });
        setMessage("Password updated. You can sign in with your new password.");
        setPassword("");
        setNewPassword("");
        setMode("signin");
      }
    } catch (cause) {
      setError(
        safeError(
          cause,
          "We couldn’t complete that request. Please try again.",
        ),
      );
    } finally {
      setBusy(false);
    }
  }

  const titles = {
    signin: "Welcome back",
    signup: "Create your account",
    forgot: "Reset your password",
    reset: "Choose a new password",
    mfa: "One more step",
  };
  const subtitles = {
    signin: "Pick up where your training left off.",
    signup: "One account for your routines, sessions and progress.",
    forgot: "We’ll send a secure reset link if this address is registered.",
    reset: "Use a fresh passphrase you have not used here before.",
    mfa: "Enter a code from your authenticator app, or use a recovery code.",
  };

  return (
    <div className="account-auth-layout">
      <aside className="account-auth-aside">
        <span className="account-kicker">
          <span className="account-dot" /> YOUR TRAINING, IN ONE PLACE
        </span>
        <h2>
          Show up.
          <br />
          <em>Build on it.</em>
        </h2>
        <p>
          Your routines and training history stay with your account, ready
          wherever you train.
        </p>
        <div className="account-aside-mark" aria-hidden="true">
          <span>F</span>
          <i />
          <i />
          <i />
        </div>
      </aside>
      <section className="account-auth-card" aria-labelledby="auth-title">
        <div className="account-kicker">FORMA MEMBER ACCESS</div>
        <h1 id="auth-title">{titles[mode]}</h1>
        <p className="account-lede">{subtitles[mode]}</p>
        {account.status === "error" && (
          <p className="account-alert" role="alert">
            {account.error || "Account service is temporarily unavailable."}
          </p>
        )}
        {error && (
          <p className="account-alert" role="alert">
            {error}
          </p>
        )}
        {message && (
          <p className="account-success" role="status">
            {message}
          </p>
        )}
        {mode === "signin" &&
          (!account.user || account.user.emailVerified === false) && (
            <div className="account-verify-note">
              <span>Need a verification link?</span>
              <button
                type="button"
                className="account-text-button"
                disabled={busy || !email.trim()}
                onClick={async () => {
                  if (!email.trim()) return;
                  setBusy(true);
                  setError("");
                  try {
                    await account.sendVerificationEmail({
                      email: email.trim(),
                    });
                    setMessage(
                      "If this address needs verification, a link is on its way.",
                    );
                  } catch (cause) {
                    setError(
                      safeError(
                        cause,
                        "We couldn’t send the verification email.",
                      ),
                    );
                  } finally {
                    setBusy(false);
                  }
                }}
              >
                Resend verification
              </button>
            </div>
          )}
        <form className="account-form" onSubmit={submit}>
          {mode === "signup" && (
            <label>
              Display name
              <input
                autoComplete="name"
                required
                maxLength={50}
                value={name}
                onChange={(event) => setName(event.target.value)}
              />
            </label>
          )}
          {mode !== "reset" && mode !== "mfa" && (
            <label>
              Email address
              <input
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(event) => setEmail(event.target.value)}
              />
            </label>
          )}
          {(mode === "signin" || mode === "signup") && (
            <label>
              Password
              <input
                type="password"
                autoComplete={
                  mode === "signin" ? "current-password" : "new-password"
                }
                required
                minLength={mode === "signup" ? 15 : undefined}
                value={password}
                onChange={(event) => setPassword(event.target.value)}
              />
              <small>
                {mode === "signup"
                  ? "Use at least 15 characters. Long passphrases work well."
                  : ""}
              </small>
            </label>
          )}
          {mode === "reset" && (
            <label>
              New password
              <input
                type="password"
                autoComplete="new-password"
                required
                minLength={15}
                value={newPassword}
                onChange={(event) => setNewPassword(event.target.value)}
              />
              <small>Use at least 15 characters.</small>
            </label>
          )}
          {mode === "mfa" && (
            <>
              <label>
                {useRecoveryCode ? "Recovery code" : "Authenticator code"}
                <input
                  autoComplete={useRecoveryCode ? "off" : "one-time-code"}
                  inputMode={useRecoveryCode ? "text" : "numeric"}
                  required
                  value={mfaLoginCode}
                  onChange={(event) => setMfaLoginCode(event.target.value)}
                />
              </label>
              <button
                type="button"
                className="account-text-button"
                onClick={() => {
                  setUseRecoveryCode((value) => !value);
                  setMfaLoginCode("");
                }}
              >
                Use {useRecoveryCode ? "authenticator code" : "recovery code"}
              </button>
            </>
          )}
          <button
            className="account-primary"
            type="submit"
            disabled={busy || account.status === "loading"}
          >
            {busy
              ? "Please wait…"
              : mode === "signup"
                ? "Create account"
                : mode === "signin"
                  ? "Sign in"
                  : mode === "forgot"
                    ? "Send reset link"
                    : mode === "mfa"
                      ? "Verify and sign in"
                      : "Update password"}
            <ArrowRight size={17} />
          </button>
        </form>
        <div className="account-auth-links">
          {mode === "signin" && (
            <>
              <button
                type="button"
                className="account-text-button"
                onClick={() => {
                  setMode("forgot");
                  setError("");
                  setMessage("");
                }}
              >
                Forgot password?
              </button>
              <button
                type="button"
                className="account-link-wide"
                onClick={() => {
                  setMode("signup");
                  setError("");
                  setMessage("");
                }}
              >
                New to FORMA? <strong>Create account</strong>
              </button>
            </>
          )}
          {mode === "signup" && (
            <button
              type="button"
              className="account-link-wide"
              onClick={() => {
                setMode("signin");
                setError("");
              }}
            >
              Already have an account? <strong>Sign in</strong>
            </button>
          )}
          {(mode === "forgot" || mode === "reset" || mode === "mfa") && (
            <button
              type="button"
              className="account-link-wide"
              onClick={() => {
                setMode("signin");
                setError("");
                setMessage("");
              }}
            >
              <ArrowLeft size={15} /> Back to sign in
            </button>
          )}
        </div>
        <div className="account-guest-note">
          <CircleHelp size={15} />{" "}
          <span>You can continue exploring as a guest.</span>
          <button
            type="button"
            className="account-text-button"
            onClick={() => onNavigate?.("overview")}
          >
            Continue as guest <ArrowRight size={14} />
          </button>
        </div>
      </section>
    </div>
  );
}

function SummaryCard({ icon: Icon, label, value, detail }) {
  return (
    <article className="account-summary-card">
      <span className="account-summary-icon">
        <Icon size={19} />
      </span>
      <span className="account-summary-label">{label}</span>
      <strong>{value}</strong>
      <small>{detail}</small>
    </article>
  );
}

export default function Account({
  account,
  workspace,
  legacy,
  onNavigate,
  notify,
}) {
  const [section, setSection] = useState("overview");
  const [name, setName] = useState("");
  const [goal, setGoal] = useState(3);
  const [email, setEmail] = useState("");
  const [profileBusy, setProfileBusy] = useState(false);
  const [profileMessage, setProfileMessage] = useState("");
  const [profileError, setProfileError] = useState("");
  const [passwordFields, setPasswordFields] = useState({
    current: "",
    next: "",
    confirm: "",
  });
  const [passwordMessage, setPasswordMessage] = useState("");
  const [passwordError, setPasswordError] = useState("");
  const [sessions, setSessions] = useState([]);
  const [sessionsBusy, setSessionsBusy] = useState(false);
  const [sessionError, setSessionError] = useState("");
  const [mfaPassword, setMfaPassword] = useState("");
  const [mfaCode, setMfaCode] = useState("");
  const [mfaEnrollment, setMfaEnrollment] = useState(null);
  const [recoveryCodes, setRecoveryCodes] = useState([]);
  const [recoveryPassword, setRecoveryPassword] = useState("");
  const [recoveryFormOpen, setRecoveryFormOpen] = useState(false);
  const [mfaDisablePassword, setMfaDisablePassword] = useState("");
  const [mfaDisableFormOpen, setMfaDisableFormOpen] = useState(false);
  const [mfaBusy, setMfaBusy] = useState(false);
  const [mfaMessage, setMfaMessage] = useState("");
  const [mfaError, setMfaError] = useState("");
  const [reauthPassword, setReauthPassword] = useState("");
  const [deletePhrase, setDeletePhrase] = useState("");
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [dataMessage, setDataMessage] = useState("");
  const [dataError, setDataError] = useState("");
  const [syncError, setSyncError] = useState("");
  const [conflictAck, setConflictAck] = useState(false);
  const [importDraft, setImportDraft] = useState(null);
  const [importAck, setImportAck] = useState(false);
  const [importBusy, setImportBusy] = useState(false);
  const [cloudBackupReady, setCloudBackupReady] = useState(false);

  const userId = account.user?.id;
  const userName = account.user?.name;
  const userEmail = account.user?.email;
  const workspaceName = workspace?.data?.profile?.name;
  const listSessions = account.listSessions;
  async function refreshSessions() {
    if (!listSessions) return;
    setSessionsBusy(true);
    setSessionError("");
    try {
      setSessions((await listSessions()) || []);
    } catch (cause) {
      setSessionError(safeError(cause, "Active sessions could not be loaded."));
    } finally {
      setSessionsBusy(false);
    }
  }
  useEffect(() => {
    if (!userId) return;
    setName(workspaceName || userName || "");
    setEmail(userEmail || "");
  }, [userId, userName, userEmail, workspaceName]);
  useEffect(() => {
    const storedGoal = Number(workspace?.data?.profile?.goal);
    if (storedGoal >= 1 && storedGoal <= 7) setGoal(storedGoal);
  }, [workspace?.data?.profile?.goal]);
  useEffect(() => {
    if (section !== "security" || !userId || !listSessions) return;
    let current = true;
    setSessionsBusy(true);
    listSessions()
      .then((items) => {
        if (current) setSessions(items || []);
      })
      .catch((cause) => {
        if (current)
          setSessionError(
            safeError(cause, "Active sessions could not be loaded."),
          );
      })
      .finally(() => {
        if (current) setSessionsBusy(false);
      });
    return () => {
      current = false;
    };
  }, [section, userId, listSessions]);

  const data = workspace?.data || {};
  const storedGoal = Number(data.profile?.goal);
  const workspaceGoal = storedGoal >= 1 && storedGoal <= 7 ? storedGoal : 3;
  const routines = getMetric(workspace, "routines");
  const history = getMetric(workspace, "history");
  const recent = history
    .slice()
    .sort(
      (a, b) =>
        new Date(b.date || b.startedAt || 0) -
        new Date(a.date || a.startedAt || 0),
    )
    .slice(0, 3);
  const weeklySessions = history.filter((session) => {
    const date = new Date(session.date || session.startedAt || 0);
    const now = new Date();
    const monday = new Date(now);
    monday.setDate(now.getDate() - ((now.getDay() + 6) % 7));
    monday.setHours(0, 0, 0, 0);
    return date >= monday && date <= now;
  }).length;
  const records = useMemo(() => {
    const best = new Map();
    history.forEach((session) =>
      (session.exercises || []).forEach((exercise) =>
        (exercise.sets || []).forEach((set) => {
          if (!set.done) return;
          const weight = Number(set.weight) || 0;
          const key = exercise.exerciseId || exercise.name || "Exercise";
          if (weight > (best.get(key)?.weight || 0))
            best.set(key, {
              weight,
              name:
                exercise.name ||
                exercises.find((item) => item.id === exercise.exerciseId)
                  ?.name ||
                key,
            });
        }),
      ),
    );
    return [...best.values()].sort((a, b) => b.weight - a.weight).slice(0, 3);
  }, [history]);
  const syncLabel =
    {
      loading: "Connecting",
      ready: "Synced",
      saving: "Saving",
      offline: "Offline",
      conflict: "Needs review",
      error: "Unavailable",
    }[workspace?.status] || "Checking";
  const memberName =
    data.profile?.name?.trim() || account.user?.name || "FORMA member";

  async function saveProfile(event) {
    event.preventDefault();
    setProfileBusy(true);
    setProfileError("");
    setProfileMessage("");
    try {
      const nextName = name.trim();
      const currentWorkspaceName = data.profile?.name || account.user.name;
      const workspaceNameChanged = nextName !== currentWorkspaceName;
      const accountNameChanged = nextName !== account.user.name;
      const goalChanged = Number(goal) !== Number(data.profile?.goal);
      if (workspaceNameChanged || goalChanged) {
        await workspace.commit(
          (current) => ({
            ...current,
            profile: {
              ...current.profile,
              name: nextName,
              goal: Number(goal),
            },
          }),
          { operationId: `account-goal-${Date.now()}` },
        );
      }
      if (accountNameChanged) {
        try {
          await account.updateProfile({ name: nextName });
        } catch (cause) {
          setProfileError(
            `Your training profile was saved, but your account name could not be synced: ${safeError(cause, "Please try again.")}`,
          );
          return;
        }
      }
      setProfileMessage("Profile and training goal saved.");
      notify?.("Profile updated.");
    } catch (cause) {
      setProfileError(safeError(cause, "Your profile could not be saved."));
    } finally {
      setProfileBusy(false);
    }
  }

  function cancelProfileChanges() {
    setName(data.profile?.name || account.user?.name || "");
    const savedGoal = Number(data.profile?.goal);
    setGoal(savedGoal >= 1 && savedGoal <= 7 ? savedGoal : 3);
    setProfileError("");
    setProfileMessage("");
  }

  async function changeEmail(event) {
    event.preventDefault();
    setProfileBusy(true);
    setProfileError("");
    setProfileMessage("");
    try {
      await account.changeEmail({
        newEmail: email.trim(),
      });
      setProfileMessage(
        "Approve this request from your current inbox, then verify the new address. Your current email stays in use until both steps are complete.",
      );
    } catch (cause) {
      setProfileError(safeError(cause, "We couldn’t start the email change."));
    } finally {
      setProfileBusy(false);
    }
  }

  async function changePassword(event) {
    event.preventDefault();
    setPasswordError("");
    setPasswordMessage("");
    if (passwordFields.next.length < 15) {
      setPasswordError("Use at least 15 characters for your new password.");
      return;
    }
    if (passwordFields.next !== passwordFields.confirm) {
      setPasswordError("The new passwords do not match.");
      return;
    }
    try {
      await account.changePassword({
        currentPassword: passwordFields.current,
        newPassword: passwordFields.next,
      });
      setPasswordFields({ current: "", next: "", confirm: "" });
      setPasswordMessage("Password updated. Other sessions were signed out.");
    } catch (cause) {
      setPasswordError(safeError(cause, "Password could not be updated."));
    }
  }

  async function startMFA(event) {
    event.preventDefault();
    setMfaBusy(true);
    setMfaError("");
    setMfaMessage("");
    try {
      const setup = await account.enableMFA({ password: mfaPassword });
      setMfaEnrollment(setup);
      setMfaPassword("");
      setRecoveryCodes(setup?.backupCodes || setup?.recoveryCodes || []);
    } catch (cause) {
      setMfaError(
        safeError(cause, "Two-step verification could not be enabled."),
      );
    } finally {
      setMfaBusy(false);
    }
  }

  async function verifyMFA(event) {
    event.preventDefault();
    setMfaBusy(true);
    setMfaError("");
    try {
      await account.verifyMFA({ code: mfaCode });
      setMfaEnrollment(null);
      setMfaCode("");
      setMfaMessage("Two-step verification is now on.");
    } catch (cause) {
      setMfaError(
        safeError(
          cause,
          "That code could not be verified. Try the latest code from your authenticator.",
        ),
      );
    } finally {
      setMfaBusy(false);
    }
  }

  async function showRecoveryCodes(event) {
    event.preventDefault();
    setMfaBusy(true);
    setMfaError("");
    try {
      setRecoveryCodes(
        await account.recoveryCodes({ password: recoveryPassword }),
      );
      setRecoveryPassword("");
      setRecoveryFormOpen(false);
    } catch (cause) {
      setMfaError(safeError(cause, "Recovery codes could not be loaded."));
    } finally {
      setMfaBusy(false);
    }
  }

  async function disableMFA(event) {
    event.preventDefault();
    setMfaBusy(true);
    setMfaError("");
    try {
      await account.disableMFA({ password: mfaDisablePassword });
      setMfaMessage("Two-step verification is off.");
      setMfaDisablePassword("");
      setMfaDisableFormOpen(false);
    } catch (cause) {
      setMfaError(
        safeError(cause, "Two-step verification could not be disabled."),
      );
    } finally {
      setMfaBusy(false);
    }
  }

  async function handleExport() {
    setDataError("");
    setDataMessage("");
    if (importDraft) setCloudBackupReady(false);
    try {
      await workspace.exportData();
      if (importDraft) setCloudBackupReady(true);
      setDataMessage("Your account data export is ready.");
    } catch (cause) {
      setDataError(safeError(cause, "The export could not be created."));
    }
  }

  function exportAttemptedChanges() {
    const attempted = workspace?.conflict?.attempted;
    if (!attempted) {
      setSyncError("The attempted changes are no longer available to export.");
      return;
    }
    const blob = new Blob([JSON.stringify(attempted)], {
      type: "application/json",
    });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = "forma-unsynced-changes.json";
    anchor.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    setSyncError("");
  }

  async function handleImport(event) {
    const input = event.currentTarget;
    const file = input.files?.[0];
    if (!file) return;
    setDataError("");
    setDataMessage("");
    try {
      const backup = await readBackupFile(file);
      setImportDraft({
        backup,
        source: file.name,
        summary: {
          routines: backup.routines?.length || 0,
          workouts: backup.history?.length || 0,
        },
      });
      setImportAck(false);
      setCloudBackupReady(false);
    } catch (cause) {
      setDataError(
        safeError(
          cause,
          "This backup could not be imported. No data was changed.",
        ),
      );
    } finally {
      input.value = "";
    }
  }

  async function confirmImport() {
    if (!importDraft || !importAck || !cloudBackupReady) return;
    setImportBusy(true);
    setDataError("");
    try {
      await workspace.importLegacy(importDraft.backup);
      setDataMessage("Workout backup imported into your account.");
      setImportDraft(null);
      setImportAck(false);
      setCloudBackupReady(false);
    } catch (cause) {
      setDataError(safeError(cause, "The backup could not be imported."));
    } finally {
      setImportBusy(false);
    }
  }

  async function deleteAccount(event) {
    event.preventDefault();
    if (deletePhrase !== "DELETE") return;
    setDeleteBusy(true);
    setDataError("");
    try {
      await account.deleteAccount({ password: reauthPassword });
      setDeleteOpen(false);
      notify?.(
        "Confirmation email sent. Your account remains active until you confirm.",
      );
    } catch (cause) {
      setDataError(safeError(cause, "Your account could not be deleted."));
    } finally {
      setDeleteBusy(false);
    }
  }

  if (account.status === "loading")
    return (
      <div className="account-loading" role="status">
        <span className="account-spinner" />
        Loading your account…
      </div>
    );
  if (account.status !== "authenticated" || !account.user)
    return (
      <AuthView account={account} notify={notify} onNavigate={onNavigate} />
    );
  if (!workspace?.data)
    return (
      <div
        className="account-workspace-state"
        role={
          workspace?.status === "error" || workspace?.status === "offline"
            ? "alert"
            : "status"
        }
      >
        <span className="account-kicker">ACCOUNT TRAINING DATA</span>
        <h1>
          {workspace?.status === "error" || workspace?.status === "offline"
            ? "Cloud data is unavailable"
            : "Loading your training data"}
        </h1>
        <p>
          {workspace?.status === "error" || workspace?.status === "offline"
            ? "Your account is still signed in. Retry the secure connection to load your routines and history."
            : "Your routines and workout history are being loaded from your account."}
        </p>
        {(workspace?.status === "error" || workspace?.status === "offline") && (
          <button
            type="button"
            className="account-secondary"
            onClick={() => workspace.retry?.()}
          >
            <RefreshCw size={16} /> Retry connection
          </button>
        )}
      </div>
    );

  return (
    <div className="account-page">
      <header className="account-page-head">
        <div>
          <span className="account-kicker">YOUR FORMA</span>
          <h1>Account</h1>
          <p>Keep your training and account details in good shape.</p>
        </div>
        <div className="account-sync" data-state={workspace?.status}>
          <Cloud size={17} />
          <span>
            <strong>{syncLabel}</strong>
            <small>Workout data</small>
          </span>
        </div>
      </header>
      <div className="account-layout">
        <nav className="account-nav" aria-label="Account sections">
          <div className="account-nav-member">
            <span className="account-avatar">{initials(memberName)}</span>
            <span>
              <strong>{memberName}</strong>
              <small>{account.user.email}</small>
            </span>
          </div>
          <div className="account-nav-items">
            {sections.map(([id, label, Icon]) => (
              <button
                key={id}
                type="button"
                aria-current={section === id ? "page" : undefined}
                className={section === id ? "is-current" : ""}
                onClick={() => setSection(id)}
              >
                <Icon size={17} />
                <span>{label}</span>
                <ChevronRight size={15} />
              </button>
            ))}
          </div>
          <button
            type="button"
            className="account-back-workspace"
            onClick={() => onNavigate?.("overview")}
          >
            <ArrowLeft size={16} /> Back to training
          </button>
        </nav>
        <div className="account-content">
          {["offline", "error", "conflict"].includes(workspace?.status) && (
            <div className="account-callout account-sync-alert" role="alert">
              <RefreshCw size={17} />
              <span>
                {syncError ||
                  (workspace.status === "conflict"
                    ? "Training data changed on another device. Reloading will replace your unsynced edits with the cloud copy."
                    : "Your account is available, but training data is not synced right now.")}
              </span>
              {workspace.status === "conflict" && (
                <>
                  <button type="button" onClick={exportAttemptedChanges}>
                    Export my unsynced changes
                  </button>
                  <label className="account-conflict-confirm">
                    <input
                      type="checkbox"
                      checked={conflictAck}
                      onChange={(event) => setConflictAck(event.target.checked)}
                    />
                    I understand reloading replaces my unsynced edits.
                  </label>
                </>
              )}
              <button
                type="button"
                onClick={async () => {
                  setSyncError("");
                  try {
                    if (workspace.status === "conflict" && conflictAck) {
                      await workspace.reloadConflict?.();
                      setConflictAck(false);
                    } else if (workspace.status !== "conflict") {
                      await workspace.retry?.();
                    }
                  } catch (cause) {
                    setSyncError(
                      safeError(cause, "Training data could not be refreshed."),
                    );
                  }
                }}
                disabled={workspace.status === "conflict" && !conflictAck}
              >
                {workspace.status === "conflict"
                  ? "Reload cloud data"
                  : "Retry sync"}
              </button>
            </div>
          )}
          {section === "overview" && (
            <>
              <section className="account-welcome">
                <div className="account-welcome-copy">
                  <span className="account-kicker">
                    MEMBER SINCE{" "}
                    {account.user.createdAt
                      ? dateLabel(account.user.createdAt).toUpperCase()
                      : ""}
                  </span>
                  <h2>
                    Good work,
                    <br />
                    <em>{memberName.split(/\s+/)[0]}.</em>
                  </h2>
                  <p>
                    Your next session starts with what you’ve already built.
                  </p>
                </div>
                <div className="account-welcome-profile">
                  <span className="account-avatar account-avatar-large">
                    {initials(memberName)}
                  </span>
                  <div>
                    <strong>{memberName}</strong>
                    <span>{account.user.email}</span>
                    <span
                      className={
                        account.user.emailVerified
                          ? "account-verified"
                          : "account-unverified"
                      }
                    >
                      {account.user.emailVerified ? (
                        <>
                          <BadgeCheck size={15} /> Email verified
                        </>
                      ) : (
                        <>
                          <Mail size={15} /> Email not verified
                        </>
                      )}
                    </span>
                  </div>
                </div>
              </section>
              {!account.user.emailVerified && (
                <div className="account-callout">
                  <Mail size={18} />
                  <span>
                    Verify your email to keep account recovery available.
                  </span>
                  <button
                    type="button"
                    onClick={async () => {
                      try {
                        await account.sendVerificationEmail();
                        notify?.("Verification email sent.");
                      } catch (cause) {
                        setProfileError(
                          safeError(
                            cause,
                            "Verification email could not be sent.",
                          ),
                        );
                      }
                    }}
                  >
                    Resend email
                  </button>
                </div>
              )}
              <div className="account-summary-grid">
                <SummaryCard
                  icon={Activity}
                  label="Workouts completed"
                  value={history.length}
                  detail="Saved to your account"
                />
                <SummaryCard
                  icon={CalendarDays}
                  label="This week"
                  value={`${weeklySessions} / ${workspaceGoal}`}
                  detail="Sessions toward your goal"
                />
                <SummaryCard
                  icon={Dumbbell}
                  label="Saved routines"
                  value={routines.length}
                  detail="Ready when you are"
                />
              </div>
              <div className="account-overview-columns">
                <section className="account-panel">
                  <div className="account-panel-heading">
                    <div>
                      <span className="account-kicker">RECENT WORK</span>
                      <h3>Latest sessions</h3>
                    </div>
                    <button
                      type="button"
                      className="account-text-button"
                      onClick={() => setSection("training")}
                    >
                      All training <ArrowRight size={15} />
                    </button>
                  </div>
                  {recent.length ? (
                    <div className="account-session-list">
                      {recent.map((item) => (
                        <div
                          className="account-session-row"
                          key={item.id || item.date}
                        >
                          <span className="account-session-icon">
                            <Dumbbell size={16} />
                          </span>
                          <span>
                            <strong>{item.name || "Workout"}</strong>
                            <small>
                              {dateLabel(item.date || item.startedAt)}
                            </small>
                          </span>
                          <span className="account-session-duration">
                            {item.duration
                              ? `${Math.round(item.duration / 60)} min`
                              : "Saved"}
                          </span>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="account-empty">
                      <Activity size={22} />
                      <span>Your completed workouts will show here.</span>
                      <button
                        type="button"
                        onClick={() => onNavigate?.("routines")}
                      >
                        Browse routines
                      </button>
                    </div>
                  )}
                </section>
                <section className="account-panel account-record-panel">
                  <div className="account-panel-heading">
                    <div>
                      <span className="account-kicker">PERSONAL RECORDS</span>
                      <h3>Strongest sets</h3>
                    </div>
                    <KeyRound size={19} />
                  </div>
                  {records.length ? (
                    <ul className="account-record-list">
                      {records.map((record) => (
                        <li key={record.name}>
                          <span>{record.name}</span>
                          <strong>
                            {record.weight} <small>kg</small>
                          </strong>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="account-empty-copy">
                      Records appear after you save a workout with a completed
                      set.
                    </p>
                  )}
                </section>
              </div>
              <section className="account-goal-strip">
                <div>
                  <span className="account-kicker">WEEKLY RHYTHM</span>
                  <strong>
                    {weeklySessions} of {workspaceGoal} sessions
                  </strong>
                </div>
                <div
                  className="account-goal-track"
                  role="progressbar"
                  aria-label="Weekly workout goal progress"
                  aria-valuemin="0"
                  aria-valuemax={workspaceGoal}
                  aria-valuenow={Math.min(weeklySessions, workspaceGoal)}
                >
                  <span
                    style={{
                      width: `${Math.min(100, (weeklySessions / Math.max(workspaceGoal, 1)) * 100)}%`,
                    }}
                  />
                </div>
                <button
                  type="button"
                  className="account-text-button"
                  onClick={() => setSection("profile")}
                >
                  Edit goal <ArrowRight size={15} />
                </button>
              </section>
            </>
          )}

          {section === "profile" && (
            <section className="account-section">
              <div className="account-section-heading">
                <span className="account-kicker">PERSONAL DETAILS</span>
                <h2>Your profile</h2>
                <p>
                  Use the name and goal that make your training space feel like
                  yours.
                </p>
              </div>
              <form className="account-settings-form" onSubmit={saveProfile}>
                <div className="account-settings-title">
                  <UserRound size={18} />
                  <h3>Profile details</h3>
                </div>
                <label>
                  Display name
                  <input
                    required
                    maxLength={50}
                    value={name}
                    onChange={(event) => setName(event.target.value)}
                  />
                </label>
                <label>
                  Weekly workout goal
                  <select
                    value={goal}
                    onChange={(event) => setGoal(Number(event.target.value))}
                  >
                    {Array.from({ length: 7 }, (_, i) => (
                      <option key={i + 1} value={i + 1}>
                        {i + 1} {i === 0 ? "workout" : "workouts"} per week
                      </option>
                    ))}
                  </select>
                </label>
                <div className="account-form-foot">
                  <span>Weights use kg. Dates follow your device locale.</span>
                  <button
                    type="button"
                    className="account-secondary"
                    disabled={profileBusy}
                    onClick={cancelProfileChanges}
                  >
                    Cancel changes
                  </button>
                  <button
                    type="submit"
                    className="account-primary"
                    disabled={profileBusy}
                  >
                    {profileBusy ? "Saving…" : "Save changes"}
                    <Check size={16} />
                  </button>
                </div>
              </form>
              {profileMessage && (
                <p className="account-success" role="status">
                  {profileMessage}
                </p>
              )}
              {profileError && (
                <p className="account-alert" role="alert">
                  {profileError}
                </p>
              )}
              <form className="account-settings-form" onSubmit={changeEmail}>
                <div className="account-settings-title">
                  <Mail size={18} />
                  <h3>Change email address</h3>
                </div>
                <p className="account-form-intro">
                  Approve the request from your current inbox, then verify the
                  new address. Your current email stays in use until both steps
                  are complete.
                </p>
                <label>
                  New email address
                  <input
                    type="email"
                    autoComplete="email"
                    required
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                  />
                </label>
                <div className="account-form-foot">
                  <span>Current: {account.user.email}</span>
                  <button
                    type="submit"
                    className="account-secondary"
                    disabled={profileBusy}
                  >
                    Send verification <ArrowRight size={16} />
                  </button>
                </div>
              </form>
            </section>
          )}

          {section === "security" && (
            <section className="account-section">
              <div className="account-section-heading">
                <span className="account-kicker">KEEP YOUR ACCOUNT SAFE</span>
                <h2>Security</h2>
                <p>
                  Review sign-in protection and manage the devices using your
                  account.
                </p>
              </div>
              <form className="account-settings-form" onSubmit={changePassword}>
                <div className="account-settings-title">
                  <KeyRound size={18} />
                  <h3>Change password</h3>
                </div>
                <label>
                  Current password
                  <input
                    type="password"
                    autoComplete="current-password"
                    required
                    value={passwordFields.current}
                    onChange={(event) =>
                      setPasswordFields({
                        ...passwordFields,
                        current: event.target.value,
                      })
                    }
                  />
                </label>
                <label>
                  New password
                  <input
                    type="password"
                    autoComplete="new-password"
                    required
                    minLength={15}
                    value={passwordFields.next}
                    onChange={(event) =>
                      setPasswordFields({
                        ...passwordFields,
                        next: event.target.value,
                      })
                    }
                  />
                  <small>
                    At least 15 characters. Passphrases are welcome.
                  </small>
                </label>
                <label>
                  Confirm new password
                  <input
                    type="password"
                    autoComplete="new-password"
                    required
                    value={passwordFields.confirm}
                    onChange={(event) =>
                      setPasswordFields({
                        ...passwordFields,
                        confirm: event.target.value,
                      })
                    }
                  />
                </label>
                <div className="account-form-foot">
                  <span>Changing your password signs out other sessions.</span>
                  <button type="submit" className="account-secondary">
                    Update password <ArrowRight size={16} />
                  </button>
                </div>
                {passwordMessage && (
                  <p className="account-success" role="status">
                    {passwordMessage}
                  </p>
                )}
                {passwordError && (
                  <p className="account-alert" role="alert">
                    {passwordError}
                  </p>
                )}
              </form>
              <section className="account-settings-form">
                <div className="account-settings-title">
                  <Smartphone size={18} />
                  <div>
                    <h3>Two-step verification</h3>
                    <small>Add an authenticator app as a second layer.</small>
                  </div>
                  <span
                    className={`account-status-pill ${account.user.twoFactorEnabled ? "is-on" : ""}`}
                  >
                    {account.user.twoFactorEnabled ? "ON" : "OFF"}
                  </span>
                </div>
                {mfaMessage && (
                  <p className="account-success" role="status">
                    {mfaMessage}
                  </p>
                )}
                {mfaError && (
                  <p className="account-alert" role="alert">
                    {mfaError}
                  </p>
                )}
                {!account.user.twoFactorEnabled && !mfaEnrollment && (
                  <form className="account-inline-form" onSubmit={startMFA}>
                    <label>
                      Confirm your password
                      <input
                        type="password"
                        autoComplete="current-password"
                        required
                        value={mfaPassword}
                        onChange={(event) => setMfaPassword(event.target.value)}
                      />
                    </label>
                    <button
                      type="submit"
                      className="account-secondary"
                      disabled={mfaBusy}
                    >
                      {mfaBusy ? "Preparing…" : "Set up authenticator"}
                      <ArrowRight size={16} />
                    </button>
                  </form>
                )}
                {mfaEnrollment && (
                  <div className="account-mfa-setup">
                    <ol>
                      <li>Open an authenticator app and add a new account.</li>
                      <li>
                        Enter this setup key if scanning is unavailable:{" "}
                        <code>
                          {mfaEnrollment.secret ||
                            (() => {
                              try {
                                return (
                                  new URL(
                                    mfaEnrollment.totpURI,
                                  ).searchParams.get("secret") ||
                                  mfaEnrollment.totpURI
                                );
                              } catch {
                                return mfaEnrollment.totpURI;
                              }
                            })()}
                        </code>
                      </li>
                      <li>
                        Enter the current six-digit code to confirm setup.
                      </li>
                    </ol>
                    <form className="account-inline-form" onSubmit={verifyMFA}>
                      <label>
                        Authenticator code
                        <input
                          inputMode="numeric"
                          autoComplete="one-time-code"
                          pattern="[0-9]{6}"
                          minLength={6}
                          maxLength={6}
                          required
                          value={mfaCode}
                          onChange={(event) =>
                            setMfaCode(event.target.value.replace(/\D/g, ""))
                          }
                        />
                      </label>
                      <button
                        type="submit"
                        className="account-secondary"
                        disabled={mfaBusy}
                      >
                        Verify and enable <Check size={16} />
                      </button>
                    </form>
                    {recoveryCodes.length > 0 && (
                      <div className="account-codes">
                        <strong>Save these recovery codes now</strong>
                        <p>
                          Each code can be used once if you lose access to your
                          authenticator.
                        </p>
                        <pre>{recoveryCodes.join("\n")}</pre>
                      </div>
                    )}
                  </div>
                )}
                {account.user.twoFactorEnabled && (
                  <div className="account-mfa-actions">
                    <button
                      type="button"
                      className="account-text-button"
                      disabled={mfaBusy}
                      onClick={() => setRecoveryFormOpen(true)}
                    >
                      Generate new recovery codes
                    </button>
                    {!mfaDisableFormOpen && (
                      <button
                        type="button"
                        className="account-danger-link"
                        disabled={mfaBusy}
                        onClick={() => setMfaDisableFormOpen(true)}
                      >
                        Turn off
                      </button>
                    )}
                  </div>
                )}
                {account.user.twoFactorEnabled && mfaDisableFormOpen && (
                  <form className="account-inline-form" onSubmit={disableMFA}>
                    <label>
                      Confirm your password
                      <input
                        type="password"
                        autoComplete="current-password"
                        required
                        value={mfaDisablePassword}
                        onChange={(event) =>
                          setMfaDisablePassword(event.target.value)
                        }
                      />
                    </label>
                    <div className="account-form-foot">
                      <button
                        type="button"
                        className="account-text-button"
                        onClick={() => {
                          setMfaDisableFormOpen(false);
                          setMfaDisablePassword("");
                        }}
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        className="account-danger-button"
                        disabled={mfaBusy}
                      >
                        {mfaBusy
                          ? "Turning off…"
                          : "Turn off two-step verification"}
                      </button>
                    </div>
                  </form>
                )}
                {account.user.twoFactorEnabled && recoveryFormOpen && (
                  <form
                    className="account-inline-form"
                    onSubmit={showRecoveryCodes}
                  >
                    <p className="account-form-intro">
                      Generating new codes replaces every existing recovery
                      code. Save the new set before closing this page.
                    </p>
                    <label>
                      Confirm your password
                      <input
                        type="password"
                        autoComplete="current-password"
                        required
                        value={recoveryPassword}
                        onChange={(event) =>
                          setRecoveryPassword(event.target.value)
                        }
                      />
                    </label>
                    <div className="account-form-foot">
                      <button
                        type="button"
                        className="account-text-button"
                        onClick={() => {
                          setRecoveryFormOpen(false);
                          setRecoveryPassword("");
                        }}
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        className="account-secondary"
                        disabled={mfaBusy}
                      >
                        {mfaBusy ? "Generating…" : "Generate new codes"}
                      </button>
                    </div>
                  </form>
                )}
                {recoveryCodes.length > 0 && !mfaEnrollment && (
                  <div className="account-codes">
                    <strong>Recovery codes</strong>
                    <pre>{recoveryCodes.join("\n")}</pre>
                    <button
                      className="account-text-button"
                      type="button"
                      onClick={() => {
                        const blob = new Blob([recoveryCodes.join("\n")], {
                          type: "text/plain",
                        });
                        const url = URL.createObjectURL(blob);
                        const anchor = document.createElement("a");
                        anchor.href = url;
                        anchor.download = "forma-recovery-codes.txt";
                        anchor.click();
                        URL.revokeObjectURL(url);
                      }}
                    >
                      Download codes <Download size={15} />
                    </button>
                  </div>
                )}
              </section>
              <section className="account-settings-form">
                <div className="account-settings-title">
                  <Users size={18} />
                  <div>
                    <h3>Active sessions</h3>
                    <small>
                      Signed-in browsers and devices for your account.
                    </small>
                  </div>
                  <button
                    type="button"
                    className="account-icon-action"
                    aria-label="Refresh sessions"
                    disabled={sessionsBusy}
                    onClick={() => {
                      void refreshSessions();
                    }}
                  >
                    <RefreshCw size={16} />
                  </button>
                </div>
                {sessionError && (
                  <p className="account-alert" role="alert">
                    {sessionError}
                  </p>
                )}
                {sessionsBusy ? (
                  <p className="account-muted-row">Loading sessions…</p>
                ) : sessions.length ? (
                  <div className="account-session-list">
                    {sessions.map((session, index) => (
                      <div
                        className="account-device-row"
                        key={session.id || index}
                      >
                        <span className="account-device-icon">
                          <Smartphone size={16} />
                        </span>
                        <span>
                          <strong>
                            {session.userAgent || "Signed-in device"}
                          </strong>
                          <small>
                            {session.current ? "This device · " : ""}
                            {dateLabel(session.updatedAt || session.createdAt)}
                            {session.ipAddress ? ` · ${session.ipAddress}` : ""}
                          </small>
                        </span>
                        {session.current ? (
                          <span className="account-current-pill">Current</span>
                        ) : (
                          <button
                            type="button"
                            className="account-text-button"
                            onClick={async () => {
                              try {
                                await account.revokeSession({ id: session.id });
                                setSessions((items) =>
                                  items.filter(
                                    (item) => item.id !== session.id,
                                  ),
                                );
                              } catch (cause) {
                                setPasswordError(
                                  safeError(
                                    cause,
                                    "Session could not be revoked.",
                                  ),
                                );
                              }
                            }}
                          >
                            Revoke
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="account-muted-row">
                    No session details are available.
                  </p>
                )}
                <button
                  type="button"
                  className="account-danger-link account-signout-others"
                  onClick={async () => {
                    if (!window.confirm("Sign out all other devices?")) return;
                    try {
                      await account.signOutOthers();
                      setSessions((items) =>
                        items.filter((item) => item.current),
                      );
                    } catch (cause) {
                      setPasswordError(
                        safeError(
                          cause,
                          "Other sessions could not be signed out.",
                        ),
                      );
                    }
                  }}
                >
                  Sign out other devices <ArrowRight size={15} />
                </button>
                <button
                  type="button"
                  className="account-danger-link account-signout-others"
                  onClick={async () => {
                    if (!window.confirm("Sign out of FORMA on every device?"))
                      return;
                    try {
                      await account.signOutEverywhere();
                      notify?.("You’ve been signed out on all devices.");
                    } catch (cause) {
                      setSessionError(
                        safeError(cause, "Sessions could not be ended."),
                      );
                    }
                  }}
                >
                  Sign out everywhere <ArrowRight size={15} />
                </button>
              </section>
              <div className="account-security-foot">
                <ShieldCheck size={18} />
                <span>
                  Password and account changes require a verified sign-in.
                  Session expiry and revocation are enforced by the account
                  service.
                </span>
              </div>
            </section>
          )}

          {section === "training" && (
            <section className="account-section">
              <div className="account-section-heading">
                <span className="account-kicker">YOUR WORK, KEPT</span>
                <h2>Training data</h2>
                <p>
                  Routines and completed sessions saved to your member account.
                </p>
              </div>
              <div className="account-data-toolbar">
                <div className="account-data-status">
                  <Cloud size={17} />
                  <span>
                    <strong>{syncLabel}</strong>
                    <small>
                      {workspace?.updatedAt
                        ? `Last updated ${dateLabel(workspace.updatedAt)}`
                        : "Account sync status"}
                    </small>
                  </span>
                </div>
                <button
                  type="button"
                  className="account-secondary"
                  onClick={handleExport}
                >
                  <Download size={16} /> Export my data
                </button>
                <label className="account-secondary account-import-label">
                  <ArrowDownToLine size={16} /> Import workout backup
                  <input
                    type="file"
                    accept="application/json,.json"
                    onChange={handleImport}
                  />
                </label>
              </div>
              {dataMessage && (
                <p className="account-success" role="status">
                  {dataMessage}
                </p>
              )}
              {dataError && !deleteOpen && (
                <p className="account-alert" role="alert">
                  {dataError}
                </p>
              )}
              {legacy?.status === "available" && (
                <section className="account-migration-card">
                  <div>
                    <span className="account-kicker">LOCAL TRAINING FOUND</span>
                    <h3>Bring your existing workouts with you</h3>
                    <p>
                      Your browser has local training data. Review the counts
                      before importing it to this account. Existing browser data
                      will stay in place.
                    </p>
                  </div>
                  <span className="account-migration-count">
                    {legacy.data?.routines?.length || 0} routines ·{" "}
                    {legacy.data?.history?.length || 0} workouts
                  </span>
                  <button
                    type="button"
                    className="account-secondary"
                    onClick={() => {
                      setImportDraft({
                        backup: legacy.data,
                        source: "This browser",
                        summary: {
                          routines: legacy.data?.routines?.length || 0,
                          workouts: legacy.data?.history?.length || 0,
                        },
                      });
                      setImportAck(false);
                      setCloudBackupReady(false);
                    }}
                  >
                    Review local data
                  </button>
                </section>
              )}
              {legacy?.status === "invalid" && (
                <div className="account-alert" role="alert">
                  We found local training data that cannot be read as a valid
                  backup. Your original browser data remains untouched.
                </div>
              )}
              {importDraft && (
                <section className="account-import-review">
                  <div>
                    <span className="account-kicker">
                      IMPORT REVIEW · {importDraft.source}
                    </span>
                    <h3>Confirm training data</h3>
                    <p>
                      This replaces the current cloud training copy with the
                      selected data. The source stays unchanged.
                    </p>
                  </div>
                  <div className="account-import-totals">
                    <span>
                      <strong>{importDraft.summary.routines}</strong> routines
                    </span>
                    <span>
                      <strong>{importDraft.summary.workouts}</strong> workouts
                    </span>
                  </div>
                  <button
                    type="button"
                    className="account-text-button"
                    onClick={handleExport}
                  >
                    {cloudBackupReady
                      ? "Cloud copy downloaded"
                      : "Download current cloud copy before replacing"}
                    <Download size={15} />
                  </button>
                  <label className="account-import-confirm">
                    <input
                      type="checkbox"
                      checked={importAck}
                      onChange={(event) => setImportAck(event.target.checked)}
                    />{" "}
                    I reviewed the counts and saved a copy of my current cloud
                    training data.
                  </label>
                  <div className="account-delete-actions">
                    <button
                      type="button"
                      className="account-secondary"
                      onClick={() => {
                        setImportDraft(null);
                        setImportAck(false);
                      }}
                    >
                      Cancel
                    </button>
                    <button
                      type="button"
                      className="account-primary"
                      disabled={!importAck || !cloudBackupReady || importBusy}
                      onClick={confirmImport}
                    >
                      {importBusy ? "Importing…" : "Import to account"}
                      <ArrowRight size={16} />
                    </button>
                  </div>
                </section>
              )}
              <div className="account-training-counts">
                <div>
                  <strong>{routines.length}</strong>
                  <span>Routines</span>
                </div>
                <div>
                  <strong>{history.length}</strong>
                  <span>Workouts</span>
                </div>
                <div>
                  <strong>
                    {Array.isArray(data.schedule) ? data.schedule.length : 0}
                  </strong>
                  <span>Training days</span>
                </div>
              </div>
              <section className="account-settings-form">
                <div className="account-panel-heading">
                  <div>
                    <span className="account-kicker">SAVED ROUTINES</span>
                    <h3>Your plan</h3>
                  </div>
                  <button
                    type="button"
                    className="account-text-button"
                    onClick={() => onNavigate?.("routines")}
                  >
                    Open routines <ArrowRight size={15} />
                  </button>
                </div>
                {routines.length ? (
                  <div className="account-routine-list">
                    {routines.map((routine) => (
                      <button
                        type="button"
                        key={routine.id}
                        onClick={() => onNavigate?.("routines")}
                      >
                        <span className="account-routine-icon">
                          <Dumbbell size={16} />
                        </span>
                        <span>
                          <strong>{routine.name}</strong>
                          <small>
                            {routine.exercises?.length || 0} exercises ·{" "}
                            {routine.minutes || "—"} min
                          </small>
                        </span>
                        <ChevronRight size={16} />
                      </button>
                    ))}
                  </div>
                ) : (
                  <p className="account-muted-row">
                    No routines have been saved yet.
                  </p>
                )}
              </section>
              <section className="account-settings-form">
                <div className="account-panel-heading">
                  <div>
                    <span className="account-kicker">TRAINING HISTORY</span>
                    <h3>Recent sessions</h3>
                  </div>
                  <button
                    type="button"
                    className="account-text-button"
                    onClick={() => onNavigate?.("history")}
                  >
                    Open history <ArrowRight size={15} />
                  </button>
                </div>
                {history.length ? (
                  <div className="account-session-list">
                    {recent.map((item) => (
                      <div
                        className="account-session-row"
                        key={item.id || item.date}
                      >
                        <span className="account-session-icon">
                          <Dumbbell size={16} />
                        </span>
                        <span>
                          <strong>{item.name || "Workout"}</strong>
                          <small>
                            {dateLabel(item.date || item.startedAt)}
                          </small>
                        </span>
                        <span className="account-session-duration">
                          {item.duration
                            ? `${Math.round(item.duration / 60)} min`
                            : "Saved"}
                        </span>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="account-muted-row">
                    Completed workouts will appear here.
                  </p>
                )}
              </section>
            </section>
          )}

          {section === "privacy" && (
            <section className="account-section">
              <div className="account-section-heading">
                <span className="account-kicker">YOUR DATA, YOUR CALL</span>
                <h2>Privacy &amp; account</h2>
                <p>
                  Export a copy, sign out of this device or request account
                  deletion.
                </p>
              </div>
              <section className="account-settings-form account-privacy-card">
                <div className="account-settings-title">
                  <Cloud size={18} />
                  <div>
                    <h3>Cloud workout storage</h3>
                    <small>
                      Your account is the home for your saved routines, settings
                      and workout history.
                    </small>
                  </div>
                  <span className="account-status-pill is-on">
                    {syncLabel.toUpperCase()}
                  </span>
                </div>
                <p>
                  Workout data is attached to your signed-in account. Signing
                  out does not delete it. Account deletion removes active
                  account data; operational backups follow the service retention
                  schedule.
                </p>
                <button
                  type="button"
                  className="account-secondary"
                  onClick={handleExport}
                >
                  <Download size={16} /> Export my data
                </button>
              </section>
              <section className="account-settings-form account-signout-card">
                <div className="account-settings-title">
                  <ArrowLeft size={18} />
                  <div>
                    <h3>Sign out</h3>
                    <small>End this session on this device.</small>
                  </div>
                </div>
                <button
                  type="button"
                  className="account-secondary"
                  onClick={async () => {
                    try {
                      await account.signOut();
                      notify?.("You’ve signed out.");
                    } catch (cause) {
                      setDataError(safeError(cause, "Could not sign out."));
                    }
                  }}
                >
                  Sign out <ArrowRight size={16} />
                </button>
              </section>
              <section className="account-settings-form account-delete-card">
                <div className="account-settings-title">
                  <X size={18} />
                  <div>
                    <h3>Delete account</h3>
                    <small>
                      Request removal of your account and active workout data.
                    </small>
                  </div>
                </div>
                <p>
                  You’ll need to confirm your password and type DELETE. We’ll
                  email a confirmation link; your account remains active until
                  you use it.
                </p>
                {!deleteOpen ? (
                  <button
                    type="button"
                    className="account-danger-button"
                    onClick={() => {
                      setDeleteOpen(true);
                      setDeletePhrase("");
                      setReauthPassword("");
                    }}
                  >
                    Review account deletion
                  </button>
                ) : (
                  <form
                    className="account-delete-confirm"
                    onSubmit={deleteAccount}
                  >
                    <label>
                      Confirm your password
                      <input
                        type="password"
                        autoComplete="current-password"
                        required
                        value={reauthPassword}
                        onChange={(event) =>
                          setReauthPassword(event.target.value)
                        }
                      />
                    </label>
                    <label>
                      Type DELETE to confirm
                      <input
                        required
                        value={deletePhrase}
                        onChange={(event) =>
                          setDeletePhrase(event.target.value)
                        }
                      />
                    </label>
                    {dataError && (
                      <p className="account-alert" role="alert">
                        {dataError}
                      </p>
                    )}
                    <div className="account-delete-actions">
                      <button
                        type="button"
                        className="account-secondary"
                        onClick={() => setDeleteOpen(false)}
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        className="account-danger-button"
                        disabled={deleteBusy || deletePhrase !== "DELETE"}
                      >
                        {deleteBusy ? "Sending…" : "Send confirmation email"}
                      </button>
                    </div>
                  </form>
                )}
              </section>
            </section>
          )}
        </div>
      </div>
    </div>
  );
}
