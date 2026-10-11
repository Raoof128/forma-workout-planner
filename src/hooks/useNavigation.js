import { useCallback, useEffect, useState } from "react";
const pages = new Set([
  "overview",
  "routines",
  "library",
  "workout",
  "history",
  "progress",
  "settings",
]);
const currentPage = () =>
  pages.has(location.hash.slice(1)) ? location.hash.slice(1) : "overview";
export function useNavigation() {
  const [page, setPage] = useState(currentPage);
  useEffect(() => {
    const update = () => setPage(currentPage());
    window.addEventListener("hashchange", update);
    return () => window.removeEventListener("hashchange", update);
  }, []);
  const navigate = useCallback((next) => {
    if (!pages.has(next)) return;
    location.hash = next;
    setPage(next);
    window.scrollTo({ top: 0, behavior: "instant" });
  }, []);
  useEffect(() => {
    const heading = document.querySelector("main h1");
    if (heading) {
      heading.tabIndex = -1;
      heading.focus({ preventScroll: true });
    }
  }, [page]);
  return [page, navigate];
}
