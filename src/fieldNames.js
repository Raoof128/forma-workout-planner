// Accessible name for a logged-set field: the visible column text, never an
// internal key such as "durationSeconds" (WCAG 2.5.3 label in name). UI-only:
// kept out of the modules the API and the native resource build read.
export const spokenField = (field) =>
  field.key === "durationSeconds"
    ? "time (seconds)"
    : field.key === "distanceMeters"
      ? "distance (meters)"
      : field.key;
