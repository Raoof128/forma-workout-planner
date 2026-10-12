import { useRef, useState } from "react";
import {
  Check,
  Download,
  Upload,
  CalendarDays,
  ShieldCheck,
} from "lucide-react";
import { PageHeading, Button, Modal } from "./UI";
import { downloadData, readBackupFile } from "../storage";
export function Settings({ data, saved, onSave, onRestore, notify }) {
  const [name, setName] = useState(data.profile.name);
  const [goal, setGoal] = useState(data.profile.goal);
  const original = useRef(data.profile);
  const [backup, setBackup] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  async function submit(event) {
    event.preventDefault();
    setBusy(true);
    try {
      const profile = { name: name.trim(), goal: Number(goal) };
      if (await onSave(profile, original.current)) original.current = profile;
    } finally {
      setBusy(false);
    }
  }
  async function importBackup(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    try {
      const imported = await readBackupFile(file);
      setBackup({ data: imported, name: file.name, revision: data.revision });
      setError("");
    } catch {
      setError(
        "Choose a valid FORMA JSON backup no larger than 20 MiB. Nothing has been changed.",
      );
    }
    event.target.value = "";
  }
  return (
    <>
      <PageHeading
        title="Your space. Your preferences."
        subtitle="A few details to make FORMA feel like you."
      />
      <form className="panel settings-panel" onSubmit={submit}>
        <h2>Your profile</h2>
        <label className="field">
          Your name
          <input
            value={name}
            maxLength={50}
            required
            pattern=".*\S.*"
            onChange={(event) => setName(event.target.value)}
          />
        </label>
        <label className="field">
          Weekly workout goal
          <select
            value={goal}
            onChange={(event) => setGoal(event.target.value)}
          >
            {Array.from({ length: 7 }, (_, index) => (
              <option key={index} value={index + 1}>
                {index + 1} {index === 0 ? "workout" : "workouts"} per week
              </option>
            ))}
          </select>
        </label>
        <p className="muted small">
          Weights are logged in kilograms (kg). Dates use Sydney time.
        </p>
        <Button variant="lime" type="submit" disabled={busy}>
          <Check size={17} />
          Save preferences
        </Button>
      </form>
      <section className="panel settings-panel">
        <div className="section-title">
          <h2>Your data stays yours</h2>
          <ShieldCheck size={22} />
        </div>
        <p>
          {saved
            ? "Routines and logs are saved in this browser on this device. Export a backup to keep a copy of your training data."
            : "Browser saving is unavailable. Export your current routines and logs now to keep a copy after this visit."}
        </p>
        <p className="muted small">
          Clearing browser data will remove your saved workouts. Private
          browsing may not keep data after the window closes.
        </p>
        <div className="backup-actions">
          <Button
            variant="secondary"
            onClick={() => {
              try {
                downloadData(data);
                setError("");
                notify("Your workout backup download has started.");
              } catch {
                setError("The backup download could not start. Try again.");
              }
            }}
          >
            <Download size={17} />
            Export my data
          </Button>
          <label className="button secondary import-label">
            <Upload size={17} />
            Import backup
            <input
              type="file"
              aria-label="Import backup"
              accept="application/json,.json"
              onChange={importBackup}
            />
          </label>
        </div>
        {error && (
          <p role="alert" className="error">
            {error}
          </p>
        )}
      </section>
      {backup && (
        <Modal
          title="Restore this backup?"
          onClose={() => !busy && setBackup(null)}
        >
          <div className="modal-content">
            <p>
              <strong>{backup.name}</strong> contains{" "}
              {backup.data.routines.length} routines and{" "}
              {backup.data.history.length} completed workouts.
            </p>
            <p className="muted">
              This replaces the current workspace. A copy of your current data
              will be preserved in this browser. Export it first if you want a
              downloadable copy.
            </p>
            {error && (
              <p role="alert" className="error">
                {error}
              </p>
            )}
            <div className="modal-actions">
              <Button
                variant="secondary"
                disabled={busy}
                onClick={() => setBackup(null)}
              >
                Cancel
              </Button>
              <Button
                variant="lime"
                disabled={busy}
                onClick={async () => {
                  setBusy(true);
                  try {
                    await onRestore(backup.data, backup.revision);
                    setBackup(null);
                  } catch (cause) {
                    setError(cause.message);
                  } finally {
                    setBusy(false);
                  }
                }}
              >
                Restore backup
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </>
  );
}
export function Schedule({ schedule, onSave, onClose }) {
  const [days, setDays] = useState(schedule);
  const [discard, setDiscard] = useState(false);
  const dirty =
    JSON.stringify([...days].sort()) !== JSON.stringify([...schedule].sort());
  function close() {
    if (dirty) setDiscard(true);
    else onClose();
  }
  return (
    <Modal
      title={discard ? "Discard schedule changes?" : "Make room for yourself."}
      onClose={discard ? () => setDiscard(false) : close}
    >
      <div className="modal-content">
        {discard ? (
          <>
            <p>Your new training days haven’t been saved.</p>
            <div className="modal-actions">
              <Button variant="secondary" onClick={() => setDiscard(false)}>
                Keep editing
              </Button>
              <Button variant="danger-solid" onClick={onClose}>
                Discard changes
              </Button>
            </div>
          </>
        ) : (
          <>
            <p className="muted">
              Choose your usual training days. These mark your weekly calendar;
              choose a routine separately before each session.
            </p>
            <div className="schedule-days">
              {[
                "Monday",
                "Tuesday",
                "Wednesday",
                "Thursday",
                "Friday",
                "Saturday",
                "Sunday",
              ].map((day, index) => (
                <button
                  key={day}
                  aria-pressed={days.includes(index)}
                  onClick={() =>
                    setDays((current) =>
                      current.includes(index)
                        ? current.filter((value) => value !== index)
                        : [...current, index],
                    )
                  }
                  className={days.includes(index) ? "active" : ""}
                >
                  <CalendarDays size={18} />
                  <span>{day}</span>
                  {days.includes(index) && <Check size={18} />}
                </button>
              ))}
            </div>
            <p className="small muted">
              {days.length} training days · {7 - days.length} recovery days
            </p>
            <div className="modal-actions">
              <Button variant="lime" onClick={() => onSave(days)}>
                Save schedule <Check size={17} />
              </Button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
}
