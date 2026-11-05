# Chat, media sharing, Creator Studio and posts

## What was wrong

| Area | Problem | Now |
| --- | --- | --- |
| Chat privacy | Every message was readable by anyone, through the open rules and a global `messages` copy. Anyone could write into anyone's chats | `dm_chats`: only the two members can read; messages are validated; the old copies are private to their owner or server-only |
| Chat logic | Three copies of each message written by the phone; no expiry, view-once, or streaks | One copy. The server keeps the summary, status, streaks and expiry |
| Storage | No `storage.rules` at all | Chat media is private to the chat; profile and content files are owner-only writes with type and size limits |
| Content | Anyone could edit or delete anyone's songs, posts, books and products | Owners create, edit and delete; others only nudge counters by one |
| Contributors | Registration ran in the app, so anyone could mark themselves verified | `contributorRegister` runs on the server, once per role, never verified by itself |
| Uploads | Separate mobile and web code everywhere, no common limits, files left behind | One uploader; files are removed when their content is deleted |
| Posts | Edit was "coming soon"; Share showed a fake "copied"; delete left files and wrong counts | Real edit, native share sheet, and delete that fixes counts and cleans up files |
| Profile photos | Uploads wrote `profileImageUrl`, but the app reads `profileImage` first, so old photos kept showing | Both fields are written; the sign-in photo updates; the old file is deleted |

## Mango Chat (`lib/Chat`, `functions/chat`)

The logic follows Snapchat closely:

- **Delete after viewing (default).** Leaving a chat marks what you saw as viewed; the scheduled cleanup (every 10 minutes) deletes it and its media. Each chat can instead use "24 hours after viewing" or "never" (`chatSetRetention`). Changing the setting posts a note in the chat.
- **Save in chat.** Press and hold a message, then Save. It's kept for both people until unsaved, and highlighted with a "Saved in chat" label.
- **Snaps** are photos and videos that open once (`chatOpenSnap`), with a countdown: 10 seconds for photos, the full length for videos. They can't be saved.
- **Streaks** grow once a day when both people Snap. ⏳ appears in the last 4 hours, and a missed day resets the streak.
- **Unsend.** Senders delete for both people; the chat shows "… deleted a chat".
- **Chat list status:**
  - icons: red for Snaps, purple for video Snaps, blue for chats; filled when new, outlined when delivered or opened;
  - labels: New Snap, New Chat, Delivered, Opened, Received, with a time and the 🔥 streak;
  - a camera button on each row to Snap back.
- **Inside a chat:**
  - messages sit under ME / NAME labels with a coloured side bar;
  - tap shows the time; press and hold for reactions, Save, Reply, Copy, Delete; swipe right to reply;
  - "typing…" and "in the chat" show live, and receipts show on your last message;
  - you can send voice notes, photos, videos and files.
- **Notifications** reuse the existing `notifications` pipeline.
- **Old chats:** `node functions/chat/scripts/migrate-legacy.js` (dry run, then `--apply`) copies them over with retention set to "keep".

## Media sharing (`lib/Media/compose`)

- **`MangoComposer.pick`** is used for chat (Snaps and media), posts, profile and banner pictures, contributor setup and every Creator Studio upload. It offers:
  - camera, gallery or files, then a preview;
  - for photos: 10 filters (Original, Vivid, Mango, Warm, Cool, Fade, Mono, Noir, Sepia, Lagos), brightness, contrast, saturation and warmth, crop shapes (1:1, 4:5, 16:9, 9:16), rotate and flip, and a caption you can drag;
  - photos render through Flutter, so the saved file matches the preview.
- **`MangoUploader`** is the single path to Storage:
  - folders: `users/{uid}/…`, `content/{uid}/…`, `chats/{chatId}/{uid}/…`;
  - photos are oriented and compressed to 2048 px;
  - size limits: images 25 MB, audio and documents 300 MB, other files 100 MB, video 2 GB;
  - progress, cancel, and retry with backoff;
  - every upload is owner-tagged.
- **`MangoVoiceRecorderButton`:**
  - hold to record, with a waveform and timer;
  - slide left to cancel, up to lock;
  - preview before sending;
  - AAC on phones, Opus on web;
  - double-tap starts recording for screen-reader users.

## Creator Studio (`lib/Contributors/studio`)

- **Entry:** the profile's Creator, Distributor and Vendor cards, and the Contributors page, open `StudioEntry`.
- **Setup** (3 steps): what you'll share, your profile (name, bio, categories, photo and banner), review. It's created on the server.
- **Dashboard:**
  - banner, avatar and verified badge, plus your item count, plays and views, and MangoCoin earned;
  - a tab per content type, where each item has Edit and Delete;
  - an Upload button and profile editing.
- **One editor** for songs, podcasts, films, books, products and vines:
  - required fields and validation;
  - file slots with previews, Replace, and per-file progress;
  - replaced files are deleted, and a failed save removes its own uploads.
- **Delete** asks first; the server then removes the content's files (`contentCleanup_*`). It never touches files in another user's folder.
- **Compatibility:** documents use the existing data model, so older uploads appear and can be edited too.

## Posts

- **The post box** (same API as before):
  - a character ring that turns amber and then red near the 280 limit;
  - one video or up to 10 photos through the composer; tap a photo to edit it again, drag to reorder, remove with the ×;
  - a link chip;
  - progress with cancel, and clear error messages.
- **The post card** keeps its signature segments and adds:
  - breathing room between segments, a soft shadow, a brand-tinted profile pill, rounded media;
  - double-tap to like with a heart burst;
  - 15 px text with #hashtags, @mentions and links highlighted, and "more" for long posts;
  - an entrance animation.
- **Owner actions:** Edit (text), Delete (counts fixed, files removed). Share opens the native share sheet, falling back to copying.

## Tests

| Where | What |
| --- | --- |
| `functions/test/chat.test.js` (8) | Opening, forged messages, retention modes, saving, snaps, streaks, unsend, migration |
| `functions/test/content.test.js` (3) | URL parsing, safe cleanup, contributor registration |
| `tests/firestore-rules` (+7 rules tests, 27 total, CI emulator) | Chat membership and message validation, reactions, old chat privacy, user profile protection, content ownership and counters, contributor status |

## Deploy together

The new Firestore and Storage rules lock down content, user and contributor documents. Deploy them in the same release as this app version: functions, then rules and indexes, then the app. Then run the chat migration.

Storage rules use `firestore.get` for chat media, so the first deploy will ask to grant Storage access to Firestore.

## Not done yet

- **Screenshot alerts.** Flutter has no built-in screenshot detection on every platform.
- **Video trimming.** Videos can be previewed and captioned, but not trimmed.
- **Group chats.** Space conversations still use their own screens.
- **Older upload pages.** The previous upload screens under `lib/Contributors/pages` still exist, but nothing in the app opens them any more. They can be removed after release.
