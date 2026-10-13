import "../brand-motion.css";

// Original FORMA geometry: a planted stem and two forward-moving facets.
const facets = [
  "M18 12H29L19 52H8Z",
  "M32 12H58L55 23H29Z",
  "M27 29H47L44 40H24Z",
];

export function BrandSymbol({ animated = false, className = "" }) {
  return (
    <span
      className={`forma-symbol ${animated ? "is-moving" : ""} ${className}`}
      aria-hidden="true"
    >
      {facets.map((path, index) => (
        <span className={`forma-facet facet-${index + 1}`} key={path}>
          <svg viewBox="0 0 64 64" fill="currentColor" focusable="false">
            <path d={path} />
          </svg>
        </span>
      ))}
    </span>
  );
}

export default function BrandMark() {
  return (
    <span className="forma-lockup">
      <span className="forma-brand-tile">
        <BrandSymbol />
      </span>
      <span className="forma-brand-type">
        <span className="forma-wordmark">FORMA</span>
        <span className="forma-signature" aria-hidden="true">
          TRAINING SPACE
        </span>
      </span>
    </span>
  );
}
