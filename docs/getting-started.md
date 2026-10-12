# Getting started

[Back to README](../README.md)

## Prerequisites

- Node.js 22.12 or newer; Node.js 24 recommended.
- npm and Git.
- A current browser. The development suite targets Chromium, Firefox, and WebKit; production smoke tests cover desktop Chromium, Firefox, and WebKit, plus mobile Chromium and WebKit emulation.

## Install and run

```sh
git clone https://github.com/Raoof128/forma-workout-planner.git
cd forma-workout-planner
npm ci
npm run dev
```

Visit http://localhost:5173. The first visit initializes three starter routines and an empty workout history. Change the example profile name in Settings. No `.env` file or service credentials are needed.

The development command listens on all network interfaces. To bind only to this machine, run `npm run dev -- --host 127.0.0.1`. A phone visiting an unencrypted LAN address may not have Web Locks available and may use temporary mode; use HTTPS to verify persistence on another device.

## Commands

| Command                           | Purpose                                                                                |
| --------------------------------- | -------------------------------------------------------------------------------------- |
| `npm run dev`                     | Start the Vite development server                                                      |
| `npm run build`                   | Generate production files in `dist/`                                                   |
| `npm run preview`                 | Serve the built files locally, usually on port 4173                                    |
| `npm run lint`                    | Check JavaScript, React Hooks, and JSX accessibility rules                             |
| `npm run format`                  | Format source, tests, configuration, and HTML                                          |
| `npm run format:check`            | Verify formatting without changing files                                               |
| `npm run docs:check`              | Check local Markdown links, fragments, images, and documented npm scripts              |
| `npm test`                        | Run unit tests, then Chromium, Firefox, and WebKit browser tests                       |
| `npm run test:unit`               | Run isolated validation/persistence tests using Node.js                                |
| `npm run test:browser`            | Run Playwright scenarios in Chromium, Firefox, and WebKit                              |
| `npm run test:browser:production` | Build the app and run production smoke tests in Chromium, Firefox, and WebKit projects |

Playwright owns a fresh development server on `127.0.0.1:5173` for browser tests. It requires that port to be free and starts Vite with strict-port behavior. The server is reused only when `PLAYWRIGHT_REUSE_SERVER=1` is explicitly set outside CI. Production browser tests build the app, then start a fresh preview server on `127.0.0.1:4173` and never reuse an existing server.

Use `npm ci` for reproducible installs from the committed lockfile. Do not commit `node_modules`, `dist`, local environment files, or real workout backups.

## Troubleshooting

| Symptom                               | Action                                                                                                                       |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Install reports an unsupported engine | Check `node --version`; use Node.js 24 and rerun `npm ci`.                                                                   |
| Port 5173 is in use                   | Stop the other server or use `npm run dev -- --port 5174`. Tests expect 5173.                                                |
| Browser executable is missing         | Run `npx playwright install chromium firefox webkit`.                                                                        |
| Linux browser libraries are missing   | Run `npx playwright install-deps chromium firefox webkit` with an account that can install system packages.                  |
| Saving is unavailable                 | Use HTTPS or localhost, allow site storage, and use a browser supporting Web Locks. Export temporary data before refreshing. |
| Old data is absent on another URL     | Storage is isolated by scheme, host, and port. Export from the old origin and import into the new one.                       |
| Saved data needs attention            | Download the original from the recovery screen, then restore a valid FORMA backup. Do not clear storage first.               |

See the [user guide](user-guide.md) for everyday workflows and the [deployment guide](deployment.md) for hosting.
