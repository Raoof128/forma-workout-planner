import { legalDocuments } from "../legal/content.js";

export const isLegalPage = (page) => page === "privacy" || page === "terms";
export const legalTitle = (page) => legalDocuments[page]?.title ?? "";

function Block({ block, onNavigate }) {
  if (block.h)
    return (
      <h2 id={block.id} tabIndex={-1}>
        {block.h}
      </h2>
    );
  if (block.h3) return <h3>{block.h3}</h3>;
  if (block.ul)
    return (
      <ul>
        {block.ul.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    );
  if (block.link)
    return (
      <p>
        {block.before}
        <a
          href={`#${block.link}`}
          onClick={(event) => {
            event.preventDefault();
            onNavigate(block.link);
          }}
        >
          {block.label}
        </a>
        {block.after}
      </p>
    );
  return <p>{block.p}</p>;
}

export default function Legal({ page, onNavigate }) {
  const legal = legalDocuments[page];
  if (!legal) return null;
  const sections = legal.blocks.filter((block) => block.h);
  return (
    <article className="legal-page" aria-labelledby="legal-title">
      <header className="legal-header">
        <span className="eyebrow">FORMA · LEGAL</span>
        <h1 id="legal-title">{legal.title}</h1>
        <p className="legal-meta">
          Version {legal.version} · Effective {legal.effective}
        </p>
        <p className="legal-summary">{legal.summary}</p>
      </header>
      <nav className="legal-toc" aria-label={`${legal.title} contents`}>
        <ol>
          {sections.map((section) => (
            <li key={section.id}>
              <a
                href={`#${page}`}
                onClick={(event) => {
                  event.preventDefault();
                  const heading = document.getElementById(section.id);
                  if (!heading) return;
                  const reducedMotion = window.matchMedia(
                    "(prefers-reduced-motion: reduce)",
                  ).matches;
                  heading.focus({ preventScroll: true });
                  heading.scrollIntoView({
                    behavior: reducedMotion ? "auto" : "smooth",
                    block: "start",
                  });
                }}
              >
                {section.h}
              </a>
            </li>
          ))}
        </ol>
      </nav>
      <div className="legal-body">
        {legal.blocks.map((block, index) => (
          <Block key={index} block={block} onNavigate={onNavigate} />
        ))}
      </div>
    </article>
  );
}
