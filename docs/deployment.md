# Deployment

[Back to README](../README.md)

## Build for a static host

```sh
npm ci
npm run build
```

Publish the **contents of `dist/`** to an HTTPS static host at the root of an origin. The host must serve `index.html`, `/assets/`, `/fonts/`, `/images/`, and `/favicon.svg`. No application server, API endpoint, database, secret, or runtime environment variable is required. `npm run preview` is for local inspection of the build, not a production hosting service.

The app uses hash URLs such as `/#history`, so page routes do not require server rewrite rules. Assets currently use root-relative paths. A GitHub Pages project path such as `/forma-workout-planner/` needs both Vite base-path configuration and corresponding asset-path changes; publishing the source repository alone does not deploy the app.

## Hosting requirements

- HTTPS, or localhost for local development, to support secure browser APIs such as Web Locks.
- Correct JavaScript/CSS/font MIME types.
- Revalidation of `index.html`; long caching of hashed `/assets/` files is appropriate.
- A stable scheme, hostname, and port. Each origin has its own separate browser storage.

All application fonts and images are bundled. Review your host's logging and analytics configuration separately from the app's own browser-local data design.

## Verify a deployment

1. Open the hosted page in a fresh browser profile and check the console for loading errors.
2. Create a routine, start a workout, complete a set, and save it.
3. Reload and confirm the workout remains in history.
4. Export a backup, then test import in a separate disposable profile.
5. Open two tabs and verify independent edits persist.
6. Check narrow phone and desktop layouts and the temporary-mode warning when storage is unavailable.

Before changing domains or ports, export the old workspace and restore it at the new origin. Rolling back static files does not roll back browser data. Preserve schema compatibility when shipping a new build.
