# Privacy Policy for Tajnica s.p.

Effective date: 2026-04-23

Tajnica s.p. is a time-entry assistant app. This policy explains what the app stores, what it sends to third-party services you choose to use, and what it does not collect.

## Summary

Tajnica s.p. does not operate a developer-run backend for storing your notes, time entries, or API keys.

The app stores some information on your device so it can work:

- API credentials are stored in the Apple Keychain.
- App preferences are stored in `UserDefaults`.
- Your latest unfinished draft, your submitted time entries, and your diary history of processed prompts are stored in the app's SwiftData database.

If iCloud is available on your device and you allow the app to use it, that SwiftData database syncs through your own private CloudKit container. When iCloud is not available or not allowed, the app falls back to local-only storage and reports that state in Settings. Anthropic/Apple/OpenAI/Toggl/Clockify/Harvest never receive this CloudKit content — it syncs device-to-device under your Apple ID.

The app sends data to third-party services only when you use features that depend on them:

- your selected cloud AI provider: Google Gemini, Anthropic Claude, or OpenAI
- Toggl, when you test your connection, load workspaces and projects, or submit time entries
- Clockify, when you test your connection, load workspaces and projects, or submit time entries
- Harvest, when you test your connection, load accounts, projects, and tasks, or submit time entries

If you choose Apple Foundation Models, note processing and "Polish with AI" run on-device through Apple's FoundationModels framework instead of a third-party cloud AI API.

## Information Stored on Your Device

The app stores the following on your device:

- AI API keys for supported cloud providers
- your Toggl API token, Clockify API key, and Harvest access token
- your selected AI provider and AI model
- your selected Toggl workspace, Clockify workspace, and Harvest account / project / task
- your optional "About Me" / user-context text
- your latest unfinished note draft and generated candidate entries
- the time entries you have submitted from the app, kept so that Review, Diary, and Data Export can reference them
- your diary history of processed prompts (the raw note text you sent via Process or Regenerate, plus the local day and a timestamp)

The draft, submitted entries, and diary history are held in a SwiftData database. When iCloud is available and allowed for this app, that database syncs through your private CloudKit container; otherwise it is kept locally on the device only.

## Information Sent to Third-Party Services

### 1. AI providers

If you choose Apple Foundation Models, the app processes your note and optional user-context text on-device and does not send that content to a third-party AI provider.

If you choose a cloud AI provider, the app sends the following to the AI provider you selected:

- your note text
- the selected date
- your local time zone
- your optional user-context text, if you added it

When you use the "Polish with AI" feature, the app sends your user-context text to the active AI engine (the selected cloud provider if it is configured, otherwise Apple Foundation Models when Apple Intelligence is enabled and available).

When you test a cloud AI connection, the app sends a small test request to the selected AI provider. When the AI settings view checks Apple Foundation Models availability, the app checks the local system model state on-device.

The app currently supports these providers:

- Apple Foundation Models (on-device)
- Google Gemini
- Anthropic Claude
- OpenAI

### 2. Toggl

When you use Toggl features, the app sends data to Toggl's API.

This includes:

- your Toggl API token for authentication
- requests for your current Toggl user profile, workspace list, and project list
- time-entry data you choose to submit, such as description, start time, stop time, duration, tags, billable flag, project ID, and workspace ID

When testing the Toggl connection, the app may receive your Toggl account name and email address from Toggl in order to show a connection result inside the app. Based on the code reviewed, this information is used in the app session and is not intentionally stored by the app as a long-term profile.

### 3. Clockify

When you use Clockify features, the app sends data to Clockify's API.

This includes:

- your Clockify API key for authentication
- requests for your current Clockify user profile, workspace list, and project list
- time-entry data you choose to submit, such as description, start time, stop time, tags, billable flag, project ID, and workspace ID

When testing the Clockify connection, the app may receive your Clockify name and email address from Clockify in order to show a connection result inside the app. Based on the code reviewed, this information is used in the app session and is not intentionally stored by the app as a long-term profile.

### 4. Harvest

When you use Harvest features, the app sends data to Harvest's API.

This includes:

- your Harvest access token and selected account ID for authentication
- requests for your accessible accounts, current user profile, and project/task assignments
- time-entry data you choose to submit, such as notes, start/stop timestamps or duration, project ID, task ID, and billable flag

When testing the Harvest connection, the app may receive your Harvest name and email address from Harvest in order to show a connection result inside the app. Based on the code reviewed, this information is used in the app session and is not intentionally stored by the app as a long-term profile.

### 5. Apple iCloud / CloudKit

If iCloud is available on your device and you allow the app to use it, the app's SwiftData store (drafts, submitted time entries, and diary history) syncs to your own private CloudKit container under your Apple ID. This content is not sent to Anthropic, Apple's AI services, or any time tracker — it is stored in your personal iCloud data and synced between your own devices.

If iCloud is not available or you have disabled it for this app, the app uses local-only storage and Settings reports that state.

## What Tajnica s.p. Does Not Do

Based on the code reviewed, Tajnica s.p. does not:

- run its own backend to collect or store your app data
- include advertising SDKs
- include analytics or telemetry SDKs
- track you across apps or websites
- sell your personal data
- access contacts, photos, camera, microphone, or location
- implement push-notification handling in the reviewed code

## Third-Party Processing

If you use a cloud AI provider, Toggl, Clockify, or Harvest, your data is processed by the third-party service you selected or connected.

That means those providers may receive your request contents and normal network metadata needed to deliver the request, such as your IP address. This is an inference from the app making direct HTTPS requests to those services.

Their handling of your data is governed by their own terms and privacy policies.

## Data Retention

Data stored by the app stays on your device (and, when iCloud is enabled for the app, in your private CloudKit container) until you change it or remove it.

In practical terms:

- API keys and tokens remain in Keychain until you clear or replace them
- preferences remain in local app storage until you change them or remove the app
- the latest unfinished draft remains until it is replaced, cleared, or removed with the app
- submitted time entries and diary history remain until you remove them or uninstall the app
- when iCloud sync is active, the same draft, submitted entries, and diary history are mirrored in your private CloudKit container and follow your iCloud account's retention behavior

The app does not provide a developer-operated cloud account or central storage for this data.

Retention by third-party cloud AI providers, Toggl, Clockify, or Harvest depends on those services and their policies.

## Your Choices

You can choose:

- whether to enter any AI API key
- which AI provider to use
- whether to enter a Toggl API token, Clockify API key, or Harvest access token
- whether to provide optional user-context text
- whether to submit time entries to Toggl, Clockify, and/or Harvest
- whether this app may use iCloud, via iOS/iPadOS/macOS System Settings for your Apple ID

You can remove stored credentials by clearing them in the app's settings, and you can remove app data by uninstalling the app. If iCloud sync is active, removing the app from a single device does not clear the synced CloudKit copy — manage that from your iCloud account settings.

## Security

The app stores API credentials in Apple Keychain storage and uses HTTPS network requests for supported external services, based on the code reviewed. If you choose Apple Foundation Models, AI processing can stay on-device.

No software can guarantee absolute security, but the app is designed to keep sensitive credentials out of plain app preference storage.

## Children's Privacy

Tajnica s.p. is not designed specifically for children.

## Contact

If you publish this policy, add your support contact here:

Contact email: [add your support email]
Website: [add your website, if any]
