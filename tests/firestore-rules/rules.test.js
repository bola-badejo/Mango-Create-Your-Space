"use strict";
// Runs against the Firestore emulator:
//   firebase emulators:exec --only firestore --project demo-mango "npm --prefix tests/firestore-rules test"
const test = require("node:test");
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs, serverTimestamp, increment } = require("firebase/firestore");

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-mango",
    firestore: { rules: fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8") },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "ledger_accounts/alice"), { address: "mng1a", balance: "100" });
    await setDoc(doc(db, "ledger_accounts/bob"), { address: "mng1b", balance: "5" });
    await setDoc(doc(db, "wallets/alice"), { balance: 1 });
    await setDoc(doc(db, "ledger_blocks/000000000000"), { hash: "h" });
    await setDoc(doc(db, "ledger_tx/t1"), { from: "mng1a", to: "mng1b", amount: "1" });
    await setDoc(doc(db, "ledger_keys/k1"), { publicKeyPem: "pem" });
    await setDoc(doc(db, "ledger_meta/chain"), { height: 0 });
    await setDoc(doc(db, "ledger_sessions/alice"), { startedAt: 1 });
    await setDoc(doc(db, "ledger_caps/alice_2026-11-04"), { counts: {} });
    await setDoc(doc(db, "ledger_addresses/mng1a"), { uid: "alice" });
    await setDoc(doc(db, "ledger_activity/e1"), { actor: "alice", type: "like_given" });
    await setDoc(doc(db, "ledger_epochs/00000000"), { totalPoints: 1 });
    await setDoc(doc(db, "ledger_epochs/00000000/points/alice"), { points: 1 });
    await setDoc(doc(db, "posts/p0"), { text: "hello", postCreator: "bob" });
    await setDoc(doc(db, "dm_chats/ada_tobi"), { members: ["ada", "tobi"], retention: "after_viewing" });
    await setDoc(doc(db, "dm_chats/ada_tobi/messages/m1"), { senderId: "tobi", kind: "text", text: "hi", reactions: {} });
    await setDoc(doc(db, "users/ada/chats/tobi/messages/old1"), { text: "old private chat" });
    await setDoc(doc(db, "messages/old2"), { text: "old global copy", participants: ["ada", "tobi"] });
    await setDoc(doc(db, "music/s1"), { title: "Song", artistId: "tobi", plays: 3 });
    await setDoc(doc(db, "contributors/c1"), { userId: "tobi", type: "Creator", isVerified: false, bio: "hi" });
    await setDoc(doc(db, "users/ada/notifications/n1"), { type: "like", title: "Bo liked your post", isRead: false });
    await setDoc(doc(db, "spaces/pub"), { title: "Open", ownerId: "tobi", postCreator: "tobi", editors: ["tobi"], visibility: "public", members: 1, theme: { skinId: "skin.meadow" } });
    await setDoc(doc(db, "spaces/priv"), { title: "Secret", ownerId: "tobi", postCreator: "tobi", editors: ["tobi"], visibility: "private", members: 1 });
    await setDoc(doc(db, "spaces/pub/inventory/obj.plant"), { itemId: "obj.plant" });
    await setDoc(doc(db, "spaces/pub/objects/o1"), { kind: "decor", itemId: "obj.plant", x: 0.5, y: 0.5 });
    await setDoc(doc(db, "spaces/priv/objects/o1"), { kind: "wall", x: 0.2, y: 0.2 });
    await setDoc(doc(db, "spaces/pub/events/live1"), { status: "live", title: "Party", hostId: "tobi" });
    await setDoc(doc(db, "spaces/pub/events/soon"), { status: "scheduled", title: "Later", hostId: "tobi" });
  });
});

test.after(async () => env && env.cleanup());

const as = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();

test("an account is readable only by its owner", async () => {
  await assertSucceeds(getDoc(doc(as("alice"), "ledger_accounts/alice")));
  await assertFails(getDoc(doc(as("bob"), "ledger_accounts/alice")));
  await assertFails(getDoc(doc(as(null), "ledger_accounts/alice")));
});

test("nobody can write balances from the app, including their own", async () => {
  await assertFails(updateDoc(doc(as("alice"), "ledger_accounts/alice"), { balance: "999999" }));
  await assertFails(setDoc(doc(as("alice"), "ledger_accounts/mallory"), { balance: "1" }));
  await assertFails(deleteDoc(doc(as("alice"), "ledger_accounts/bob")));
  await assertFails(updateDoc(doc(as("alice"), "wallets/alice"), { balance: 999999 }));
});

test("nobody can forge blocks, transactions, keys or chain metadata", async () => {
  const db = as("alice");
  await assertFails(setDoc(doc(db, "ledger_tx/forged"), { from: "mng1b", to: "mng1a", amount: "1000" }));
  await assertFails(setDoc(doc(db, "ledger_blocks/000000000001"), { hash: "x" }));
  await assertFails(setDoc(doc(db, "ledger_keys/evil"), { publicKeyPem: "x" }));
  await assertFails(updateDoc(doc(db, "ledger_meta/chain"), { height: 99 }));
  await assertFails(setDoc(doc(db, "ledger_epochs/00000000/points/alice"), { points: 1e9 }));
});

test("the public ledger is readable by signed-in users; keys by anyone", async () => {
  await assertSucceeds(getDoc(doc(as("bob"), "ledger_blocks/000000000000")));
  await assertSucceeds(getDoc(doc(as("bob"), "ledger_tx/t1")));
  await assertSucceeds(getDoc(doc(as("bob"), "ledger_meta/chain")));
  await assertFails(getDoc(doc(as(null), "ledger_tx/t1")));
  await assertSucceeds(getDoc(doc(as(null), "ledger_keys/k1")));
});

test("server-internal ledger data is hidden from every client", async () => {
  const db = as("alice");
  await assertFails(getDoc(doc(db, "ledger_sessions/alice")));
  await assertFails(getDoc(doc(db, "ledger_caps/alice_2026-11-04")));
  await assertFails(getDoc(doc(db, "ledger_addresses/mng1a")));
});

test("activity records and epoch points are visible only to their owner", async () => {
  await assertSucceeds(getDoc(doc(as("alice"), "ledger_activity/e1")));
  await assertFails(getDoc(doc(as("bob"), "ledger_activity/e1")));
  await assertSucceeds(getDocs(query(collection(as("alice"), "ledger_activity"), where("actor", "==", "alice"))));
  await assertSucceeds(getDoc(doc(as("alice"), "ledger_epochs/00000000/points/alice")));
  await assertFails(getDoc(doc(as("bob"), "ledger_epochs/00000000/points/alice")));
  await assertSucceeds(getDoc(doc(as("bob"), "ledger_epochs/00000000")));
});

test("the rest of the app behaves as before", async () => {
  await assertSucceeds(setDoc(doc(as("alice"), "posts/p1"), { text: "hi", postCreator: "alice" }));
  await assertSucceeds(getDoc(doc(as(null), "posts/p0")));
  await assertFails(setDoc(doc(as(null), "posts/p2"), { text: "anon" }));
});

// ---------------------------------------------------------------- Spaces
const msg = (uid, text = "hello") => ({ authorId: uid, text, createdAt: serverTimestamp() });

test("only the owner or editors can edit a Space, and never its server fields", async () => {
  await assertSucceeds(updateDoc(doc(as("tobi"), "spaces/pub"), { description: "New description" }));
  await assertFails(updateDoc(doc(as("ada"), "spaces/pub"), { title: "Hijacked" }));
  await assertFails(updateDoc(doc(as("tobi"), "spaces/pub"), { theme: { skinId: "skin.gold" } }));
  await assertFails(updateDoc(doc(as("tobi"), "spaces/pub"), { ownerId: "ada" }));
  await assertFails(deleteDoc(doc(as("ada"), "spaces/pub")));
});

test("anyone signed in may only nudge the member count by one", async () => {
  await assertSucceeds(updateDoc(doc(as("ada"), "spaces/pub"), { members: increment(1) }));
  await assertFails(updateDoc(doc(as("ada"), "spaces/pub"), { members: 9999 }));
});

test("legacy Space creation is limited to the creator and cannot set server fields", async () => {
  await assertSucceeds(setDoc(doc(as("ada"), "spaces/legacy1"), { title: "Mine", postCreator: "ada" }));
  await assertFails(setDoc(doc(as("ada"), "spaces/legacy2"), { title: "Fake", postCreator: "tobi" }));
  await assertFails(setDoc(doc(as("ada"), "spaces/legacy3"), { title: "Mine", postCreator: "ada", theme: { skinId: "skin.gold" } }));
});

test("objects: editors place owned items only, within the canvas", async () => {
  const db = as("tobi");
  await assertSucceeds(setDoc(doc(db, "spaces/pub/objects/o2"), { kind: "decor", itemId: "obj.plant", x: 0.1, y: 0.9, scale: 1 }));
  await assertFails(setDoc(doc(db, "spaces/pub/objects/o3"), { kind: "decor", itemId: "obj.castle", x: 0.1, y: 0.9 }));
  await assertFails(setDoc(doc(db, "spaces/pub/objects/o4"), { kind: "decor", itemId: "obj.plant", x: 1.5, y: 0.5 }));
  await assertSucceeds(setDoc(doc(db, "spaces/pub/objects/o5"), { kind: "content", contentRef: { type: "song", id: "s1", title: "Track" }, x: 0.4, y: 0.4 }));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/objects/o6"), { kind: "wall", x: 0.4, y: 0.4 }));
  await assertFails(setDoc(doc(db, "spaces/pub/inventory/obj.castle"), { itemId: "obj.castle" }));
});

test("private Spaces are hidden from people who were not invited", async () => {
  await assertFails(getDoc(doc(as("ada"), "spaces/priv/objects/o1")));
  await assertSucceeds(getDoc(doc(as("tobi"), "spaces/priv/objects/o1")));
  await assertFails(setDoc(doc(as("ada"), "spaces/priv/subscribers/ada"), { userId: "ada" }));
  await assertSucceeds(setDoc(doc(as("tobi"), "spaces/priv/subscribers/ada"), { userId: "ada" }));
  await assertSucceeds(getDoc(doc(as("ada"), "spaces/priv/objects/o1")));
  await assertSucceeds(getDoc(doc(as("ada"), "spaces/pub/objects/o1")));
});

test("wall messages: your own name only, server time, sensible length; no edits", async () => {
  await assertSucceeds(setDoc(doc(as("ada"), "spaces/pub/wall/w1"), msg("ada")));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/wall/w2"), msg("tobi")));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/wall/w3"), msg("ada", "x".repeat(501))));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/wall/w4"), { authorId: "ada", text: "hi", createdAt: new Date(0) }));
  await assertFails(updateDoc(doc(as("ada"), "spaces/pub/wall/w1"), { text: "edited" }));
  await assertFails(setDoc(doc(as(null), "spaces/pub/wall/w5"), msg("ada")));
  await assertFails(setDoc(doc(as("ada"), "spaces/priv/wall/w6"), msg("ada")));
  await assertSucceeds(deleteDoc(doc(as("tobi"), "spaces/pub/wall/w1")), "owners can moderate");
});

test("presence: only your own, with server time and valid position", async () => {
  const p = { name: "Ada", x: 0.5, y: 0.5, lastSeen: serverTimestamp(), status: "here" };
  await assertSucceeds(setDoc(doc(as("ada"), "spaces/pub/presence/ada"), p));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/presence/tobi"), p));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/presence/ada"), { ...p, x: 7 }));
  await assertFails(setDoc(doc(as("ada"), "spaces/priv/presence/ada"), p));
});

test("live events: run by the server; chat only while live", async () => {
  await assertFails(setDoc(doc(as("tobi"), "spaces/pub/events/fake"), { status: "live" }));
  await assertFails(updateDoc(doc(as("tobi"), "spaces/pub/events/soon"), { status: "live" }));
  await assertSucceeds(setDoc(doc(as("ada"), "spaces/pub/events/live1/chat/c1"), msg("ada", "hey!")));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/events/soon/chat/c2"), msg("ada", "early")));
  await assertSucceeds(setDoc(doc(as("ada"), "spaces/pub/events/live1/attendees/ada"), { name: "Ada", joinedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/events/live1/attendees/tobi"), { name: "Tobi", joinedAt: serverTimestamp() }));
});

test("existing Space features keep working", async () => {
  await assertSucceeds(setDoc(doc(as("ada"), "spaces/pub/conversations/c1"), { title: "Chat" }));
  await assertSucceeds(setDoc(doc(as("ada"), "spaces/pub/subscribers/ada"), { userId: "ada" }));
});

test("attendees can raise a hand on their own entry only; speakers are server-only", async () => {
  const entry = { name: "Ada", joinedAt: serverTimestamp(), handRaised: true };
  await assertSucceeds(setDoc(doc(as("ada"), "spaces/pub/events/live1/attendees/ada"), entry));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/events/live1/attendees/ada"), { ...entry, handRaised: "yes" }));
  await assertFails(setDoc(doc(as("ada"), "spaces/pub/events/live1/attendees/bob"), entry));
  await assertFails(updateDoc(doc(as("ada"), "spaces/pub/events/live1"), { speakers: ["ada"] }));
});

// ---------------------------------------------------------------- Media
const list = (owner, extra = {}) => ({ ownerId: owner, title: "Late night", visibility: "public", items: [{ type: "song", id: "s1" }], updatedAt: serverTimestamp(), ...extra });

test("content lists: owners create their own; Space lists need an editor", async () => {
  await assertSucceeds(setDoc(doc(as("ada"), "content_lists/l1"), list("ada")));
  await assertFails(setDoc(doc(as("ada"), "content_lists/l2"), list("tobi")));
  await assertFails(setDoc(doc(as("ada"), "content_lists/l3"), list("ada", { spaceId: "pub" })));
  await assertSucceeds(setDoc(doc(as("tobi"), "content_lists/l4"), list("tobi", { spaceId: "pub" })));
  await assertFails(setDoc(doc(as("ada"), "content_lists/l5"), list("ada", { items: Array.from({ length: 201 }, (_, i) => ({ id: `${i}` })) })));
  await assertFails(updateDoc(doc(as("bob"), "content_lists/l1"), { title: "Mine now", updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(as("ada"), "content_lists/l1"), { title: "Renamed", updatedAt: serverTimestamp() }));
});

test("private lists and lists in private Spaces stay hidden", async () => {
  await assertSucceeds(setDoc(doc(as("ada"), "content_lists/p1"), list("ada", { visibility: "private" })));
  await assertFails(getDoc(doc(as("bob"), "content_lists/p1")));
  await assertSucceeds(getDoc(doc(as("ada"), "content_lists/p1")));
  await assertSucceeds(setDoc(doc(as("tobi"), "content_lists/sp"), list("tobi", { spaceId: "priv" })));
  await assertFails(getDoc(doc(as("bob"), "content_lists/sp")));
});

test("progress is private; taste is read-only for its owner", async () => {
  const p = { type: "book", id: "b1", page: 12, pageCount: 200, updatedAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(as("ada"), "media_progress/ada/items/book_b1"), p));
  await assertFails(getDoc(doc(as("bob"), "media_progress/ada/items/book_b1")));
  await assertFails(setDoc(doc(as("bob"), "media_progress/ada/items/book_b1"), p));
  await assertFails(setDoc(doc(as("ada"), "media_taste/ada"), { genres: {} }));
});

// ------------------------------------------------------------- Chats
const chatMsg = (uid, extra = {}) => ({ senderId: uid, kind: "text", text: "hey", createdAt: serverTimestamp(), ...extra });

test("chats are visible only to their two members", async () => {
  await assertSucceeds(getDoc(doc(as("ada"), "dm_chats/ada_tobi")));
  await assertSucceeds(getDoc(doc(as("tobi"), "dm_chats/ada_tobi/messages/m1")));
  await assertFails(getDoc(doc(as("bob"), "dm_chats/ada_tobi")));
  await assertFails(getDoc(doc(as("bob"), "dm_chats/ada_tobi/messages/m1")));
  await assertFails(setDoc(doc(as("ada"), "dm_chats/ada_bob"), { members: ["ada", "bob"] }));
});

test("members send as themselves; media must live in their own chat folder", async () => {
  await assertSucceeds(setDoc(doc(as("ada"), "dm_chats/ada_tobi/messages/n1"), chatMsg("ada")));
  await assertFails(setDoc(doc(as("ada"), "dm_chats/ada_tobi/messages/n2"), chatMsg("tobi")));
  await assertFails(setDoc(doc(as("bob"), "dm_chats/ada_tobi/messages/n3"), chatMsg("bob")));
  await assertSucceeds(setDoc(doc(as("ada"), "dm_chats/ada_tobi/messages/n4"), chatMsg("ada", { kind: "snap", text: null, media: { path: "chats/ada_tobi/ada/s.jpg", url: "https://x" } })));
  await assertFails(setDoc(doc(as("ada"), "dm_chats/ada_tobi/messages/n5"), chatMsg("ada", { kind: "snap", media: { path: "chats/ada_tobi/tobi/s.jpg" } })));
  await assertFails(setDoc(doc(as("ada"), "dm_chats/ada_tobi/messages/n6"), chatMsg("ada", { expiresAt: null })));
});

test("reactions: only your own; no editing, saving or deleting from the app", async () => {
  await assertSucceeds(updateDoc(doc(as("ada"), "dm_chats/ada_tobi/messages/m1"), { reactions: { ada: "🔥" } }));
  await assertFails(updateDoc(doc(as("ada"), "dm_chats/ada_tobi/messages/m1"), { reactions: { ada: "🔥", tobi: "😂" } }));
  await assertFails(updateDoc(doc(as("ada"), "dm_chats/ada_tobi/messages/m1"), { text: "edited" }));
  await assertFails(updateDoc(doc(as("ada"), "dm_chats/ada_tobi/messages/m1"), { savedBy: ["ada"] }));
  await assertFails(deleteDoc(doc(as("tobi"), "dm_chats/ada_tobi/messages/m1")));
});

test("old chat data is private now", async () => {
  await assertSucceeds(getDoc(doc(as("ada"), "users/ada/chats/tobi/messages/old1")));
  await assertFails(getDoc(doc(as("bob"), "users/ada/chats/tobi/messages/old1")));
  await assertFails(getDoc(doc(as(null), "users/ada/chats/tobi/messages/old1")));
  await assertFails(getDoc(doc(as("ada"), "messages/old2")));
});

// --------------------------------------------------- Users and content
test("profiles are public; only you edit yours, and never your verified or creator status", async () => {
  await assertSucceeds(getDoc(doc(as(null), "users/ada")));
  await assertSucceeds(setDoc(doc(as("ada"), "users/ada"), { displayName: "Ada" }, { merge: true }));
  await assertFails(setDoc(doc(as("bob"), "users/ada"), { displayName: "Hacked" }, { merge: true }));
  await assertFails(setDoc(doc(as("ada"), "users/ada"), { isVerified: true }, { merge: true }));
  await assertFails(setDoc(doc(as("ada"), "users/ada"), { isCreator: true, creatorID: "fake" }, { merge: true }));
  await assertSucceeds(updateDoc(doc(as("bob"), "users/ada"), { views: increment(1) }));
  await assertFails(updateDoc(doc(as("bob"), "users/ada"), { views: 99999 }));
  await assertSucceeds(setDoc(doc(as("bob"), "users/ada/followers/bob"), {}));
  await assertFails(setDoc(doc(as("bob"), "users/ada/followers/eve"), {}));
});

test("creators edit and delete their own content; others can only nudge counters", async () => {
  await assertSucceeds(setDoc(doc(as("ada"), "music/s2"), { title: "Mine", artistId: "ada", ownerId: "ada" }));
  await assertFails(setDoc(doc(as("ada"), "music/s3"), { title: "Fake", artistId: "tobi" }));
  await assertSucceeds(updateDoc(doc(as("tobi"), "music/s1"), { title: "Renamed" }));
  await assertFails(updateDoc(doc(as("ada"), "music/s1"), { title: "Hijacked" }));
  await assertSucceeds(updateDoc(doc(as("ada"), "music/s1"), { plays: increment(1) }));
  await assertFails(updateDoc(doc(as("ada"), "music/s1"), { plays: 1000000 }));
  await assertFails(deleteDoc(doc(as("ada"), "music/s1")));
  await assertSucceeds(deleteDoc(doc(as("tobi"), "music/s1")));
  await assertSucceeds(setDoc(doc(as("ada"), "posts/p0/likes/ada"), {}), "likes still work");
  await assertSucceeds(updateDoc(doc(as("ada"), "posts/p0"), { likeCount: increment(1) }));
});

test("contributor profiles: owners edit details, never their status", async () => {
  await assertSucceeds(updateDoc(doc(as("tobi"), "contributors/c1"), { bio: "new bio" }));
  await assertFails(updateDoc(doc(as("tobi"), "contributors/c1"), { isVerified: true }));
  await assertFails(updateDoc(doc(as("ada"), "contributors/c1"), { bio: "hijack" }));
  await assertFails(setDoc(doc(as("ada"), "contributors/c2"), { userId: "ada", type: "Creator" }));
});

// ------------------------------------------------------ Notifications
test("notifications: only the server creates them; you read, mark read and delete your own", async () => {
  await assertSucceeds(getDoc(doc(as("ada"), "users/ada/notifications/n1")));
  await assertFails(getDoc(doc(as("bob"), "users/ada/notifications/n1")));
  await assertSucceeds(updateDoc(doc(as("ada"), "users/ada/notifications/n1"), { isRead: true }));
  await assertFails(updateDoc(doc(as("ada"), "users/ada/notifications/n1"), { title: "fake" }));
  await assertFails(setDoc(doc(as("bob"), "users/ada/notifications/spam"), { title: "Click here", isRead: false }));
  await assertFails(setDoc(doc(as("ada"), "users/ada/notifications/self"), { title: "x" }));
  await assertFails(setDoc(doc(as("bob"), "notifications/push"), { receiverId: "ada", title: "spam" }));
  await assertSucceeds(deleteDoc(doc(as("ada"), "users/ada/notifications/n1")));
});

test("usernames and onboarding status are server-only", async () => {
  await assertFails(setDoc(doc(as("ada"), "usernames/ada"), { uid: "ada" }));
  await assertFails(getDoc(doc(as("ada"), "usernames/tobi")));
  await assertFails(setDoc(doc(as("newbie"), "users/newbie"), { displayName: "N", onboarding: { completedAt: 1 } }));
  await assertSucceeds(setDoc(doc(as("newbie"), "users/newbie"), { displayName: "N" }));
});
