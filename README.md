# Planner

Planner is a shared SwiftUI app for iOS, iPadOS, and macOS that turns a free-form daily note into editable Toggl Track time entries using Gemini structured output.

## What v1 includes

- Capture screen with automatic current-day handling, multiline note input, draft persistence, and Gemini processing.
- Review screen with a vertical day timeline, editable entries, inline validation, add/delete/duplicate actions, and Toggl submission.
- Settings screen with Gemini and Toggl credentials, Gemini model selection, live workspace refresh, workspace persistence, and connection tests.
- Local draft storage for the latest unfinished note and candidate entries.
- Keychain storage for secrets and `UserDefaults` storage for non-secret preferences.

## Setup

1. Open `Planner.xcodeproj` in Xcode.
2. In Settings inside the app, paste:
   - a Gemini API key
   - a Toggl Track API token
3. Optionally change the Gemini model. The default is `gemini-2.5-flash`.
4. Use `Refresh Workspaces` or `Test Toggl` to load the live workspace list.
5. Capture a note, review the generated entries, fix any validation issues, and submit to Toggl.

## Implementation notes

- Gemini requests use JSON Schema structured output only. The app decodes the returned JSON string directly and does not parse fenced markdown.
- The capture flow always uses the current local day and sends Gemini an explicit `Today is YYYY-MM-DD.` line in the prompt.
- Toggl workspace selection is always resolved from the live API:
  - no saved workspace -> first fetched workspace
  - saved workspace still exists -> keep it
  - saved workspace missing -> first fetched workspace
- Candidate entries are validated locally before submission for blank descriptions, invalid durations, overlaps, tag cleanup, project/workspace consistency, long entries, and large gaps.
- Project assignment is optional. When live projects are available for the resolved workspace, Gemini project names are matched by normalized name and the entry editor exposes a picker.
- Successful Toggl submission clears the unfinished draft so the app reopens to a fresh capture state.

## Assumptions

- Toggl API token authentication uses Basic Auth as `token:api_token`.
- Long-entry warnings trigger at 4 hours and large-gap warnings trigger at 2 hours.
- The app stores a single latest unfinished draft, which keeps the implementation lightweight and easy to restore across launches.
