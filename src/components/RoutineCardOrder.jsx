import { useEffect, useRef, useState } from "react";
import {
  MotionConfig,
  motion,
  useDragControls,
  useMotionValue,
  useReducedMotion,
} from "motion/react";
import { Button, RoutineCard } from "./UI";

// Touch needs a deliberate hold so ordinary swipes keep scrolling the page.
const LONG_PRESS_MS = 400;
const TOUCH_SLOP = 8;
const EDGE = 64;

function moveTo(order, id, index) {
  const next = order.filter((key) => key !== id);
  next.splice(index, 0, id);
  return next;
}

export default function RoutineCardOrder({
  routines,
  archived,
  onOpen,
  onDuplicate,
  onArchive,
  onReorder,
  onPreview,
  children,
}) {
  const grid = useRef(null);
  const drag = useRef(null);
  const [preview, setPreview] = useState(null);
  const [active, setActive] = useState(null);
  const [landed, setLanded] = useState(null);
  const [announcement, setAnnouncement] = useState("");
  const byId = new Map(routines.map((routine) => [routine.id, routine]));
  const current = routines.map((routine) => routine.id);
  const order =
    preview &&
    preview.length === current.length &&
    preview.every((id) => byId.has(id))
      ? preview
      : current;

  useEffect(() => {
    if (!landed) return;
    const clear = setTimeout(() => setLanded(null), 1400);
    return () => clearTimeout(clear);
  }, [landed]);

  useEffect(() => {
    // A held touch becomes a drag; stop the page from panning underneath it.
    const holdPage = (event) => {
      if (drag.current?.touch && event.cancelable) event.preventDefault();
    };
    document.addEventListener("touchmove", holdPage, { passive: false });
    return () => document.removeEventListener("touchmove", holdPage);
  }, []);

  useEffect(() => {
    const gesture = active;
    if (!gesture || drag.current !== gesture) return;
    let frame;
    const cancel = () => {
      if (drag.current !== gesture) return;
      gesture.cancelled = true;
      setPreview(gesture.start);
      gesture.controls.stop();
      finish();
    };
    const onKey = (event) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      cancel();
    };
    function scroll() {
      if (drag.current !== gesture) return;
      const { y } = gesture.pointer;
      const edge =
        y < EDGE
          ? y - EDGE
          : y > innerHeight - EDGE
            ? y - innerHeight + EDGE
            : 0;
      if (edge) {
        window.scrollBy(
          0,
          Math.sign(edge) * Math.min(18, Math.abs(edge) * 0.3),
        );
        hitTest(gesture.pointer);
      }
      frame = requestAnimationFrame(scroll);
    }
    frame = requestAnimationFrame(scroll);
    window.addEventListener("keydown", onKey, true);
    window.addEventListener("blur", cancel);
    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener("keydown", onKey, true);
      window.removeEventListener("blur", cancel);
    };
    // finish and hitTest only read refs and stable setters.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active]);

  function hitTest(pointer) {
    const gesture = drag.current;
    if (!gesture || !grid.current) return;
    const bounds = grid.current.getBoundingClientRect();
    // offsetLeft/Top ignore the cards' in-flight layout transforms.
    const target = [...grid.current.children].find(
      (node) =>
        node.dataset.routineId &&
        node.dataset.routineId !== gesture.id &&
        pointer.x >= bounds.left + node.offsetLeft &&
        pointer.x <= bounds.left + node.offsetLeft + node.offsetWidth &&
        pointer.y >= bounds.top + node.offsetTop &&
        pointer.y <= bounds.top + node.offsetTop + node.offsetHeight,
    );
    if (!target) return;
    const next = moveTo(
      gesture.order,
      gesture.id,
      gesture.order.indexOf(target.dataset.routineId),
    );
    if (next.every((id, index) => id === gesture.order[index])) return;
    gesture.order = next;
    setPreview(next);
  }

  function begin(id, controls, touch, event) {
    drag.current = {
      id,
      controls,
      touch,
      start: order,
      order,
      cancelled: false,
      pointer: { x: event.clientX, y: event.clientY },
    };
    setActive(drag.current);
    setPreview(order);
    setAnnouncement(`Moving ${byId.get(id).name}. Press Escape to cancel.`);
  }

  async function commit(id, next) {
    setPreview(next);
    setLanded({ id });
    setAnnouncement(
      `Moved ${byId.get(id).name} to position ${next.indexOf(id) + 1} of ${next.length}.`,
    );
    await onReorder(next);
    setPreview(null);
  }

  function finish() {
    const gesture = drag.current;
    if (!gesture) return;
    drag.current = null;
    setActive(null);
    const moved = gesture.order.some(
      (id, index) => id !== gesture.start[index],
    );
    if (gesture.cancelled || !moved) {
      setPreview(null);
      if (gesture.cancelled)
        setAnnouncement(
          `Move cancelled. ${byId.get(gesture.id).name} returned to its place.`,
        );
      return;
    }
    void commit(gesture.id, gesture.order);
  }

  async function step(id, direction) {
    const index = order.indexOf(id);
    await commit(id, moveTo(order, id, index + direction));
    grid.current
      ?.querySelector(`[data-routine-id="${id}"] .routine-card-menu summary`)
      ?.focus();
  }

  return (
    <MotionConfig reducedMotion="user">
      <div
        ref={grid}
        className={`routine-grid full-grid${active ? " is-ordering" : ""}`}
      >
        {order.map((id, index) => (
          <SortableRoutineCard
            key={id}
            routine={byId.get(id)}
            archived={archived}
            first={index === 0}
            last={index === order.length - 1}
            dragging={active?.id === id}
            ordering={!!active}
            landed={landed?.id === id}
            onOpen={onOpen}
            onDuplicate={onDuplicate}
            onArchive={onArchive}
            onPreview={onPreview}
            onStep={(direction) => step(id, direction)}
            onDragStart={(controls, touch, event) =>
              begin(id, controls, touch, event)
            }
            onDrag={(event) => {
              const gesture = drag.current;
              if (gesture?.id !== id) return;
              gesture.pointer = { x: event.clientX, y: event.clientY };
              hitTest(gesture.pointer);
            }}
            onDragEnd={() => {
              if (drag.current?.id === id) finish();
            }}
          />
        ))}
        {children}
      </div>
      {/* aria-live without role="status": the page toast owns that role. */}
      <span className="sr-only" aria-live="polite" aria-atomic="true">
        {announcement}
      </span>
    </MotionConfig>
  );
}

function SortableRoutineCard({
  routine,
  archived,
  first,
  last,
  dragging,
  ordering,
  landed,
  onOpen,
  onDuplicate,
  onArchive,
  onPreview,
  onStep,
  onDragStart,
  onDrag,
  onDragEnd,
}) {
  const controls = useDragControls();
  const reduceMotion = useReducedMotion();
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const press = useRef(null);
  const suppressClick = useRef(false);
  const [settling, setSettling] = useState(false);

  useEffect(() => {
    if (!settling) return;
    const settle = () => {
      if (Math.abs(x.get()) < 0.5 && Math.abs(y.get()) < 0.5)
        setSettling(false);
    };
    const stops = [
      x.on("animationComplete", settle),
      y.on("animationComplete", settle),
    ];
    const fallback = setTimeout(() => setSettling(false), 700);
    return () => {
      stops.forEach((stop) => stop());
      clearTimeout(fallback);
    };
  }, [settling, x, y]);

  useEffect(() => () => clearTimeout(press.current?.timer), []);

  const lifted = dragging || settling;

  function release() {
    clearTimeout(press.current?.timer);
    press.current = null;
  }

  return (
    <motion.div
      className={`routine-card-wrap${lifted ? " is-lifted" : ""}${
        landed && !lifted ? " is-landed" : ""
      }`}
      data-routine-id={routine.id}
      layout
      drag
      dragListener={false}
      dragControls={controls}
      dragMomentum={false}
      dragSnapToOrigin
      style={{ x, y }}
      transition={{
        layout: reduceMotion
          ? { duration: 0 }
          : { type: "spring", stiffness: 500, damping: 42 },
      }}
      dragTransition={{ bounceStiffness: 500, bounceDamping: 42 }}
      onPointerDown={(event) => {
        suppressClick.current = false;
        if (
          ordering ||
          !event.isPrimary ||
          event.button !== 0 ||
          event.target.closest(".routine-card-menu")
        )
          return;
        if (event.pointerType !== "touch") {
          controls.start(event, { distanceThreshold: 6 });
          return;
        }
        const origin = { x: event.clientX, y: event.clientY };
        const native = event.nativeEvent;
        press.current = {
          origin,
          timer: setTimeout(() => {
            press.current = null;
            navigator.vibrate?.(10);
            controls.start(native);
          }, LONG_PRESS_MS),
        };
      }}
      onPointerMove={(event) => {
        const pending = press.current;
        if (
          pending &&
          Math.hypot(
            event.clientX - pending.origin.x,
            event.clientY - pending.origin.y,
          ) > TOUCH_SLOP
        )
          release();
      }}
      onPointerUp={release}
      onPointerCancel={release}
      onContextMenu={(event) => {
        if (press.current || dragging) event.preventDefault();
      }}
      onClickCapture={(event) => {
        if (!suppressClick.current) return;
        suppressClick.current = false;
        event.preventDefault();
        event.stopPropagation();
      }}
      onDragStart={(event) => {
        suppressClick.current = true;
        onDragStart(controls, event.pointerType === "touch", event);
      }}
      onDrag={onDrag}
      onDragEnd={() => {
        if (reduceMotion) {
          x.stop();
          y.stop();
          x.set(0);
          y.set(0);
        } else if (Math.abs(x.get()) > 0.5 || Math.abs(y.get()) > 0.5)
          setSettling(true);
        onDragEnd();
      }}
    >
      <RoutineCard routine={routine} onClick={onOpen} />
      <details className="routine-card-menu">
        <summary aria-label={`Actions for ${routine.name}`}>⋯</summary>
        <div>
          <Button
            variant="secondary"
            onClick={(event) => {
              event.currentTarget.closest("details").open = false;
              onPreview(routine);
            }}
          >
            Preview workout
          </Button>
          <Button
            variant="secondary"
            disabled={first || ordering}
            onClick={(event) => {
              event.currentTarget.closest("details").open = false;
              onStep(-1);
            }}
          >
            Move earlier
          </Button>
          <Button
            variant="secondary"
            disabled={last || ordering}
            onClick={(event) => {
              event.currentTarget.closest("details").open = false;
              onStep(1);
            }}
          >
            Move later
          </Button>
          <Button
            variant="secondary"
            onClick={(event) => {
              event.currentTarget.closest("details").open = false;
              onDuplicate(routine);
            }}
          >
            Duplicate routine
          </Button>
          <Button
            variant="secondary"
            onClick={(event) => {
              event.currentTarget.closest("details").open = false;
              onArchive(routine);
            }}
          >
            {archived ? "Restore routine" : "Archive routine"}
          </Button>
        </div>
      </details>
    </motion.div>
  );
}
