# Brightday

A visual day planner for ADHD brains. Android app built with Flutter.

> "Brightday" and the package id `com.brightday.planner` are working names.
> Change them before the first Play upload if you want something else
> (see [docs/RELEASE.md](docs/RELEASE.md)); the package id can never change
> after that.

## What it does

- **Visual timeline.** The day is a colourful timeline where each block's
  height is its length, with a live "now" line and an "anytime" list for
  tasks without a time. A "Now / Next up" card shows how long is left or how
  soon the next thing starts, to fight time blindness.
- **Break it down.** One tap turns a big task into small steps. It uses an
  AI endpoint when one is configured and falls back to built-in offline
  templates, so it always works.
- **Gentle reminders.** Optional heads-up before a task starts (local
  notifications, no account, nothing leaves the phone).
- **Focus mode with a buddy.** A "time timer" wedge that shrinks as time
  passes, the current step front and centre, and a calm body-doubling buddy
  who checks in every few minutes. Pause, add 5 minutes, or finish.
- **No guilt.** Unfinished tasks roll forward with one tap instead of piling
  up as red "overdue" items.
- Light and dark themes, reduce-motion setting, haptics toggle, screen
  reader labels, and "delete all my data".

Everything is stored on the device (`tasks.json` in app storage, included in
Android's own backup). There are no accounts and no analytics.

## Project layout

| Path | What |
| --- | --- |
| `lib/models` | Task and settings data |
| `lib/data` | On-device storage (atomic JSON file, shared preferences) |
| `lib/state` | `PlannerController` (tasks, reminders), focus timer maths |
| `lib/services` | Notifications, AI / offline task breakdown |
| `lib/ui` | Home timeline, task editor and detail, focus mode, settings, onboarding |
| `proxy/` | Cloudflare Worker that holds the AI key and calls Claude |
| `store/` | Play Store icon, feature graphic, listing text |
| `docs/` | Release checklist and privacy policy template |

## Develop

```sh
flutter pub get
flutter test
flutter run
```

Build settings are passed with `--dart-define`:

| Name | Purpose |
| --- | --- |
| `BREAKDOWN_API_URL` | Full URL of the proxy's `/breakdown` endpoint. Empty means offline suggestions only. |
| `BREAKDOWN_API_TOKEN` | Shared token the proxy checks (`APP_TOKEN` there). |
| `PRIVACY_POLICY_URL` | Shown in Settings. Required for the Play listing. |
| `SUPPORT_EMAIL` | Shown in Settings. |

## AI task breakdown

The app never contains an API key. It calls the small Worker in `proxy/`,
which keeps the Anthropic key as a secret. To deploy it:

```sh
cd proxy
npm ci
npx wrangler login
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put APP_TOKEN   # any long random string
npx wrangler deploy
```

Then build the app with
`--dart-define=BREAKDOWN_API_URL=https://<your-worker>.workers.dev/breakdown`
and `--dart-define=BREAKDOWN_API_TOKEN=<same random string>`.

The Worker uses Claude Opus 5.5 at low effort by default. To cut cost, set a
`MODEL` var in `wrangler.toml` to `claude-sonnet-5-5`.

## Release

CI builds a release app bundle on every push. Signing, store listing and the
full Play Store checklist are in [docs/RELEASE.md](docs/RELEASE.md).
