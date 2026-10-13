import BrandMark, { BrandSymbol } from "./BrandMark";

export function LoadingGlyph() {
  return <BrandSymbol animated className="forma-loading-glyph" />;
}

export default function Loading({
  label = "Loading…",
  detail,
  inline = false,
  className = "",
  announce = true,
}) {
  if (inline)
    return (
      <span
        className={`forma-loading-inline ${className}`}
        role={announce ? "status" : undefined}
      >
        <LoadingGlyph />
        <span>{label}</span>
      </span>
    );
  return (
    <div
      className={`forma-loading-panel ${className}`}
      role={announce ? "status" : undefined}
    >
      <div className="forma-loading-brand" aria-hidden="true">
        <BrandMark />
      </div>
      <div className="forma-loading-stage" aria-hidden="true">
        <span className="forma-orbit orbit-outer" />
        <span className="forma-orbit orbit-inner" />
        <span className="forma-loading-core">
          <BrandSymbol animated />
        </span>
        <span className="forma-stage-cross cross-top" />
        <span className="forma-stage-cross cross-bottom" />
      </div>
      <div className="forma-loading-copy">
        <p className="forma-loading-label">{label}</p>
        {detail && <p className="forma-loading-detail">{detail}</p>}
      </div>
      <div className="forma-loading-baseline" aria-hidden="true">
        <span />
        BUILT ONE REP AT A TIME
        <span />
      </div>
    </div>
  );
}
