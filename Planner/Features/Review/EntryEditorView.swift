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
    let availableProjects: [ProjectSummary]
    let onSave: (CandidateTimeEntry) -> Void

    @State private var start: Date
    @State private var stop: Date
    @State private var descriptionText: String
    @State private var tagsText: String
    @State private var projectName: String
    @State private var selectedProjectID: Int?
    @State private var billableChoice: BillableChoice

    init(
        entry: CandidateTimeEntry,
        availableProjects: [ProjectSummary],
        onSave: @escaping (CandidateTimeEntry) -> Void
    ) {
        self.entry = entry
        self.availableProjects = availableProjects
        self.onSave = onSave

        _start = State(initialValue: entry.start)
        _stop = State(initialValue: entry.stop)
        _descriptionText = State(initialValue: entry.description)
        _tagsText = State(initialValue: entry.tags.joined(separator: ", "))
        _projectName = State(initialValue: entry.projectName ?? "")
        _selectedProjectID = State(initialValue: entry.projectId)
        _billableChoice = State(initialValue: BillableChoice.from(entry.billable))
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

                Section("Project") {
                    if availableProjects.isEmpty {
                        TextField("Project name", text: $projectName)
                    } else {
                        Picker("Assigned project", selection: $selectedProjectID) {
                            Text("None").tag(nil as Int?)

                            ForEach(availableProjects) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }

                        if !projectName.trimmed.isEmpty, selectedProjectID == nil {
                            Text("Suggested by Gemini: \(projectName.trimmed)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
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
        .frame(minWidth: 360, minHeight: 320)
    }

    private func save() {
        var updated = entry
        updated.start = start
        updated.stop = stop
        updated.description = descriptionText
        updated.tags = tagsText.split(separator: ",").map { String($0) }
        updated.billable = billableChoice.value

        if let selectedProjectID,
           let project = availableProjects.first(where: { $0.id == selectedProjectID }) {
            updated.projectId = project.id
            updated.projectName = project.name
            updated.workspaceId = project.workspaceId
        } else {
            updated.projectId = nil
            updated.projectName = projectName.trimmed.nilIfBlank
            updated.workspaceId = nil
        }

        onSave(updated)
        dismiss()
    }
}
