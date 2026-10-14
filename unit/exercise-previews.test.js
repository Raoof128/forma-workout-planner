import assert from "node:assert/strict";
import fs from "node:fs";
import crypto from "node:crypto";
import { URL } from "node:url";
import path from "node:path";
import { test } from "node:test";

test("compact artwork has smaller hash-versioned previews preserving atlas proportions and originals", () => {
  const media = JSON.parse(fs.readFileSync("src/catalog/media.json", "utf8"));
  for (const asset of Object.values(media.assets)) {
    assert.equal(asset.previewId, asset.sha256.slice(0, 16));
    const preview = media.previews?.[asset.previewId];
    assert(preview, `Missing compact preview for ${asset.src}`);
    const original = fs.readFileSync(
      path.join("public", new URL(asset.src, "https://forma.example").pathname),
    );
    const url = new URL(preview.src, "https://forma.example");
    const bytes = fs.readFileSync(path.join("public", url.pathname));
    assert(url.pathname.startsWith("/exercise-media/previews/"));
    assert(bytes.length < original.length);
    assert.equal(bytes.toString("ascii", 12, 16), "VP8 ");
    assert.equal(bytes.readUInt16LE(26) & 0x3fff, preview.width);
    assert.equal(bytes.readUInt16LE(28) & 0x3fff, preview.height);
    assert.equal(preview.width * asset.height, preview.height * asset.width);
    assert.equal(
      crypto.createHash("sha256").update(original).digest("hex"),
      asset.sha256,
    );
    const sha = crypto.createHash("sha256").update(bytes).digest("hex");
    assert.equal(sha, preview.sha256);
    assert.equal(url.searchParams.get("v"), sha.slice(0, 12));
  }
});
