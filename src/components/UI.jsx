import { useEffect, useRef, useId } from "react";
import { X, Dumbbell, Clock, ChevronRight } from "lucide-react";
export function Button({
  children,
  variant = "",
  className = "",
  type = "button",
  ...props
}) {
  return (
    <button type={type} className={`button ${variant} ${className}`} {...props}>
      {children}
    </button>
  );
}
export function Modal({ title, children, onClose, wide = false }) {
  const ref = useRef(null);
  const closeRef = useRef(onClose);
  const titleId = useId();
  useEffect(() => {
    closeRef.current = onClose;
  }, [onClose]);
  useEffect(() => {
    const dialog = ref.current;
    const previous = document.activeElement;
    const oldOverflow = document.body.style.overflow;
    dialog.showModal();
    const initial =
      dialog.querySelector("[data-autofocus]") ||
      dialog.querySelector("button");
    initial?.focus();
    document.body.style.overflow = "hidden";
    const cancel = (event) => {
      event.preventDefault();
      closeRef.current();
    };
    const backdrop = (event) => {
      if (event.target !== dialog) return;
      const rect = dialog.getBoundingClientRect();
      if (
        event.clientX < rect.left ||
        event.clientX > rect.right ||
        event.clientY < rect.top ||
        event.clientY > rect.bottom
      )
        closeRef.current();
    };
    const trap = (event) => {
      if (event.key !== "Tab") return;
      const controls = [
        ...dialog.querySelectorAll(
          'button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled),a[href],[tabindex="0"]',
        ),
      ].filter((node) => node.getClientRects().length);
      const first = controls[0],
        last = controls.at(-1);
      if (
        event.shiftKey &&
        (document.activeElement === first || document.activeElement === dialog)
      ) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first?.focus();
      }
    };
    dialog.addEventListener("keydown", trap);
    dialog.addEventListener("cancel", cancel);
    dialog.addEventListener("click", backdrop);
    return () => {
      dialog.removeEventListener("keydown", trap);
      dialog.removeEventListener("cancel", cancel);
      dialog.removeEventListener("click", backdrop);
      dialog.close();
      document.body.style.overflow = oldOverflow;
      if (previous?.isConnected) previous.focus();
    };
  }, []);
  return (
    <dialog
      className={`modal ${wide ? "wide" : ""}`}
      aria-labelledby={titleId}
      ref={ref}
    >
      <header className="modal-header">
        <h2 id={titleId}>{title}</h2>
        <button
          type="button"
          className="icon-button"
          aria-label="Close dialog"
          onClick={onClose}
        >
          <X size={20} />
        </button>
      </header>
      {children}
    </dialog>
  );
}
export function RoutineCard({ routine, onClick }) {
  return (
    <button className="routine-card" onClick={() => onClick(routine)}>
      <div className={`routine-photo photo-${routine.image ?? 0}`} />
      <div className="routine-card-body">
        <div>
          <h3>{routine.name}</h3>
          <div className="meta">
            <Dumbbell size={16} />
            <span>{routine.exercises.length} exercises</span>
            <span className="dot">·</span>
            <Clock size={15} />
            <span>{routine.minutes} min</span>
          </div>
        </div>
        <span className="circle-arrow">
          <ChevronRight size={19} />
        </span>
      </div>
    </button>
  );
}
export function Empty({ icon: Icon = Dumbbell, title, description, children }) {
  return (
    <div className="empty">
      <span className="empty-icon">
        <Icon size={28} />
      </span>
      <h2>{title}</h2>
      <p>{description}</p>
      {children}
    </div>
  );
}
export function PageHeading({ title, subtitle, children }) {
  return (
    <div className="page-heading">
      <div>
        <h1>{title}</h1>
        <p>{subtitle}</p>
      </div>
      {children}
    </div>
  );
}
