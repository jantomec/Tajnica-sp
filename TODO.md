# TODO

## How To Use This Checklist

- [ ] Run the **UI integrity smoke suite** on every device profile listed below.
- [ ] Run the **AI matrix** against every Apple Intelligence state and every external AI provider.
- [ ] Run the **time tracker matrix** against every tracker connection set.
- [ ] Run the **storage and export matrix** in both local-storage and iCloud-storage modes.
- [ ] Run the **Siri / Shortcuts smoke suite** on iPhone simulator and on at least one real iPhone.
- [ ] Repeat at least one full end-to-end pass on both **macOS** and **iOS/iPadOS** before release.

## Combination Axes That Must Be Covered

- [ ] Storage mode: Local only
- [ ] Storage mode: iCloud enabled and app allowed to use it
- [ ] Apple Intelligence: unavailable
- [ ] Apple Intelligence: available and enabled
- [ ] Apple Intelligence: available and disabled
- [ ] External AI primary: Gemini
- [ ] External AI primary: Claude
- [ ] External AI primary: OpenAI
- [ ] Tracker connection set: none
- [ ] Tracker connection set: Toggl only
- [ ] Tracker connection set: Clockify only
- [ ] Tracker connection set: Harvest only
- [ ] Tracker connection set: Toggl + Clockify
- [ ] Tracker connection set: Toggl + Harvest
- [ ] Tracker connection set: Clockify + Harvest
- [ ] Tracker connection set: Toggl + Clockify + Harvest
- [ ] Export format: Toggl JSON
- [ ] Export format: Clockify JSON
- [ ] Export format: Harvest JSON

## Device Profiles

- [ ] macOS window at default width and height
- [ ] macOS narrow window
- [ ] macOS wide window
- [ ] macOS full screen
- [ ] iPhone small portrait
- [ ] iPhone small landscape
- [ ] iPhone standard portrait
- [ ] iPhone standard landscape
- [ ] iPhone Max portrait
- [ ] iPhone Max landscape
- [ ] iPad small portrait
- [ ] iPad small landscape
- [ ] iPad large portrait
- [ ] iPad large landscape

## UI Integrity Smoke Suite

- [ ] App launches without layout jumps, clipped controls, or broken navigation
- [ ] Capture tab layout is correct
- [ ] Review tab layout is correct
- [ ] Diary tab layout is correct
- [ ] Settings tab layout is correct
- [ ] Settings tabs switch correctly on every supported form factor
- [ ] Forms scroll correctly when content is taller than the viewport
- [ ] No buttons, pickers, toggles, or text fields are clipped or truncated unexpectedly
- [ ] Submit button uses the expected native appearance on macOS
- [ ] Connect, disconnect, test, export, cancel, and confirmation buttons use the expected native appearance on every platform
- [ ] Sheets open and dismiss correctly
- [ ] File export panel opens correctly on macOS
- [ ] Keyboard focus and tab order make sense on macOS
- [ ] Text fields and secure fields remain usable when the keyboard is shown on iPhone and iPad
- [ ] No console-visible crashes or obvious runtime warnings during normal navigation

## Siri / Shortcuts Smoke Suite

- [ ] First launch registers Planner shortcuts and they appear in the Shortcuts app
- [ ] Siri phrase opens Capture
- [ ] Siri phrase opens Review
- [ ] Alternate Siri phrase still opens Review
- [ ] Siri background action can append to the current draft note
- [ ] Siri background action can log a manual draft entry
- [ ] Siri background action can submit a populated draft
- [ ] Siri tracker-assignment action works for each connected provider
- [ ] Siri reports a clear error when there are no draft entries to submit
- [ ] Siri reports a clear error when the required tracker connection is missing
- [ ] Siri reports a clear error when AI processing is requested without a configured AI provider
- [ ] Automated Siri smoke tests pass on iPhone simulator

## Settings: AI Section

- [ ] Apple Intelligence availability is checked automatically on view load
- [ ] When Apple Intelligence is unavailable, the existing error-style UI is shown
- [ ] When Apple Intelligence is available, the toggle is shown instead of the error state
- [ ] On first load with Apple Intelligence available, the toggle defaults to enabled
- [ ] Apple Intelligence can be turned off and back on
- [ ] The "Apple Intelligence & Siri" system settings link opens the correct system settings screen
- [ ] External provider section text correctly explains primary-provider behavior and Apple fallback behavior
- [ ] Only one external AI provider can be selected at a time
- [ ] Changing external provider updates the configuration section correctly
- [ ] Provider-specific labels, placeholders, and hints are correct for Gemini
- [ ] Provider-specific labels, placeholders, and hints are correct for Claude
- [ ] Provider-specific labels, placeholders, and hints are correct for OpenAI

## Settings: Time Tracker Section

- [ ] App storage section correctly reports local storage mode
- [ ] App storage section correctly reports iCloud-backed storage mode
- [ ] When not using iCloud storage, the iCloud settings link is visible
- [ ] The iCloud settings link opens the correct system settings screen
- [ ] Export Data button opens the export configuration sheet
- [ ] Export sheet shows format picker
- [ ] Export sheet shows start and end date pickers
- [ ] Export sheet closes on cancel without side effects
- [ ] Export sheet proceeds to the native export destination flow on confirmation
- [ ] Export success message is correct
- [ ] Export failure message is correct
- [ ] Toggl card layout is correct
- [ ] Clockify card layout is correct
- [ ] Harvest card layout is correct
- [ ] Dynamic button text is correct for unconfigured vs configured states
- [ ] Connection-progress spinner and explanatory text are visible while a connection test is running
- [ ] Saved-token state is visually clear for every tracker

## AI Provider Functional Matrix

### Apple Intelligence Only

- [ ] Apple Intelligence available, no external provider configured, process note succeeds
- [ ] Apple Intelligence available, no external provider configured, Polish with AI succeeds
- [ ] Apple Intelligence disabled and no external provider configured, process note is blocked with the correct error

### Gemini

- [ ] Valid Gemini API key passes connection test
- [ ] Invalid Gemini API key fails with a clear error
- [ ] Empty Gemini API key prevents connection testing
- [ ] Gemini as primary processes notes successfully with Apple Intelligence disabled
- [ ] Gemini as primary processes notes successfully with Apple Intelligence enabled
- [ ] Gemini as primary can polish user context successfully
- [ ] Gemini failure falls back to Apple Intelligence when Apple Intelligence is enabled
- [ ] Gemini failure shows a hard error when Apple Intelligence is disabled or unavailable

### Claude

- [ ] Valid Claude API key passes connection test
- [ ] Invalid Claude API key fails with a clear error
- [ ] Empty Claude API key prevents connection testing
- [ ] Claude as primary processes notes successfully with Apple Intelligence disabled
- [ ] Claude as primary processes notes successfully with Apple Intelligence enabled
- [ ] Claude as primary can polish user context successfully
- [ ] Claude failure falls back to Apple Intelligence when Apple Intelligence is enabled
- [ ] Claude failure shows a hard error when Apple Intelligence is disabled or unavailable

### OpenAI

- [ ] Valid OpenAI API key passes connection test
- [ ] Invalid OpenAI API key fails with a clear error
- [ ] Empty OpenAI API key prevents connection testing
- [ ] OpenAI as primary processes notes successfully with Apple Intelligence disabled
- [ ] OpenAI as primary processes notes successfully with Apple Intelligence enabled
- [ ] OpenAI as primary can polish user context successfully
- [ ] OpenAI failure falls back to Apple Intelligence when Apple Intelligence is enabled
- [ ] OpenAI failure shows a hard error when Apple Intelligence is disabled or unavailable

## Time Tracker Connection Matrix

### Toggl

- [ ] Connect dialog opens
- [ ] Toggl instructions correctly explain where to find the API token
- [ ] Valid Toggl token passes connection test
- [ ] Invalid Toggl token fails with a clear error
- [ ] On successful connection test, workspaces are fetched automatically
- [ ] When workspaces are returned, the first workspace is selected automatically
- [ ] Changing the selected Toggl workspace works
- [ ] Toggl workspace selection persists across app relaunch
- [ ] Disconnect clears the token, workspace list, and selection state
- [ ] Returning to the settings view retests the stored Toggl token automatically

### Clockify

- [ ] Connect dialog opens
- [ ] Clockify instructions correctly explain where to find the API key
- [ ] Valid Clockify token passes connection test
- [ ] Invalid Clockify token fails with a clear error
- [ ] On successful connection test, workspaces are fetched automatically
- [ ] When workspaces are returned, the first valid workspace is selected automatically
- [ ] Changing the selected Clockify workspace works
- [ ] Clockify workspace selection persists across app relaunch
- [ ] Disconnect clears the token, workspace list, and selection state
- [ ] Returning to the settings view retests the stored Clockify token automatically

### Harvest

- [ ] Connect dialog opens
- [ ] Harvest instructions correctly explain where to find the access token
- [ ] Valid Harvest token passes connection test
- [ ] Invalid Harvest token fails with a clear error
- [ ] On successful connection test, accounts are fetched automatically
- [ ] When accounts are returned, the first account is selected automatically
- [ ] When projects are returned, the first project is selected automatically
- [ ] When tasks are returned, the first task is selected automatically
- [ ] Changing Harvest account refreshes projects and tasks correctly
- [ ] Changing Harvest project refreshes task options correctly
- [ ] Harvest account, project, and task selections persist across app relaunch
- [ ] Disconnect clears the token and all Harvest selection state
- [ ] Returning to the settings view retests the stored Harvest token automatically

## Tracker Connection Set Matrix

- [ ] No external trackers connected: submit saves only to app storage
- [ ] Toggl only: submit saves to app storage and Toggl
- [ ] Clockify only: submit saves to app storage and Clockify
- [ ] Harvest only: submit saves to app storage and Harvest
- [ ] Toggl + Clockify: submit saves to app storage and both trackers
- [ ] Toggl + Harvest: submit saves to app storage and both trackers
- [ ] Clockify + Harvest: submit saves to app storage and both trackers
- [ ] Toggl + Clockify + Harvest: submit saves to app storage and all three trackers

## Submit Flow Data Cases

- [ ] Single generated entry
- [ ] Multiple generated entries
- [ ] Manually edited entry after AI generation
- [ ] Manually added entry
- [ ] Entry with tags
- [ ] Entry with no tags
- [ ] Entry with billable enabled
- [ ] Entry with billable disabled
- [ ] Entry with no explicit billable value
- [ ] Entry with matched project
- [ ] Entry with no matched project
- [ ] Entry with long duration warning
- [ ] Entry with overlap error blocks submission
- [ ] Entry with blank description blocks submission
- [ ] Cross-check that validation state is correct before submit
- [ ] After successful submit, draft is cleared
- [ ] After successful submit, diary history is retained
- [ ] After successful submit, stored entries are persisted
- [ ] After app relaunch, stored entries can still be exported

## Export Matrix

### General

- [ ] Export with populated date range works
- [ ] Export with empty date range works and produces a valid JSON file
- [ ] Export start date after end date is handled correctly
- [ ] Export cancel from the native save panel does not break the UI
- [ ] Exported filename contains the selected format and date range

### Toggl Export

- [ ] Toggl export JSON schema looks correct
- [ ] Toggl export contains the stored workspace ID
- [ ] Toggl export contains the stored workspace name
- [ ] Toggl export contains the request payload needed to reconstruct a Toggl time-entry post

### Clockify Export

- [ ] Clockify export JSON schema looks correct
- [ ] Clockify export contains the stored workspace ID
- [ ] Clockify export contains the stored workspace name
- [ ] Clockify export contains the request payload needed to reconstruct a Clockify time-entry post

### Harvest Export

- [ ] Harvest export JSON schema looks correct
- [ ] Harvest export contains the stored account, project, and task IDs
- [ ] Harvest export contains the stored account, project, and task names
- [ ] Harvest export contains the timestamp-based request payload needed to reconstruct a Harvest time-entry post
- [ ] Harvest export contains the duration-fallback request payload needed to reconstruct a Harvest time-entry post

## Partial Failure Matrix

- [ ] App storage save succeeds while Toggl submission fails
- [ ] App storage save succeeds while Clockify submission fails
- [ ] App storage save succeeds while Harvest submission fails
- [ ] App storage save succeeds while Toggl and Clockify submissions fail
- [ ] App storage save succeeds while Toggl and Harvest submissions fail
- [ ] App storage save succeeds while Clockify and Harvest submissions fail
- [ ] App storage save succeeds while all external tracker submissions fail
- [ ] Partial-failure message clearly reports which services failed
- [ ] Successful services are still reported as successful when another service fails

## Cross-Product Release Pass

- [ ] Run the full smoke suite on every device profile
- [ ] Run the full AI provider functional matrix on macOS
- [ ] Run the full AI provider functional matrix on at least one iPhone and one iPad
- [ ] Run the full tracker connection matrix on macOS
- [ ] Run the full tracker connection matrix on at least one iPhone and one iPad
- [ ] Run the full export matrix in local-storage mode
- [ ] Run the full export matrix in iCloud-storage mode
- [ ] Run at least one full end-to-end pass for every tracker connection set
- [ ] Run at least one full end-to-end pass for every external AI provider with Apple Intelligence enabled
- [ ] Run at least one full end-to-end pass for every external AI provider with Apple Intelligence disabled
