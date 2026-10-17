import { useEffect, useRef, useState } from "react";
import { MotionConfig, Reorder } from "motion/react";
import RoutinePrescription from "./RoutinePrescription.jsx";
import { exerciseById } from "../data.js";
import { entryKey, repRangeText } from "../routineProgramming.js";

export default function RoutinePrescriptions({
  items,
  repInputs,
  onRepInput,
  update,
  move,
  join,
  defaultRest,
  onReorder,
  onOrderingChange,
  onReady,
}) {
  const group = useRef(null);
  const drag = useRef(null);
  const [preview, setPreview] = useState(null);
  const [active, setActive] = useState(null);
  const [announcement, setAnnouncement] = useState("");
  const byKey = new Map(items.map((item) => [entryKey(item), item]));
  const order = preview ?? items.map(entryKey);
  const ordered = order.map((key) => byKey.get(key)).filter(Boolean);

  useEffect(() => {
    onReady(true);
  }, [onReady]);

  useEffect(() => {
    if (!active) return;
    let frame;
    let previousFrame;
    const dialog = drag.current.scroller;
    const cancelOnBlur = () => {
      if (!drag.current) return;
      drag.current.cancelled = true;
      drag.current.controls.stop();
    };
    const cancelOnEscape = (event) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      event.stopPropagation();
      cancelOnBlur();
    };
    function scroll(now) {
      const elapsed = Math.min(100, now - (previousFrame ?? now - 1000 / 60));
      previousFrame = now;
      const gesture = drag.current;
      if (!gesture) return;
      const { scroller, pointer, scrollLimit } = gesture;
      const bounds = scroller.getBoundingClientRect();
      const top = Math.max(
        scroller.querySelector(".modal-header").getBoundingClientRect().bottom,
        0,
      );
      const bottom = Math.min(bounds.bottom, window.innerHeight);
      if (
        pointer.x >= bounds.left &&
        pointer.x <= bounds.right &&
        pointer.y >= top &&
        pointer.y <= bottom
      ) {
        const edge =
          pointer.y < top + 48
            ? pointer.y - top - 48
            : pointer.y > bottom - 48
              ? pointer.y - bottom + 48
              : 0;
        const amount =
          Math.sign(edge) *
          Math.min(14, Math.abs(edge) * 0.3) *
          (elapsed / (1000 / 60));
        const index = gesture.order.indexOf(gesture.key);
        const row = group.current.children[index];
        const rowBounds = row?.getBoundingClientRect();
        const before = scroller.scrollTop;
        scroller.scrollTop = Math.max(
          0,
          Math.min(scrollLimit, scroller.scrollTop + amount),
        );
        const direction = Math.sign(scroller.scrollTop - before);
        const neighbor = group.current.children[index + direction];
        // Motion checks collisions on pointer movement. Continue checking the
        // next layout position when a stationary pointer scrolls the dialog.
        // offsetTop excludes the neighbor's temporary layout animation.
        if (
          direction &&
          rowBounds &&
          row.dataset.entryKey === gesture.key &&
          neighbor?.dataset.entryKey === gesture.order[index + direction]
        ) {
          const center =
            group.current.getBoundingClientRect().top +
            neighbor.offsetTop +
            neighbor.offsetHeight / 2;
          if (
            direction > 0 ? rowBounds.bottom > center : rowBounds.top < center
          ) {
            const next = [...gesture.order];
            next.splice(index + direction, 0, ...next.splice(index, 1));
            gesture.order = next;
            setPreview(next);
          }
        }
      }
      frame = requestAnimationFrame(scroll);
    }
    frame = requestAnimationFrame(scroll);
    window.addEventListener("blur", cancelOnBlur);
    dialog.addEventListener("keydown", cancelOnEscape, true);
    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener("blur", cancelOnBlur);
      dialog.removeEventListener("keydown", cancelOnEscape, true);
      if (drag.current) {
        drag.current.controls.cancel();
        drag.current = null;
        onOrderingChange(false);
      }
    };
  }, [active, onOrderingChange]);

  function begin(key, controls, event) {
    const scroller = group.current.closest("dialog");
    drag.current = {
      key,
      controls,
      order: items.map(entryKey),
      cancelled: false,
      scroller,
      scrollLimit: scroller.scrollHeight - scroller.clientHeight,
      pointer: { x: event.clientX, y: event.clientY },
    };
    setActive(key);
    setPreview(items.map(entryKey));
    onOrderingChange(true);
    setAnnouncement(
      `Moving ${exerciseById.get(byKey.get(key).exerciseId).name}. Press Escape to cancel.`,
    );
  }

  function finish(event) {
    const gesture = drag.current;
    if (!gesture) return;
    const bounds = group.current.getBoundingClientRect();
    const viewport = gesture.scroller.getBoundingClientRect();
    const valid =
      !gesture.cancelled &&
      gesture.order.length === items.length &&
      gesture.order.every((key) => byKey.has(key)) &&
      event.clientX >= bounds.left &&
      event.clientX <= bounds.right &&
      event.clientY >=
        Math.max(
          bounds.top,
          gesture.scroller
            .querySelector(".modal-header")
            .getBoundingClientRect().bottom,
        ) &&
      event.clientY <= Math.min(bounds.bottom, viewport.bottom);
    const name = exerciseById.get(byKey.get(gesture.key).exerciseId).name;
    if (valid) {
      onReorder(gesture.order);
      setAnnouncement(
        `Moved ${name} to position ${gesture.order.indexOf(gesture.key) + 1} of ${items.length}.`,
      );
    } else
      setAnnouncement(
        `Move cancelled. ${name} returned to its original position.`,
      );
    drag.current = null;
    setActive(null);
    setPreview(null);
    onOrderingChange(false);
  }

  function cancel() {
    if (!drag.current) return;
    drag.current.cancelled = true;
    drag.current.controls.stop();
  }

  return (
    <MotionConfig reducedMotion="user">
      <Reorder.Group
        as="div"
        axis="y"
        ref={group}
        className="prescription-order"
        values={order}
        onReorder={(next) => {
          if (!drag.current) return;
          if (drag.current.order.some((key, index) => key !== order[index]))
            return;
          drag.current.order = next;
          setPreview(next);
        }}
        onPointerCancelCapture={cancel}
      >
        {ordered.map((item, index) => (
          <RoutinePrescription
            key={entryKey(item)}
            item={item}
            exercise={exerciseById.get(item.exerciseId)}
            index={index}
            count={items.length}
            repInput={repInputs[entryKey(item)] ?? repRangeText(item)}
            onRepInput={onRepInput}
            update={update}
            move={move}
            join={join}
            joined={
              !!item.groupId &&
              index > 0 &&
              ordered[index - 1].groupId === item.groupId
            }
            defaultRest={defaultRest}
            dragging={active === entryKey(item)}
            ordering={!!active}
            onDragStart={(controls, event) =>
              begin(entryKey(item), controls, event)
            }
            onDrag={(event) => {
              if (drag.current)
                drag.current.pointer = { x: event.clientX, y: event.clientY };
            }}
            onDragEnd={finish}
          />
        ))}
      </Reorder.Group>
      <span className="sr-only" role="status" aria-live="polite">
        {announcement}
      </span>
    </MotionConfig>
  );
}
