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
    const heading = document.querySelector("main h1");
    if (heading) {
      heading.tabIndex = -1;
      heading.focus({ preventScroll: true });
    }
  }, [page]);
  return [page, navigate];
}
