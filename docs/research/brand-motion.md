# FORMA brand and loading motion

Reviewed 2026-10-13. The mark and animation are original local vectors and CSS,
using the existing graphite/lime palette and locally hosted typefaces.

The forward-leaning F is built from three facets: a planted stem, a long upper
bar and a shorter middle bar. The navigation lockup, account illustration,
favicon and loading states use the same geometry. Loading motion moves these
facets in a staggered, controlled rhythm; larger states add two quiet orbit rails.
The rails are indeterminate decoration, never a completion percentage.

## References consulted

- [Motion: useReducedMotion](https://motion.dev/docs/react-use-reduced-motion)
  explains adapting or disabling animation for the device preference. The
  implementation uses native CSS media queries, so no runtime dependency or
  React effect is needed to respond to preference changes.
- [Motion: animate](https://motion.dev/docs/animate) demonstrates the relationship
  between transform animation, SVG and sequencing. The original facets animate
  on HTML wrappers around SVG, keeping the vectors static.
- [web.dev: high-performance CSS animations](https://web.dev/articles/animations-guide)
  recommends transform and opacity and avoiding animation of layout or paint
  properties. The animated properties here are only transform and opacity.
- [MDN: prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion)
  documents the native preference. Reduced motion removes every brand/loading
  animation and retains the complete static F and readable state label.
- [MDN: transform](https://developer.mozilla.org/en-US/docs/Web/CSS/transform)
  and [animation-timing-function](https://developer.mozilla.org/en-US/docs/Web/CSS/animation-timing-function)
  informed the wrapper transforms and eased facet timing.
- The [Codrops tutorial index](https://tympanus.net/codrops/category/tutorials/)
  was accessible on the first request, but a specific preloader reference and a
  later index request returned HTTP 403. No tutorial code or assets were copied.

## Runtime and accessibility

- No artificial wait, progress estimate, tracking, external assets, font/CDN
  dependency or new package. Motion is present only while actual work is pending.
- Standalone loading states announce their existing state text with `role=status`.
  Error states keep their retry actions and error announcements.
- Pending buttons retain their action labels, expose `aria-busy` and show a
  decorative inline mark. The mark is hidden from assistive technology, with no
  nested live region. Disabled controls are never inferred to be busy.
- Authentication, member keys, workspace isolation, request arguments, legal
  content and persistence validation are unchanged. New presentation flags on
  password/session actions clear in `finally` and disable duplicate actions.

## Validation approach

Use existing lint/build/browser coverage, then inspect desktop and mobile
screenshots. A controlled Playwright route can hold the real session or guide
request pending for visual inspection; releasing it must show the actual page
immediately. Repeat with `reducedMotion: reduce` and verify all brand animations
compute to `none`. No inspection delay is shipped in product code.

The 2026-10-13 validation passed at 1280 × 900 and 390 × 900 in system Chromium:
session loading and immediate completion, stable sign-in labels and pending/error
button transitions, lazy guide loading/completion, reduced-motion computed styles,
zero loading-screen WCAG axe violations, no runtime errors and no horizontal
overflow. Screenshots were inspected outside the repository. Browser plugin was
not available, so the existing Playwright dependency was used. Scoped ESLint,
Prettier, the Vite build, TypeScript and documentation checks also passed.
