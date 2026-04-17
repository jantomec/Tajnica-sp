import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var appModel: PlannerAppModel

    private var aiSettingsActionView: AnyView {
        #if os(macOS)
        return AnyView(
            SettingsLink {
                Text("Open AI Settings")
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    appModel.selectedSettingsTab = .aiProvider
                }
            )
        )
        #else
        return AnyView(
            Button("Open AI Settings") {
                appModel.selectedSettingsTab = .aiProvider
                appModel.selectedTab = .settings
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        )
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let status = appModel.captureStatusMessage {
                    StatusBanner(text: status, style: .success)
                }

                if let error = appModel.captureErrorMessage {
                    StatusBanner(text: error, style: .error)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("What did you do today?")
                        .font(.title2.weight(.semibold))

                    Text("Paste or write your day in any language. \(AppConfiguration.displayName) turns your note into candidate time entries using your selected AI engine.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(PlannerFormatters.dateString(appModel.draft.note.date))
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                        )

                    ZStack(alignment: .topLeading) {
                        TextEditor(
                            text: Binding(
                                get: { appModel.draft.note.rawText },
                                set: { appModel.updateRawText($0) }
                            )
                        )
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)

                        if appModel.draft.note.rawText.isEmpty {
                            Text("Write your note here. Example: client call in the morning, lunch, bug fixing in the afternoon, admin at the end of the day.")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(12)
                }

                if !appModel.isAIConfigured {
                    StatusBanner(
                        text: "Your AI engine is not configured. Enable Apple Intelligence or finish setting up the selected external provider before processing notes.",
                        style: .warning,
                        actionView: aiSettingsActionView
                    )
                } else if !appModel.draft.candidateEntries.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("\(appModel.draft.candidateEntries.count) candidate entries saved. Regenerating will replace them.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        appModel.clearDraft()
                    } label: {
                        Label("Clear Draft", systemImage: "trash")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)

                    Spacer()

                    if appModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button {
                        Task {
                            await appModel.processNote()
                        }
                    } label: {
                        Label(
                            appModel.draft.candidateEntries.isEmpty ? "Process" : "Regenerate",
                            systemImage: appModel.draft.candidateEntries.isEmpty ? "wand.and.stars" : "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .disabled(!appModel.canProcess)
                }
            }
            .padding(24)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Capture")
        .onAppear {
            appModel.refreshNoteDateForPresentation()
        }
        .confirmationDialog(
            "Replace the current review entries?",
            isPresented: $appModel.shouldConfirmRegeneration,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                Task {
                    await appModel.processNote(replacingExistingEntries: true)
                }
            }
        } message: {
            Text("Manual edits in the review draft will be replaced.")
        }
    }
}
