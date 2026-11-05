"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { MemoryStore } = require("../ledger/stores/memory");
const { ContentService, pathFromUrl, filesToDelete, ownerOf } = require("../content/service");

test("storage paths are read from every URL form", () => {
  assert.equal(pathFromUrl("https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/content%2Fada%2Fsong%2Fa.mp3?alt=media&token=1"), "content/ada/song/a.mp3");
  assert.equal(pathFromUrl("gs://app.appspot.com/songs/b.mp3"), "songs/b.mp3");
  assert.equal(pathFromUrl("https://example.com/c.mp3"), null);
});

test("deleting content removes its files but never someone else's", () => {
  const doc = {
    artistId: "ada",
    trackUrl: "https://firebasestorage.googleapis.com/v0/b/x/o/content%2Fada%2Fsong%2Ft.mp3?alt=media",
    artworkUrl: "https://firebasestorage.googleapis.com/v0/b/x/o/users%2Ftobi%2Fart.jpg?alt=media",
    storagePaths: ["content/ada/song/cover.jpg", "content/mallory/x.jpg"],
    credits: [{ img: "gs://x/legacy/ada_old.jpg" }],
  };
  assert.equal(ownerOf("music", doc), "ada");
  assert.deepEqual(filesToDelete("music", doc).sort(), ["content/ada/song/cover.jpg", "content/ada/song/t.mp3", "legacy/ada_old.jpg"]);
  assert.deepEqual(filesToDelete("music", { trackUrl: "gs://x/songs/a.mp3" }), [], "no owner: nothing deleted");
});

test("contributor registration is server-side, once per role, and never verified by itself", async () => {
  const store = new MemoryStore();
  const svc = new ContentService({ store });
  const r = await svc.registerContributor("ada", { role: "creator", name: "Ada Beats", bio: "Afro-fusion", categories: ["Music", "Podcasts"], isVerified: true }, 1, { email: "a@x.com" });
  assert.equal(r.created, true);
  const c = await store.get(`contributors/${r.contributorId}`);
  assert.equal(c.userId, "ada");
  assert.equal(c.type, "Creator");
  assert.equal(c.isVerified, false);
  const u = await store.get("users/ada");
  assert.equal(u.isCreator, true);
  assert.equal(u.creatorID, r.contributorId);
  assert.deepEqual(await svc.registerContributor("ada", { role: "creator", name: "Again" }, 2), { contributorId: r.contributorId, created: false });
  await assert.rejects(svc.registerContributor("ada", { role: "admin", name: "X" }, 3), /Choose Creator/);
  await assert.rejects(svc.registerContributor("ada", { role: "vendor", name: "" }, 3), /at least 2/);
});
