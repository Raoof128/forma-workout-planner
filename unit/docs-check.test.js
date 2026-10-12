import test from "node:test";
import assert from "node:assert/strict";
import { headingSlugs } from "../scripts/check-docs.mjs";

test("heading fragments retain inline-code text and omit fenced examples", () => {
  const slugs = headingSlugs(
    "## Run `npm ci`\n\n```md\n## Example `npm run hidden`\n```\n",
  );

  assert.equal(slugs.has("run-npm-ci"), true);
  assert.equal(slugs.has("example-npm-run-hidden"), false);
});
