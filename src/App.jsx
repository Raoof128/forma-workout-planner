import { useCallback, useEffect, useRef, useState } from "react";
import { CalendarDays, ChevronRight, Play } from "lucide-react";
import { createId, displayDate, sessionSets } from "./data";
import { freshData, readStore } from "./storage";
import { useWorkoutStore } from "./hooks/useWorkoutStore";
import { useNavigation } from "./hooks/useNavigation";
import Navigation, { navigationItems } from "./components/Navigation";
import { Button, Empty, Modal } from "./components/UI";
import Recovery from "./components/Recovery";
import Notification from "./components/Notification";
import Overview from "./components/Overview";
import { Routines, RoutineDetail, RoutineEditor } from "./components/Routines";
import Library from "./components/Library";
import Workout from "./components/Workout";
import { WorkoutHistory, Progress } from "./components/Insights";
import { Settings, Schedule } from "./components/Preferences";
import Account from "./components/Account.jsx";
import { useAccount } from "./account/AccountProvider.jsx";
const equal = (a, b) => JSON.stringify(a) === JSON.stringify(b);
export default function App() {
  const account = useAccount();
  return (
    <AccountWorkspace
      key={
        account.status === "authenticated" ? account.user?.id : account.status
      }
    />
  );
}

function AccountWorkspace() {
  const account = useAccount();
  const { data, issue, raw, commit, saving, repository, status } =
    useWorkoutStore(account);
  const [page, navigate] = useNavigation();
  const [modal, setModal] = useState(null);
  const [toast, setToast] = useState("");
  const [legacySnapshot] = useState(() => readStore());
  const toastTimer = useRef(null);
  const notify = useCallback((message) => {
    setToast(message);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(""), 6000);
  }, []);
  useEffect(() => () => clearTimeout(toastTimer.current), []);
  const workspace = {
    status:
      account.status !== "authenticated"
        ? account.status === "guest"
          ? "guest"
          : account.status
        : status,
    data: account.status === "authenticated" ? data : null,
    revision:
      account.status === "authenticated"
        ? repository?.getSnapshot().revision
        : null,
    updatedAt:
      account.status === "authenticated"
        ? repository?.getSnapshot().updatedAt
        : null,
    conflict:
      account.status === "authenticated"
        ? repository?.getSnapshot().conflict
        : null,
    refresh: () => repository?.refresh(),
    reloadConflict: () => repository?.reloadConflict(),
    retry: () => repository?.retry(),
    commit,
    importLegacy: (backup) => repository?.importLegacy(backup),
    exportData: () => repository?.exportData(),
  };
  const legacy = {
    status:
      legacySnapshot.issue === "invalid"
        ? "invalid"
        : legacySnapshot.raw === null
          ? "empty"
          : "available",
    data: legacySnapshot.data,
  };
  async function change(update, message) {
    try {
      const result = await commit(update);
      if (message)
        notify(
          result.saved
            ? message
            : "Updated for this visit. Export your data to keep a copy.",
        );
      return result;
    } catch (error) {
      notify(error.message || "The change could not be saved.");
      return null;
    }
  }
  async function begin(routine, replaceId = null) {
    const session = {
      id: createId(),
      name: routine.name,
      routineId: routine.id,
      startedAt: Date.now(),
      notes: "",
      restSeconds: 90,
      restEnd: null,
      restPaused: null,
      exercises: routine.exercises.map((item) => ({
        exerciseId: item.exerciseId,
        sets: Array.from({ length: item.sets }, () => ({
          weight: item.weight,
          reps: item.reps,
          done: false,
        })),
      })),
    };
    const result = await change((current) => {
      if (
        !equal(
          current.routines.find((item) => item.id === routine.id),
          routine,
        )
      )
        throw new Error(
          "This routine changed in another tab. Reopen it before starting a workout.",
        );
      if (current.active && current.active.id !== replaceId)
        throw new Error(
          "A workout is already active. Resume it from the overview.",
        );
      return { ...current, active: session };
    });
    if (result) {
      setModal(null);
      navigate("workout");
    }
  }
  function start(routine) {
    if (data.active) {
      if (routine && routine.id !== data.active.routineId) {
        setModal({ type: "switch", routine, activeId: data.active.id });
        return;
      }
      setModal(null);
      navigate("workout");
      return;
    }
    if (!routine) {
      navigate("routines");
      setModal({ type: "editor" });
      return;
    }
    void begin(routine);
  }
  async function saveRoutine(routine) {
    const original = modal?.routine;
    const result = await change((current) => {
      const existing = current.routines.find((item) => item.id === routine.id);
      if (original && !equal(existing, original))
        throw new Error(
          "This routine changed in another tab. Close the editor and reopen it to see the latest version.",
        );
      return {
        ...current,
        routines: existing
          ? current.routines.map((item) =>
              item.id === routine.id ? routine : item,
            )
          : [...current.routines, routine],
      };
    }, "Routine saved. Make it a good one.");
    if (result) {
      setModal(null);
      navigate("routines");
    }
    return !!result;
  }
  async function updateSession(update) {
    const id = data.active?.id;
    return change((current) => {
      if (!current.active || current.active.id !== id)
        throw new Error(
          "This session changed in another tab. The latest saved data has been loaded.",
        );
      return { ...current, active: update(current.active) };
    });
  }
  async function finish(duration) {
    const id = data.active?.id;
    const result = await change((current) => {
      if (!current.active || current.active.id !== id)
        throw new Error(
          "This session was already finished or discarded in another tab.",
        );
      if (!sessionSets(current.active))
        throw new Error("Complete at least one set before saving.");
      return {
        ...current,
        active: null,
        history: [
          {
            ...current.active,
            date: new Date().toISOString(),
            duration,
            restEnd: null,
            restPaused: null,
          },
          ...current.history,
        ],
      };
    }, "Workout saved. That’s progress worth showing up for.");
    if (result) navigate("history");
  }
  async function saveHistory(next, original) {
    const result = await change((current) => {
      if (
        !equal(
          current.history.find((item) => item.id === next.id),
          original,
        )
      )
        throw new Error(
          "This workout changed in another tab. Reopen it before editing.",
        );
      return {
        ...current,
        history: current.history.map((item) =>
          item.id === next.id ? next : item,
        ),
      };
    }, "Workout updated. Your progress has been recalculated.");
    return !!result;
  }
  async function restore(backup, revision, recoveryRaw) {
    const result =
      account.status === "authenticated"
        ? await commit(() => backup, { operationId: createId() })
        : await commit(() => backup, {
            recover: true,
            expectedRevision: revision,
            ...(recoveryRaw !== undefined ? { expectedRaw: recoveryRaw } : {}),
          });
    setModal(null);
    navigate("overview");
    notify(
      result.saved
        ? account.status === "authenticated"
          ? "Cloud backup restored. Your prior cloud data was replaced."
          : "Backup restored. Your previous data was preserved in this browser."
        : "Restored for this visit only.",
    );
  }
  if (issue === "invalid")
    return (
      <Recovery
        raw={raw}
        onRestore={(backup) => restore(backup, undefined, raw)}
        onReset={() => restore(freshData(), undefined, raw)}
      />
    );
  if (account.status === "loading")
    return (
      <main className="account-session-state" aria-live="polite">
        <p>Checking your account session…</p>
      </main>
    );
  if (account.status === "error")
    return (
      <main className="account-session-state" role="alert">
        <h1>Your account session could not be checked.</h1>
        <p>
          Your private workspace is hidden until the connection is restored.
        </p>
        <Button variant="lime" onClick={() => account.refresh()}>
          Try again
        </Button>
      </main>
    );
  if (account.status === "authenticated" && !data && page !== "account")
    return (
      <main className="account-session-state" aria-live="polite">
        <p>
          {status === "error"
            ? "Your private workspace could not be loaded."
            : "Loading your private workspace…"}
        </p>
        {status === "error" && (
          <Button variant="lime" onClick={() => repository?.refresh()}>
            Try again
          </Button>
        )}
      </main>
    );
  const visiblePage = page;
  return (
    <div className="app-shell" data-saving={saving}>
      <a
        href="#main-content"
        className="skip-link"
        onClick={(event) => {
          event.preventDefault();
          document.querySelector("main h1")?.focus();
        }}
      >
        Skip to content
      </a>
      <Navigation
        page={visiblePage}
        navigate={navigate}
        data={data}
        account={account}
      />
      <main id="main-content" data-page={visiblePage}>
        <header className="topbar">
          {saving && <span className="save-indicator">Saving changes…</span>}
          <div>
            <span>Workspace</span>
            <ChevronRight size={13} />
            <strong>
              {visiblePage === "workout"
                ? "Active workout"
                : visiblePage === "settings"
                  ? "Settings"
                  : visiblePage === "account"
                    ? "Account"
                    : navigationItems.find(
                        (item) => item[0] === visiblePage,
                      )?.[1]}
            </strong>
          </div>
          <span className="top-date">
            <CalendarDays size={16} />
            {displayDate(new Date(), {
              weekday: "long",
              month: "long",
              day: "numeric",
              year: "numeric",
            })}
          </span>
        </header>
        <div className="main-content">
          {visiblePage === "account" && (
            <Account
              account={account}
              workspace={workspace}
              legacy={legacy}
              onNavigate={navigate}
              notify={notify}
            />
          )}
          {visiblePage !== "account" && data && (
            <>
              {issue === "unavailable" && (
                <div role="alert" className="storage-warning">
                  Browser saving is unavailable. Changes last only for this
                  visit. Export your data in Settings.
                </div>
              )}
              {visiblePage === "overview" && (
                <Overview
                  data={data}
                  saved={issue !== "unavailable"}
                  onStart={start}
                  onRoutine={(routine) => setModal({ type: "detail", routine })}
                  onNavigate={navigate}
                  onSchedule={() =>
                    setModal({ type: "schedule", schedule: data.schedule })
                  }
                />
              )}
              {visiblePage === "routines" && (
                <Routines
                  routines={data.routines}
                  onOpen={(routine) => setModal({ type: "detail", routine })}
                  onCreate={() => setModal({ type: "editor" })}
                />
              )}
              {visiblePage === "library" && <Library />}
              {visiblePage === "workout" &&
                (data.active ? (
                  <Workout
                    key={data.active.id}
                    session={data.active}
                    onUpdate={updateSession}
                    onFinish={finish}
                    onCancel={() =>
                      setModal({ type: "discard", activeId: data.active.id })
                    }
                    onBack={() => navigate("overview")}
                    notify={notify}
                  />
                ) : (
                  <Empty
                    heading="h1"
                    title="No workout is running."
                    description="Start a routine when you’re ready."
                  >
                    <Button
                      variant="lime"
                      onClick={() => start(data.routines[0])}
                    >
                      Start workout
                    </Button>
                  </Empty>
                ))}
              {visiblePage === "history" && (
                <WorkoutHistory
                  history={data.history}
                  onStart={() => start(data.routines[0])}
                  onSave={saveHistory}
                  onDelete={async (session) => {
                    const result = await change((current) => {
                      if (
                        !equal(
                          current.history.find(
                            (item) => item.id === session.id,
                          ),
                          session,
                        )
                      )
                        throw new Error(
                          "This workout changed in another tab. Reopen it first.",
                        );
                      return {
                        ...current,
                        history: current.history.filter(
                          (item) => item.id !== session.id,
                        ),
                      };
                    }, "Workout deleted. Progress has been updated.");
                    return !!result;
                  }}
                />
              )}
              {visiblePage === "progress" && (
                <Progress
                  history={data.history}
                  onStart={() => start(data.routines[0])}
                />
              )}
              {visiblePage === "settings" && (
                <Settings
                  data={data}
                  saved={issue !== "unavailable"}
                  memberMode={account.status === "authenticated"}
                  onExport={
                    account.status === "authenticated"
                      ? workspace.exportData
                      : undefined
                  }
                  onRestore={restore}
                  onSave={async (profile, original) => {
                    const result = await change((current) => {
                      if (!equal(current.profile, original))
                        throw new Error(
                          "Your profile changed in another tab. Reload Settings before saving.",
                        );
                      return { ...current, profile };
                    }, "Your preferences are saved.");
                    return !!result;
                  }}
                  notify={notify}
                />
              )}
            </>
          )}
        </div>
      </main>
      {modal?.type === "detail" && (
        <RoutineDetail
          routine={modal.routine}
          onClose={() => setModal(null)}
          onStart={start}
          onEdit={(routine) => setModal({ type: "editor", routine })}
          onDelete={(routine) => setModal({ type: "delete", routine })}
        />
      )}
      {modal?.type === "editor" && (
        <RoutineEditor
          routine={modal.routine}
          onClose={() => setModal(null)}
          onSave={saveRoutine}
        />
      )}
      {modal?.type === "schedule" && (
        <Schedule
          schedule={modal.schedule}
          onClose={() => setModal(null)}
          onSave={async (schedule) => {
            const result = await change((current) => {
              if (!equal(current.schedule, modal.schedule))
                throw new Error(
                  "Your schedule changed in another tab. Reopen it before saving.",
                );
              return { ...current, schedule };
            }, "Your week is planned. You’ve got this.");
            if (result) setModal(null);
          }}
        />
      )}
      {modal?.type === "switch" && (
        <Modal
          title="You already have a workout running."
          onClose={() => setModal(null)}
        >
          <div className="modal-content">
            <p>
              Resume <strong>{data.active?.name}</strong>, or discard its
              unfinished sets and start <strong>{modal.routine.name}</strong>.
            </p>
            <div className="modal-actions">
              <Button
                variant="secondary"
                onClick={() => {
                  setModal(null);
                  navigate("workout");
                }}
              >
                <Play size={16} />
                Resume existing
              </Button>
              <Button
                variant="danger-solid"
                onClick={() => begin(modal.routine, modal.activeId)}
              >
                Discard and start new
              </Button>
            </div>
          </div>
        </Modal>
      )}
      {["discard", "delete"].includes(modal?.type) && (
        <Modal
          title={
            modal.type === "discard"
              ? "Discard this workout?"
              : "Delete this routine?"
          }
          onClose={() => setModal(null)}
        >
          <div className="modal-content">
            <p>
              {modal.type === "discard"
                ? "The sets in this unfinished session will not be saved."
                : "This removes the routine. Your completed workout history will stay."}
            </p>
            <div className="modal-actions">
              <Button variant="secondary" onClick={() => setModal(null)}>
                Keep it
              </Button>
              <Button
                variant="danger-solid"
                onClick={async () => {
                  const result = await change(
                    (current) => {
                      if (modal.type === "discard") {
                        if (current.active?.id !== modal.activeId)
                          throw new Error(
                            "The active session changed. Reopen it before discarding.",
                          );
                        return { ...current, active: null };
                      }
                      if (
                        !equal(
                          current.routines.find(
                            (item) => item.id === modal.routine.id,
                          ),
                          modal.routine,
                        )
                      )
                        throw new Error(
                          "This routine changed in another tab. Reopen it before deleting.",
                        );
                      return {
                        ...current,
                        routines: current.routines.filter(
                          (item) => item.id !== modal.routine.id,
                        ),
                      };
                    },
                    modal.type === "delete" ? "Routine deleted." : null,
                  );
                  if (result) {
                    if (modal.type === "discard") navigate("overview");
                    setModal(null);
                  }
                }}
              >
                {modal.type === "discard"
                  ? "Discard workout"
                  : "Delete routine"}
              </Button>
            </div>
          </div>
        </Modal>
      )}
      {toast && <Notification message={toast} onDismiss={() => setToast("")} />}
    </div>
  );
}
