# Mango design system: phase 1–3 implementation notes

Branch: `design-system-foundation`, based on the single commit of `main` reviewed in November 2026.

## 1. Summary

This change adds the design system foundation, a first set of shared components and an adaptive navigation shell. It turns the new theme on app-wide behind one flag. No business logic, controllers, routes, Firebase calls or state management were changed.

The biggest user-facing change is navigation. The old bar was icon-only, auto-hid into 8 × 8 px dots after 5 seconds, and switched tabs by horizontal swipe. It is replaced with a labelled bottom bar on mobile, a navigation rail on tablets and side navigation on desktop.

## 2. Files

**New**

| File | Purpose |
| --- | --- |
| `lib/Core/theme/mango_tokens.dart` | Spacing, radius, sizes, motion tokens |
| `lib/Core/theme/mango_colors.dart` | Semantic colours (light and dark) as a `ThemeExtension` |
| `lib/Core/theme/mango_typography.dart` | Poppins type scale mapped to Material `TextTheme` |
| `lib/Core/theme/mango_theme.dart` | `ThemeData` builder and component themes |
| `lib/Core/theme/mango_context.dart` | `context.colors`, `context.type` |
| `lib/Core/responsive/breakpoints.dart` | Device classes (320 / 375 / 768 / 1024 / 1400) |
| `lib/Core/responsive/responsive_layout.dart` | `MangoResponsiveBuilder`, `MangoContentWidth` |
| `lib/Core/accessibility/mango_motion.dart` | Reduced-motion helpers, polite announcements |
| `lib/Core/design_system/buttons/mango_button.dart` | `MangoButton`, `MangoIconButton` |
| `lib/Core/design_system/inputs/mango_text_field.dart` | `MangoTextField` |
| `lib/Core/design_system/feedback/mango_state_view.dart` | Empty, error, offline, permission-denied states |
| `lib/Core/design_system/feedback/mango_skeleton.dart` | `MangoSkeleton`, `MangoLoadingRegion` |
| `lib/Core/design_system/feedback/mango_toast.dart` | `MangoToast` |
| `lib/Core/design_system/navigation/mango_adaptive_shell.dart` | Adaptive navigation shell |
| `asset/fonts/Poppins-{Regular,Medium,SemiBold}.ttf`, `OFL-Poppins.txt` | Bundled fonts and licence (from google/fonts on GitHub) |
| `test/design_system/*.dart` | Contrast, button and navigation tests |
| `tool/check_styling.sh` | CI guard against new hard-coded styling |

**Modified**

| File | Change |
| --- | --- |
| `lib/Home/home.dart` | `MangoHome` now uses `MangoAdaptiveShell`; same five pages, same order, Home still the default |
| `lib/Utils/theme.dart` | `AppThemes.lightTheme` / `darkTheme` return the Mango theme when `kUseMangoDesignSystem` is true |
| `pubspec.yaml` | Declares the Poppins font family |
| `lib/main.dart`, `lib/splash/settings.dart`, `lib/SpaceLive/space_live_sessions_model.dart`, `lib/Home/pages/post_detail_screen.dart`, `lib/Home/post_creation_box.dart` | Import paths corrected to match folder casing (`core/` → `Core/`, `utils/` → `Utils/`, `app/` → `App/`, `models/` → `Models/`, `home/` → `Home/`). These imports fail on case-sensitive file systems such as Linux CI |

## 3. Responsive behaviour

| Width (logical px) | Navigation | Notes |
| --- | --- | --- |
| 320–767 | Bottom `NavigationBar`, labels always shown, mini player above it | Tested at 320 for overflow in `adaptive_shell_test.dart` |
| 768–1023 | `NavigationRail` with labels | Mini player docks at the bottom of the content column |
| 1024+ | Extended `NavigationRail` (240 px) | Content widths are capped per screen with `MangoContentWidth` (feed 640, reading 720, grids 1200) |

Breakpoints follow the responsive brief. They replace the 600/840/1200 values in the earlier design system specification, which has been updated to match.

## 4. Accessibility implementation

- Every destination has a visible text label and an outline/filled icon pair, so selection is shown by shape and weight, not only colour.
- Off-stage tabs are excluded from focus traversal and the semantics tree, so keyboard and screen-reader users stay in the visible tab.
- `MangoButton` exposes button role, enabled state and a busy label ("Publish, loading"), and announces success.
- `MangoIconButton` cannot be built without a `semanticLabel`; toggles expose their state.
- `MangoTextField` keeps a persistent label, shows "(required)" as text, and links errors to the field.
- `MangoStateView` errors are live regions; skeletons are silent; `MangoLoadingRegion` announces loading once.
- The theme pads controls to 48 dp touch targets (`MaterialTapTargetSize.padded`).
- Reduced motion: `MangoMotion` shortens transitions to a 100 ms fade and stops the skeleton shimmer.

## 5. Semantic decisions

Flutter builds its own semantics tree, which Flutter web maps to ARIA. Native Material widgets (`NavigationBar`, `NavigationRail`, `FilledButton`, `TextFormField`) already expose correct roles and selected states, so custom `Semantics` is added only where they fall short: busy and success labels on buttons, toggled state on icon buttons, the "Main navigation" container on wide screens, and live regions for errors.

## 6. Keyboard interaction

- Tab and Shift+Tab move through navigation destinations and page content; off-stage tabs are skipped.
- Enter or Space activates a destination or button.
- Arrow keys move within the navigation rail's destinations (Material default).
- Escape closes dialogs and sheets (Flutter `ModalRoute` default; unchanged).
- Android system back on any tab other than Home returns to Home, then exits.

## 7. Micro-interactions

| Interaction | Duration | Curve | Reduced motion |
| --- | --- | --- | --- |
| Button press overlay | Material default (instant) | — | Unchanged |
| Button label ↔ spinner ↔ check | 150 ms | Switcher default | 100 ms |
| Button success hold | 600 ms | — | Unchanged |
| Tab content fade-in | 200 ms | `standard` | 100 ms |
| Navigation indicator | 200 ms | Material default | 100 ms |
| Skeleton shimmer | 1,200 ms loop | Linear | Static |

`MangoMotionTokens.moderate` is now 250 ms (was 300 ms in the specification) to keep sheets and menus inside the brief's 200–280 ms range.

## 8. Performance

- Tabs are built lazily on first visit, then kept, instead of the previous `PageView` keeping all five alive once visited. Off-stage tabs have tickers disabled (`TickerMode`), so their animations pause.
- The 5-second auto-hide timer and its `AnimationController` are removed.
- Fonts are bundled, removing the runtime font fetch for the new theme.
- `MangoBreakpoints.of` uses `MediaQuery.sizeOf`, which avoids rebuilds on keyboard insets.

## 9. Testing performed

**No Dart or Flutter tooling was available in the environment where this change was written.** The code has **not** been compiled, analysed or run, and none of the tests below have been executed. Treat every file as a reviewed draft until `flutter analyze` and `flutter test` pass locally.

What was checked:

- Every colour pairing asserted in `contrast_test.dart` was computed with the WCAG 2.x formula in Python and passes (lowest: dark tertiary text on the raised surface, 4.51:1).
- `pubspec.yaml` parses as valid YAML and declares the font family with weights 400, 500 and 600.
- `tool/check_styling.sh` passes `bash -n`.
- Import paths changed for casing were checked against the folders on disk.

Run locally:

```
flutter pub get
flutter analyze lib/Core lib/Home/home.dart test/design_system
flutter test test/design_system
```

Then check manually: sign in, switch all five tabs on a phone, a tablet and a desktop browser width; play a track and confirm the mini player stays visible; use Android back from each tab; walk the bar with TalkBack and VoiceOver.

## 10. Known limitations

- **Mixed styling until migration.** Screens still contain about 6,700 hard-coded colour references. With the flag on, Material widgets pick up green, Poppins and new shapes, but hard-coded orange, black and white remain where screens set them. Migrate screen by screen, or set `kUseMangoDesignSystem = false` until a feature is ready.
- **Brand direction.** Green replaces the current orange. The logo assets are orange-toned; confirm the brand change before release.
- **Navigation chrome.** Pages previously drew under a floating bar (`extendBody: true`). Some pages may have bottom padding sized for that bar and will now show extra space.
- **Profile tab.** `KeepAliveProfilePage` still reads `FirebaseAuth.instance.currentUser!`, as before; it is now built only when first opened.
- **The existing `test/widget_test.dart`** is Flutter's default counter test and does not match the app. It was left unchanged; it will fail as it did before.
- **`pubspec.yaml` structure.** `cupertino_icons`, `http`, `path_provider` and `flutter_lints` sit under the wrong keys, so lints are not active. Not changed here, because moving them changes dependency resolution; fix in a separate change.
- **`SemanticsService.announce`** is deprecated in newer Flutter releases in favour of view-aware announcements; the call carries an ignore comment and should be updated when the SDK is upgraded.

## 11. Remaining work

1. Run analysis and tests; fix anything they report.
2. Migrate screens feature by feature, starting with the dashboard, post card and chat (largest files), using `context.colors` and `context.type`.
3. Add golden tests per component (light, dark, 200% text, RTL).
4. Build the remaining library: sheets, dialogs, tabs, carousel, media player controls, post shell, product card, chat bubble.
5. Add the styling guard to CI.
6. Remove `glass` and `glassmorphism` packages once no screen uses them.

---

# Phase 4: app-wide visual codemod

A scripted pass restyled every screen outside `lib/Core/` in one change, using only substitutions that keep the code valid Dart.

## What changed (161 files)

| Change | Count | Why it is safe |
| --- | ---: | --- |
| `Colors.orange`, `orangeAccent`, `deepOrange`, `green`, `greenAccent` and their shades → `MangoPalette.green*` | 714 | Palette entries are `const`, so they work inside `const` widget trees; shades map to the matching step of the green scale |
| `Colors.grey` and every shade → green-tinted `MangoPalette.grey*` | 2,279 | Each tinted grey matches the relative luminance of the Material grey it replaces, so contrast is unchanged in both themes |
| `Colors.black` → `MangoPalette.black` (`#0B0F0C`) | 931 | Same role, slightly warmer near-black; alpha blacks (`black87`, `black54`) untouched |
| Brand-orange and off-black hex literals → brand green and tinted surfaces | 83 | Only the hex value inside `Color(...)` changes |
| `GoogleFonts.montserrat(...)` / `roboto(...)` → `TextStyle(fontFamily: 'Poppins', ...)` | 14 | Same named parameters |
| Font sizes below 12 raised to 12 | 641 | Literal-only change |
| `BorderRadius.circular(n)` for n < 25 → `MangoRadius` tokens | all | Values 2–4.5 → xs (4), 5–10 → sm (8), 12–16 → md (12), 18–24 → lg (20); 25 and above (pills, circles) unchanged |
| `import 'package:mango/Core/theme/mango_palette.dart';` added | 155 files | Inserted after the last import |

Semantic colours (red, blue, purple, teal, amber) were deliberately left alone, because they may carry meaning such as errors, links or ratings.

## Verification performed

- Every Dart file in `lib/` and `test/` (325) was parsed with the tree-sitter Dart grammar before and after the codemod. No file gained a syntax error; the one pre-existing parse failure (`lib/Notifications/notifications_controller.dart`) is unchanged.
- Every file using `MangoPalette` or `MangoRadius` was checked for the import.
- No `MaterialColor` or swatch-typed parameter receives a replaced colour.

These checks catch syntax and import mistakes, **not type errors**. `flutter analyze` must still be run.

## Visual risks to check by eye

- **Text overflow.** 641 sizes grew to 12, including badges and chips that were sized for 8–10. Look for clipped or wrapped labels in the dashboard, post cards, music pod and store.
- **Accent on dark screens.** Orange on black was very bright; `green500` on black measures 4.92:1, which passes AA but reads calmer.
- **Hard-coded orange imagery.** The logo and illustration assets are still orange.

## Not yet changed

- 18 `BackdropFilter` blurs and 82 `LinearGradient`s (structural edits, best done per screen).
- About 2,800 remaining `Colors.*` references, mostly `Colors.white`, `transparent` and semantic colours, plus the 1,756 manual dark-mode branches. These move to `context.colors` during per-screen migration.

---

# Phase 5: accessibility, micro-interactions, transitions, loading and feedback

## New components (`lib/Core/design_system/`, one import: `mango_ui.dart`)

| Component | What it does |
| --- | --- |
| `MangoPressable` | Drop-in for a tap-only `GestureDetector`. Adds press feedback (scale 0.94 on small targets, 0.98 on medium, an opacity dip on large ones; opacity only under reduced motion), button semantics, keyboard focus with a visible ring, Enter/Space activation, a pointer cursor on web, and Material's standard tap and long-press feedback |
| `MangoReactionButton` | Like, repost, comment, share: icon "pop" (280 ms) when activated, cross-fading icon and count, light haptic for likes, spoken state ("Liked, 13 likes"), 44 × 44 touch area |
| `MangoShimmer` | Drop-in for `Shimmer.fromColors`; stops under reduced motion; hidden from screen readers |
| `MangoAppear` | Fade and 8 px rise for content entering, with a 0 / 40 / 80 ms stagger capped at three items |
| `MangoStateSwitcher` | Cross-fade between loading, empty, error and content |
| `MangoPageTransitionsBuilder` | Platform transitions for `MaterialPageRoute`, replaced by a fade under reduced motion |

## App-wide changes

| Change | Reach | Notes |
| --- | ---: | --- |
| `GestureDetector` → `MangoPressable` | 182 | Only calls whose arguments are `child`, `onTap`, `onLongPress`, `onDoubleTap`, `key`, `behavior`. Skipped: 14 with an empty `onTap: () {}` (left as-is so they do not pose as working buttons), 2 screen-level wrappers, 6 with drag or pan gestures |
| Labels on icon-only tap targets | 10 | From a fixed icon-to-label dictionary |
| `IconButton` tooltips (which are also their accessible names) | 135 | 25 skipped where the icon's meaning was not certain (for example star, visibility, mic) |
| `semanticsLabel: 'Loading'` on progress indicators | 158 | Commented-out code untouched |
| `Shimmer.fromColors` → `MangoShimmer` | 20 | Plus the shared `ShimmerWidget`, which now uses theme colours, so dark screens get dark skeletons |
| Feedback messages (`UtilsService.showSnackbar`) | 355 calls | Same signature. Tone is inferred from the caller's colour and title, then shown with an icon, tinted container and border, never colour alone. Errors stay at least 6 seconds; a new message replaces the old one instead of queueing |
| Post-card actions | 4 per post | Comment, repost, like and share use `MangoReactionButton` |
| Screen transitions (GetX) | All routes | Native Material on Android (was the iOS slide), Cupertino on iOS, fade on web; 250 ms; 150 ms fade under reduced motion |
| Screen transitions (`MaterialPageRoute`) | 41 pushes | Theme `pageTransitionsTheme` |
| Web screen readers | Whole app | `SemanticsBinding.instance.ensureSemantics()` on web, so NVDA, JAWS and VoiceOver work without the hidden "Enable accessibility" button |

## Verification performed

- All 331 Dart files re-parsed with tree-sitter after the final run: no new syntax errors (one pre-existing failure unchanged).
- Every file using the new components imports `mango_ui.dart`.
- An earlier run matched a spinner inside a commented-out line and paired its bracket with real code, breaking two files. The call finder was fixed to ignore comments and strings, every file was restored, and all edits were replayed from a clean state.

Still unverified: types, runtime behaviour and visual result. Run `flutter analyze` and test on devices.

## Behaviour to check on device

- **Layout height.** Post action buttons now have a 44 px touch area, so the action row is taller.
- **Press feedback on large cards.** Cards over 400 px dim slightly instead of scaling; confirm this feels right.
- **Tap sound and vibration.** `MangoPressable` uses Material's standard feedback (the same as `InkWell`), which can play a click sound on Android.
- **Screen readers.** Many custom tiles now read as one button with their text as the name, instead of separate fragments. Walk the dashboard and store with TalkBack and VoiceOver.
- **Web performance.** Always-on semantics adds some cost on the web build; measure on a mid-range laptop.

## Not covered

- The 14 empty tap handlers need a decision: wire them up or remove them.
- 25 icon buttons need labels chosen by someone who knows what they do.
- Page-level spinners (`Center(child: CircularProgressIndicator())`) are labelled but not yet replaced by skeletons matching each layout.
- Images from the network have no alt text; that needs data from creators at upload time.
- `MangoAppear` and `MangoStateSwitcher` are available but not yet applied to lists and screens; that is per-screen work.

---

# Phase 6: build readiness, CI and verification tools

## Why the app could not be compiled here

The environment this work was done in blocks `storage.googleapis.com` (Flutter SDK downloads) and `pub.dev` (every Dart package). Neither a compile nor `flutter pub get` is possible there, so compiling and testing happen in GitHub Actions, and a preflight checker catches what it can without the SDK.

## New tools

| Tool | What it does | Run |
| --- | --- | --- |
| `.github/workflows/flutter-ci.yml` | On every push and pull request: preflight → `pub get` → analyze (errors fail the whole app; warnings also fail the design-system code) → all tests → web release build → Android debug APK. iOS build on demand. Builds are downloadable from the run page | Automatic; or Actions → Flutter CI → Run workflow |
| `tool/preflight.py` | Six checks that need no Flutter SDK: syntax, exact-case import resolution, browser-only libraries reachable on mobile, undeclared packages, missing assets, and design-token names | `python3 tool/preflight.py` |
| `tool/verify.sh` | The CI checks on your machine; `--build` also builds web and Android | `bash tool/verify.sh` |

## Build breakers found and fixed

These were in the code before any design-system work and would stop CI.

| Problem | Effect | Fix |
| --- | --- | --- |
| `notifications_controller.dart` line 12: `as web` placed before the conditional `if (...)` | Syntax error; no platform can compile the app | Conditional import of a web implementation and a stub |
| `notifications_controller.dart` and `Profile/pages/settings.dart` import `dart:js_interop` / `package:web` unconditionally | Android and iOS builds fail | Web code moved to `web_notifications.dart` behind a conditional import; an unused `JSHelper` extension and its imports removed from settings |
| Web permission compared a JavaScript string with a Dart string | Always false, so granted permission was never recognised | The web implementation converts to a Dart string first |
| Four more imports with wrong letter case (`Splash/` → `splash/`, `upload_Movie` → `upload_movie`, `upload_Product` → `upload_product`) | Fail on Linux CI and case-sensitive builds | Corrected |
| `flutter_lints` mis-indented under `flutter_launcher_icons` | `analysis_options.yaml` include cannot be found | Moved into `dev_dependencies` |
| `test/widget_test.dart` was Flutter's counter template | Fails against this app | Replaced with theme and component smoke tests |

## Before the first CI run

1. **Add the `.env` contents as a repository secret** named `DOTENV` (Settings → Secrets and variables → Actions). Without it CI writes an empty `.env`, which compiles and tests but gives builds no runtime configuration.
2. Push the branch. Open the Actions tab to see each step.

## Expect on the first run

- **Analyzer errors in existing screens are possible.** The preflight cannot check types. If the whole-app analyze step fails, its log lists each error with a file and line; those are the remaining fixes.
- **Many infos and warnings.** `flutter_lints` is now active for the first time. They are reported but do not fail the build.
- **Remaining preflight warnings (9):** eight packages are imported directly but only installed through other packages (`bloc`, `cross_file`, `image`, `path`, `path_provider`, `uuid`, `video_player`, `web`). They compile; declaring them in `pubspec.yaml` is recommended. The ninth is the local `.env`.

---

# Phase 7: MangoChain (secure MangoCoin ledger)

Full design and deployment guide: `functions/ledger/README.md`.

## What was wrong

- Signatures were not signatures: verification only passed if the "signature" equalled the private key.
- "Mining" was two leading zeros of SHA-256, and block signatures were a timestamp plus a random number.
- The phone calculated its own rewards and wrote its own balance. With the open rules, any signed-in user could set any balance.
- App startup mined a demo block (`Telli` → `Gun`, reward to `Miner1`) on the main thread at every launch.
- Content mining was never registered, so it never ran. Wallet "claim" buttons paid out for sharing, reading and watching without anything happening.

## What replaced it

| Part | Files |
| --- | --- |
| Ledger core: chain rules, Merkle trees, Ed25519, policy, service | `functions/ledger/*.js` |
| Cloud Functions: 6 callables, 3 activity triggers, block producer, audit, optional anchoring | `functions/ledger/functions.js`, exported from `functions/index.js` |
| Anchor contract | `functions/ledger/contracts/MangoChainAnchor.sol` |
| Operator scripts: key generation, audit and export, legacy migration | `functions/ledger/scripts/` |
| Security rules: ledger and old wallet collections are server-only; everything else unchanged | `firestore.rules` (now deployed via `firebase.json`) |
| Ledger indexes, added to the existing 10 | `firestore.indexes.json` |
| App client: callable client and server-timed session tracker | `lib/Wallet/ledger/` |
| `WalletService` and `ContentMiningService` on MangoChain, same public API | `lib/Wallet/services/wallet_services.dart`, `lib/Wallet/data/content_mining_services.dart` |
| Listening sessions on play, pause, resume, finish and stop; podcast and film sessions on play | `global_music_controller.dart`, `mango_podcasts.dart`, `mango_movie_manger.dart` |
| Startup demo chain removed; old Dart chain files marked deprecated | `lib/main.dart`, `lib/Wallet/data/{blockchain,block,transaction_signer}.dart` |

## Verification performed

- **36 of 36 Node tests pass** (`cd functions && npm test`):
  - chain rules and tamper detection;
  - Merkle proofs and Ed25519;
  - emission and supply caps;
  - all anti-abuse rules and server-timed sessions;
  - transfers, sealing, and multi-block epoch rewards for 3,000 accounts;
  - migration, the offline verifier, and the anchor contract on a local EVM (Ganache).
- All 11 functions load and register with the real Firebase SDK (firebase-functions 6.6, firebase-admin 13.10).
- The anchor contract compiles with solc 0.8.26, with no warnings.
- All 335 Dart files parse with tree-sitter, and the preflight reports 0 errors.

## Not verified here

- **Firestore rules:** the tests are written (`tests/firestore-rules`) but need the emulator; CI job `firestore-rules` runs them.
- **Dart types:** checked by CI's `flutter analyze`.
- **End-to-end on a device:** needs a deployed project.

## Deploy together

The new rules block the old client's balance writes. Deploy indexes, functions, rules and the app update as one release, following `functions/ledger/README.md`.

---

# Phase 8: virtual Spaces

Design and security model: `functions/spaces/README.md`.

| Part | Files |
| --- | --- |
| Server logic | `functions/spaces/service.js`, `functions/spaces/functions.js` (6 callables, 2 moderation triggers) |
| Catalog | `functions/spaces/catalog.json`, mirrored at `asset/space_catalog.json` |
| Atomic purchase hooks in the ledger | `functions/ledger/service.js` (`transfer(..., hooks)`) |
| Rules | `firestore.rules`: Spaces carved out of the default rule, with strict rules for world data |
| App | `lib/Spaces/world/`: catalog renderer, data service, creation wizard, world screen, shop, event room |
| Wiring | "Create a Space" on the Spaces home (there was no entry point before); "Enter Space" on Space details; the `newSpace` route opens the wizard |

## Fixed on the way

- **Space owner field.** The ledger did not recognise the owner (stored as `postCreator`), so Space owners earned nothing from visits.
- **Space edit rights.** Any signed-in user could edit or delete any Space document; now only owners and editors can, apart from the ±1 member count.
- **Space creation entry point.** There was no button to create a Space.

## Verification performed

- 46 of 46 backend tests pass (10 new for Spaces). All 8 Space functions load with the real Firebase SDK.
- 341 Dart files parse; the preflight reports 0 errors.
- Rules tests are written and run in CI's emulator job.


---

# Phase 9: live audio and video, direct messages

See `functions/spaces/README.md`, sections "Live audio and video" and "Direct messages".

| Part | Files |
| --- | --- |
| Token issuance, speaker management, room shutdown | `functions/spaces/live.js`; `spaceLiveToken`, `spaceSetSpeaker` and `spaceSetEventStatus` in `functions/spaces/functions.js` |
| Stage UI | `lib/Spaces/world/space_live_stage.dart`, shown in the event room while live |
| Direct messages | `openDirectMessage` and `showPersonActions` in `lib/Spaces/world/space_world_screen.dart` |
| Rules | Attendees may set `handRaised` on their own entry; speakers remain server-only |
| Native permissions | `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` |
| Dependencies | `livekit_client: ^2.13.1`; `grpc: ^5.2.0` (protobuf 6); `livekit-server-sdk` in functions |

## Fixed on the way

- **Android:** declared no camera or microphone permission, so even the old audio rooms could not work on phones.
- **iOS:** had no camera, microphone or photo-library usage descriptions. Apple rejects apps without them, and the app crashes when it asks.

## Verification performed

- 53 of 53 backend tests pass (7 new). Tokens are verified with LiveKit's own `TokenVerifier`.
- The functions load with and without LiveKit enabled.
- 342 Dart files parse, and the preflight reports 0 errors.
- Every LiveKit Flutter API used was checked against the v2.13.1 source.
- The Info.plist and AndroidManifest parse.

## Not verified here

- **Audio and video on real devices:** needs a LiveKit project and CI's Flutter build.
- **Dependency resolution:** `flutter pub get` with `livekit_client`. Every constraint was checked against the lockfile: flutter_webrtc 1.6.3 is within `^1.2.0`, and grpc 5.2 resolves the protobuf 6 requirement.

---

# Phase 10: media players, Mango Reader, content lists, recommendations

Full description: `docs/media/README.md`.

## Verification performed

- 59 of 59 backend tests pass (6 new for taste, recommendations and AI shuffle).
- 350 Dart files parse; the preflight reports 0 errors.
- Every Syncfusion PDF API and LiveKit API used was checked against its source; the web pdf.js setup follows Syncfusion's README.
- New public names are unique; the two `RepeatMode` enums are never imported together.

## Not verified here

- `test/media/play_queue_test.dart` (13 tests) and all Dart compilation; these run in CI.
- 3 new Firestore rules tests (lists, progress, taste), which run on the CI emulator.
- Playback, reading and read aloud on real devices.

---

# Phase 11: chat, media sharing, Creator Studio, posts

Full description: `docs/chat-media-creators/README.md`.

## Verification performed

- 70 of 70 backend tests pass (11 new); 27 rules tests are written for the CI emulator.
- 361 Dart files parse; the preflight reports 0 errors and 5 warnings.
- New class names don't collide in any file that imports them.
- The `record` 6.x API was checked against its source.

## Not verified here

Dart compilation and analysis, and behaviour on devices; both run in CI.

---

# Phase 12: one-minute onboarding and notifications

Full description: `docs/onboarding-notifications/README.md`.

## Verification performed

- 81 of 81 backend tests pass (12 new).
- 366 Dart files parse; the preflight reports 0 errors.
- The google_sign_in 7 and sign_in_with_apple APIs were checked against their source.
- 29 rules tests are written for the CI emulator.

## Action required

Revoke the FCM server key that was embedded in `user_services.dart`. It remains in git history.
