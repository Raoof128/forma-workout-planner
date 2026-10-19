import { useEffect, useId, useRef, useState } from "react";
import { Ellipsis } from "lucide-react";

// A ⋯ button that opens a short list of actions, following the WAI-ARIA menu
// button pattern: Enter, Space or Down opens on the first item and Up on the
// last; arrows wrap, Home/End jump, Escape closes and returns focus, and Tab
// or a click outside closes. Unavailable actions stay in the list, focusable
// and marked aria-disabled, so the menu keeps its shape.
export default function ActionsMenu({ label, items, className = "" }) {
  const [open, setOpen] = useState(false);
  const [start, setStart] = useState("first");
  const id = useId();
  const wrapper = useRef(null);
  const trigger = useRef(null);
  const menu = useRef(null);
  useEffect(() => {
    if (!open) return;
    const all = [...menu.current.querySelectorAll('[role="menuitem"]')];
    // Open on the first (or last) action that can run; unavailable ones
    // stay reachable with the arrow keys.
    const ready = all.filter((item) => !item.hasAttribute("aria-disabled"));
    const pool = ready.length ? ready : all;
    (start === "last" ? pool.at(-1) : pool[0])?.focus();
    const outside = (event) => {
      if (!wrapper.current?.contains(event.target)) setOpen(false);
    };
    document.addEventListener("pointerdown", outside);
    return () => document.removeEventListener("pointerdown", outside);
  }, [open, start]);
  function show(from) {
    setStart(from);
    setOpen(true);
  }
  function close() {
    setOpen(false);
    trigger.current?.focus();
  }
  function onKeyDown(event) {
    const all = [...menu.current.querySelectorAll('[role="menuitem"]')];
    const index = all.indexOf(document.activeElement);
    const move = {
      ArrowDown: (index + 1) % all.length,
      ArrowUp: (index - 1 + all.length) % all.length,
      Home: 0,
      End: all.length - 1,
    }[event.key];
    if (move !== undefined) {
      event.preventDefault();
      all[move].focus();
    } else if (event.key === "Escape") {
      // Close only the menu, never a dialog or drawer around it.
      event.preventDefault();
      event.stopPropagation();
      close();
    } else if (event.key === "Tab") setOpen(false);
  }
  return (
    <div className={`actions-menu ${className}`} ref={wrapper}>
      <button
        ref={trigger}
        type="button"
        className="icon-button actions-menu-trigger"
        aria-label={label}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? id : undefined}
        onClick={() => (open ? setOpen(false) : show("first"))}
        onKeyDown={(event) => {
          if (event.key === "ArrowDown" || event.key === "ArrowUp") {
            event.preventDefault();
            show(event.key === "ArrowUp" ? "last" : "first");
          }
        }}
      >
        <Ellipsis size={19} />
      </button>
      {open && (
        <div
          ref={menu}
          id={id}
          role="menu"
          tabIndex={-1}
          aria-label={label}
          className="actions-menu-list"
          onKeyDown={onKeyDown}
        >
          {items.map((item) => (
            <button
              key={item.label}
              type="button"
              role="menuitem"
              tabIndex={-1}
              className={item.danger ? "is-danger" : undefined}
              aria-disabled={item.disabled || undefined}
              onClick={() => {
                if (item.disabled) return;
                setOpen(false);
                item.onSelect();
              }}
            >
              {item.icon}
              {item.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
