"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { MemoryStore } = require("../ledger/stores/memory");
const { Notifier, joinNames, PUSH_PER_HOUR } = require("../notify/service");
const { AccountService, remindToResume, completeness, usernameProblem } = require("../account/service");

const T0 = Date.UTC(2026, 10, 5, 12);
const DAY = 24 * 3600 * 1000;

async function setup() {
  const store = new MemoryStore();
  const pushed = [];
  const notifier = new Notifier({ store, push: async (tokens, payload) => { pushed.push({ tokens, payload }); return { invalid: tokens.filter((t) => t.startsWith("dead")) }; } });
  await store.set("users/tobi", { displayName: "Tobi", fcmTokens: ["tok1", "dead1"] });
  await store.set("users/ada", { displayName: "Ada" });
  const inbox = async (uid) => (await store.query({ collection: `users/${uid}/notifications` })).map((r) => r.data);
  return { store, notifier, pushed, inbox };
}

test("names are joined the way people read them", () => {
  assert.equal(joinNames(["Ada"], 1), "Ada");
  assert.equal(joinNames(["Ada", "Bo"], 2), "Ada and Bo");
  assert.equal(joinNames(["Ada", "Bo"], 5), "Ada, Bo and 3 others");
});

test("a notification lands in the inbox and is pushed; dead tokens are removed", async () => {
  const { notifier, pushed, inbox, store } = await setup();
  const r = await notifier.notify({ to: "tobi", type: "reply", actorId: "ada", actorName: "Ada", title: "Ada replied to your post", body: "nice!", target: { kind: "post", id: "p1" }, now: T0 });
  assert.equal(r.pushed, true);
  const [n] = await inbox("tobi");
  assert.equal(n.title, "Ada replied to your post");
  assert.equal(n.isRead, false);
  assert.deepEqual(n.target, { kind: "post", id: "p1" });
  assert.equal(pushed[0].payload.data.targetId, "p1");
  assert.deepEqual((await store.get("users/tobi")).fcmTokens, ["tok1"]);
});

test("likes on the same post group into one entry", async () => {
  const { notifier, inbox } = await setup();
  for (const [i, name] of ["Ada", "Bo", "Cy", "Di"].entries()) {
    await notifier.notify({ to: "tobi", type: "like", actorId: `u${i}`, actorName: name, title: "", target: { kind: "post", id: "p1" }, group: "post_p1", now: T0 + i });
  }
  await notifier.notify({ to: "tobi", type: "like", actorId: "u0", actorName: "Ada", title: "", group: "post_p1", now: T0 + 10 });
  const items = await inbox("tobi");
  assert.equal(items.length, 1);
  assert.equal(items[0].count, 4, "the same person liking twice counts once");
  assert.equal(items[0].title, "Di, Cy and 2 others liked your post");
});

test("self, blocked, disabled and muted are respected", async () => {
  const { notifier, store, pushed } = await setup();
  assert.equal((await notifier.notify({ to: "tobi", type: "like", actorId: "tobi", title: "x" })).skipped, "self");
  await store.set("users/tobi", { blockedUsers: ["eve"], notificationPrefs: { follows: false }, muteUntil: T0 + 1000 }, { merge: true });
  assert.equal((await notifier.notify({ to: "tobi", type: "reply", actorId: "eve", title: "x" })).skipped, "blocked");
  assert.equal((await notifier.notify({ to: "tobi", type: "follow", actorId: "ada", title: "x" })).skipped, "disabled");
  const muted = await notifier.notify({ to: "tobi", type: "reply", actorId: "ada", title: "x", now: T0 });
  assert.equal(muted.delivered, true);
  assert.equal(muted.pushed, false);
  assert.equal(pushed.length, 0);
});

test("pushes are rate limited per person; the inbox still fills", async () => {
  const { notifier } = await setup();
  let pushedCount = 0;
  for (let i = 0; i < PUSH_PER_HOUR + 5; i++) {
    const r = await notifier.notify({ to: "tobi", type: "reply", actorId: "ada", title: `r${i}`, now: T0 + i });
    if (r.pushed) pushedCount += 1;
  }
  assert.equal(pushedCount, PUSH_PER_HOUR);
});

test("creators hear about milestones, not every single play", async () => {
  const { notifier, inbox } = await setup();
  const hits = [];
  for (let i = 0; i < 12; i++) {
    const r = await notifier.countAndCelebrate({ type: "book", id: "b1", title: "Lagos Nights", ownerId: "tobi", now: T0 + i });
    if (r.milestone) hits.push(r.milestone);
  }
  assert.deepEqual(hits, [1, 10]);
  const items = await inbox("tobi");
  assert.equal(items.length, 2);
  assert.ok(items.some((n) => /started reading "Lagos Nights"/.test(n.body)));
  assert.ok(items.some((n) => /reached 10 reads/.test(n.body)));
});

test("readers get one 'pick up where you left off' per item, after a day", async () => {
  const { notifier, inbox } = await setup();
  const item = { uid: "ada", key: "book_b1", data: { type: "book", id: "b1", title: "Lagos Nights", page: 45, pageCount: 200, updatedMs: T0 - 2 * DAY } };
  const fresh = { uid: "ada", key: "book_b2", data: { type: "book", id: "b2", title: "New", page: 2, updatedMs: T0 - 1000 } };
  const done = { uid: "ada", key: "book_b3", data: { type: "book", id: "b3", completed: true, updatedMs: T0 - 2 * DAY } };
  const r = await remindToResume({ notifier, items: [item, fresh, done], now: T0 });
  assert.equal(r.sent, 1);
  const [n] = await inbox("ada");
  assert.match(n.body, /page 45 of 200/);
  assert.deepEqual(n.target, { kind: "book", id: "b1" });
});

// ------------------------------------------------------------ accounts
async function accounts() {
  const ctx = await setup();
  const acct = new AccountService({ store: ctx.store, notifier: ctx.notifier, random: () => 0.5 });
  return { ...ctx, acct };
}

test("usernames: validated, unique (including older accounts), suggested", async () => {
  const { acct, store } = await accounts();
  assert.match(usernameProblem("ab"), /3 characters/);
  assert.match(usernameProblem("admin"), /reserved/);
  assert.match(usernameProblem("_ada"), /start or end/);
  await store.set("users/old1", { username: "adaeze" });
  assert.equal((await acct.checkUsername("new1", "@AdaEze")).available, false);
  assert.equal((await acct.checkUsername("old1", "adaeze")).available, true, "your own username is fine");
  const s = await acct.suggestUsername("new1", { name: "Ada Eze" });
  assert.notEqual(s.username, "adaeze");
  assert.match(s.username, /^adaeze\d+$/);
});

test("onboarding takes name and username, fills every field, and sends the welcome and profile nudge", async () => {
  const { acct, store, inbox } = await accounts();
  const r = await acct.onboard("new1", { displayName: "  Ada   Eze ", username: "ada_eze", interests: ["Music", "Books"] }, T0, { email: "ada@x.com" });
  assert.equal(r.onboarded, true);
  const u = await store.get("users/new1");
  assert.equal(u.displayName, "Ada Eze");
  assert.equal(u.username, "ada_eze");
  assert.equal(u.email, "ada@x.com");
  assert.deepEqual(u.hobbies, ["Music", "Books"]);
  assert.equal(u.isCreator, false, "defaults present");
  assert.equal((await store.get("usernames/ada_eze")).uid, "new1");
  assert.equal((await acct.status("new1")).onboarded, true);
  const items = await inbox("new1");
  assert.deepEqual(items.map((n) => n.type).sort(), ["complete_profile", "welcome"]);
  await assert.rejects(acct.onboard("new2", { displayName: "Someone", username: "ada_eze" }, T0), /taken/);
});

test("changing username releases the old one", async () => {
  const { acct, store } = await accounts();
  await acct.onboard("new1", { displayName: "Ada", username: "ada_one" }, T0);
  await acct.onboard("new1", { displayName: "Ada", username: "ada_two" }, T0 + 1);
  assert.equal(await store.get("usernames/ada_one"), null);
  assert.equal((await acct.checkUsername("other", "ada_one")).available, true);
});

test("unfinished profiles get at most 3 reminders, 3 days apart", async () => {
  const { acct, store, inbox } = await accounts();
  await acct.onboard("new1", { displayName: "Ada", username: "ada_x" }, T0);
  const users = async () => [{ id: "new1", data: await store.get("users/new1") }];
  assert.equal((await acct.remindIncomplete(T0 + DAY / 2, await users())).sent, 0, "not in the first day");
  assert.equal((await acct.remindIncomplete(T0 + DAY + 1, await users())).sent, 1);
  assert.equal((await acct.remindIncomplete(T0 + 2 * DAY, await users())).sent, 0, "3 days apart");
  await acct.remindIncomplete(T0 + 5 * DAY, await users());
  await acct.remindIncomplete(T0 + 9 * DAY, await users());
  assert.equal((await acct.remindIncomplete(T0 + 13 * DAY, await users())).sent, 0, "max 3");
  assert.equal(completeness({ profileImage: "x", bio: "hi", bannerImage: "y", country: "NG", hobbies: ["a"] }).percent, 100);
  assert.ok((await inbox("new1")).length >= 1);
});
