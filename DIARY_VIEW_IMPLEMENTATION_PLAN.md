# Diary View Implementation Plan

## Goal

Add a new `Diary` surface that preserves previously submitted user prompts and lets the user browse them by day.

The feature should:

- keep the current `Capture -> Review -> Submit to Toggl` flow intact
- store historical prompt snapshots separately from the transient draft
- show a scrollable reverse-chronological list prompts as read-only user messages
- add a thin line and date caption separator between prompts on different dates
- stay visually close to Apple-native apps by leaning on default SwiftUI list, navigation, and typography behavior

## Product Definition

For v1 of this feature, a "prompt" should mean:

- the raw text the user intentionally sends via `Process` or `Regenerate`
- not every keystroke while editing the draft

Recommended archive rules:

- archive only non-empty prompt text
- archive when processing begins, after basic validation passes and before the network request is sent
- keep the diary entry even if the LLM request later fails, because the user still intentionally submitted that prompt
- prevent obvious clutter by skipping an archive append when the newest stored prompt for the same day has identical `rawText`

Important limitation:

- historical prompts from before this feature ships cannot be reconstructed reliably, because the app currently persists only one unfinished `draft.json` and clears it after successful submission

## Apple-Native Visual Direction

### Primary references

1. Journal
   - Apple describes Journal as a place where users "scroll through your journal to see previous entries" and find entries for a specific day via calendar/search.
   - This is the right reference for the archive list: date-first, quiet, content-led browsing.
   - Sources:
     - [Get started with Journal on iPhone](https://support.apple.com/en-lamr/guide/iphone/iph0e5ca7dd3/ios)
     - [View and search your journal entries on iPhone](https://support.apple.com/guide/iphone/view-and-search-journal-entries-iph6257be047/ios)
     - [Get started with Journal on iPad](https://support.apple.com/is-is/guide/ipad/ipadbeee4bc5/ipados)
     - [View and search your journal entries on iPad](https://support.apple.com/guide/ipad/view-and-search-journal-entries-ipad5b2de4c6/ipados)

2. Messages
   - Apple shows Messages as a conversation list on compact devices and a list-plus-transcript layout on iPad.
   - This is the right reference for the prompt feed styling: a simple transcript of user-authored message bubbles.
   - Sources:
     - [Send and reply to messages on iPhone](https://support.apple.com/en-in/guide/iphone/-iph82fb73ba3/ios)
     - [Send and reply to messages on iPad](https://support.apple.com/sq-al/guide/ipad/ipad99acb44a/ipados)

### Practical UI translation

- `Diary` should feel like a merged Journal archive and one-sided Messages transcript:
  - reverse chronological ordering
  - content-led browsing instead of an index-first drill-down
  - quiet date separators between days
  - no heavy card chrome
- the prompt feed should feel like a one-sided Messages thread:
  - read-only bubbles for user prompts only
  - mostly default spacing and typography
  - system accent color for outgoing bubbles instead of custom brand colors
  - no avatars, no fake assistant replies, no decorative timeline
- prefer structural fidelity over pixel imitation:
  - `NavigationStack`
  - `ScrollView` / `LazyVStack`
  - `ContentUnavailableView`
  - standard navigation titles
  - minimal custom background shaping only where needed for message bubbles and date separators

## Proposed UX

### Entry point

- Add a new `Diary` tab in `PlannerRootView`
- Suggested SF Symbol: `book.closed`

### Diary feed

- Show a single scrollable transcript of archived prompts
- Sort prompts newest first across the whole feed
- Render each prompt as a read-only outgoing message bubble
- Long prompts should appear collapsed by default
- Short prompts should render fully and should not show any collapse affordance
- Recommended collapse threshold:
  - use a small number of visible lines rather than a character count
  - start with `4` visible lines as the default collapsed height
- Each collapsible prompt should support toggling between collapsed and expanded states
- Insert a date separator whenever the prompt's local day differs from the previous visible prompt
- Each separator should contain:
  - a thin horizontal line
  - a small centered date caption
- Recommended date ordering within the feed:
  - newest prompt near the top
  - older prompts below

### Empty state

- If no prompts are archived yet, use `ContentUnavailableView`
- Keep the copy focused on the archive behavior rather than setup instructions

### Adaptive layout

- Keep the same feed structure on iPhone, iPad, and macOS
- Do not introduce a second-level diary detail screen
- Do not introduce split-view complexity unless a later requirement needs filtering or search

## Data Model And Persistence

### New model types

Add a dedicated history model instead of overloading `PlannerDraft`.

Recommended shapes:

- `DiaryPromptRecord`
  - `id: UUID`
  - `day: Date` normalized to local start-of-day
  - `rawText: String`
  - `createdAt: Date`
- `DiaryFeedItem`
  - computed UI model, not persisted
  - either a date separator or a prompt row
  - derived from the flat stored prompt records after sorting

Expansion state should remain UI-local and should not be persisted into the diary history store.

### New store

Create a separate store, parallel to `DraftStore`.

Recommended file:

- `Application Support/<AppName>/diary.json`

Recommended responsibilities:

- load all stored prompt records
- save the full prompt history
- append a prompt record
- keep JSON encoder/decoder settings aligned with `DraftStore`

Why a separate store:

- `draft.json` is transient working state
- diary history must survive `Clear Draft` and successful Toggl submission
- the feature is easier to reason about when unfinished work and archived history are isolated

## App Model Integration

### New published state

In `PlannerAppModel`, add:

- a loaded diary history collection
- a derived `[DiaryFeedItem]` collection for rendering the feed
- no diary-specific selection state unless a future feature adds filtering or search

Collapse and expansion state should live in the diary view layer, not in persisted models and not in `PlannerAppModel`, unless implementation constraints force a shared state object.

### New dependency

Inject a `DiaryStore` into `PlannerAppModel`, mirroring the current `DraftStore` pattern.

### Archive hook

The best integration point is `processNote(replacingExistingEntries:)`.

Recommended behavior:

1. run existing guard checks first
2. if processing will actually proceed, archive a snapshot of `draft.note.rawText`
3. continue with the LLM request as today

This keeps the feature aligned with actual user intent and avoids storing partial typing noise.

### Non-hooks

Do not archive on:

- every `updateRawText`
- `clearDraft()`
- `submitEntries()`

Those actions manage working state, not diary history.

## UI Implementation Outline

### Files likely to change

- `Planner/App/PlannerRootView.swift`
- `Planner/App/PlannerAppModel.swift`
- `Planner/Utilities/PlannerFormatters.swift`

### New files likely to be added

- `Planner/Persistence/DiaryStore.swift`
- `Planner/Models/DiaryPromptRecord.swift`
- `Planner/Models/DiaryFeedItem.swift`
- `Planner/Features/Diary/DiaryView.swift`
- `Planner/Features/Diary/DiaryDateSeparatorView.swift`
- `Planner/Features/Diary/DiaryMessageBubble.swift`

### Navigation note

Current tabs wrap each feature in a `NavigationStack`.

Recommendation:

- keep the existing tab-level `NavigationStack`
- render `DiaryView` as a single-screen feed with a standard navigation title
- avoid introducing diary-only navigation infrastructure because the updated feature no longer has a drill-down step

## Styling Guidance

Keep the implementation deliberately restrained.

Recommended:

- default navigation titles
- default text styles
- a simple `ScrollView` with a lightweight vertical stack
- system date typography with only small weight adjustments
- one custom bubble background using system tint
- one thin separator treatment using `Divider` or an equivalent minimal line
- one secondary metadata style for timestamps only if needed after visual review
- a minimal expand/collapse affordance only for prompts that actually exceed the collapsed line limit

Avoid:

- custom gradients
- strong shadows
- custom row cards
- complex animations
- manually reproducing Messages chrome

If the prompt bubbles need structure, prefer the smallest useful set of modifiers:

- padding
- max-width alignment
- rounded rectangle background
- `foregroundStyle(.white)` or equivalent readable system treatment against tint
- `lineLimit` and a lightweight tap target or inline button for expand/collapse behavior

If the date separators need structure, prefer:

- a `Divider`
- a centered caption
- minimal vertical spacing

## Migration And Backfill

No true backfill is possible for already-cleared historical prompts.

Recommended migration stance:

- ship with an empty diary for past history
- load future prompt archives from the new store only
- keep the current draft untouched

Optional one-time import:

- if desired, the current live draft could appear only after its next successful archive event, not by silent migration

## Testing Plan

### Unit tests

Add targeted tests for the new persistence and archive behavior.

Recommended coverage:

- `DiaryStore` round-trip save/load
- empty history load
- append preserves existing records
- feed derivation inserts separators at local day boundaries
- feed derivation sorts prompts newest first
- archive on `processNote` only when prompt text is non-empty
- no duplicate append when the newest same-day prompt has identical text
- diary history survives `clearDraft()`
- diary history survives successful `submitEntries()`
- collapse state defaults to collapsed for long prompts
- short prompts do not expose expand/collapse UI

### UI checks

At minimum, verify manually:

- empty diary state
- multiple prompts on the same day
- multiple days in descending order
- separator placement when the day changes
- long prompt wrapping in bubble layout
- long prompts start collapsed
- long prompts expand and collapse cleanly
- short prompts render fully with no collapse affordance

## Suggested Implementation Sequence

1. Add history model and `DiaryStore`
2. Inject diary persistence into `PlannerAppModel`
3. Archive prompt snapshots from `processNote`
4. Derive feed items with date separators from stored prompt records
5. Add the new `Diary` tab and transcript feed view
6. Add tests and do a visual polish pass

## Open Decisions

These are the only points worth resolving before implementation:

- Should each message bubble show a timestamp?
  - Recommendation: hide it initially and rely on date separators unless usability testing shows ambiguity
- Should date captions use relative labels like Today / Yesterday or always use the full localized date?
  - Recommendation: start with the full localized date for predictability in an archive view
- What should the default collapsed threshold be for long prompts?
  - Recommendation: start with `4` visible lines and tune only if real prompts feel too cramped or too verbose
- Should identical consecutive prompts be stored if the user retries the same request?
  - Recommendation: no, skip only exact consecutive duplicates for the same day

## Repo-Specific Notes

- The app currently stores only one unfinished draft in `Planner/Persistence/DraftStore.swift`; diary history should stay independent of that file and lifecycle.
- `Planner/App/PlannerAppModel.swift` already owns the right archive trigger point because `processNote` is the intentional handoff from raw prompt to structured entries.
- `Planner/Utilities/PlannerFormatters.swift` should likely gain diary-specific separator date formatting, and optionally prompt time formatting if timestamps are later added.

## Ready-To-Implement Outcome

After this plan is approved, the implementation should produce:

- a new `Diary` tab
- persistent archived prompt history
- a single reverse-chronological prompt feed with date separators
- collapsed-by-default rendering for long prompts, with shorter prompts shown in full
- a read-only prompt transcript styled like a lightweight Messages thread
- tests for storage and archive behavior
