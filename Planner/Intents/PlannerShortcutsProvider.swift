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
                "Log time in \(.applicationName)",
                "Add a time entry to \(.applicationName)"
            ],
            shortTitle: "Log Time",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: UpdateDraftEntryIntent(),
            phrases: [
                "Update a draft entry in \(.applicationName)",
                "Edit an entry in \(.applicationName)"
            ],
            shortTitle: "Update Entry",
            systemImageName: "slider.horizontal.3"
        )

        AppShortcut(
            intent: ProcessCurrentDraftIntent(),
            phrases: [
                "Process my \(.applicationName) draft",
                "Review my \(.applicationName) draft"
            ],
            shortTitle: "Process Draft",
            systemImageName: "wand.and.stars"
        )

        AppShortcut(
            intent: AssignTogglProjectIntent(),
            phrases: [
                "Set the Toggl project in \(.applicationName)",
                "Assign a Toggl project in \(.applicationName)"
            ],
            shortTitle: "Toggl Project",
            systemImageName: "briefcase"
        )

        AppShortcut(
            intent: AssignClockifyProjectIntent(),
            phrases: [
                "Set the Clockify project in \(.applicationName)",
                "Assign a Clockify project in \(.applicationName)"
            ],
            shortTitle: "Clockify Project",
            systemImageName: "clock.badge"
        )

        AppShortcut(
            intent: AssignHarvestTaskIntent(),
            phrases: [
                "Set the Harvest task in \(.applicationName)",
                "Assign a Harvest task in \(.applicationName)"
            ],
            shortTitle: "Harvest Task",
            systemImageName: "checklist"
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
                "Review entries in \(.applicationName)"
            ],
            shortTitle: "Review Entries",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: SubmitCurrentDraftIntent(),
            phrases: [
                "Submit my \(.applicationName) entries",
                "Send my \(.applicationName) entries"
            ],
            shortTitle: "Submit Draft",
            systemImageName: "paperplane"
        )
    }
}
