import { Component } from "react";
import { downloadData, STORAGE_KEY } from "../storage";
export default class ErrorBoundary extends Component {
  state = { failed: false, downloadError: "" };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <main className="recovery-page">
        <h1>Let’s get your workspace back.</h1>
        <p>
          Something went wrong while displaying the app. Your saved data has not
          been cleared.
        </p>
        <div className="recovery-actions">
          <button
            className="button secondary"
            onClick={() => {
              try {
                const saved = localStorage.getItem(STORAGE_KEY);
                // Never hand over an empty file as if it were a backup.
                if (!saved) {
                  this.setState({
                    downloadError:
                      "No training data is saved in this browser. Account training stays in your account: reload to reach it.",
                  });
                  return;
                }
                downloadData(saved, "forma-original-data", true);
              } catch {
                this.setState({
                  downloadError:
                    "Your browser could not access the saved data. Allow site storage and try again.",
                });
              }
            }}
          >
            Download saved data
          </button>
          <button
            className="button lime"
            onClick={() => window.location.reload()}
          >
            Reload workspace
          </button>
        </div>
        {this.state.downloadError && (
          <p className="error" role="alert">
            {this.state.downloadError}
          </p>
        )}
      </main>
    );
  }
}
