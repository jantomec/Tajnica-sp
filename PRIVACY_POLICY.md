# Privacy Policy for Tajnica s.p.

Effective date: 2026-04-15

Tajnica s.p. is a time-entry assistant app. This policy explains what the app stores, what it sends to third-party services you choose to use, and what it does not collect.

## Summary

Tajnica s.p. does not operate a developer-run backend for storing your notes, time entries, or API keys.

The app stores some information locally on your device so it can work:

- API credentials are stored in the Apple Keychain.
- App preferences are stored in `UserDefaults`.
- Your latest unfinished draft is stored on your device in the app's Application Support folder.

The app sends data to third-party services only when you use features that depend on them:

- your selected cloud AI provider: Google Gemini, Anthropic Claude, or OpenAI
- Toggl, when you test your connection, load workspaces/projects, or submit time entries

If you choose Apple Foundation Models, note processing and "Polish with AI" run on-device through Apple's FoundationModels framework instead of a third-party cloud AI API.

Clockify and Harvest appear in the app as future options, but based on the code reviewed they are not active yet and the app does not currently send data to those services.

## Information Stored on Your Device

The app stores the following locally on your device:

- AI API keys for supported cloud providers
- your Toggl API token
- your selected AI provider
- your selected AI model
- your selected time tracker
- your selected workspace ID and workspace name
- your optional "About Me" / user-context text
- your latest unfinished note draft and generated candidate entries

## Information Sent to Third-Party Services

### 1. AI providers

If you choose Apple Foundation Models, the app processes your note and optional user-context text on-device and does not send that content to a third-party AI provider.

If you choose a cloud AI provider, the app sends the following to the AI provider you selected:

- your note text
- the selected date
- your local time zone
- your optional user-context text, if you added it

When you use the "Polish with AI" feature with a cloud AI provider, the app sends your user-context text to that provider.

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

If you use a cloud AI provider or Toggl features, your data is processed by the third-party service you selected or connected.

That means those providers may receive your request contents and normal network metadata needed to deliver the request, such as your IP address. This is an inference from the app making direct HTTPS requests to those services.

Their handling of your data is governed by their own terms and privacy policies.

## Data Retention

Local data stays on your device until you change it or remove it.

In practical terms:

- API keys and tokens remain in Keychain until you clear or replace them
- preferences remain in local app storage until you change them or remove the app
- the latest unfinished draft remains on your device until it is replaced, cleared, or removed with the app

The app does not provide a developer-operated cloud account or central storage for this data.

Retention by third-party cloud AI providers or Toggl depends on those services and their policies.

## Your Choices

You can choose:

- whether to enter any AI API key
- which AI provider to use
- whether to enter a Toggl API token
- whether to provide optional user-context text
- whether to submit time entries to Toggl

You can remove locally stored credentials by clearing them in the app's settings, and you can remove local app data by uninstalling the app.

## Security

The app stores API credentials in Apple Keychain storage and uses HTTPS network requests for supported external services, based on the code reviewed. If you choose Apple Foundation Models, AI processing can stay on-device.

No software can guarantee absolute security, but the app is designed to keep sensitive credentials out of plain app preference storage.

## Children's Privacy

Tajnica s.p. is not designed specifically for children.

## Contact

If you publish this policy, add your support contact here:

Contact email: [add your support email]
Website: [add your website, if any]
