# Onboarding and notifications

## Onboarding in about a minute

**Flow:**
1. Splash
2. Intro slides (first launch only)
3. Welcome: sign in or sign up with email, Google, Apple or phone
4. **Quick start**
5. Explainer (3 cards, skippable)
6. Home

The quick start (`lib/AccountSetup/quick_start.dart`) is one screen:
- photo (optional, square crop through the composer);
- name, prefilled from Google or Apple;
- @username, suggested from your name and checked live;
- interests (optional).

Everything else (bio, banner, birthday, location) is added later from the profile.

**Every sign-in method ends in `OnboardingService.continueAfterSignIn`:**
- onboarded people go home;
- everyone else gets the quick start;
- older accounts with a name and username count as onboarded, so no existing user is sent through setup again.

**Server (`accountOnboard`):**
- reserves the username in `usernames/{name}` (also checking older accounts);
- writes every field the app's user model reads, so screens never break on new accounts;
- marks onboarding complete;
- sends the welcome and "Finish your profile" notifications.

**Profile:** a completion card shows what's missing (photo, bio, banner, location, interests) with one-tap chips. If the profile is still unfinished, `notifyProfileReminders` sends up to 3 reminders, 3 days apart.

### Sign-in fixes

| Before | Now |
| --- | --- |
| Google and Apple users went through setup again on every sign-in | Returning users go straight home |
| Google sign-in never called `initialize()` (required by google_sign_in 7) and passed the access token as the ID token | Initialises once and uses the ID token; uses a popup on web |
| Phone sign-in opened `/otp-screen`, which doesn't exist, and skipped setup | Opens `/otp`, then continues normally |
| Email sign-in re-sent a verification email every time | Verification is sent at sign-up and never blocks you |
| Apple's name was lost | Saved from the first Apple sign-in |
| The splash waited 2 seconds and showed intro slides to signed-in users | 0.6 seconds; signed-in users go home or to the quick start |

## Notifications

**One server path (`functions/notify`)** fills the in-app centre (`users/{uid}/notifications`) and pushes to the person's devices. It:
- respects per-category settings, mute, push-off and blocked users;
- groups repeats ("Ada, Bo and 3 others liked your post");
- rate-limits pushes to 20 an hour per person (the centre still fills);
- removes dead device tokens.

| Event | Who hears | Setting |
| --- | --- | --- |
| Like on your post (grouped per post) | Post author | Likes |
| Reply to your post; @mention in a post | Author; mentioned person | Replies and mentions |
| New follower (grouped per day) | The person followed | New followers |
| Message on your Space wall (grouped) | Space owner | Spaces |
| A Space you joined goes live | Members | Spaces |
| Your song, episode, film or book reaches a milestone (first play or read, 10, 50, 100, 500, 1,000 and so on) | Creator | Your content |
| "Continue reading…" for books, episodes and films you started 1 to 4 days ago (once per item) | Reader, listener or watcher | Pick up where you left off |
| Welcome; "Finish your profile" | You | Account and tips |
| Chats | The other person (push, as before) | |

**The centre** (`lib/Profile/pages/notifications.dart`):
- sections for Today, This week and Earlier, with All and Unread filters;
- unread items highlighted, swipe to delete, mark all read;
- tap opens the real screen (post, profile, chat, player, video, reader, Space, settings) through `NotificationRouter`, and push taps use the same router;
- settings: a switch for each category, push on or off, mute for 8 hours, and a test notification.

### Security fixes

- **An FCM server key was embedded in the app** (`UserService.sendNotification`). Anyone could have used it to push to every user. It has been removed from the code. **Revoke it in the Firebase console** (Project settings, Cloud Messaging); it's still in the repository's history.
- **Clients can no longer create notifications**, either in the centre or in the push queue. People can read, mark read and delete their own.
- **`sendTestNotification`** (open HTTP, anyone could notify anyone) is replaced by the `notifyTest` callable, which only reaches your own devices.
- **`proxyImage`** only fetches images from an allowlist of hosts; before, it fetched any URL.

### Removed broken triggers

These never ran:
- `sendPostNotification` checked `post.authorId`, a field posts don't have.
- `onSongPlayed`, `onBookRead` and `onProfileViewed` listened to collections the app never writes.

`onPostLiked` pushed without filling the in-app centre. All five are replaced by the triggers above.

## Tests

- `functions/test/notify.test.js` (12 tests):
  - grouping, preferences, blocking, mute, rate limits and token cleanup;
  - milestones and resume reminders;
  - usernames, onboarding, username changes, and profile reminder limits.
- Rules (CI emulator, 29 total):
  - clients can't create notifications;
  - only `isRead` can be updated;
  - `usernames` is server-only, and onboarding status can't be set at account creation.

## Deploy

Deploy, in order:
1. functions;
2. rules and indexes (a new collection-group index on `items.updatedAt` is needed for reading reminders);
3. the app.

Then revoke the old FCM server key.
