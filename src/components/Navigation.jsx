import { useEffect, useRef, useState } from "react";
import BrandMark from "./BrandMark";
import {
  House,
  Dumbbell,
  BookOpen,
  History,
  ChartNoAxesColumnIncreasing,
  Settings,
  UserRound,
  ChevronRight,
  ChevronUp,
  LogOut,
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
export default function Navigation({ page, navigate, data, account, notify }) {
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
  const displayName = account?.user?.name || data?.profile?.name || "Guest";
  const initials = displayName
    .split(/\s+/)
    .map((part) => part[0])
    .slice(0, 2)
    .join("");
  return (
    <>
      <div className="mobile-top">
        <a
          className="brand"
          aria-label="FORMA"
          href="#overview"
          onClick={(e) => {
            e.preventDefault();
            go("overview");
          }}
        >
          <BrandMark />
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
          aria-label="FORMA"
          href="#overview"
          onClick={(e) => {
            e.preventDefault();
            go("overview");
          }}
        >
          <BrandMark />
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
          {account?.user ? (
            <ProfileMenu
              name={displayName}
              email={account.user.email}
              initials={initials}
              onManage={() => go("account")}
              onSignOut={async () => {
                await account.signOut();
                notify?.("You’ve signed out.");
                go("account");
              }}
              onError={() =>
                notify?.(
                  "Could not sign out. Check your connection and try again.",
                )
              }
            />
          ) : (
            <button className="profile-button" onClick={() => go("account")}>
              <span className="avatar">{initials}</span>
              <div>
                <strong>{displayName}</strong>
                <small>Guest workspace</small>
              </div>
              <ChevronRight size={16} />
            </button>
          )}
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

// Signed-in profile row: opens a small menu above it, following the WAI-ARIA
// menu button pattern (arrow keys, Home/End, Escape returns focus).
function ProfileMenu({ name, email, initials, onManage, onSignOut, onError }) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const wrapper = useRef(null);
  const trigger = useRef(null);
  const menu = useRef(null);
  useEffect(() => {
    if (!open) return;
    menu.current?.querySelector('[role="menuitem"]')?.focus();
    const outside = (event) => {
      if (!wrapper.current?.contains(event.target)) setOpen(false);
    };
    document.addEventListener("pointerdown", outside);
    return () => document.removeEventListener("pointerdown", outside);
  }, [open]);
  function close() {
    setOpen(false);
    trigger.current?.focus();
  }
  function onKeyDown(event) {
    const items = [...menu.current.querySelectorAll('[role="menuitem"]')];
    const index = items.indexOf(document.activeElement);
    const move = {
      ArrowDown: (index + 1) % items.length,
      ArrowUp: (index - 1 + items.length) % items.length,
      Home: 0,
      End: items.length - 1,
    }[event.key];
    if (move !== undefined) {
      event.preventDefault();
      items[move].focus();
    } else if (event.key === "Escape") {
      // Keep the phone drawer open; only the menu closes.
      event.preventDefault();
      event.stopPropagation();
      close();
    } else if (event.key === "Tab") setOpen(false);
  }
  return (
    <div className="profile-menu-wrap" ref={wrapper}>
      {open && (
        <div
          ref={menu}
          id="profile-menu"
          role="menu"
          tabIndex={-1}
          aria-label="Account menu"
          className="profile-menu"
          onKeyDown={onKeyDown}
        >
          <button
            type="button"
            role="menuitem"
            tabIndex={-1}
            onClick={() => {
              setOpen(false);
              onManage();
            }}
          >
            <UserRound size={17} />
            Manage account
          </button>
          <button
            type="button"
            role="menuitem"
            tabIndex={-1}
            className="profile-menu-signout"
            aria-disabled={busy || undefined}
            onClick={async () => {
              if (busy) return;
              setBusy(true);
              try {
                await onSignOut();
                setOpen(false);
              } catch {
                onError();
              } finally {
                setBusy(false);
              }
            }}
          >
            <LogOut size={17} />
            {busy ? "Signing out…" : "Sign out"}
          </button>
        </div>
      )}
      <button
        ref={trigger}
        type="button"
        className="profile-button"
        aria-label={`Account menu: ${name}, ${email}`}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? "profile-menu" : undefined}
        onClick={() => setOpen((value) => !value)}
        onKeyDown={(event) => {
          if (event.key === "ArrowUp" || event.key === "ArrowDown") {
            event.preventDefault();
            setOpen(true);
          }
        }}
      >
        <span className="avatar">{initials}</span>
        <div>
          <strong>{name}</strong>
          <small>{email}</small>
        </div>
        <ChevronUp size={16} className="profile-chevron" />
      </button>
    </div>
  );
}
