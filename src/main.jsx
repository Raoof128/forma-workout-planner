import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import ErrorBoundary from "./components/ErrorBoundary";
import { AccountProvider } from "./account/AccountProvider.jsx";
import "./styles.css";
createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <ErrorBoundary>
      <AccountProvider>
        <App />
      </AccountProvider>
    </ErrorBoundary>
  </React.StrictMode>,
);
