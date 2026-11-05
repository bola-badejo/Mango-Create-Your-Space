# Virtual Spaces

A Space is now a place you walk into. It shows:

- the owner's content and objects on a themed canvas;
- the people who are there now;
- a message wall, and a way to connect with the people there;
- live events with chat.

Owners arrange the room themselves and buy skins, icons and objects with MangoCoin.

## Who does what

| Action | Where it runs | Why |
| --- | --- | --- |
| Create a Space, reserve its @handle | `spaceCreate` (server) | Handles must be unique, the owner must be the real caller, and the starter world and items are granted atomically |
| Check a handle while typing | `spaceCheckHandle` | Live feedback in the wizard |
| Buy a skin, icon or object | `spaceBuyItem` | Payment (a MangoChain transfer to the treasury) and the item commit in one transaction. A repeated request returns the original receipt and never charges twice |
| Apply a skin or icon | `spaceApplyTheme` | Only owned or free items |
| Schedule, start, end an event | `spaceCreateEvent`, `spaceSetEventStatus` | Only editors; only in order (scheduled, then live, then ended) |
| Moderate wall and live chat | `spaceOnWallMessage`, `spaceOnEventChat` triggers | Removes forged authors, invalid text, and floods (more than 6 messages a minute) |
| Place, move, resize, remove objects | Firestore, guarded by rules | Editors only; decor must be owned; positions stay on the canvas |
| Presence (who is here) | Firestore, guarded by rules | Only your own entry, stamped with server time |
| Wall posts, RSVPs, live chat | Firestore, guarded by rules | Your own name only, server time, at most 500 characters; chat only while live |

## Visibility

| Setting | Who can see inside |
| --- | --- |
| Public | Everyone |
| Members | Anyone who joins (`subscribers/{uid}`) |
| Private | Only people the owner or editors add |

Space cards (title, description) stay discoverable as before. Older Spaces without a `visibility` field are treated as Public, or as Members if they were marked private.

## Mining

- Time spent in a Space opens a server-timed `space` session. The owner earns 90% of a visit's points and the visitor 10%.
- Content played while inside a Space credits the Space owner 10% (creator 70%, listener 20%).
- The ledger reads the Space owner from `ownerId`, or from `postCreator` for older Spaces.

## Catalog

`catalog.json` holds 33 items (8 skins, 10 icons, 15 objects); 7 are free and given to every new Space. The app bundles an identical copy at `asset/space_catalog.json`, and a test fails if the two differ. Prices are enforced only on the server.

To add an item, add it to both files (keep them identical), then deploy functions and ship the app.

## Tests

- `functions/test/spaces.test.js` (10 tests):
  - creation and handles;
  - atomic purchases, including failed payments and non-editors;
  - themes, the event lifecycle and moderation;
  - visit mining for the owner.
- `tests/firestore-rules/rules.test.js` (9 Space tests, run on the emulator in CI):
  - edit rights and server-only fields;
  - the member-count nudge and legacy creation;
  - object placement, private Spaces, wall and presence;
  - live chat only while live;
  - older Space features unchanged.

## Live audio and video

Live events stream audio and video on [LiveKit](https://livekit.io), either LiveKit Cloud or self-hosted. The app never connects to the media server on its own say-so. It asks `spaceLiveToken`, which issues a signed token only when:

- the event is **live** (not scheduled, not ended, not more than 30 minutes past its end time); and
- the caller may **enter the Space**: Public, or a member of a Members or Private Space, or an editor.

The token is valid for 2 hours and for that one room only (`space_{spaceId}_{eventId}`). It carries the caller's role:

| Role | Who | Can |
| --- | --- | --- |
| host | The event host and Space editors | Camera, microphone, screen share; room admin (mute or remove people) |
| speaker | People the host invited (up to 12) | Camera and microphone |
| listener | Everyone else | Watch and listen. Raise a hand (`attendees/{uid}.handRaised`) to ask to speak |

- **Inviting a speaker:** `spaceSetSpeaker` records the change on the event and applies it to the live room at once, so the person can unmute without reconnecting.
- **Ending an event:** this closes the media room for everyone.
- **Cameras and microphones** stay off until each person turns them on.

### Setting it up

1. Create a LiveKit project and copy its URL (`wss://…`), API key and API secret.
2. Store the credentials as secrets:
   ```
   firebase functions:secrets:set LIVEKIT_API_KEY
   firebase functions:secrets:set LIVEKIT_API_SECRET
   ```
3. Add these to `functions/.env`:
   ```
   LIVEKIT_ENABLED=true
   LIVEKIT_URL=wss://your-project.livekit.cloud
   ```
4. Deploy functions.

Until this is done, the app shows "Live audio and video aren't set up for this app yet" and live chat still works. Deploying without LiveKit needs no secrets.

### App

- `lib/Spaces/world/space_live_stage.dart` uses `livekit_client` 2.13.1. It provides:
  - the stage tiles, showing camera or avatar, a speaking ring and a mic state;
  - mic, camera and screen-share controls;
  - raise hand;
  - the host's raised-hands and speakers panel.
- Native permissions were added: Android camera, microphone, audio settings, network and Bluetooth; iOS camera, microphone, photo library and Bluetooth descriptions, plus background audio.
- `grpc` was raised to 5.2 so the app and LiveKit agree on `protobuf` 6. The app does not import grpc.

## Direct messages

Every person in the people list has a **Message** button, and every wall author's avatar opens **Message** and **Connect**. Message opens the existing one-to-one conversation in Chats (`ConversationChatPage`).

## Not included

- **Recording live events.** Use LiveKit Egress if you need recordings.
- **Handle release.** Deleting a Space does not free its handle yet.
- **The old SpaceLive audio rooms** (`lib/SpaceLive`, `lib/Server/server.js`) are deprecated. They use an unauthenticated signalling server; the Space event stage replaces them.
