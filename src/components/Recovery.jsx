import { useState } from "react";
import { Button } from "./UI";
import { downloadData, validateData } from "../storage";
export default function Recovery({ raw, onRestore, onReset }) {
  const [error, setError] = useState("");
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  async function importFile(event) {
    const input = event.target;
    const file = input.files?.[0];
    if (!file || busy) return;
    setError("");
    setBusy(true);
    if (file.size > 20 * 1024 * 1024) {
      setError(
        "Choose a FORMA backup smaller than 20 MB. Your original data is still untouched.",
      );
      setBusy(false);
      input.value = "";
      return;
    }
    let data;
    try {
      data = validateData(JSON.parse(await file.text()));
    } catch {
      setError(
        "This file is not a valid FORMA backup. Your original data is still untouched.",
      );
      setBusy(false);
      input.value = "";
      return;
    }
    try {
      await onRestore(data);
    } catch (error) {
      setError(error.message || "This backup could not be saved. Try again.");
    } finally {
      setBusy(false);
      input.value = "";
    }
  }
  async function reset() {
    if (busy) return;
    setError("");
    setBusy(true);
    try {
      await onReset();
    } catch (error) {
      setError(
        error.message || "Your workspace could not be reset. Try again.",
      );
    } finally {
      setBusy(false);
    }
  }
  return (
    <main className="recovery-page">
      <h1>Your saved data needs attention.</h1>
      <p>
        We couldn’t read this browser’s workout data. It has been left
        untouched. Download the original before restoring a backup or starting
        fresh.
      </p>
      <div className="recovery-actions">
        <Button
          variant="secondary"
          onClick={() => {
            try {
              downloadData(raw, "forma-original-data", true);
            } catch {
              setError(
                "The download could not start. Try again before replacing your data.",
              );
            }
          }}
        >
          Download original data
        </Button>
        <label className="button secondary import-label">
          Restore a backup
          <input
            aria-label="Restore recovery backup"
            type="file"
            accept="application/json,.json"
            disabled={busy}
            onChange={importFile}
          />
        </label>
      </div>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {confirm ? (
        <div className="panel recovery-confirm">
          <p>
            Start with the starter routines? We’ll preserve a copy of the
            unreadable data in this browser before replacing it.
          </p>
          <Button
            variant="secondary"
            disabled={busy}
            onClick={() => setConfirm(false)}
          >
            Keep original
          </Button>
          <Button variant="danger-solid" disabled={busy} onClick={reset}>
            Start fresh
          </Button>
        </div>
      ) : (
        <Button
          variant="secondary"
          disabled={busy}
          onClick={() => setConfirm(true)}
        >
          Start a fresh workspace
        </Button>
      )}
    </main>
  );
}
