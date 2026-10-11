# Reference research and product brief

Research date: 2026-10-11. Sources: [Australian App Store listing](https://apps.apple.com/au/app/gym-workout-planner-gym-log/id1602190236), Apple lookup metadata, listing screenshots, and [developer website](https://leaphealth.fitness/).

## Findings

Leap Health's Gym Workout Planner & Gym Log centers on customizable routines, set-by-set weight/repetition logging, an exercise library searchable by muscle and equipment, rest timers, and training history. The listing describes 500+ exercises, exercise instructions, estimated one-repetition maximum, progress charts, custom exercises, offline use, and Apple Health integration. These are developer claims; this research inspected public materials, not the installed app.

The screenshots show goal, muscle group, and equipment selection; editable sets, reps, and weights; and prominent session-start controls. Public reviews emphasize ease of editing workouts and beginner accessibility. Reviews are anecdotal, not usability testing. Listing prices and rating counts can change.

## Web implementation

User confirmed personal use with browser-local storage. FORMA is an original responsive implementation of the core training workflow, not an affiliated product. React + Vite; localStorage persists routines, active sessions, history, schedule, and preferences. No account or remote health-data service. A deliberately curated exercise library is included rather than claiming the reference's 500+ exercise catalog. Apple Health, automated coaching, and subscription payments are outside this first version.

Core flow: choose or build a routine → start session → edit weight/reps → mark sets complete and use rest timer → finish → see persisted history and calculated progress. Users can search/filter exercises, create and edit routines, set weekly training days, edit profile/weekly target, export and restore saved data, and review/correct history details.

## Design system

Full dashboard concept, followed by matching functional screens. White sidebar, cool gray canvas, charcoal text and hero photography, lime primary emphasis. DM Sans typography, 1px neutral borders, 12–18px panel radii. Desktop sidebar and two-column dashboard become compact navigation and a single content column on phones. All controls use semantic HTML and keyboard focus styles. Empty progress is truthful; no seeded workout achievements.

## Validation

Build and real-browser tests: routine creation/editing, search/filter, exercise details, session logging, rest timer, finish/history, reload persistence, navigation, preferences and mobile overflow. Visual inspection compares the generated concept and browser screenshots.
