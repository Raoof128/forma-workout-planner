// Browser-bundle-only projection of src/catalog/exercises.json.
//
// Each sourced exercise's `description` is a 360-character preview of its full
// instructions, which the guide already loads lazily from instructions.json.
// In the browser the preview was only a loading placeholder, yet it made up
// about 60% of the compressed catalogue in the startup bundle. The JSON file,
// the API (which imports it through Node) and the iOS resources are unchanged.
const CATALOG = "/src/catalog/exercises.json";

export function leanCatalogRows(rows) {
  return rows.map((row) =>
    Object.fromEntries(
      Object.entries(row).filter(([key]) => key !== "description"),
    ),
  );
}

export default function leanExerciseCatalog() {
  return {
    name: "forma-lean-exercise-catalog",
    enforce: "pre",
    transform(code, id) {
      if (!id.split("?")[0].replaceAll("\\", "/").endsWith(CATALOG))
        return null;
      return {
        code: JSON.stringify(leanCatalogRows(JSON.parse(code))),
        map: null,
      };
    },
  };
}
