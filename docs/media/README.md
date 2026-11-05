# Mango media: players, reader, lists and recommendations

## What changed and why

| Before | After |
| --- | --- |
| Three audio engines (`GlobalMusicController`, `MangoMusicController`, `AppAudioHandler`) that could play over each other | One audio engine. `MangoMusicController.playMusic` now routes into it |
| Podcasts opened the music player with a podcast id, which looked it up in `music` and failed | Podcasts play in the same engine, resume where you stopped, and skip 15 or 30 seconds |
| Shuffle reshuffled a list of "upcoming" tracks; no repeat-all or repeat-one; Previous only went back one index | A proper queue (below), with repeat off, all and one, and Previous that restarts after 3 seconds |
| Nothing was kept when the app closed | Queue, position, speed and "playing from" restore, paused, on the next launch |
| No video player; Space film cards did nothing | Mango video player, opened from film cards and from Spaces |
| A basic PDF view (an iframe on web) | Mango Reader |

## The queue (`lib/Media/core/play_queue.dart`)

Pure Dart, shared by every player and covered by `test/media/play_queue_test.dart` (13 tests, run in CI). It is ordered as history, then the current item, then upcoming:

- **Up next.** "Play next" goes first; "Add to queue" goes after other queued items. Both always play before the rest of the album, list or Space.
- **Context.** The album, list or Space content you started from.
- **Autoplay.** Recommendations that continue when the context ends.
- **Shuffle** covers every other item and never touches Up next. Turning it off resumes in order from the current item.
- **AI shuffle** applies the server's taste-based order, which:
  - keeps the current item first;
  - spreads creators apart;
  - mixes in about one recommendation every four items, labelled "AI pick".
- **Repeat:** off, all, or one. Repeat one only repeats when an item finishes by itself; pressing Next still moves on.
- **Queue editing:** reorder (drag, or the arrow buttons), remove (swipe, or the remove button), and jump to any item.

## Taste and recommendations (`functions/media/taste.js`)

- **Learning.** The app records start, complete and skip events (`mediaRecord`). An early skip counts more than a late one. Taste decays, so it follows what you listen to now.
- **Recommendations** (`mediaRecommend`) for songs, podcasts, films and books:
  - based on the genre or category and creator affinity in your taste, plus the item playing now;
  - just-played items rank lower and skipped items lower still;
  - no more than two in a row from the same creator.
- **AI shuffle** (`mediaSmartShuffle`): taste-weighted random order, with creators spread out and recommendations mixed in.
- **Privacy.** Profiles live in `media_taste/{uid}`. Only the server writes them, and only you can read yours.
- **Tests.** `functions/test/media.test.js` has 6 tests.

## Players

**Music and podcasts** (`GlobalMusicController`, `lib/Media/ui/queue_sheet.dart`):
- **Full player:**
  - labelled controls with 48 dp targets, and a play button that says "Play" or "Pause" correctly;
  - shuffle that cycles off, shuffle, then AI shuffle;
  - repeat, "Playing from…", and a Queue button.
- **Queue sheet:**
  - Up next, with drag to reorder and swipe to remove (both with button alternatives);
  - "Because you played…" recommendations with Play next and Add to queue;
  - speed from 0.75x to 2x;
  - a sleep timer (15, 30 or 60 minutes, or end of track);
  - Add to a list.
- **Mining.** Playing opens a server-timed session (see MangoChain). Anything played inside a Space credits its owner.

**Video** (`lib/Media/video/mango_video_player.dart`):
- **Controls:**
  - resume on any device (with a "Start over" option);
  - double-tap to seek ±10 s with a ripple, plus ±10 s buttons;
  - speed from 0.5x to 2x, mute, and fullscreen with immersive landscape.
- **Keyboard:** Space or K plays and pauses; arrows or J/L seek; F toggles fullscreen; M mutes; Esc exits fullscreen.
- **Controls hide after 3 seconds.** They stay visible while paused and when a screen reader is on.
- **When a film ends:** Replay, plus an Up Next row of recommendations with an 8-second countdown that you can cancel. There's no countdown under reduced motion.
- **Music pauses automatically** when a video starts.

**Mango Reader** (`lib/Media/reader/mango_reader.dart`):
- **Themes:** Paper, Sepia, Night. The page itself is tinted, not just the interface.
- **Focus mode:** hides everything but the page; tap to bring the controls back.
- **Reading guide:** dims the page around a band you can drag, or move with arrow buttons.
- **Read aloud:** uses the device voice, at slow, normal or fast speed. It turns pages by itself, skips image-only pages, and has a sleep timer.
- **Navigation:** contents (the PDF's outline), search with next and previous match, bookmarks, a page slider, and single-page or continuous scrolling.
- **Progress:** resumes on any device and shows the time left, based on your own reading pace.
- **Fallback:** if a book can't load on web, an "Open in browser" button is offered.

## Content lists (`lib/Media/lists/`)

- **What a list is:** a playlist that can mix songs, podcast episodes, films and books, up to 200 items.
- **Ownership:** a list belongs to you, or to a Space. Space editors manage that Space's lists.
- **Adding items:** "Add to a list" appears in the queue sheet, track actions, the video player and the reader.
- **In Spaces:** in edit mode, open Add, then Lists. Create a list and place it in the room; visitors tap it to open.
- **List page:** Play all and Shuffle (the audio items, with "Playing from" the list or Space); tap any item to open it in the right player; editors can reorder and remove.
- **Rules:** owners only, editors for Space lists, size-capped, and private lists or lists in private Spaces stay hidden. Covered by the CI rules tests.

## State and "playing from"

- **`PlaySource`** records where playback started: a Space, a list, home, a profile, search or recommendations.
- **Survives closing the app.** The source is stored with the queue and restored with it.
- **Tappable.** The queue sheet shows it; for a Space, tapping returns you there.
- **Progress** for podcasts, films and books is in `media_progress/{uid}/items`, private to you and synced across devices. The music queue is kept on the device.

## Setup

- **New app dependencies:**
  - `video_player`, `syncfusion_flutter_pdf`: already resolved indirectly, now declared;
  - `flutter_tts` 4.2.
- **Web:** the pdf.js scripts Syncfusion requires were added to `web/index.html`.
- **Server:** deploy functions (`mediaRecord`, `mediaRecommend`, `mediaSmartShuffle`), rules and indexes.

## Not done yet

- **Lock-screen and notification controls.** The engine uses audioplayers, which has no media session. The project already includes `audio_service` and `just_audio`; moving the engine's backend to them is the next step. The queue logic is player-independent, so this is a contained change.
- **Captions.** Films have `subtitles` fields, but no caption files are uploaded yet.
- **Offline downloads.**
- **A `/movie-home` route.** Space screens link to it, but it doesn't exist.
- **Crediting book authors.** Books do not store an uploader id, so reading can't credit authors in MangoChain.
