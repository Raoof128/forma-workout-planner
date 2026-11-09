import { useCallback, useLayoutEffect, useSyncExternalStore } from "react";
const pages = new Set([
  "overview",
  "routines",
  "library",
  "workout",
  "history",
  "progress",
  "settings",
  "account",
  "privacy",
  "terms",
]);
const currentPage = () =>
  pages.has(location.hash.slice(1)) ? location.hash.slice(1) : "overview";
const subscribe = (update) => {
  window.addEventListener("hashchange", update);
  return () => window.removeEventListener("hashchange", update);
};
export function useNavigation() {
  // React rechecks the URL after subscribing, closing the render/setup gap.
  const page = useSyncExternalStore(subscribe, currentPage);
  const navigate = useCallback((next) => {
    if (!pages.has(next)) return;
    location.hash = next;
    window.scrollTo({ top: 0, behavior: "instant" });
  }, []);
  useLayoutEffect(() => {
    const labels = {
      overview: "Overview",
      routines: "My routines",
      library: "Exercise library",
      workout: "Active workout",
      history: "Workout history",
      progress: "Progress",
      settings: "Settings",
      account: "Account",
      privacy: "Privacy Policy",
      terms: "Terms of Use",
    };
    document.title = `${labels[page]} · FORMA`;
    const initialFocus = document.activeElement;
    const mayMoveDelayedFocus =
      initialFocus === document.body ||
      initialFocus === document.documentElement ||
      initialFocus?.matches(".skip-link");
    const prepareHeading = (delayed = false) => {
      const heading = document.querySelector("main h1");
      if (!heading) return false;
      heading.tabIndex = -1;
      // A workspace can arrive after this layout effect. Make its heading
      // reachable without taking focus from a control the member already used.
      if (
        !delayed ||
        (mayMoveDelayedFocus &&
          document.activeElement === initialFocus &&
          !document.querySelector('dialog[open], [role="menu"]'))
      )
        heading.focus({ preventScroll: true });
      return true;
    };
    if (prepareHeading()) return;
    const observer = new MutationObserver(() => {
      if (prepareHeading(true)) observer.disconnect();
    });
    observer.observe(document.body, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, [page]);
  return [page, navigate];
}
