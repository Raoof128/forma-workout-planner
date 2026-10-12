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

The repository contains OFL license texts for the Barlow Condensed and DM Sans fonts. It does not include a project-wide software license, and it does not document the provenance or redistribution terms for the bundled workout photographs. Confirm rights for every asset before redistributing or publishing a copy; do not infer that the font license covers other files.

## Smoke-check and rollback

After publishing, check the deployment in a disposable browser profile so no real workout data is at risk:

1. Open the hosted page and check that HTML, JavaScript, CSS, fonts, and images load without console errors.
2. Create a synthetic routine, start a workout, complete a set, save it, reload, and confirm it appears in history.
3. Export a backup and test import in a separate disposable profile.
4. Open two tabs and check that independent edits persist.
5. Check a narrow phone layout and desktop layout. If storage is unavailable, confirm the temporary-mode warning appears.

If the static build needs rollback, republish the previously reviewed `dist/` contents and repeat the smoke check. A code rollback does not restore, migrate, or roll back browser-local workspace data. Keep the backup-format compatibility contract when rolling application files forward or back. Do not clear user storage as part of deployment rollback.

Before changing domains or ports, export the old workspace and restore it at the new origin. Each scheme, host, and port has separate browser storage. Preserve schema compatibility when shipping a new build.
