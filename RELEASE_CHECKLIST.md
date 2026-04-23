# Tajnica s.p. Release Checklist

This file is the release source of truth for shipping `Tajnica s.p.`.

Use `TODO.md` for general backlog work. Use this checklist for release sign-off only.

Treat this file as locked once release review starts. Any exception should be documented here explicitly instead of silently changing the gate.

## Automation Labels

- `Automated`: should be covered by unit tests, UI tests, static checks, or build/test jobs.
- `Manual`: requires a human sign-off on a real device, simulator, or distribution portal.
- `Decision`: requires an explicit product or release decision before shipping.
- `Ops`: requires credentials, portal setup, support prep, or release-day operational work.

## Current Audit Snapshot (2026-04-19)

- [ ] `Automated`: remove remaining legacy `Planner` user-facing copy from intents, dialogs, exports, tests, and docs.
- [x] `Decision`: keep the legacy technical identifiers intentionally unchanged for storage continuity:
  `JanTomec.Planner`, `planner://`, and `iCloud.com.jantomec.planner`.
- [x] `Decision`: Debug and Release use different `PRODUCT_BUNDLE_IDENTIFIER` values intentionally — Debug
  builds use `com.jantomec.planner` for local development, and Release ships as `JanTomec.Planner` to
  preserve storage continuity with the original distribution. Do not unify them.
- [x] `Manual`: resolve the macOS build warning about `UIBackgroundModes` containing `remote-notification` by scoping it to iOS SDK builds only.
- [ ] `Ops`: define release smoke-test credentials and safe test workspaces/accounts for Gemini, Claude, OpenAI, Toggl, Clockify, and Harvest. Official docs review did not confirm dedicated sandbox/test endpoints, so plan on approved non-production accounts or workspaces.
- [ ] `Manual`: complete a final multi-device smoke pass on macOS, iPhone, and iPad before release.

## Product Identity And Packaging

- [ ] `Automated`: all user-facing copy uses `Tajnica s.p.` or neutral wording instead of `Planner`.
- [ ] `Manual`: app icon, app name, accent color, and screenshots match the release brand.
- [x] `Decision`: keep the Release bundle identifier `JanTomec.Planner` to preserve storage continuity and
  existing integrations; Debug intentionally uses `com.jantomec.planner` and the divergence is expected.
- [x] `Decision`: keep the deep-link URL scheme to preserve legacy automation and existing links.
- [x] `Decision`: keep the CloudKit container identifier to preserve existing synced storage continuity.
- [ ] `Manual`: `CFBundleDisplayName`, signing assets, entitlements, and exported artifacts match the intended release identity.
- [ ] `Manual`: release notes, support contact, privacy URL, and marketing copy use the final brand consistently.

## Build, Signing, And Distribution

- [ ] `Manual`: release version and build number are set correctly.
- [ ] `Manual`: release build compiles cleanly for macOS and iOS/iPadOS.
- [x] `Manual`: platform-specific plist settings do not produce avoidable shipping warnings.
- [ ] `Manual`: code signing works for all shipping targets.
- [ ] `Manual`: App Store Connect or distribution metadata is complete and internally consistent.
- [ ] `Manual`: archive/notarization/TestFlight or equivalent distribution flow succeeds.
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
- [ ] `Automated`: "Polish with AI" works and reports useful failures.
- [ ] `Manual`: real provider smoke tests succeed with release credentials and acceptable latency/cost.
- [ ] `Ops`: quotas, billing alerts, and key rotation procedures are defined for every enabled provider.
- [ ] `Decision`: confirm which providers are officially supported in release copy and support docs.

## Time Tracker Integrations

- [ ] `Automated`: empty credential states show clear guardrails for Toggl, Clockify, and Harvest.
- [x] `Automated`: stored credentials are retested on settings load.
- [ ] `Automated`: successful connection tests fetch reference data and persist usable selections where supported.
- [x] `Automated`: submit can save locally and push to every enabled external tracker combination that is represented in automated tests.
- [ ] `Automated`: partial submission failures are reported without losing locally stored entries.
- [ ] `Manual`: live Toggl smoke test succeeds against a non-production workspace or an approved release workspace.
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
- [ ] `Automated`: shortcut phrases and user-facing intent copy match the release brand.
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
