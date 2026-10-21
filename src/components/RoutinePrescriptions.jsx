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
  hidden,
}) {
  const group = useRef(null);
  const drag = useRef(null);
  const pendingPress = useRef(null);
  const [preview, setPreview] = useState(null);
  const [active, setActive] = useState(null);
  const [announcement, setAnnouncement] = useState("");
  const [landed, setLanded] = useState(null);
  const byKey = new Map(items.map((item) => [entryKey(item), item]));
  const order = preview ?? items.map(entryKey);
  const ordered = order.map((key) => byKey.get(key)).filter(Boolean);

  useEffect(() => {
    onReady(true);
  }, [onReady]);

  useEffect(() => {
    if (!landed) return;
    // Long enough for the row to settle and the confirmation to finish.
    const clear = setTimeout(() => setLanded(null), 1400);
    return () => clearTimeout(clear);
  }, [landed]);

  useEffect(() => {
    function captureRelease(event) {
      const press = pendingPress.current;
      if (
        !press ||
        press.release ||
        press.pointerId !== event.pointerId ||
        event.timeStamp < press.startedAt
      )
        return;
      const gesture = drag.current?.press === press ? drag.current : null;
      const bounds = group.current.getBoundingClientRect();
      const scroller = group.current.closest("dialog");
      const viewport = scroller.getBoundingClientRect();
      const order =
        gesture?.order ??
        [...group.current.children].map((row) => row.dataset.entryKey);
      const stationaryScrollPreview =
        gesture?.scrollPreviewPointer?.x === event.clientX &&
        gesture?.scrollPreviewPointer?.y === event.clientY;
      const valid =
        event.type === "pointerup" &&
        event.clientX >= bounds.left &&
        event.clientX <= bounds.right &&
        event.clientY >=
          Math.max(
            bounds.top,
            scroller.querySelector(".modal-header").getBoundingClientRect()
              .bottom,
          ) &&
        event.clientY <=
          Math.min(bounds.bottom, viewport.bottom, window.innerHeight);
      press.release = {
        time: event.timeStamp,
        valid,
        order:
          valid && !stationaryScrollPreview
            ? orderAtRelease(
                { key: press.key, order, pointerOffset: press.offset },
                event,
                bounds,
              )
            : [...order],
      };
    }
    window.addEventListener("pointerup", captureRelease, true);
    window.addEventListener("pointercancel", captureRelease, true);
    return () => {
      window.removeEventListener("pointerup", captureRelease, true);
      window.removeEventListener("pointercancel", captureRelease, true);
    };
  }, []);

  useEffect(() => {
    const gesture = active;
    if (!gesture || drag.current !== gesture) return;
    let frame;
    let previousFrame;
    const dialog = gesture.scroller;
    const cancelOnBlur = () => {
      if (drag.current !== gesture) return;
      gesture.cancelled = true;
      gesture.controls.stop();
    };
    const cancelOnEscape = (event) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      event.stopPropagation();
      cancelOnBlur();
    };
    function scroll(now) {
      const elapsed = Math.min(500, now - (previousFrame ?? now - 1000 / 60));
      previousFrame = now;
      if (drag.current !== gesture) return;
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
        const direction =
          Math.sign(scroller.scrollTop - before) || gesture.direction;
        // Motion can advance only one neighbor per rendered order update.
        // Catch up across all crossed layout centers in one preview commit.
        if (direction && rowBounds && row.dataset.entryKey === gesture.key) {
          const original = gesture.order;
          const next = [...original];
          const top = group.current.getBoundingClientRect().top;
          let destination = index;
          for (
            let neighborIndex = index + direction;
            neighborIndex >= 0 && neighborIndex < original.length;
            neighborIndex += direction
          ) {
            const neighbor = group.current.children[neighborIndex];
            if (
              !neighbor ||
              neighbor.dataset.entryKey !== original[neighborIndex]
            )
              break;
            // offsetTop excludes the neighbor's temporary layout animation.
            const center = top + neighbor.offsetTop + neighbor.offsetHeight / 2;
            if (
              direction > 0
                ? rowBounds.bottom <= center
                : rowBounds.top >= center
            )
              break;
            next.splice(
              destination + direction,
              0,
              ...next.splice(destination, 1),
            );
            destination += direction;
          }
          if (destination !== index) {
            gesture.order = next;
            if (scroller.scrollTop !== before)
              gesture.scrollPreviewPointer = { ...pointer };
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
      if (drag.current === gesture) {
        gesture.controls.cancel();
        drag.current = null;
        onOrderingChange(false);
      }
    };
  }, [active, onOrderingChange]);

  function begin(key, controls, event, info, press) {
    if (drag.current && event.timeStamp < drag.current.startedAt) return;
    const scroller = group.current.closest("dialog");
    drag.current = {
      key,
      startedAt: event.timeStamp,
      direction: Math.sign(info.offset.y),
      press,
      controls,
      order: items.map(entryKey),
      cancelled: false,
      scroller,
      scrollLimit: scroller.scrollHeight - scroller.clientHeight,
      pointer: { x: event.clientX, y: event.clientY },
    };
    setActive(drag.current);
    setPreview(items.map(entryKey));
    onOrderingChange(true);
    setAnnouncement(
      `Moving ${exerciseById.get(byKey.get(key).exerciseId).name}. Press Escape to cancel.`,
    );
  }

  function orderAtRelease(gesture, event, bounds) {
    const next = [...gesture.order];
    const heights = new Map(
      [...group.current.children].map((row) => [
        row.dataset.entryKey,
        row.getBoundingClientRect().height,
      ]),
    );
    if (next.some((key) => !heights.has(key))) return next;
    let index = next.indexOf(gesture.key);
    let top =
      bounds.top +
      next.slice(0, index).reduce((sum, key) => sum + heights.get(key), 0);
    const height = heights.get(gesture.key);
    const targetTop = event.clientY - gesture.pointerOffset;
    const direction = Math.sign(targetTop - top);
    // Resolve against virtual layout positions: preview commits and snap-back
    // transforms can still be pending when Motion delivers the release.
    while (direction && next[index + direction]) {
      const neighborHeight = heights.get(next[index + direction]);
      const center =
        direction > 0
          ? top + height + neighborHeight / 2
          : top - neighborHeight / 2;
      if (direction > 0 ? targetTop + height <= center : targetTop >= center)
        break;
      [next[index], next[index + direction]] = [
        next[index + direction],
        next[index],
      ];
      index += direction;
      top += direction * neighborHeight;
    }
    return next;
  }

  function finish(event) {
    const gesture = drag.current;
    // Motion delivers drag-end after rendering. An earlier release must not
    // finish a newer gesture that already started on the same handle.
    if (!gesture || event.timeStamp < gesture.startedAt) return;
    const release = gesture.press.release;
    const valid =
      !gesture.cancelled &&
      release?.time === event.timeStamp &&
      release.valid &&
      release.order.length === items.length &&
      release.order.every((key) => byKey.has(key));
    const name = exerciseById.get(byKey.get(gesture.key).exerciseId).name;
    if (valid) {
      const next = release.order;
      onReorder(next);
      setLanded({ key: gesture.key });
      setAnnouncement(
        `Moved ${name} to position ${next.indexOf(gesture.key) + 1} of ${items.length}.`,
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
            dragging={active?.key === entryKey(item)}
            ordering={!!active}
            landed={landed?.key === entryKey(item)}
            hidden={hidden}
            onPress={(event, offset) => {
              const press = {
                key: entryKey(item),
                startedAt: event.timeStamp,
                pointerId: event.pointerId,
                offset,
                release: null,
              };
              pendingPress.current = press;
              return press;
            }}
            onDragStart={(controls, event, info, press) =>
              begin(entryKey(item), controls, event, info, press)
            }
            onDrag={(event) => {
              const gesture = drag.current;
              if (gesture && event.timeStamp >= gesture.startedAt) {
                if (
                  event.clientX !== gesture.pointer.x ||
                  event.clientY !== gesture.pointer.y
                )
                  gesture.scrollPreviewPointer = null;
                gesture.direction =
                  Math.sign(event.clientY - gesture.pointer.y) ||
                  gesture.direction;
                gesture.pointer = { x: event.clientX, y: event.clientY };
              }
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
