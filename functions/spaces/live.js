"use strict";
// Live audio and video for Space events, on LiveKit.
//
// The app never connects to a media server on its own say-so: it asks for
// a token, and the server issues one only if the event is live right now
// and the caller is allowed into the Space. What a person may do is written
// into the signed token itself:
//   host      the event host and Space editors: camera, microphone, screen
//             share, and room admin (mute or remove participants)
//   speaker   people the host invited up: camera and microphone
//   listener  everyone else: watch and listen only
const { AccessToken, RoomServiceClient, TrackSource } = require("livekit-server-sdk");
const { LedgerError } = require("../ledger/service");
const { isEditor } = require("./service");

const TOKEN_TTL_SECONDS = 2 * 60 * 60;
const MAX_SPEAKERS = 12;
const LATE_GRACE_MS = 30 * 60 * 1000;

const fail = (code, message) => { throw new LedgerError(code, message); };

const roomName = (spaceId, eventId) => `space_${spaceId}_${eventId}`;

function grantFor(role, room) {
  const base = { roomJoin: true, room, canSubscribe: true, canUpdateOwnMetadata: false };
  if (role === "host") {
    return { ...base, roomAdmin: true, canPublish: true, canPublishData: true,
      canPublishSources: [TrackSource.CAMERA, TrackSource.MICROPHONE, TrackSource.SCREEN_SHARE, TrackSource.SCREEN_SHARE_AUDIO] };
  }
  if (role === "speaker") {
    return { ...base, canPublish: true, canPublishData: true, canPublishSources: [TrackSource.CAMERA, TrackSource.MICROPHONE] };
  }
  return { ...base, canPublish: false, canPublishData: false };
}

class SpaceLive {
  /**
   * @param {object} deps
   * @param {object} deps.store     MemoryStore or FirestoreStore
   * @param {{url:string, apiKey:string, apiSecret:string}|null} deps.config
   * @param {object} [deps.rooms]   RoomServiceClient-like (for tests)
   */
  constructor({ store, config, rooms }) {
    this.store = store;
    this.config = config;
    this.rooms = rooms || (config ? new RoomServiceClient(config.url.replace(/^wss:/, "https:").replace(/^ws:/, "http:"), config.apiKey, config.apiSecret) : null);
  }

  _requireConfig() {
    if (!this.config || !this.config.url || !this.config.apiKey || !this.config.apiSecret) {
      fail("failed-precondition", "Live audio and video aren't set up for this app yet.");
    }
  }

  async _canEnter(space, spaceId, uid) {
    if (isEditor(space, uid)) return true;
    const visibility = space.visibility || (space.isPrivate ? "members" : "public");
    if (visibility === "public") return true;
    return !!(await this.store.get(`spaces/${spaceId}/subscribers/${uid}`));
  }

  /** Issues a LiveKit token for a live event, with the caller's role built in. */
  async token(uid, { spaceId, eventId, name } = {}, now) {
    this._requireConfig();
    if (!uid) fail("unauthenticated", "Sign in to join.");
    const space = await this.store.get(`spaces/${spaceId}`);
    if (!space) fail("not-found", "That Space doesn't exist.");
    const event = await this.store.get(`spaces/${spaceId}/events/${eventId}`);
    if (!event) fail("not-found", "That event doesn't exist.");
    if (event.status !== "live") fail("failed-precondition", event.status === "ended" ? "This event has ended." : "This event isn't live yet.");
    if (now > event.endsAt + LATE_GRACE_MS) fail("failed-precondition", "This event has run past its end time.");
    if (!(await this._canEnter(space, spaceId, uid))) fail("permission-denied", "Join this Space to watch its live events.");

    const role = event.hostId === uid || isEditor(space, uid) ? "host"
      : (event.speakers || []).includes(uid) ? "speaker" : "listener";
    const room = roomName(spaceId, eventId);
    const displayName = typeof name === "string" && name.trim() ? name.trim().slice(0, 60) : "Guest";
    const at = new AccessToken(this.config.apiKey, this.config.apiSecret, {
      identity: uid,
      name: displayName,
      ttl: TOKEN_TTL_SECONDS,
      metadata: JSON.stringify({ role }),
    });
    at.addGrant(grantFor(role, room));
    return {
      url: this.config.url,
      token: await at.toJwt(),
      room,
      role,
      canPublish: role !== "listener",
      expiresAt: now + TOKEN_TTL_SECONDS * 1000,
    };
  }

  /** Host invites someone up to speak, or moves them back to listening. */
  async setSpeaker(uid, { spaceId, eventId, userId, speaker } = {}) {
    const space = await this.store.get(`spaces/${spaceId}`);
    if (!space) fail("not-found", "That Space doesn't exist.");
    const path = `spaces/${spaceId}/events/${eventId}`;
    const result = await this.store.runTransaction(async (tx) => {
      const event = await tx.get(path);
      if (!event) fail("not-found", "That event doesn't exist.");
      if (event.hostId !== uid && !isEditor(space, uid)) fail("permission-denied", "Only the host can choose speakers.");
      if (typeof userId !== "string" || !userId) fail("invalid-argument", "Choose who to invite.");
      const speakers = new Set(event.speakers || []);
      if (speaker) {
        if (!speakers.has(userId) && speakers.size >= MAX_SPEAKERS) fail("resource-exhausted", `Up to ${MAX_SPEAKERS} speakers at once.`);
        speakers.add(userId);
      } else {
        speakers.delete(userId);
      }
      tx.set(path, { ...event, speakers: [...speakers] });
      return { userId, speaker: !!speaker, speakers: [...speakers] };
    });
    // Apply immediately in the live room; their next token carries it too.
    if (this.rooms) {
      try {
        await this.rooms.updateParticipant(roomName(spaceId, eventId), userId, undefined, {
          canSubscribe: true,
          canPublish: !!speaker,
          canPublishData: !!speaker,
          canPublishSources: speaker ? [TrackSource.CAMERA, TrackSource.MICROPHONE] : [],
        });
      } catch {
        // Not in the room right now; the permission applies when they join.
      }
    }
    return result;
  }

  /** Closes the media room for everyone (called when an event ends). */
  async endRoom(spaceId, eventId) {
    if (!this.rooms) return { closed: false };
    try {
      await this.rooms.deleteRoom(roomName(spaceId, eventId));
      return { closed: true };
    } catch {
      return { closed: false };
    }
  }
}

module.exports = { SpaceLive, roomName, grantFor, MAX_SPEAKERS, TOKEN_TTL_SECONDS };
