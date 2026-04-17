import AppIntents

struct PlannerShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor {
        .teal
    }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AppendToCurrentDraftIntent(),
            phrases: [
                "Add to \(.applicationName)",
                "Append to \(.applicationName)"
            ],
            shortTitle: "Add Note",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: AddDraftEntryIntent(),
            phrases: [
                "Add a time entry to \(.applicationName)",
                "Add an entry in \(.applicationName)"
            ],
            shortTitle: "Add Entry",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: UpdateDraftEntryIntent(),
            phrases: [
                "Update an entry in \(.applicationName)",
                "Edit an entry in \(.applicationName)"
            ],
            shortTitle: "Update Entry",
            systemImageName: "slider.horizontal.3"
        )

        AppShortcut(
            intent: DeleteDraftEntryIntent(),
            phrases: [
                "Delete an entry from \(.applicationName)",
                "Remove an entry from \(.applicationName)"
            ],
            shortTitle: "Delete Entry",
            systemImageName: "trash"
        )

        AppShortcut(
            intent: ProcessCurrentDraftIntent(),
            phrases: [
                "Process my \(.applicationName) draft",
                "Process \(.applicationName)"
            ],
            shortTitle: "Process Draft",
            systemImageName: "wand.and.stars"
        )

        AppShortcut(
            intent: ShowCurrentDraftSummaryIntent(),
            phrases: [
                "Show my \(.applicationName) draft",
                "What's in \(.applicationName)"
            ],
            shortTitle: "Draft Summary",
            systemImageName: "doc.text.magnifyingglass"
        )

        AppShortcut(
            intent: OpenPlannerCaptureIntent(),
            phrases: [
                "Open Capture in \(.applicationName)",
                "Show Capture in \(.applicationName)"
            ],
            shortTitle: "Open Capture",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: OpenPlannerReviewIntent(),
            phrases: [
                "Open Review in \(.applicationName)",
                "Show Review in \(.applicationName)"
            ],
            shortTitle: "Open Review",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: SubmitCurrentDraftIntent(),
            phrases: [
                "Submit my \(.applicationName) entries",
                "Submit \(.applicationName)"
            ],
            shortTitle: "Submit Draft",
            systemImageName: "paperplane"
        )
    }
}
