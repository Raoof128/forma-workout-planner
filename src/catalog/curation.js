const equipmentNames = new Map([
  ["none (bodyweight exercise)", "Bodyweight"],
  ["Gym mat", "Bodyweight"],
  ["Cable machine", "Cable"],
  ["SZ-Bar", "EZ bar"],
  ["Swiss Ball", "Exercise ball"],
]);
export function usableGuide(text) {
  if (typeof text !== "string" || text.trim().length < 60) return false;
  const lower = text.toLowerCase();
  return ![
    "custom description created",
    "routine importer",
    "lorem ipsum",
    "placeholder",
    "coming soon",
    "no description",
    "description pending",
    "this is a test",
  ].some((phrase) => lower.includes(phrase));
}
export function canonicalId(id, curation) {
  const seen = new Set();
  while (curation.aliases?.[id]) {
    if (seen.has(id)) throw new Error("Catalog alias cycle");
    seen.add(id);
    id = curation.aliases[id];
  }
  return id;
}
export function createCatalogView(records, curation) {
  const byId = new Map(records.map((row) => [row.id, row]));
  const hidden = new Set(curation.hidden ?? []);
  const extraNames = new Map();
  for (const [from, to] of Object.entries(curation.aliases ?? {})) {
    const resolved = canonicalId(to, curation);
    if (!byId.has(from) || !byId.has(resolved))
      throw new Error("Unknown catalog alias ID");
    if (!extraNames.has(resolved)) extraNames.set(resolved, []);
    const row = byId.get(from);
    extraNames.get(resolved).push(row.name, ...(row.aliases ?? []));
  }
  return records
    .filter(
      (row) => !hidden.has(row.id) && canonicalId(row.id, curation) === row.id,
    )
    .map((row) => {
      const entry = { ...row, ...(curation.overrides?.[row.id] ?? {}) };
      const tags = [
        ...new Set(
          (entry.equipmentTags ?? entry.equipment?.split(" + ") ?? []).map(
            (tag) => equipmentNames.get(tag) ?? tag,
          ),
        ),
      ];
      return {
        ...entry,
        equipment: equipmentNames.get(entry.equipment) ?? entry.equipment,
        equipmentTags: tags,
        aliases: [
          ...new Set([
            ...(entry.aliases ?? []),
            ...(extraNames.get(row.id) ?? []),
            ...(entry.name !== row.name ? [row.name] : []),
          ]),
        ].filter((name) => name !== entry.name),
      };
    });
}
export function matchesEquipment(exercise, equipment) {
  return (
    equipment === exercise.equipment ||
    exercise.equipmentTags?.includes(equipment) === true
  );
}
