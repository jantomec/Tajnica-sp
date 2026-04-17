import SwiftUI

struct DiaryView: View {
    @EnvironmentObject private var appModel: PlannerAppModel
    @State private var selectedPrompt: DiaryPromptRecord?

    var body: some View {
        GeometryReader { geometry in
            if appModel.diaryPromptHistory.isEmpty {
                ContentUnavailableView(
                    "No Prompts Yet",
                    systemImage: "book.closed",
                    description: Text("Processed prompts will appear here once you send them.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(appModel.diaryFeedItems) { item in
                            switch item {
                            case let .dateSeparator(day):
                                DiaryDateSeparatorView(day: day)
                            case let .prompt(record):
                                DiaryMessageBubble(
                                    record: record,
                                    bubbleWidth: bubbleWidth(for: geometry.size.width),
                                    onOpen: {
                                        selectedPrompt = record
                                    }
                                )
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Diary")
        .sheet(item: $selectedPrompt) { record in
            DiaryPromptTimelineSheet(record: record)
                .environmentObject(appModel)
        }
    }

    private func bubbleWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth - 48, 240), 560)
    }
}

private struct DiaryPromptTimelineSheet: View {
    @EnvironmentObject private var appModel: PlannerAppModel
    @Environment(\.dismiss) private var dismiss

    let record: DiaryPromptRecord

    @State private var selectedEntryID: UUID?

    private var submittedEntries: [StoredTimeEntryRecord] {
        appModel.latestStoredEntries(for: record.id)
    }

    private var draftEntries: [CandidateTimeEntry] {
        appModel.activeDraftEntries(for: record.id)
    }

    private var timelineEntries: [CandidateTimeEntry] {
        if !submittedEntries.isEmpty {
            return submittedEntries.map(\.displayCandidateEntry)
        }

        return draftEntries
    }

    private var isShowingSubmittedEntries: Bool {
        !submittedEntries.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt")
                            .font(.headline)
                        Text(record.rawText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    StatusBanner(
                        text: isShowingSubmittedEntries
                            ? "Showing the latest saved submission generated from this prompt."
                            : "No submitted entries are saved for this prompt yet. Showing the current draft entries when available.",
                        style: isShowingSubmittedEntries ? .info : .warning
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timeline")
                            .font(.headline)

                        if timelineEntries.isEmpty {
                            ContentUnavailableView(
                                "No Entries Saved",
                                systemImage: "clock.badge.xmark",
                                description: Text("There are no local entries associated with this prompt yet.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(
                                Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        } else {
                            DayTimelineView(
                                entries: timelineEntries,
                                selectedEntryID: selectedEntryID,
                                onSelect: { entry in
                                    selectedEntryID = entry.id
                                }
                            )
                            .padding(12)
                            .background(
                                Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                    }

                    if !timelineEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Entries")
                                .font(.headline)

                            ForEach(timelineEntries) { entry in
                                diaryEntryCard(entry)
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 960, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle(PlannerFormatters.dateString(record.day))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 520)
    }

    @ViewBuilder
    private func diaryEntryCard(_ entry: CandidateTimeEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
            }

            if let serviceSummary = serviceSummary(for: entry), !serviceSummary.isEmpty {
                Text(serviceSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !entry.tags.isEmpty {
                Text(entry.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selectedEntryID == entry.id ? Color.accentColor.opacity(0.35) : .clear, lineWidth: 1)
        }
        .onTapGesture {
            selectedEntryID = entry.id
        }
    }

    private func serviceSummary(for entry: CandidateTimeEntry) -> String? {
        var segments = [String]()

        if let toggl = entry.togglTarget {
            let details = [toggl.workspaceName?.trimmed.nilIfBlank, toggl.projectName?.trimmed.nilIfBlank]
                .compactMap { $0 }
                .joined(separator: " / ")
            if !details.isEmpty {
                segments.append("Toggl: \(details)")
            }
        }

        if let clockify = entry.clockifyTarget {
            let details = [clockify.workspaceName?.trimmed.nilIfBlank, clockify.projectName?.trimmed.nilIfBlank]
                .compactMap { $0 }
                .joined(separator: " / ")
            if !details.isEmpty {
                segments.append("Clockify: \(details)")
            }
        }

        if let harvest = entry.harvestTarget {
            let details = [
                harvest.accountName?.trimmed.nilIfBlank,
                harvest.projectName?.trimmed.nilIfBlank,
                harvest.taskName?.trimmed.nilIfBlank
            ]
            .compactMap { $0 }
            .joined(separator: " / ")
            if !details.isEmpty {
                segments.append("Harvest: \(details)")
            }
        }

        return segments.isEmpty ? nil : segments.joined(separator: "  |  ")
    }
}

private extension StoredTimeEntryRecord {
    var displayCandidateEntry: CandidateTimeEntry {
        CandidateTimeEntry(
            id: id,
            date: baseEntry.date,
            start: baseEntry.start,
            stop: baseEntry.stop,
            description: baseEntry.description,
            togglTarget: toggl.map {
                CandidateTimeEntry.TogglTarget(
                    workspaceName: $0.workspaceName,
                    workspaceId: $0.workspaceID,
                    projectName: $0.projectName,
                    projectId: $0.request.projectId
                )
            },
            clockifyTarget: clockify.map {
                CandidateTimeEntry.ClockifyTarget(
                    workspaceName: $0.workspaceName,
                    workspaceId: $0.workspaceID,
                    projectName: $0.projectName,
                    projectId: $0.request.projectId
                )
            },
            harvestTarget: harvest.map {
                CandidateTimeEntry.HarvestTarget(
                    accountName: $0.accountName,
                    accountId: $0.accountID,
                    projectName: $0.projectName,
                    projectId: $0.projectID,
                    taskName: $0.taskName,
                    taskId: $0.taskID
                )
            },
            tags: baseEntry.tags,
            billable: baseEntry.billable,
            source: baseEntry.source
        )
    }
}
