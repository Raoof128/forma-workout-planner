import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { Check, X } from "lucide-react";
export default function Notification({ message, onDismiss }) {
  const [target, setTarget] = useState(document.body);
  useEffect(() => {
    const sync = () =>
      setTarget(document.querySelector("dialog[open]") || document.body);
    sync();
    const observer = new MutationObserver(sync);
    observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["open"],
    });
    return () => observer.disconnect();
  }, []);
  return createPortal(
    <div className="toast" role="status">
      <span>
        <Check size={17} />
      </span>
      {message}
      <button aria-label="Dismiss notification" onClick={onDismiss}>
        <X size={16} />
      </button>
    </div>,
    target,
  );
}
