import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var appModel: PlannerAppModel

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

                    Text("Paste or write your day in any language. Planner turns your note into candidate Toggl entries using \(appModel.selectedProvider.displayName).")
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

                if appModel.activeAPIKey.trimmed.isEmpty {
                    StatusBanner(
                        text: "\(appModel.selectedProvider.displayName) is not configured. Open Settings (\u{2318},) to add your API key.",
                        style: .warning
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
                    Button("Clear Draft", role: .destructive) {
                        appModel.clearDraft()
                    }
                    .controlSize(.regular)

                    Spacer()

                    if appModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button(appModel.draft.candidateEntries.isEmpty ? "Process" : "Regenerate") {
                        Task {
                            await appModel.processNote()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!appModel.canProcess)
                }
            }
            .padding(24)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Capture")
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
