import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var appModel: PlannerAppModel
    @State private var editingEntry: CandidateTimeEntry?

    private var timeTrackerSettingsActionView: AnyView {
        #if os(macOS)
        return AnyView(
            SettingsLink {
                Text("Open Time Tracker Settings")
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    appModel.selectedSettingsTab = .timeTracker
                }
            )
        )
        #else
        return AnyView(
            Button("Open Time Tracker Settings") {
                appModel.selectedSettingsTab = .timeTracker
                appModel.selectedTab = .settings
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        )
        #endif
    }

    /// Summarise the date(s) covered by candidate entries.
    private var entryDateSummary: String {
        let dates = Set(appModel.draft.candidateEntries.map {
            PlannerFormatters.dateString($0.date)
        })
        if dates.isEmpty {
            return PlannerFormatters.dateString(appModel.draft.note.date)
        }
        return dates.sorted().joined(separator: " / ")
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                let isWide = geometry.size.width >= 940

                Group {
                    if isWide {
                        HStack(alignment: .top, spacing: 24) {
                            timelineSection
                                .frame(width: 330)

                            entriesSection
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            timelineSection
                            entriesSection
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Review")
        .sheet(item: $editingEntry) { entry in
            EntryEditorView(entry: entry, availableProjects: appModel.availableProjects) { updated in
                appModel.saveEditedEntry(updated)
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day Timeline")
                .font(.headline)

            if appModel.draft.candidateEntries.isEmpty {
                ContentUnavailableView(
                    "No Entries Yet",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Process a daily note first, or add an entry manually.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                DayTimelineView(
                    entries: appModel.draft.candidateEntries,
                    selectedEntryID: editingEntry?.id,
                    onSelect: { entry in
                        editingEntry = entry
                    }
                )
                .padding(12)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            if let summary = appModel.draft.summary {
                StatusBanner(text: summary, style: .info)
            }

            if !appModel.draft.assumptions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Assumptions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(appModel.draft.assumptions, id: \.self) { assumption in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(assumption)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let status = appModel.reviewStatusMessage {
                StatusBanner(text: status, style: .success)
            }

            if let error = appModel.reviewErrorMessage {
                StatusBanner(text: error, style: .error)
            }

            if appModel.draft.candidateEntries.isEmpty {
                Text("No candidate entries for \(PlannerFormatters.dateString(appModel.draft.note.date)).")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appModel.draft.candidateEntries) { entry in
                    entryCard(entry)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entryDateSummary)
                        .font(.title3.weight(.semibold))

                    if appModel.totalErrorCount > 0 || appModel.totalWarningCount > 0 {
                        HStack(spacing: 12) {
                            if appModel.totalErrorCount > 0 {
                                Label("\(appModel.totalErrorCount) errors", systemImage: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            if appModel.totalWarningCount > 0 {
                                Label("\(appModel.totalWarningCount) warnings", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.subheadline)
                    }
                }

                Spacer()

                if appModel.isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    appModel.addEntry()
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }

                Button("Submit to \(appModel.selectedTimeTracker.displayName)") {
                    Task {
                        await appModel.submitEntries()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appModel.canSubmit)
            }

            if let workspace = appModel.resolvedWorkspace {
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.caption)
                    Text("Workspace: \(workspace.name)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                StatusBanner(
                    text: "No workspace resolved for \(appModel.selectedTimeTracker.displayName). Configure your time tracker settings first.",
                    style: .warning,
                    actionView: timeTrackerSettingsActionView
                )
            }
        }
    }

    @ViewBuilder
    private func entryCard(_ entry: CandidateTimeEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.description.isBlank ? "Untitled Entry" : entry.description)
                        .font(.headline)

                    Text("\(PlannerFormatters.dateString(entry.date))  \(PlannerFormatters.timeRange(start: entry.start, stop: entry.stop))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(PlannerFormatters.durationString(entry.duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Button("Edit") {
                    editingEntry = entry
                }
                .controlSize(.small)

                Button("Duplicate") {
                    appModel.duplicateEntry(id: entry.id)
                }
                .controlSize(.small)

                Button("Delete", role: .destructive) {
                    appModel.deleteEntry(id: entry.id)
                }
                .controlSize(.small)
            }

            if let projectName = entry.projectName {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption)
                    Text(projectName)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }

            if !entry.validationIssues.isEmpty {
                Divider()

                ForEach(entry.validationIssues) { issue in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
                            .font(.caption)

                        Text(issue.message)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    entry.hasErrors ? Color.red.opacity(0.3) :
                    entry.hasWarnings ? Color.orange.opacity(0.3) :
                    Color.clear,
                    lineWidth: 1
                )
        )
    }
}
