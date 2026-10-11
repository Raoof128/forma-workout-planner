import { useEffect, useState } from "react";

// Keep the editing value synchronous. Async storage acknowledgments must not
// replace text or move the caret while the user is still typing.
export default function SavedField({
  as: Tag = "input",
  value,
  onChange,
  ...props
}) {
  const [draft, setDraft] = useState(value);
  const [focused, setFocused] = useState(false);
  useEffect(() => {
    if (!focused) setDraft(value);
  }, [value, focused]);
  return (
    <Tag
      {...props}
      value={draft}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      onChange={(event) => {
        setDraft(event.target.value);
        onChange(event);
      }}
    />
  );
}
