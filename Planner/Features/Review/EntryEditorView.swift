import SwiftUI

private enum BillableChoice: String, CaseIterable, Identifiable {
    case unset
    case yes
    case no

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unset: "Unset"
        case .yes: "Billable"
        case .no: "Non-billable"
        }
    }

    var value: Bool? {
        switch self {
        case .unset: nil
        case .yes: true
        case .no: false
        }
    }

    static func from(_ value: Bool?) -> BillableChoice {
        switch value {
        case true: .yes
        case false: .no
        case nil: .unset
        }
    }
}

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let entry: CandidateTimeEntry
    let togglCatalogs: [TogglWorkspaceCatalog]
    let clockifyCatalogs: [ClockifyWorkspaceCatalog]
    let harvestCatalogs: [HarvestAccountCatalog]
    let enabledTrackers: Set<TimeTrackerProvider>
    let onSave: (CandidateTimeEntry) -> Void

    @State private var start: Date
    @State private var stop: Date
    @State private var descriptionText: String
    @State private var tagsText: String
    @State private var billableChoice: BillableChoice
    @State private var togglWorkspaceID: Int?
    @State private var togglProjectID: Int?
    @State private var clockifyWorkspaceID: String?
    @State private var clockifyProjectID: String?
    @State private var harvestAccountID: Int?
    @State private var harvestProjectID: Int?
    @State private var harvestTaskID: Int?

    init(
        entry: CandidateTimeEntry,
        togglCatalogs: [TogglWorkspaceCatalog],
        clockifyCatalogs: [ClockifyWorkspaceCatalog],
        harvestCatalogs: [HarvestAccountCatalog],
        enabledTrackers: Set<TimeTrackerProvider>,
        onSave: @escaping (CandidateTimeEntry) -> Void
    ) {
        self.entry = entry
        self.togglCatalogs = togglCatalogs
        self.clockifyCatalogs = clockifyCatalogs
        self.harvestCatalogs = harvestCatalogs
        self.enabledTrackers = enabledTrackers
        self.onSave = onSave

        let initialTogglWorkspaceID = entry.togglTarget?.workspaceId ?? (togglCatalogs.count == 1 ? togglCatalogs.first?.workspace.id : nil)
        let initialClockifyWorkspaceID = entry.clockifyTarget?.workspaceId ?? (clockifyCatalogs.count == 1 ? clockifyCatalogs.first?.workspace.id : nil)
        let initialHarvestAccountID = entry.harvestTarget?.accountId ?? (harvestCatalogs.count == 1 ? harvestCatalogs.first?.account.id : nil)

        let initialTogglProjectID: Int? = {
            guard let initialTogglWorkspaceID,
                  let workspace = togglCatalogs.first(where: { $0.workspace.id == initialTogglWorkspaceID }) else {
                return entry.togglTarget?.projectId
            }

            return entry.togglTarget?.projectId ?? (workspace.projects.count == 1 ? workspace.projects.first?.id : nil)
        }()

        let initialClockifyProjectID: String? = {
            guard let initialClockifyWorkspaceID,
                  let workspace = clockifyCatalogs.first(where: { $0.workspace.id == initialClockifyWorkspaceID }) else {
                return entry.clockifyTarget?.projectId
            }

            return entry.clockifyTarget?.projectId ?? (workspace.projects.count == 1 ? workspace.projects.first?.id : nil)
        }()

        let initialHarvestProjectID: Int? = {
            guard let initialHarvestAccountID,
                  let account = harvestCatalogs.first(where: { $0.account.id == initialHarvestAccountID }) else {
                return entry.harvestTarget?.projectId
            }

            return entry.harvestTarget?.projectId ?? (account.projects.count == 1 ? account.projects.first?.id : nil)
        }()

        let initialHarvestTaskID: Int? = {
            guard let initialHarvestAccountID,
                  let initialHarvestProjectID,
                  let account = harvestCatalogs.first(where: { $0.account.id == initialHarvestAccountID }),
                  let project = account.projects.first(where: { $0.id == initialHarvestProjectID }) else {
                return entry.harvestTarget?.taskId
            }

            return entry.harvestTarget?.taskId ?? (project.taskAssignments.count == 1 ? project.taskAssignments.first?.id : nil)
        }()

        _start = State(initialValue: entry.start)
        _stop = State(initialValue: entry.stop)
        _descriptionText = State(initialValue: entry.description)
        _tagsText = State(initialValue: entry.tags.joined(separator: ", "))
        _billableChoice = State(initialValue: BillableChoice.from(entry.billable))
        _togglWorkspaceID = State(initialValue: initialTogglWorkspaceID)
        _togglProjectID = State(initialValue: initialTogglProjectID)
        _clockifyWorkspaceID = State(initialValue: initialClockifyWorkspaceID)
        _clockifyProjectID = State(initialValue: initialClockifyProjectID)
        _harvestAccountID = State(initialValue: initialHarvestAccountID)
        _harvestProjectID = State(initialValue: initialHarvestProjectID)
        _harvestTaskID = State(initialValue: initialHarvestTaskID)
    }

    private var selectedTogglWorkspace: TogglWorkspaceCatalog? {
        guard let togglWorkspaceID else { return nil }
        return togglCatalogs.first(where: { $0.workspace.id == togglWorkspaceID })
    }

    private var selectedClockifyWorkspace: ClockifyWorkspaceCatalog? {
        guard let clockifyWorkspaceID else { return nil }
        return clockifyCatalogs.first(where: { $0.workspace.id == clockifyWorkspaceID })
    }

    private var selectedHarvestAccount: HarvestAccountCatalog? {
        guard let harvestAccountID else { return nil }
        return harvestCatalogs.first(where: { $0.account.id == harvestAccountID })
    }

    private var selectedHarvestProject: HarvestProjectSummary? {
        guard let harvestProjectID else { return nil }
        return selectedHarvestAccount?.projects.first(where: { $0.id == harvestProjectID })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Stop", selection: $stop, displayedComponents: .hourAndMinute)
                }

                Section("Details") {
                    TextField("Description", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Tags", text: $tagsText, prompt: Text("Comma-separated"))
                }

                if enabledTrackers.contains(.toggl) {
                    togglSection
                }

                if enabledTrackers.contains(.clockify) {
                    clockifySection
                }

                if enabledTrackers.contains(.harvest) {
                    harvestSection
                }

                Section("Billing") {
                    Picker("Billable", selection: $billableChoice) {
                        ForEach(BillableChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
        .onChange(of: togglWorkspaceID) { _, newValue in
            guard let newValue else {
                togglProjectID = nil
                return
            }

            guard let workspace = togglCatalogs.first(where: { $0.workspace.id == newValue }) else {
                togglProjectID = nil
                return
            }

            if !workspace.projects.contains(where: { $0.id == togglProjectID }) {
                togglProjectID = workspace.projects.count == 1 ? workspace.projects.first?.id : nil
            }
        }
        .onChange(of: clockifyWorkspaceID) { _, newValue in
            guard let newValue else {
                clockifyProjectID = nil
                return
            }

            guard let workspace = clockifyCatalogs.first(where: { $0.workspace.id == newValue }) else {
                clockifyProjectID = nil
                return
            }

            if !workspace.projects.contains(where: { $0.id == clockifyProjectID }) {
                clockifyProjectID = workspace.projects.count == 1 ? workspace.projects.first?.id : nil
            }
        }
        .onChange(of: harvestAccountID) { _, newValue in
            guard let newValue,
                  let account = harvestCatalogs.first(where: { $0.account.id == newValue }) else {
                harvestProjectID = nil
                harvestTaskID = nil
                return
            }

            if !account.projects.contains(where: { $0.id == harvestProjectID }) {
                harvestProjectID = account.projects.count == 1 ? account.projects.first?.id : nil
            }

            syncHarvestTaskSelection()
        }
        .onChange(of: harvestProjectID) { _, _ in
            syncHarvestTaskSelection()
        }
    }

    @ViewBuilder
    private var togglSection: some View {
        Section("Toggl") {
            if togglCatalogs.isEmpty {
                unavailableTrackerText("Toggl workspace data is unavailable. Reconnect Toggl in Settings.")
            } else {
                if togglCatalogs.count > 1 {
                    Picker("Workspace", selection: $togglWorkspaceID) {
                        Text("Select workspace").tag(nil as Int?)
                        ForEach(togglCatalogs) { workspace in
                            Text(workspace.workspace.name).tag(Optional(workspace.workspace.id))
                        }
                    }
                } else if let workspace = togglCatalogs.first {
                    resolvedRow(label: "Workspace", value: workspace.workspace.name)
                }

                let projects = selectedTogglWorkspace?.projects ?? []
                if projects.count > 1 {
                    Picker("Project", selection: $togglProjectID) {
                        Text("No specific project").tag(nil as Int?)
                        ForEach(projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                } else if let project = projects.first {
                    resolvedRow(label: "Project", value: project.name)
                }

                suggestionText(entry.togglTarget?.workspaceName, when: togglWorkspaceID == nil, label: "Workspace")
                suggestionText(entry.togglTarget?.projectName, when: togglProjectID == nil, label: "Project")
            }
        }
    }

    @ViewBuilder
    private var clockifySection: some View {
        Section("Clockify") {
            if clockifyCatalogs.isEmpty {
                unavailableTrackerText("Clockify workspace data is unavailable. Reconnect Clockify in Settings.")
            } else {
                if clockifyCatalogs.count > 1 {
                    Picker("Workspace", selection: $clockifyWorkspaceID) {
                        Text("Select workspace").tag(nil as String?)
                        ForEach(clockifyCatalogs) { workspace in
                            Text(workspace.workspace.name).tag(Optional(workspace.workspace.id))
                        }
                    }
                } else if let workspace = clockifyCatalogs.first {
                    resolvedRow(label: "Workspace", value: workspace.workspace.name)
                }

                let projects = selectedClockifyWorkspace?.projects ?? []
                if projects.count > 1 {
                    Picker("Project", selection: $clockifyProjectID) {
                        Text("No specific project").tag(nil as String?)
                        ForEach(projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                } else if let project = projects.first {
                    resolvedRow(label: "Project", value: project.name)
                }

                suggestionText(entry.clockifyTarget?.workspaceName, when: clockifyWorkspaceID == nil, label: "Workspace")
                suggestionText(entry.clockifyTarget?.projectName, when: clockifyProjectID == nil, label: "Project")
            }
        }
    }

    @ViewBuilder
    private var harvestSection: some View {
        Section("Harvest") {
            if harvestCatalogs.isEmpty {
                unavailableTrackerText("Harvest assignment data is unavailable. Reconnect Harvest in Settings.")
            } else {
                if harvestCatalogs.count > 1 {
                    Picker("Account", selection: $harvestAccountID) {
                        Text("Select account").tag(nil as Int?)
                        ForEach(harvestCatalogs) { account in
                            Text(account.account.name).tag(Optional(account.account.id))
                        }
                    }
                } else if let account = harvestCatalogs.first {
                    resolvedRow(label: "Account", value: account.account.name)
                }

                let projects = selectedHarvestAccount?.projects ?? []
                if projects.count > 1 {
                    Picker("Project", selection: $harvestProjectID) {
                        Text("Select project").tag(nil as Int?)
                        ForEach(projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                } else if let project = projects.first {
                    resolvedRow(label: "Project", value: project.name)
                }

                let tasks = selectedHarvestProject?.taskAssignments ?? []
                if tasks.count > 1 {
                    Picker("Task", selection: $harvestTaskID) {
                        Text("Select task").tag(nil as Int?)
                        ForEach(tasks) { task in
                            Text(task.name).tag(Optional(task.id))
                        }
                    }
                } else if let task = tasks.first {
                    resolvedRow(label: "Task", value: task.name)
                }

                suggestionText(entry.harvestTarget?.accountName, when: harvestAccountID == nil, label: "Account")
                suggestionText(entry.harvestTarget?.projectName, when: harvestProjectID == nil, label: "Project")
                suggestionText(entry.harvestTarget?.taskName, when: harvestTaskID == nil, label: "Task")
            }
        }
    }

    @ViewBuilder
    private func unavailableTrackerText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func resolvedRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func suggestionText(_ suggestion: String?, when condition: Bool, label: String) -> some View {
        if condition, let suggestion = suggestion?.trimmed.nilIfBlank {
            Text("AI suggested \(label.lowercased()): \(suggestion)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func syncHarvestTaskSelection() {
        let tasks = selectedHarvestProject?.taskAssignments ?? []
        if !tasks.contains(where: { $0.id == harvestTaskID }) {
            harvestTaskID = tasks.count == 1 ? tasks.first?.id : nil
        }
    }

    private func save() {
        var updated = entry
        updated.start = start
        updated.stop = stop
        updated.description = descriptionText
        updated.tags = tagsText.split(separator: ",").map { String($0) }
        updated.billable = billableChoice.value

        if enabledTrackers.contains(.toggl) {
            updated.togglTarget = makeTogglTarget()
        }

        if enabledTrackers.contains(.clockify) {
            updated.clockifyTarget = makeClockifyTarget()
        }

        if enabledTrackers.contains(.harvest) {
            updated.harvestTarget = makeHarvestTarget()
        }

        onSave(updated)
        dismiss()
    }

    private func makeTogglTarget() -> CandidateTimeEntry.TogglTarget? {
        let workspace = selectedTogglWorkspace
        let project = workspace?.projects.first(where: { $0.id == togglProjectID })

        let target = CandidateTimeEntry.TogglTarget(
            workspaceName: workspace?.workspace.name ?? entry.togglTarget?.workspaceName?.trimmed.nilIfBlank,
            workspaceId: workspace?.workspace.id,
            projectName: project?.name ?? entry.togglTarget?.projectName?.trimmed.nilIfBlank,
            projectId: project?.id
        )

        return target.hasSelection ? target : nil
    }

    private func makeClockifyTarget() -> CandidateTimeEntry.ClockifyTarget? {
        let workspace = selectedClockifyWorkspace
        let project = workspace?.projects.first(where: { $0.id == clockifyProjectID })

        let target = CandidateTimeEntry.ClockifyTarget(
            workspaceName: workspace?.workspace.name ?? entry.clockifyTarget?.workspaceName?.trimmed.nilIfBlank,
            workspaceId: workspace?.workspace.id,
            projectName: project?.name ?? entry.clockifyTarget?.projectName?.trimmed.nilIfBlank,
            projectId: project?.id
        )

        return target.hasSelection ? target : nil
    }

    private func makeHarvestTarget() -> CandidateTimeEntry.HarvestTarget? {
        let account = selectedHarvestAccount
        let project = selectedHarvestProject
        let task = project?.taskAssignments.first(where: { $0.id == harvestTaskID })

        let target = CandidateTimeEntry.HarvestTarget(
            accountName: account?.account.name ?? entry.harvestTarget?.accountName?.trimmed.nilIfBlank,
            accountId: account?.account.id,
            projectName: project?.name ?? entry.harvestTarget?.projectName?.trimmed.nilIfBlank,
            projectId: project?.id,
            taskName: task?.name ?? entry.harvestTarget?.taskName?.trimmed.nilIfBlank,
            taskId: task?.id
        )

        return target.hasSelection ? target : nil
    }
}

#if DEBUG
private enum EntryEditorPreviewData {
    static let timeZone = TimeZone(identifier: "Europe/Ljubljana") ?? .autoupdatingCurrent

    static let togglCatalogs = [
        TogglWorkspaceCatalog(
            workspace: WorkspaceSummary(id: 101, name: "Client Work"),
            projects: [
                ProjectSummary(id: 1_001, name: "Tajnica s.p. macOS", workspaceId: 101),
                ProjectSummary(id: 1_002, name: "Admin", workspaceId: 101)
            ]
        ),
        TogglWorkspaceCatalog(
            workspace: WorkspaceSummary(id: 102, name: "Internal"),
            projects: [
                ProjectSummary(id: 1_003, name: "Ops", workspaceId: 102)
            ]
        )
    ]

    static let clockifyCatalogs = [
        ClockifyWorkspaceCatalog(
            workspace: ClockifyWorkspaceSummary(id: "clockify-client", name: "Client Workspace"),
            projects: [
                ClockifyProjectSummary(id: "clockify-planner", name: "Tajnica s.p. Refresh", workspaceId: "clockify-client"),
                ClockifyProjectSummary(id: "clockify-support", name: "Support", workspaceId: "clockify-client")
            ]
        ),
        ClockifyWorkspaceCatalog(
            workspace: ClockifyWorkspaceSummary(id: "clockify-internal", name: "Internal Workspace"),
            projects: [
                ClockifyProjectSummary(id: "clockify-rd", name: "R&D", workspaceId: "clockify-internal")
            ]
        )
    ]

    static let harvestCatalogs = [
        HarvestAccountCatalog(
            account: HarvestAccountSummary(id: 201, name: "Acme Studio"),
            projects: [
                HarvestProjectSummary(
                    id: 2_001,
                    name: "Tajnica s.p. Product",
                    taskAssignments: [
                        HarvestTaskSummary(id: 3_001, name: "Feature Development"),
                        HarvestTaskSummary(id: 3_002, name: "Bugfixing")
                    ]
                ),
                HarvestProjectSummary(
                    id: 2_002,
                    name: "Discovery",
                    taskAssignments: [
                        HarvestTaskSummary(id: 3_003, name: "Research")
                    ]
                )
            ]
        ),
        HarvestAccountCatalog(
            account: HarvestAccountSummary(id: 202, name: "Internal Org"),
            projects: [
                HarvestProjectSummary(
                    id: 2_003,
                    name: "Operations",
                    taskAssignments: [
                        HarvestTaskSummary(id: 3_004, name: "Planning")
                    ]
                )
            ]
        )
    ]

    static var entry: CandidateTimeEntry {
        CandidateTimeEntry(
            date: day,
            start: date(hour: 9, minute: 30),
            stop: date(hour: 11, minute: 0),
            description: "Refine the EntryEditor preview and sync review flow",
            togglTarget: CandidateTimeEntry.TogglTarget(
                workspaceName: "Client Work",
                workspaceId: 101,
                projectName: "Tajnica s.p. macOS",
                projectId: 1_001
            ),
            clockifyTarget: CandidateTimeEntry.ClockifyTarget(
                workspaceName: "Client Workspace",
                workspaceId: "clockify-client",
                projectName: "Tajnica s.p. Refresh",
                projectId: "clockify-planner"
            ),
            harvestTarget: CandidateTimeEntry.HarvestTarget(
                accountName: "Acme Studio",
                accountId: 201,
                projectName: "Tajnica s.p. Product",
                projectId: 2_001,
                taskName: "Feature Development",
                taskId: 3_001
            ),
            tags: ["swiftui", "preview", "review"],
            billable: true,
            source: .user
        )
    }

    private static var day: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 16
        ))!
    }

    private static func date(hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 16,
            hour: hour,
            minute: minute
        ))!
    }
}

#Preview("Entry Editor", traits: .fixedLayout(width: 420, height: 720)) {
    EntryEditorView(
        entry: EntryEditorPreviewData.entry,
        togglCatalogs: EntryEditorPreviewData.togglCatalogs,
        clockifyCatalogs: EntryEditorPreviewData.clockifyCatalogs,
        harvestCatalogs: EntryEditorPreviewData.harvestCatalogs,
        enabledTrackers: Set(TimeTrackerProvider.allCases),
        onSave: { _ in }
    )
}
#endif
