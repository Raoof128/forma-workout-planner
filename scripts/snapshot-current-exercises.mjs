import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { URL } from "node:url";
import { log } from "node:console";
import { format } from "prettier";
import { exercises } from "../src/data.js";
const ids = new Set(exercises.map((exercise) => exercise.id));
const names = new Set(
  exercises.map((exercise) =>
    exercise.name.toLowerCase().replace(/[^a-z0-9]/g, ""),
  ),
);
const licenses = new Map([
  [
    1,
    {
      name: "CC-BY-SA 3",
      url: "https://creativecommons.org/licenses/by-sa/3.0/",
    },
  ],
  [
    2,
    {
      name: "CC-BY-SA 4",
      url: "https://creativecommons.org/licenses/by-sa/4.0/",
    },
  ],
  [
    3,
    { name: "CC0", url: "https://creativecommons.org/publicdomain/zero/1.0/" },
  ],
  [4, { name: "CC-BY 4", url: "https://creativecommons.org/licenses/by/4.0/" }],
]);
const stripHtml = (value) =>
  String(value ?? "")
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "")
    .replace(/<\/(?:p|li)>|<br\s*\/?>/gi, "\n\n")
    .replace(/<[^>]+>/g, " ")
    .replace(
      /&(?:nbsp|amp|quot|lt|gt|#39);/g,
      (value) =>
        ({
          "&nbsp;": " ",
          "&amp;": "&",
          "&quot;": '"',
          "&lt;": "<",
          "&gt;": ">",
          "&#39;": "'",
        })[value],
    )
    .replace(/[ \t]+/g, " ")
    .replace(/\n\s*\n/g, "\n\n")
    .trim();
const group = (value) =>
  /chest|pector/.test(value)
    ? "Chest"
    : /lat|back|trap/.test(value)
      ? "Back"
      : /shoulder|deltoid/.test(value)
        ? "Shoulders"
        : /bicep|tricep|forearm|arm/.test(value)
          ? "Arms"
          : /abs|abdom|oblique|core/.test(value)
            ? "Core"
            : /quad|hamstring|glut|calv|adduct|abduct|leg|tibial/.test(value)
              ? "Legs"
              : "Full body";
const snapshotUrl = new URL(
  "../docs/research/current-wger-additions.json",
  import.meta.url,
);
let previous;
try {
  previous = JSON.parse(await readFile(snapshotUrl, "utf8"));
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
// Retain published IDs even when the live source changes or removes a record.
const additions = [...(previous?.additions ?? [])];
const retainedSupplementalEntries = additions.length;
for (const exercise of additions) {
  ids.add(exercise.id);
  names.add(exercise.name.toLowerCase().replace(/[^a-z0-9]/g, ""));
}
const pages = [];
const dispositions = {
  alreadyIncluded: 0,
  noEnglishTranslation: 0,
  licenseExcluded: 0,
  incompleteDescription: 0,
  added: 0,
};
let next = "https://wger.de/api/v2/exerciseinfo/?language=2&limit=100";
let total = 0,
  expected;
while (next) {
  const url = new URL(next);
  if (
    url.origin !== "https://wger.de" ||
    url.pathname !== "/api/v2/exerciseinfo/" ||
    pages.length >= 20
  )
    throw new Error("Unexpected catalog pagination");
  const response = await globalThis.fetch(url, {
    redirect: "error",
    signal: globalThis.AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error(`Current catalog HTTP ${response.status}`);
  const text = await response.text();
  if (text.length > 16 * 1024 * 1024) throw new Error("Source page too large");
  const data = JSON.parse(text);
  expected ??= data.count;
  pages.push({
    url: url.href,
    sha256: createHash("sha256").update(text).digest("hex"),
  });
  for (const record of data.results) {
    total++;
    const translation = record.translations.find(
      (translation) => translation.language === 2,
    );
    if (!translation) {
      dispositions.noEnglishTranslation++;
      continue;
    }
    const id = `wger-${record.uuid}`,
      name = translation.name.trim(),
      normalized = name.toLowerCase().replace(/[^a-z0-9]/g, "");
    if (ids.has(id) || names.has(normalized)) {
      dispositions.alreadyIncluded++;
      continue;
    }
    const licenseId =
      typeof translation.license === "number"
        ? translation.license
        : translation.license?.id;
    const license = licenses.get(licenseId);
    if (!license) {
      dispositions.licenseExcluded++;
      continue;
    }
    const description = stripHtml(
      translation.description_source || translation.description,
    );
    if (description.length < 60) {
      dispositions.incompleteDescription++;
      continue;
    }
    const primary = record.muscles.map(
      (muscle) => muscle.name_en || muscle.name,
    );
    const categoryName = record.category.name.toLowerCase();
    additions.push({
      id,
      name,
      muscle: group((primary.join(" ") || categoryName).toLowerCase()),
      equipment:
        record.equipment.map((equipment) => equipment.name).join(" + ") ||
        "Bodyweight",
      primaryMuscles: primary,
      secondaryMuscles: record.muscles_secondary.map(
        (muscle) => muscle.name_en || muscle.name,
      ),
      category: categoryName === "cardio" ? "cardio" : "strength",
      level: "Unspecified",
      description,
      aliases: (translation.aliases ?? [])
        .map((alias) => (typeof alias === "string" ? alias : alias.alias))
        .filter(Boolean),
      source: {
        title: "wger",
        url: `https://wger.de/en/exercise/${record.id}/view/`,
        author:
          translation.license_author ||
          record.license_author ||
          "wger contributors",
        license: license.name,
        licenseUrl: license.url,
        modified: "HTML removed; taxonomy and measurement labels normalized",
      },
    });
    ids.add(id);
    names.add(normalized);
    dispositions.added++;
  }
  next = data.next;
}
if (total !== expected)
  throw new Error("Catalog pagination did not cover the advertised total");
const report = {
  retrievedAt: new Date().toISOString(),
  sourceRecords: total,
  retainedSupplementalEntries,
  dispositions,
  pages,
  additions,
};
await writeFile(
  snapshotUrl,
  await format(JSON.stringify(report), { parser: "json" }),
);
log(
  JSON.stringify({
    sourceRecords: total,
    dispositions,
    supplementalEntries: additions.length,
  }),
);
