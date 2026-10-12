# FORMA

**Plan your training. Log every set. See your progress.**

FORMA is a personal workout planner built with React and Vite. Create routines, track weights and repetitions, use a persistent rest timer, and review your training history in a responsive interface. Your workout data is stored in your browser on your device.

[Getting started](docs/getting-started.md) · [User guide](docs/user-guide.md) · [Architecture](docs/architecture.md) · [Contributing](CONTRIBUTING.md)

## Features

| Plan                               | Train                                   | Review                                     |
| ---------------------------------- | --------------------------------------- | ------------------------------------------ |
| Three editable starter routines    | Set-by-set weight and rep logging       | Editable workout history                   |
| Custom routines and exercise order | Persistent rest timer and session notes | Volume, completed sets, and personal bests |
| Weekly training schedule           | Exercise instructions while logging     | Estimated one-repetition maximum           |
| Searchable 16-exercise library     | Resume an unfinished session            | Validated JSON backup and restore          |

The interface uses semantic controls, keyboard navigation, accessible dialogs, mobile workout controls, and locally hosted fonts. Browser accessibility scans and responsive checks are documented in the verification record. Physical assistive-technology testing has not been performed.

## Quick start

Use **Node.js 22.12 or newer** and npm. Node.js 24 is recommended.

```sh
git clone https://github.com/Raoof128/forma-workout-planner.git
cd forma-workout-planner
npm ci
npm run dev
```

Open **http://localhost:5173**. No API keys, environment variables, accounts, or database setup are required.

```sh
npm run build
npm run preview
```

The production output is `dist/`. See the [deployment guide](docs/deployment.md) for HTTPS, hosting paths, and verification.

## Data and privacy

FORMA is a **browser-local application**. It has no application server, remote database, authentication, analytics, or cloud sync. `localStorage` stores your workspace; Web Locks coordinate writes between tabs on the same origin. Storage is specific to the browser profile and origin. FORMA does not encrypt saved data. Other scripts running on the same origin, browser extensions, and anyone with access to the browser profile may be able to read it. Export a JSON backup from Settings and keep a copy outside the browser before clearing site data, changing browsers, or moving to another domain.

If persistence is unavailable, the app uses temporary memory and displays an explicit warning. Export your data before leaving that visit. Fonts and images are served with the application; a hosting provider may still record ordinary web access logs. See the [privacy and recovery guidance](docs/user-guide.md#back-up-and-restore) before resetting or clearing site data.

Weights use kilograms and calendar dates use Australia/Sydney. Starter weights are editable examples. One plank rep represents a 10-second hold. FORMA does not include Apple Health integration, videos, subscriptions, or automated coaching.

## Development checks

```sh
npx playwright install chromium firefox webkit
npm run lint
npm run format:check
npm run docs:check
npm run build
npm test
```

On Linux, Playwright may require system dependencies: `npx playwright install-deps chromium firefox webkit`. `npm test` runs unit tests followed by development-browser tests in Chromium, Firefox, and WebKit. `npm run test:browser:production` builds the app and exercises the production preview across desktop and mobile-emulation projects. See [testing](docs/testing.md) and the [verification record](docs/verification.md) for evidence and browser limits.

## Documentation

| Document                                                  | Purpose                                                                             |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [Getting started](docs/getting-started.md)                | Installation, commands, and troubleshooting                                         |
| [User guide](docs/user-guide.md)                          | Routines, logging, progress, backups, and recovery                                  |
| [Architecture](docs/architecture.md)                      | Components, data flow, persistence, and trust boundaries                            |
| [Data model](docs/data-model.md)                          | Workspace structure, units, validation, and backup compatibility                    |
| [Deployment](docs/deployment.md)                          | Static hosting and production checks                                                |
| [Testing](docs/testing.md)                                | Automated checks and test conventions                                               |
| [Contributing](CONTRIBUTING.md)                           | Development workflow and pull requests                                              |
| [Changelog](CHANGELOG.md)                                 | Notable changes                                                                     |
| [Equipment and workout coverage](docs/research/README.md) | 76 equipment families, 236 exercise candidates, sources, and implementation roadmap |
| [Research](docs/research.md)                              | Reference research and product scope                                                |
| [Frontend audit](docs/frontend-design-audit.md)           | Design findings and source-file coverage                                            |
| [Data-layer audit](docs/backend-audit.md)                 | Persistence and business-logic findings, fixes, and coverage                        |
| [QA and release evidence](docs/qa/README.md)              | Index for current release-readiness evidence                                        |
| [Security reporting](SECURITY.md)                         | Responsible reporting guidance                                                      |

FORMA uses an original design informed by research into Leap Health's Gym Workout Planner & Gym Log. It is not affiliated with that product. Historical concept screenshots in `docs/` are design references, not current release screenshots. The Barlow Condensed and DM Sans fonts include their OFL licenses in `public/fonts/`. The repository does not currently include a project-wide software license. The provenance and redistribution terms for the bundled workout photographs are not documented in this repository; do not treat the absent project license as granting rights to those assets.
