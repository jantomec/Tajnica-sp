# Tajnica s.p.

Tajnica s.p. is a shared SwiftUI app for iOS, iPadOS, and macOS that turns a free-form daily note into editable time entries using Apple Foundation Models on-device and external LLM providers such as Gemini, Claude, and ChatGPT, then saves or submits them to the supported trackers.

## What v1 includes

- Capture screen with automatic current-day handling, multiline note input, draft persistence, and AI-assisted note processing.
- Review screen with a vertical day timeline, editable entries, inline validation, add/delete/duplicate actions, and submission to app storage plus any connected trackers.
- Diary screen with a reverse-chronological transcript of processed prompts, date separators, and a per-prompt timeline sheet that shows the submitted entries linked to that prompt (falling back to the active draft when nothing has been submitted yet).
- Settings screen with Apple Intelligence availability detection, Apple fallback control, single-select external provider configuration, live workspace refresh, workspace persistence, "Polish with AI" for the user-context text, and connection tests for Toggl, Clockify, and Harvest.
- Data export for submitted entries in Toggl, Clockify, or Harvest JSON formats over a selected date range.
- SwiftData-backed app storage that syncs through the user's private CloudKit container when iCloud is available and transparently falls back to local-only storage otherwise.
- Keychain storage for secrets and `UserDefaults` storage for non-secret preferences.

## Setup

1. Open `Planner.xcodeproj` in Xcode.
2. In Settings inside the app:
   - Apple Intelligence is detected automatically and can be left enabled as an on-device fallback
   - choose one external provider (`Gemini`, `Claude`, or `OpenAI ChatGPT`) and add its API key if you want cloud processing as the primary option
3. Add any time-tracker credentials you want to use (`Toggl`, `Clockify`, and/or `Harvest`).
4. Optionally change the cloud model override. The default Gemini model is `gemini-2.5-flash`.
5. Use the relevant connection test in Settings to load live workspaces, projects, accounts, and tasks.
6. Capture a note, review the generated entries, fix any validation issues, and submit to `Tajnica s.p. Storage` and any connected trackers.
7. Browse processed prompts in the Diary tab, and tap any prompt to see the submitted entries it produced.

## Implementation notes

- Every cloud provider uses strict structured output. Gemini uses `responseJsonSchema`, Claude uses `tool_use` with a forced `tool_choice`, and OpenAI uses `response_format: json_schema` in strict mode. The app decodes the returned JSON directly and never parses fenced markdown.
- Every cloud provider shares a single `LLMRetryPolicy` that retries 408, 425, 429, 500, 502, 503, 504, and Anthropic's 529 status codes plus recoverable URL errors. Backoff is exponential with full jitter (250 ms → 4 s cap). `Retry-After` headers are honored when present and capped at 30 seconds so an upstream typo cannot lock a request for hours.
- Apple Foundation Models uses the system `FoundationModels` framework on-device and returns the same entry schema as the cloud providers.
- The capture flow always uses the current local day and sends the active AI engine an explicit `Today is YYYY-MM-DD.` line in the prompt.
- Tradeoff summary:
  - Apple Foundation Models stays on-device, is lower-latency, and keeps note content local, but it depends on Apple Intelligence availability and can be less capable on harder or multilingual notes.
  - Cloud providers usually offer stronger nuanced reasoning and broader multilingual support, but they require API keys and send note content to the selected provider.
- When an external provider is configured, Tajnica s.p. uses it first and falls back to Apple Foundation Models if Apple Intelligence is enabled and the external provider is unavailable.
- Toggl workspace selection is always resolved from the live API:
  - no saved workspace -> first fetched workspace
  - saved workspace still exists -> keep it
  - saved workspace missing -> first fetched workspace
- Candidate entries are validated locally before submission for blank descriptions, invalid durations, overlaps, tag cleanup, project/workspace consistency, long entries, and large gaps.
- Project assignment is optional. When live projects are available for the resolved workspace, AI-suggested project names are matched by normalized name and the entry editor exposes a picker.
- Successful submission clears the unfinished draft so the app reopens to a fresh capture state, while the submitted entries remain in app storage for Review, Diary, and Export.

## Diary notes

- A "prompt" is the raw note text the user intentionally sends via `Process` or `Regenerate` — draft keystrokes are not archived.
- A snapshot is appended only when processing actually proceeds, the text is non-empty, and it is not an exact same-day duplicate of the most recent archived prompt.
- Diary history survives `Clear Draft`, successful submission, and app relaunch, and it syncs through the same SwiftData store as drafts and submitted entries.
- Historical prompts from before the feature shipped cannot be reconstructed, because the app previously persisted only a single unfinished draft and cleared it on successful submission.
- The Diary feed is intentionally styled close to Apple-native apps (Journal archive + one-sided Messages transcript) and should stay that way: default navigation titles, `ScrollView`/`LazyVStack`, `ContentUnavailableView` for the empty state, a thin `Divider` with a centered date caption for day separators, and system tint bubbles with no custom chrome.
- Long prompts are collapsed by default (4 visible lines) with an inline expand/collapse affordance; short prompts render fully with no affordance. Expansion state lives in the view layer only and is not persisted.
- Tapping a bubble opens a timeline sheet that prefers the latest saved submission for that prompt and falls back to the current draft entries when no submission exists yet.

## Assumptions

- Toggl API token authentication uses Basic Auth as `token:api_token`.
- Long-entry warnings trigger at 4 hours and large-gap warnings trigger at 2 hours.
- The app stores a single latest unfinished draft alongside submitted entries and diary history, which keeps the implementation lightweight and easy to restore across launches.
- When iCloud is available and the app is allowed to use it, drafts, submitted entries, and diary history sync through the user's private CloudKit container; otherwise the app uses local-only storage and reports that state in Settings.
- Some technical identifiers still use legacy `Planner` naming for storage continuity; see `RELEASE_CHECKLIST.md` before changing bundle IDs, URL schemes, or CloudKit identifiers.
