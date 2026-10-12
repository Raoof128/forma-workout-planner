import { error, log } from "node:console";
import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const ignoredDirectories = new Set([
  ".git",
  "dist",
  "node_modules",
  "test-results",
  "playwright-report",
]);
const failures = [];

async function collectMarkdown(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if (entry.isDirectory() && !ignoredDirectories.has(entry.name)) {
      files.push(...(await collectMarkdown(path.join(directory, entry.name))));
    } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".md")) {
      files.push(path.join(directory, entry.name));
    }
  }

  return files;
}

function stripFencedCode(markdown) {
  return markdown.replace(
    /^\s{0,3}(```+|~~~+)[^\n]*\n[\s\S]*?^\s{0,3}\1\s*$/gm,
    "",
  );
}

function stripCode(markdown) {
  return stripFencedCode(markdown).replace(/(`+)(?!`).*?\1/g, "");
}

function normalizeReference(label) {
  return label.trim().replace(/\s+/g, " ").toLowerCase();
}

function findClosing(text, start, open, close) {
  let depth = 0;
  let escaped = false;

  for (let index = start; index < text.length; index += 1) {
    const character = text[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (character === "\\") {
      escaped = true;
      continue;
    }
    if (character === open) depth += 1;
    if (character === close && --depth === 0) return index;
  }

  return -1;
}

function readDestination(text, openParen) {
  let index = openParen + 1;
  // nosemgrep: ajinabraham.njsscan.dos.regex_dos.regex_dos -- one-character test, dev-only docs checker
  while (/\s/.test(text[index] ?? "")) index += 1;
  if (text[index] === ")") return { destination: "", end: index + 1 };

  let destination = "";
  if (text[index] === "<") {
    index += 1;
    let escaped = false;
    while (index < text.length) {
      const character = text[index++];
      if (escaped) {
        destination += character;
        escaped = false;
      } else if (character === "\\") {
        escaped = true;
      } else if (character === ">") {
        break;
      } else {
        destination += character;
      }
    }
  } else {
    let nestedParens = 0;
    let escaped = false;
    while (index < text.length) {
      const character = text[index];
      if (escaped) {
        destination += character;
        escaped = false;
        index += 1;
      } else if (character === "\\") {
        escaped = true;
        index += 1;
      } else if (character === "(") {
        nestedParens += 1;
        destination += character;
        index += 1;
      } else if (character === ")" && nestedParens > 0) {
        nestedParens -= 1;
        destination += character;
        index += 1;
      } else if (character === ")" || /\s/.test(character)) {
        break;
      } else {
        destination += character;
        index += 1;
      }
    }
  }

  // nosemgrep: ajinabraham.njsscan.dos.regex_dos.regex_dos -- one-character test, dev-only docs checker
  while (/\s/.test(text[index] ?? "")) index += 1;
  if (text[index] === '"' || text[index] === "'" || text[index] === "(") {
    const titleEnd = text[index] === "(" ? ")" : text[index];
    index += 1;
    let escaped = false;
    while (index < text.length) {
      const character = text[index++];
      if (escaped) escaped = false;
      else if (character === "\\") escaped = true;
      else if (character === titleEnd) break;
    }
    // nosemgrep: ajinabraham.njsscan.dos.regex_dos.regex_dos -- one-character test, dev-only docs checker
    while (/\s/.test(text[index] ?? "")) index += 1;
  }

  if (text[index] !== ")") return null;
  return { destination, end: index + 1 };
}

function extractLinks(markdown) {
  const definitions = new Map();
  const body = stripCode(markdown).replace(
    /^\s{0,3}\[([^\]]+)\]:\s*(?:<([^>\n]+)>|(\S+))(?:\s+["'(].*)?$/gm,
    (line, label, angle, bare) => {
      const match = line.match(/^\s{0,3}\[([^\]]+)\]:\s*(?:<([^>\n]+)>|(\S+))/);
      if (match)
        definitions.set(
          normalizeReference(label),
          angle ?? bare ?? match[2] ?? match[3],
        );
      return "";
    },
  );
  const links = [];

  for (let index = 0; index < body.length; index += 1) {
    if (body[index] !== "[" || (index > 0 && body[index - 1] === "\\"))
      continue;
    const isImage = index > 0 && body[index - 1] === "!";
    const closingBracket = findClosing(body, index, "[", "]");
    if (closingBracket < 0) continue;
    const label = body.slice(index + 1, closingBracket);
    let next = closingBracket + 1;
    if (body[next] === "(") {
      const parsed = readDestination(body, next);
      if (parsed) {
        links.push({ destination: parsed.destination, isImage });
        index = parsed.end - 1;
      }
      continue;
    }

    let reference = label;
    if (body[next] === "[") {
      const referenceEnd = findClosing(body, next, "[", "]");
      if (referenceEnd < 0) continue;
      const explicit = body.slice(next + 1, referenceEnd);
      reference = explicit || label;
      next = referenceEnd + 1;
    } else if (body[next] === ":") {
      continue;
    }
    const destination = definitions.get(normalizeReference(reference));
    if (destination !== undefined) {
      links.push({ destination, isImage });
      index = next - 1;
    }
  }

  for (const match of body.matchAll(/<img\b[^>]*\bsrc\s*=\s*(["'])(.*?)\1/gi)) {
    links.push({ destination: match[2], isImage: true });
  }
  return links;
}

function githubSlug(text) {
  return text
    .replace(/<[^>]*>/g, "")
    .replace(/!?(\[([^\]]+)\])(?:\([^)]*\))?/g, "$2")
    .replace(/[`*_~]/g, "")
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}_\-\s]/gu, "")
    .replace(/\s/g, "-");
}

export function headingSlugs(markdown) {
  const counts = new Map();
  const slugs = new Set();
  const clean = stripFencedCode(markdown);
  for (const match of clean.matchAll(/^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$/gm)) {
    const base = githubSlug(match[1]);
    const count = counts.get(base) ?? 0;
    counts.set(base, count + 1);
    slugs.add(count === 0 ? base : `${base}-${count}`);
  }
  for (const match of clean.matchAll(/^(.+)\n(?:=+|-+)\s*$/gm)) {
    const base = githubSlug(match[1]);
    const count = counts.get(base) ?? 0;
    counts.set(base, count + 1);
    slugs.add(count === 0 ? base : `${base}-${count}`);
  }
  return slugs;
}

function decodePart(value, source, kind) {
  try {
    return decodeURIComponent(value);
  } catch {
    failures.push(
      `${path.relative(repositoryRoot, source)}: malformed URL escape in ${kind} '${value}'`,
    );
    return null;
  }
}

async function validateLink(source, link, markdownCache) {
  const raw = link.destination.trim().replace(/\\([ ()])/g, "$1");
  if (!raw || raw.startsWith("#")) {
    if (raw.startsWith("#")) {
      const fragment = decodePart(raw.slice(1), source, "fragment");
      if (fragment === null) return;
      const sourceMarkdown = markdownCache.get(source);
      if (sourceMarkdown && !headingSlugs(sourceMarkdown).has(fragment)) {
        failures.push(
          `${path.relative(repositoryRoot, source)}: missing heading '#${fragment}'`,
        );
      }
    }
    return;
  }
  if (/^(?:[a-z][a-z\d+.-]*:|\/\/)/i.test(raw)) return;

  const hashIndex = raw.indexOf("#");
  const queryIndex = raw.indexOf("?");
  const pathEnd = [hashIndex, queryIndex]
    .filter((value) => value >= 0)
    .reduce((min, value) => Math.min(min, value), raw.length);
  const encodedPath = raw.slice(0, pathEnd);
  const encodedFragment =
    hashIndex >= 0
      ? raw.slice(
          hashIndex + 1,
          queryIndex > hashIndex ? queryIndex : undefined,
        )
      : "";
  const decodedPath = decodePart(encodedPath, source, "path");
  const decodedFragment = decodePart(encodedFragment, source, "fragment");
  if (decodedPath === null || decodedFragment === null) return;

  let target = decodedPath.startsWith("/")
    ? path.resolve(repositoryRoot, decodedPath.slice(1))
    : path.resolve(path.dirname(source), decodedPath || ".");
  if (
    !target.startsWith(`${repositoryRoot}${path.sep}`) &&
    target !== repositoryRoot
  ) {
    failures.push(
      `${path.relative(repositoryRoot, source)}: local link escapes repository: '${raw}'`,
    );
    return;
  }
  try {
    const targetStat = await stat(target);
    if (targetStat.isDirectory()) target = path.join(target, "README.md");
    await stat(target);
  } catch {
    failures.push(
      `${path.relative(repositoryRoot, source)}: missing ${link.isImage ? "image" : "link"} target '${raw}'`,
    );
    return;
  }

  if (decodedFragment) {
    if (path.extname(target).toLowerCase() === ".md") {
      let markdown = markdownCache.get(target);
      if (markdown === undefined) {
        markdown = await readFile(target, "utf8");
        markdownCache.set(target, markdown);
      }
      if (!headingSlugs(markdown).has(decodedFragment)) {
        failures.push(
          `${path.relative(repositoryRoot, source)}: missing heading '${raw}' in ${path.relative(repositoryRoot, target)}`,
        );
      }
    }
  }
}

async function validateNpmScriptNames(markdownFiles, packageJson) {
  const knownScripts = new Set(Object.keys(packageJson.scripts ?? {}));
  const npmCommands = new Set([
    "ci",
    "install",
    "test",
    "start",
    "stop",
    "publish",
    "version",
    "audit",
    "exec",
    "view",
    "ls",
    "outdated",
    "update",
    "uninstall",
  ]);
  for (const source of markdownFiles) {
    const markdown = await readFile(source, "utf8");
    const snippets = [
      ...markdown
        .matchAll(/^\s{0,3}(```+|~~~+)[^\n]*\n([\s\S]*?)^\s{0,3}\1\s*$/gm)
        .map((match) => match[2]),
    ];
    const outsideFences = markdown.replace(
      /^\s{0,3}(```+|~~~+)[^\n]*\n[\s\S]*?^\s{0,3}\1\s*$/gm,
      "",
    );
    snippets.push(
      ...[...outsideFences.matchAll(/`([^`\n]+)`/g)].map((match) => match[1]),
    );
    for (const snippet of snippets) {
      for (const match of snippet.matchAll(
        /\bnpm\s+(run\s+)?([a-zA-Z0-9:_-]+)/g,
      )) {
        const isRunCommand = Boolean(match[1]);
        const scriptName = match[2];
        const isValid = isRunCommand
          ? knownScripts.has(scriptName)
          : knownScripts.has(scriptName) || npmCommands.has(scriptName);
        if (!isValid) {
          failures.push(
            `${path.relative(repositoryRoot, source)}: npm script '${scriptName}' is not defined in package.json`,
          );
        }
      }
    }
  }
}

async function main() {
  const markdownFiles = await collectMarkdown(repositoryRoot);
  const markdownCache = new Map();
  for (const source of markdownFiles)
    markdownCache.set(source, await readFile(source, "utf8"));
  for (const source of markdownFiles) {
    for (const link of extractLinks(markdownCache.get(source))) {
      await validateLink(source, link, markdownCache);
    }
  }
  const packageJson = JSON.parse(
    await readFile(path.join(repositoryRoot, "package.json"), "utf8"),
  );
  await validateNpmScriptNames(markdownFiles, packageJson);

  if (failures.length) {
    error(`Documentation check failed with ${failures.length} issue(s):`);
    for (const failure of failures) error(`- ${failure}`);
    process.exitCode = 1;
  } else {
    log(
      `Documentation check passed: ${markdownFiles.length} Markdown files, local links/images/fragments, and npm script names.`,
    );
  }
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  await main();
}
