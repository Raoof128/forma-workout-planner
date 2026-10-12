import { useEffect, useRef, useState } from "react";
import {
  House,
  Dumbbell,
  BookOpen,
  History,
  ChartNoAxesColumnIncreasing,
  Settings,
  UserRound,
  ChevronRight,
  Menu,
  X,
  Play,
} from "lucide-react";
export const navigationItems = [
  ["overview", "Overview", House],
  ["routines", "My routines", Dumbbell],
  ["library", "Exercise library", BookOpen],
  ["history", "Workout history", History],
  ["progress", "Progress", ChartNoAxesColumnIncreasing],
];
export default function Navigation({ page, navigate, data, account }) {
  const [mobile, setMobile] = useState(
    () => matchMedia("(max-width:700px)").matches,
  );
  const [open, setOpen] = useState(false);
  const sidebar = useRef(null);
  const toggle = useRef(null);
  useEffect(() => {
    const query = matchMedia("(max-width:700px)");
    const update = () => {
      setMobile(query.matches);
      setOpen(false);
    };
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);
  useEffect(() => {
    if (!mobile || !open) return;
    const main = document.querySelector("main");
    const previousOverflow = document.body.style.overflow;
    main.inert = true;
    document.body.style.overflow = "hidden";
    sidebar.current.querySelector("button")?.focus();
    const key = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        setOpen(false);
        toggle.current?.focus();
      }
      if (event.key === "Tab") {
        const controls = [
          toggle.current,
          ...sidebar.current.querySelectorAll("button,a[href]"),
        ];
        const first = controls[0],
          last = controls.at(-1);
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    };
    document.addEventListener("keydown", key);
    return () => {
      main.inert = false;
      document.body.style.overflow = previousOverflow;
      document.removeEventListener("keydown", key);
    };
  }, [mobile, open]);
  function go(next) {
    setOpen(false);
    navigate(next);
  }
  const brand = (
    <>
      <span className="brand-mark" aria-hidden="true">
        <i />
        <i />
        <i />
      </span>
      FORMA<span className="brand-period">.</span>
    </>
  );
  return (
    <>
      <div className="mobile-top">
        <a
          className="brand"
          href="#overview"
          onClick={(e) => {
            e.preventDefault();
            go("overview");
          }}
        >
          {brand}
        </a>
        <button
          ref={toggle}
          className="icon-button"
          aria-label="Toggle navigation"
          aria-expanded={open}
          aria-controls="main-sidebar"
          onClick={() => setOpen((value) => !value)}
        >
          {open ? <X /> : <Menu />}
        </button>
      </div>
      {mobile && open && (
        <button
          className="sidebar-shade"
          aria-label="Close navigation"
          tabIndex={-1}
          onClick={() => {
            setOpen(false);
            toggle.current?.focus();
          }}
        />
      )}
      <aside
        id="main-sidebar"
        ref={sidebar}
        className={`sidebar ${open ? "open" : ""}`}
        inert={mobile && !open}
        aria-label="Workspace navigation"
      >
        <a
          className="brand"
          href="#overview"
          onClick={(e) => {
            e.preventDefault();
            go("overview");
          }}
        >
          {brand}
        </a>
        <nav aria-label="Main navigation">
          {navigationItems.map(([key, label, Icon]) => (
            <button
              key={key}
              className={`nav-item ${page === key ? "active" : ""}`}
              onClick={() => go(key)}
              aria-current={page === key ? "page" : undefined}
            >
              <Icon size={20} strokeWidth={1.7} />
              <span>{label}</span>
              {page === key && <span className="nav-active-dot" />}
            </button>
          ))}
        </nav>
        {data?.active && (
          <button className="resume-sidebar" onClick={() => go("workout")}>
            <span className="pulse-dot" />
            <div>
              Workout in progress<small>{data.active.name}</small>
            </div>
            <Play size={16} />
          </button>
        )}
        <div className="sidebar-bottom">
          <button
            className={`nav-item ${page === "account" ? "active" : ""}`}
            onClick={() => go("account")}
            aria-current={page === "account" ? "page" : undefined}
          >
            <UserRound size={20} />
            Account
          </button>
          <button
            className={`nav-item ${page === "settings" ? "active" : ""}`}
            onClick={() => go("settings")}
            aria-current={page === "settings" ? "page" : undefined}
          >
            <Settings size={20} />
            Settings
          </button>
          <button className="profile-button" onClick={() => go("account")}>
            <span className="avatar">
              {(account?.user?.name || data?.profile?.name || "Guest")
                .split(/\s+/)
                .map((part) => part[0])
                .slice(0, 2)
                .join("")}
            </span>
            <div>
              <strong>
                {account?.user?.name || data?.profile?.name || "Guest"}
              </strong>
              <small>
                {account?.user ? account.user.email : "Guest workspace"}
              </small>
            </div>
            <ChevronRight size={16} />
          </button>
          <nav className="legal-links" aria-label="Legal">
            <a
              href="#privacy"
              aria-current={page === "privacy" ? "page" : undefined}
              onClick={(event) => {
                event.preventDefault();
                go("privacy");
              }}
            >
              Privacy
            </a>
            <a
              href="#terms"
              aria-current={page === "terms" ? "page" : undefined}
              onClick={(event) => {
                event.preventDefault();
                go("terms");
              }}
            >
              Terms
            </a>
          </nav>
        </div>
      </aside>
    </>
  );
}
