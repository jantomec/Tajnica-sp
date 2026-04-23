import Foundation

struct LLMExtractionContext {
    var userContext: String?
    var togglWorkspaces: [TogglWorkspaceCatalog]
    var clockifyWorkspaces: [ClockifyWorkspaceCatalog]
    var harvestAccounts: [HarvestAccountCatalog]

    var hasTrackerReferenceData: Bool {
        !togglWorkspaces.isEmpty || !clockifyWorkspaces.isEmpty || !harvestAccounts.isEmpty
    }
}

enum LLMExtractionPromptBuilder {
    static func makeUserPrompt(
        selectedDate: Date,
        timeZone: TimeZone,
        note: String,
        context: LLMExtractionContext
    ) -> String {
        let isoDate = PlannerFormatters.isoLocalDateString(selectedDate, timeZone: timeZone)
        var prompt = """
        Today's date is \(isoDate).
        Local timezone: \(timeZone.identifier)

        User note:
        \(note)
        """

        if let userContext = context.userContext?.trimmed.nilIfBlank {
            prompt += "\n\nUser context (use this to better understand the user's work patterns):\n\(userContext)"
        }

        if !context.togglWorkspaces.isEmpty {
            prompt += "\n\nToggl reference data:\n\(togglPromptSection(from: context.togglWorkspaces))"
        }

        if !context.clockifyWorkspaces.isEmpty {
            prompt += "\n\nClockify reference data:\n\(clockifyPromptSection(from: context.clockifyWorkspaces))"
        }

        if !context.harvestAccounts.isEmpty {
            prompt += "\n\nHarvest reference data:\n\(harvestPromptSection(from: context.harvestAccounts))"
        }

        return prompt
    }

    static var systemInstruction: String {
        """
        Convert the user's note into candidate time entries for \(AppConfiguration.displayName).
        Determine the correct date for each entry from the note content.
        If the note says "yesterday" or references a past day, use that day's date (YYYY-MM-DD).
        If no specific day is mentioned, default to today's date.
        Each entry MUST include a date_local field in YYYY-MM-DD format.
        Infer reasonable contiguous time blocks.
        Do not fabricate high-confidence details that are not supported by the note.
        Keep descriptions concise and suitable for time tracking.
        If user context is provided, use it to make better inferences about working hours, typical activities, and tracker targets.
        If tracker reference data is provided, choose the most appropriate target names for each enabled service.
        Use exact names from the provided tracker reference data when selecting tracker targets.
        Leave tracker target fields null when:
        - that tracker is not enabled,
        - the choice is trivial and the app can auto-select it,
        - or the note does not support a confident choice.
        Never invent tracker names that are not present in the provided reference data.
        Return structured content that matches the requested schema exactly.
        """
    }

    static var jsonSchemaSummary: String {
        """
        {
          "entries": [{
            "date_local": "YYYY-MM-DD",
            "start_local": "HH:mm",
            "stop_local": "HH:mm",
            "description": "string",
            "toggl_workspace_name": "string or null",
            "toggl_project_name": "string or null",
            "clockify_workspace_name": "string or null",
            "clockify_project_name": "string or null",
            "harvest_account_name": "string or null",
            "harvest_project_name": "string or null",
            "harvest_task_name": "string or null",
            "tags": ["string"],
            "billable": true/false/null
          }],
          "assumptions": ["string"],
          "summary": "string or null"
        }
        """
    }

    static func responseSchema(additionalPropertiesDisallowed: Bool = false) -> [String: Any] {
        var entryItem: [String: Any] = [
            "type": "object",
            "properties": [
                "date_local": ["type": "string"],
                "start_local": ["type": "string"],
                "stop_local": ["type": "string"],
                "description": ["type": "string"],
                "toggl_workspace_name": ["type": ["string", "null"]],
                "toggl_project_name": ["type": ["string", "null"]],
                "clockify_workspace_name": ["type": ["string", "null"]],
                "clockify_project_name": ["type": ["string", "null"]],
                "harvest_account_name": ["type": ["string", "null"]],
                "harvest_project_name": ["type": ["string", "null"]],
                "harvest_task_name": ["type": ["string", "null"]],
                "tags": [
                    "type": "array",
                    "items": ["type": "string"]
                ],
                "billable": ["type": ["boolean", "null"]]
            ],
            "required": [
                "date_local",
                "start_local",
                "stop_local",
                "description",
                "toggl_workspace_name",
                "toggl_project_name",
                "clockify_workspace_name",
                "clockify_project_name",
                "harvest_account_name",
                "harvest_project_name",
                "harvest_task_name",
                "tags",
                "billable"
            ]
        ]

        var root: [String: Any] = [
            "type": "object",
            "properties": [
                "entries": [
                    "type": "array",
                    "items": entryItem
                ],
                "assumptions": [
                    "type": "array",
                    "items": ["type": "string"]
                ],
                "summary": ["type": ["string", "null"]]
            ],
            "required": ["entries", "assumptions", "summary"]
        ]

        if additionalPropertiesDisallowed {
            entryItem["additionalProperties"] = false
            var properties = root["properties"] as? [String: Any] ?? [:]
            properties["entries"] = [
                "type": "array",
                "items": entryItem
            ] as [String: Any]
            root["properties"] = properties
            root["additionalProperties"] = false
        }

        return root
    }

    private static func togglPromptSection(from workspaces: [TogglWorkspaceCatalog]) -> String {
        var lines = [String]()

        if workspaces.count == 1, let workspace = workspaces.first {
            lines.append("There is exactly one Toggl workspace and the app can auto-select it if toggl_workspace_name is null.")
            lines.append("Workspace: \(workspace.workspace.name)")
        } else {
            lines.append("Use toggl_workspace_name when you need to distinguish between multiple Toggl workspaces.")
            for workspace in workspaces {
                lines.append("- Workspace: \(workspace.workspace.name)")
                appendProjectLines(workspace.projects, to: &lines)
            }
            return lines.joined(separator: "\n")
        }

        appendProjectLines(workspaces.first?.projects ?? [], to: &lines)
        return lines.joined(separator: "\n")
    }

    private static func clockifyPromptSection(from workspaces: [ClockifyWorkspaceCatalog]) -> String {
        var lines = [String]()

        if workspaces.count == 1, let workspace = workspaces.first {
            lines.append("There is exactly one Clockify workspace and the app can auto-select it if clockify_workspace_name is null.")
            lines.append("Workspace: \(workspace.workspace.name)")
        } else {
            lines.append("Use clockify_workspace_name when you need to distinguish between multiple Clockify workspaces.")
            for workspace in workspaces {
                lines.append("- Workspace: \(workspace.workspace.name)")
                appendClockifyProjectLines(workspace.projects, to: &lines)
            }
            return lines.joined(separator: "\n")
        }

        appendClockifyProjectLines(workspaces.first?.projects ?? [], to: &lines)
        return lines.joined(separator: "\n")
    }

    private static func harvestPromptSection(from accounts: [HarvestAccountCatalog]) -> String {
        var lines = [String]()

        if accounts.count == 1, let account = accounts.first {
            lines.append("There is exactly one Harvest account and the app can auto-select it if harvest_account_name is null.")
            lines.append("Account: \(account.account.name)")
            appendHarvestProjectLines(account.projects, to: &lines)
            return lines.joined(separator: "\n")
        }

        lines.append("Use harvest_account_name when you need to distinguish between multiple Harvest accounts.")
        for account in accounts {
            lines.append("- Account: \(account.account.name)")
            appendHarvestProjectLines(account.projects, to: &lines)
        }
        return lines.joined(separator: "\n")
    }

    private static func appendProjectLines(_ projects: [ProjectSummary], to lines: inout [String]) {
        if projects.isEmpty {
            lines.append("  Projects: none")
            return
        }

        if projects.count == 1, let project = projects.first {
            lines.append("  There is exactly one Toggl project here and the app can auto-select it if toggl_project_name is null.")
            lines.append("  Project: \(project.name)")
            return
        }

        lines.append("  Projects:")
        for project in projects {
            lines.append("  - \(project.name)")
        }
    }

    private static func appendClockifyProjectLines(_ projects: [ClockifyProjectSummary], to lines: inout [String]) {
        if projects.isEmpty {
            lines.append("  Projects: none")
            return
        }

        if projects.count == 1, let project = projects.first {
            lines.append("  There is exactly one Clockify project here and the app can auto-select it if clockify_project_name is null.")
            lines.append("  Project: \(project.name)")
            return
        }

        lines.append("  Projects:")
        for project in projects {
            lines.append("  - \(project.name)")
        }
    }

    private static func appendHarvestProjectLines(_ projects: [HarvestProjectSummary], to lines: inout [String]) {
        if projects.isEmpty {
            lines.append("  Projects: none")
            return
        }

        for project in projects {
            lines.append("  Project: \(project.name)")

            if project.taskAssignments.count == 1, let task = project.taskAssignments.first {
                lines.append("    There is exactly one Harvest task here and the app can auto-select it if harvest_task_name is null.")
                lines.append("    Task: \(task.name)")
            } else {
                lines.append("    Tasks:")
                for task in project.taskAssignments {
                    lines.append("    - \(task.name)")
                }
            }
        }
    }
}
