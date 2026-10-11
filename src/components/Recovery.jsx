import { useState } from "react";
import { Button } from "./UI";
import { downloadData, validateData } from "../storage";
export default function Recovery({ raw, onRestore, onReset }) {
  const [error, setError] = useState("");
  const [confirm, setConfirm] = useState(false);
  async function importFile(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    try {
      if (file.size > 20 * 1024 * 1024)
        throw new Error("Choose a backup smaller than 20 MB.");
      const data = validateData(JSON.parse(await file.text()));
      await onRestore(data);
    } catch {
      setError(
        "This file is not a valid FORMA backup. Your original data is still untouched.",
      );
    }
    event.target.value = "";
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
          onClick={() => downloadData(raw, "forma-original-data", true)}
        >
          Download original data
        </Button>
        <label className="button secondary import-label">
          Restore a backup
          <input
            aria-label="Restore recovery backup"
            type="file"
            accept="application/json,.json"
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
          <Button variant="secondary" onClick={() => setConfirm(false)}>
            Keep original
          </Button>
          <Button
            variant="danger-solid"
            onClick={() => onReset().catch((e) => setError(e.message))}
          >
            Start fresh
          </Button>
        </div>
      ) : (
        <Button variant="secondary" onClick={() => setConfirm(true)}>
          Start a fresh workspace
        </Button>
      )}
    </main>
  );
}
