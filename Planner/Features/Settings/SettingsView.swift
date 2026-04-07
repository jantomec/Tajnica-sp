import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: PlannerAppModel

    var body: some View {
        TabView {
            llmSettingsTab
                .tabItem {
                    Label("AI Provider", systemImage: "cpu")
                }

            togglSettingsTab
                .tabItem {
                    Label("Toggl", systemImage: "timer")
                }

            aboutMeTab
                .tabItem {
                    Label("About Me", systemImage: "person.crop.circle")
                }
        }
        .frame(width: 520, height: 460)
    }

    // MARK: - AI Provider Tab

    private var llmSettingsTab: some View {
        Form {
            Section("AI Provider") {
                Picker("Provider", selection: Binding(
                    get: { appModel.selectedProvider },
                    set: { appModel.updateSelectedProvider($0) }
                )) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("\(appModel.selectedProvider.displayName) Configuration") {
                SecureField(
                    appModel.selectedProvider.apiKeyLabel,
                    text: Binding(
                        get: { appModel.activeAPIKey },
                        set: { appModel.updateAPIKey($0, for: appModel.selectedProvider) }
                    )
                )

                TextField(
                    "Model",
                    text: Binding(
                        get: { appModel.llmModel },
                        set: { appModel.updateLLMModel($0) }
                    )
                )

                Text("Leave blank to use default: \(appModel.selectedProvider.defaultModel)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Test Connection") {
                        Task {
                            await appModel.testLLMConnection()
                        }
                    }
                    .disabled(appModel.activeAPIKey.trimmed.isEmpty)

                    if appModel.isTestingLLM {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if let result = appModel.llmTestResult {
                        InlineResultLabel(result: result)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }

    // MARK: - Toggl Tab

    private var togglSettingsTab: some View {
        Form {
            Section("Toggl Track") {
                SecureField(
                    "Toggl API Token",
                    text: Binding(
                        get: { appModel.togglAPIToken },
                        set: { appModel.updateTogglAPIToken($0) }
                    )
                )

                HStack(spacing: 8) {
                    Button("Test Toggl") {
                        Task {
                            await appModel.testTogglConnection()
                        }
                    }
                    .disabled(appModel.togglAPIToken.trimmed.isEmpty)

                    Button("Refresh Workspaces") {
                        Task {
                            await appModel.refreshWorkspaces(showErrors: true)
                        }
                    }
                    .disabled(appModel.togglAPIToken.trimmed.isEmpty)

                    if appModel.isTestingToggl || appModel.isRefreshingWorkspaces {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let result = appModel.togglTestResult {
                    InlineResultLabel(result: result)
                }
            }

            Section("Workspace") {
                if appModel.availableWorkspaces.isEmpty {
                    Text("No live workspaces loaded yet. Test your Toggl token to load workspaces.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker(
                        "Selected Workspace",
                        selection: Binding(
                            get: { appModel.resolvedWorkspace?.id },
                            set: { appModel.selectWorkspace(id: $0) }
                        )
                    ) {
                        ForEach(appModel.availableWorkspaces) { workspace in
                            Text(workspace.name).tag(Optional(workspace.id))
                        }
                    }
                }

                if let workspace = appModel.resolvedWorkspace {
                    Text("Resolved: \(workspace.name)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }

    // MARK: - About Me Tab

    private var aboutMeTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell the AI about yourself so it can better predict your schedule.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ZStack(alignment: .topLeading) {
                        TextEditor(
                            text: $appModel.userContext
                        )
                        .font(.body)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)

                        if appModel.userContext.isEmpty {
                            Text("Example: I work as a software engineer, usually 9am-6pm with a lunch break around noon. I work on projects Alpha and Beta, and have a daily standup at 9:15am. Most of my work is billable except for internal meetings...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 8) {
                        Spacer()

                        if let result = appModel.polishResult {
                            InlineResultLabel(result: result)
                        }

                        if appModel.isPolishingContext {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Button {
                            Task {
                                await appModel.polishUserContext()
                            }
                        } label: {
                            Label("Polish with AI", systemImage: "wand.and.stars")
                        }
                        .disabled(appModel.userContext.isBlank || appModel.activeAPIKey.trimmed.isEmpty || appModel.isPolishingContext)
                        .help("Use the active AI provider to refine your description and suggest missing details")
                    }

                    if appModel.activeAPIKey.trimmed.isEmpty {
                        Text("Configure an AI provider key in the AI Provider tab to use the polish feature.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("About Me")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// MARK: - Inline Result Label

/// Small inline feedback label shown next to a button after an action completes.
private struct InlineResultLabel: View {
    let result: PlannerAppModel.InlineResult

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: result.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.caption)
            Text(result.message)
                .font(.caption)
                .lineLimit(2)
        }
        .foregroundStyle(result.isError ? .red : .green)
    }
}
