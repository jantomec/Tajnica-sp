# Tajnica s.p. Release Checklist

This file is the release source of truth for shipping `Tajnica s.p.`. The high-level sections drive
release sign-off; the **Manual Test Matrices** appendix at the bottom enumerates the per-device and
per-provider checks that back up the `Manual` items above.

Treat this file as locked once release review starts. Any exception should be documented here explicitly instead of silently changing the gate.

## Automation Labels

- `Automated`: should be covered by unit tests, UI tests, static checks, or build/test jobs.
- `Manual`: requires a human sign-off on a real device, simulator, or distribution portal.
- `Decision`: requires an explicit product or release decision before shipping.
- `Ops`: requires credentials, portal setup, support prep, or release-day operational work.

## Current Audit Snapshot (2026-04-19)

- [x] `Automated`: remove remaining legacy `Planner` user-facing copy from intents, dialogs, exports, tests, and docs. Covered by `ReleaseReadinessTests.appSourcesDoNotLeakLegacyPlannerIntoStringLiterals`, which scans every Swift file under `Planner/` for string literals containing `Planner` and fails unless the line matches the documented allowlist (bundle-ID fallbacks and legacy storage namespaces called out under the `Decision` entries below).
- [x] `Decision`: keep the legacy technical identifiers intentionally unchanged for storage continuity:
  `JanTomec.Planner`, `planner://`, and `iCloud.com.jantomec.planner`.
- [x] `Decision`: Debug and Release use different `PRODUCT_BUNDLE_IDENTIFIER` values intentionally — Debug
  builds use `com.jantomec.planner` for local development, and Release ships as `JanTomec.Planner` to
  preserve storage continuity with the original distribution. Do not unify them.
- [x] `Manual`: resolve the macOS build warning about `UIBackgroundModes` containing `remote-notification` by scoping it to iOS SDK builds only.
- [ ] `Ops`: define release smoke-test credentials and safe test workspaces/accounts for Gemini, Claude, OpenAI, Toggl, Clockify, and Harvest. Official docs review did not confirm dedicated sandbox/test endpoints, so plan on approved non-production accounts or workspaces. Credentials live in the gitignored Planner scheme (Test action → Environment Variables, names `TAJNICA_SMOKE_*`); the gitignored `smoke-test-credentials.local.md` documents which dummy account each variable maps to. Current status: Gemini (AI Studio free-tier, `gemini-2.5-flash`) and Toggl (dummy account) provisioned and exercised by `PlannerTests/SmokeTests.swift`; Claude, OpenAI, Clockify, and Harvest still to define.
- [ ] `Manual`: complete a final multi-device smoke pass on macOS, iPhone, and iPad before release.

## Product Identity And Packaging

- [x] `Automated`: all user-facing copy uses `Tajnica s.p.` or neutral wording instead of `Planner`. Enforced by `ReleaseReadinessTests.appSourcesDoNotLeakLegacyPlannerIntoStringLiterals` (Swift-source string literals) plus `disabledLLMCopyUsesReleaseName` and `exportFilenamePrefixMatchesReleaseBrand` (specific brand-critical surfaces); the release `CFBundleDisplayName` is pinned to `Tajnica s.p.` in the project build settings.
- [x] `Manual`: app icon, app name, accent color, and screenshots match the release brand.
- [x] `Decision`: keep the Release bundle identifier `JanTomec.Planner` to preserve storage continuity and
  existing integrations; Debug intentionally uses `com.jantomec.planner` and the divergence is expected.
- [x] `Decision`: keep the deep-link URL scheme to preserve legacy automation and existing links.
- [x] `Decision`: keep the CloudKit container identifier to preserve existing synced storage continuity.
- [x] `Manual`: `CFBundleDisplayName`, signing assets, entitlements, and exported artifacts match the intended release identity.
- [x] `Manual`: release notes, support contact, privacy URL, and marketing copy use the final brand consistently.

## Build, Signing, And Distribution

- [x] `Manual`: release version and build number are set correctly. `MARKETING_VERSION = 1.1.0` and `CURRENT_PROJECT_VERSION = 1` on the `Planner` app target for both Debug and Release configurations.
- [x] `Automated`: release build compiles cleanly for macOS and iOS/iPadOS. Covered by `scripts/release-build.sh` and the `.github/workflows/release-build.yml` CI job, which run `xcodebuild -configuration Release clean build` against `generic/platform=macOS` and `generic/platform=iOS` with code signing disabled.
- [x] `Manual`: platform-specific plist settings do not produce avoidable shipping warnings.
- [x] `Manual`: code signing works for all shipping targets.
- [x] `Manual`: App Store Connect or distribution metadata is complete and internally consistent.
- [x] `Manual`: archive/notarization/TestFlight or equivalent distribution flow succeeds.
- [ ] `Ops`: store the final build artifact, commit SHA, and release notes in the release record.

## Core Product Flows

- [x] `Automated`: app launches into a healthy initial state with no crash.
- [x] `Automated`: capture note, process note, review entries, and submit entries work with no external tracker connected.
- [x] `Automated`: edited entries remain valid after manual changes, duplication, deletion, and tag changes.
- [x] `Automated`: stored entries remain linked back to the originating diary prompt where applicable.
- [ ] `Manual`: first-run experience is understandable with no hidden prerequisite.
- [ ] `Manual`: repeated launch, quit, relaunch, and background/foreground cycles do not lose user work unexpectedly.

## AI And LLM Flows

- [x] `Automated`: Apple Intelligence-only processing works when available.
- [x] `Automated`: disabling cloud AI still allows Apple Intelligence fallback when enabled.
- [x] `Automated`: missing AI configuration produces a clear blocking error.
- [x] `Automated`: Gemini connection test, extraction, and fallback behavior are covered.
- [x] `Automated`: Claude connection test, extraction, and fallback behavior are covered.
- [x] `Automated`: OpenAI connection test, extraction, and fallback behavior are covered.
- [x] `Automated`: shared retry policy honors Retry-After, exponential backoff with jitter, and the full list of retryable status codes across every cloud provider.
- [x] `Automated`: "Polish with AI" works and reports useful failures. Covered by `DiaryFeatureTests.polishUserContextUpdatesContextAndReportsSuccess`, `…FallsBackToAppleIntelligenceWhenPrimaryFails`, `…ReportsConfigurationErrorWhenNoProviderAvailable`, `…RejectsBlankInput`, and `…SurfacesServiceErrorWhenFallbackUnavailable`, which exercise primary success, Apple fallback, missing-provider guard, blank-input guard, and surfaced service-error paths through `PlannerAppModel.polishUserContext()`.
- [ ] `Manual`: real provider smoke tests succeed with release credentials and acceptable latency/cost. Partial coverage: `PlannerTests/SmokeTests.swift` exercises Gemini connection and extraction live against the scheme-provided credentials; Claude and OpenAI still manual until their keys are provisioned.
- [ ] `Ops`: quotas, billing alerts, and key rotation procedures are defined for every enabled provider.
- [ ] `Decision`: confirm which providers are officially supported in release copy and support docs.

## Time Tracker Integrations

- [x] `Automated`: empty credential states show clear guardrails for Toggl, Clockify, and Harvest. Covered by `DiaryFeatureTests.emptyCredentialsBlockConnectionTestsWithGuardrailMessages`, `…whitespaceOnlyCredentialsAreTreatedAsMissing`, `…submitEntriesSkipsTrackersWithoutCredentialsAndOnlyReportsAppStorage`, `…refreshTimeTrackerConnectionsOnViewLoadSkipsWhenNoCredentialsStored`, `…disconnectingTimeTrackerClearsTokenCatalogsAndTestResult`, `…intentFacadeReportsUnconfiguredClockifyWhenAssigningWorkspace`, and `…intentFacadeReportsUnconfiguredHarvestWhenAssigningTask`, which verify the connection-test guardrail copy, whitespace-only token rejection, per-provider submit skipping, view-load retest skipping, disconnect cleanup, and Clockify/Harvest intent-level "is not connected" errors (Toggl was already covered).
- [x] `Automated`: stored credentials are retested on settings load.
- [x] `Automated`: successful connection tests fetch reference data and persist usable selections where supported. Covered by `DiaryFeatureTests.successfulTogglConnectionTestLoadsCatalogsAndPersistsResolvedWorkspace`, `…successfulClockifyConnectionTestLoadsCatalogsAndPersistsResolvedWorkspace`, and `…successfulHarvestConnectionTestLoadsCatalogsAndPersistsResolvedAccount`, which run each `testXxxConnection()` with a valid token, assert the workspace/account catalogs and resolved-selection state on the model, and verify the matching IDs and names land in `PreferencesStore` (`selectedWorkspaceID`/`Name`, `selectedClockifyWorkspaceID`/`Name`, `selectedHarvestAccountID`/`Name`).
- [x] `Automated`: submit can save locally and push to every enabled external tracker combination that is represented in automated tests.
- [x] `Automated`: partial submission failures are reported without losing locally stored entries. Covered by `DiaryFeatureTests.partialSubmissionFailurePreservesLocalStorageAndReportsFailingProvider` (Toggl fails while Clockify + Harvest succeed) and `…allExternalSubmissionsFailingStillPreservesLocalStorage` (every tracker fails). The service stubs now accept an injected `createError`; both tests verify the entry still round-trips through `syncRepository.loadSnapshot(...)` and `model.storedEntries`, the failing provider name appears in `reviewErrorMessage`, the successful destinations and app storage still show up in `reviewStatusMessage`, the draft is not cleared, and submit does not overwrite the capture status with a `"Saved …"` success line.
- [ ] `Manual`: live Toggl smoke test succeeds against a non-production workspace or an approved release workspace. Partial coverage: `PlannerTests/SmokeTests.swift` exercises Toggl `fetchCurrentUser` and `fetchWorkspaces` live; submit + cleanup is still manual.
- [ ] `Manual`: live Clockify smoke test succeeds against a non-production workspace or an approved release workspace.
- [ ] `Manual`: live Harvest smoke test succeeds against a non-production account/project/task or an approved release workspace.
- [ ] `Ops`: document the exact credentials, workspace/account names, and cleanup steps used for release smoke tests.

## Persistence, Sync, And Data Safety

- [x] `Automated`: deferred draft persistence flushes correctly on lifecycle changes.
- [x] `Automated`: in-memory and local persistence behave correctly in tests.
- [x] `Automated`: recoverable CloudKit startup failures fall back to local storage.
- [ ] `Manual`: iCloud-enabled devices sync correctly across at least two devices signed into the same account.
- [ ] `Manual`: iCloud-disabled or signed-out devices fall back safely and explain the state correctly.
- [x] `Decision`: current local/iCloud namespaces are intentionally preserved for migration compatibility.
- [ ] `Ops`: define a rollback plan if a persistence or CloudKit issue is discovered after release.

## Export And Data Portability

- [x] `Automated`: export generation works for Toggl JSON payloads.
- [x] `Automated`: export generation works for Clockify JSON payloads.
- [x] `Automated`: export generation works for Harvest JSON payloads.
- [x] `Automated`: export filenames and payload metadata use the release brand and correct date ranges.
- [ ] `Manual`: native export flow works on macOS and iOS/iPadOS.
- [ ] `Manual`: exported files can be inspected externally and match the selected range/format.

## Shortcuts, Siri, And Deep Links

- [x] `Automated`: intent facade responses do not leak the legacy product name.
- [x] `Automated`: shortcut phrases and user-facing intent copy match the release brand. Covered by `ReleaseReadinessTests.shortcutPhrasesUseApplicationNamePlaceholder`, which parses every `phrases: [ ... ]` block in `PlannerShortcutsProvider.swift` and asserts each phrase uses the `\(.applicationName)` token (so Siri substitutes the `CFBundleDisplayName`-provided release brand) and contains no hard-coded `Planner` or `Tajnica` literal; and by `ReleaseReadinessTests.intentSourceFilesDoNotLeakLegacyBrand`, which runs a scope-tightened version of the Swift-literal scan against `Planner/Intents/` with no allowlist so any legacy-brand leak in intent titles, descriptions, dialogs, or facade copy fails the gate (back-stopped by `appSourcesDoNotLeakLegacyPlannerIntoStringLiterals`).
- [ ] `Manual`: shortcuts register on first launch and appear in the Shortcuts app.
- [ ] `Manual`: Siri can open Capture and Review on a real iPhone.
- [ ] `Manual`: background shortcuts for appending, creating, processing, and submitting drafts work on device.
- [x] `Decision`: the `planner://` deep-link scheme remains as a documented legacy technical identifier.

## UI, UX, And Accessibility

- [ ] `Manual`: Capture, Review, Diary, and Settings are visually correct on supported form factors.
- [ ] `Manual`: no clipped controls, broken sheets, or unusable scrolling states remain.
- [ ] `Manual`: keyboard navigation and focus order make sense on macOS.
- [ ] `Manual`: VoiceOver/Accessibility Inspector labels are sane for primary actions and key content.
- [ ] `Manual`: contrast, text sizing, and reduced-motion behavior are acceptable.
- [ ] `Manual`: empty, loading, success, and error states are all understandable without reading the code.

## Security, Privacy, And Compliance

- [ ] `Automated`: secrets are stored in Keychain, not plain `UserDefaults`.
- [x] `Automated`: non-secret preferences persist correctly across launches.
- [ ] `Manual`: privacy policy matches actual data flows, especially for LLM providers, tracker APIs, and iCloud sync.
- [ ] `Manual`: third-party licenses, notices, and disclosures are complete.
- [ ] `Decision`: confirm whether any analytics, telemetry, or crash reporting are present; if added later, update policy and disclosures first.
- [ ] `Ops`: prepare internal support guidance for credential issues, provider outages, and sync problems.

## Reliability And Performance

- [x] `Automated`: unit test suite passes on the release branch.
- [ ] `Manual`: cold launch time is acceptable on target devices.
- [ ] `Manual`: long notes, multiline notes, and edge-case time edits remain responsive.
- [ ] `Manual`: offline behavior and provider outage behavior are understandable and do not corrupt local data.
- [ ] `Manual`: repeated submit attempts do not create silent duplicates or inconsistent UI state.

## Documentation And Support

- [ ] `Automated`: repository docs use the release name and describe the current feature set accurately.
- [ ] `Manual`: setup instructions, privacy policy, known limitations, and support contacts are current.
- [ ] `Ops`: create a short release status report with blockers, accepted risks, and post-release watch items.

## Exit Criteria

- [ ] All `Automated` items are green on the release branch.
- [ ] All `Manual` items are signed off by a named human.
- [ ] All `Decision` items are resolved and written down.
- [ ] All `Ops` items needed for launch day are complete.
- [ ] Any accepted risk is documented with owner, impact, and follow-up plan.

---

# Appendix: Manual Test Matrices

This appendix is the detailed expansion of the `Manual` items above. The matrices repeat per release
cycle — reset the checkboxes (or copy the appendix into the release status report) at the start of each
release pass.

## How To Run This Appendix

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

- [ ] First launch registers Tajnica s.p. shortcuts and they appear in the Shortcuts app
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
