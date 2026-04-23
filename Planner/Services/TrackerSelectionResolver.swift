import Foundation

enum TrackerSelectionResolver {
    static func resolve(
        entries: [CandidateTimeEntry],
        context: LLMExtractionContext
    ) -> [CandidateTimeEntry] {
        entries.map { entry in
            var copy = entry
            copy.togglTarget = resolveTogglTarget(copy.togglTarget, workspaces: context.togglWorkspaces)
            copy.clockifyTarget = resolveClockifyTarget(copy.clockifyTarget, workspaces: context.clockifyWorkspaces)
            copy.harvestTarget = resolveHarvestTarget(copy.harvestTarget, accounts: context.harvestAccounts)
            return copy
        }
    }

    private static func resolveTogglTarget(
        _ target: CandidateTimeEntry.TogglTarget?,
        workspaces: [TogglWorkspaceCatalog]
    ) -> CandidateTimeEntry.TogglTarget? {
        guard !workspaces.isEmpty else { return nil }

        let rawTarget = target
        let singleWorkspace = workspaces.count == 1 ? workspaces.first : nil
        var resolvedWorkspace = matchTogglWorkspace(named: rawTarget?.workspaceName, workspaces: workspaces)
        var resolvedProject: ProjectSummary?

        if let projectName = rawTarget?.projectName?.trimmed.nilIfBlank {
            if let resolvedWorkspace {
                resolvedProject = matchTogglProject(
                    named: projectName,
                    projects: resolvedWorkspace.projects
                )
            } else {
                let matches = allTogglProjectMatches(named: projectName, workspaces: workspaces)
                if matches.count == 1, let match = matches.first {
                    resolvedWorkspace = match.workspace
                    resolvedProject = match.project
                }
            }
        }

        if resolvedWorkspace == nil {
            resolvedWorkspace = singleWorkspace
        }

        if resolvedProject == nil,
           let resolvedWorkspace,
           resolvedWorkspace.projects.count == 1 {
            resolvedProject = resolvedWorkspace.projects.first
        }

        if resolvedWorkspace == nil && resolvedProject == nil && !(rawTarget?.hasSelection ?? false) {
            return nil
        }

        return CandidateTimeEntry.TogglTarget(
            workspaceName: resolvedWorkspace?.workspace.name ?? rawTarget?.workspaceName?.trimmed.nilIfBlank,
            workspaceId: resolvedWorkspace?.workspace.id,
            projectName: resolvedProject?.name ?? rawTarget?.projectName?.trimmed.nilIfBlank,
            projectId: resolvedProject?.id
        )
    }

    private static func resolveClockifyTarget(
        _ target: CandidateTimeEntry.ClockifyTarget?,
        workspaces: [ClockifyWorkspaceCatalog]
    ) -> CandidateTimeEntry.ClockifyTarget? {
        guard !workspaces.isEmpty else { return nil }

        let rawTarget = target
        let singleWorkspace = workspaces.count == 1 ? workspaces.first : nil
        var resolvedWorkspace = matchClockifyWorkspace(named: rawTarget?.workspaceName, workspaces: workspaces)
        var resolvedProject: ClockifyProjectSummary?

        if let projectName = rawTarget?.projectName?.trimmed.nilIfBlank {
            if let resolvedWorkspace {
                resolvedProject = matchClockifyProject(
                    named: projectName,
                    projects: resolvedWorkspace.projects
                )
            } else {
                let matches = allClockifyProjectMatches(named: projectName, workspaces: workspaces)
                if matches.count == 1, let match = matches.first {
                    resolvedWorkspace = match.workspace
                    resolvedProject = match.project
                }
            }
        }

        if resolvedWorkspace == nil {
            resolvedWorkspace = singleWorkspace
        }

        if resolvedProject == nil,
           let resolvedWorkspace,
           resolvedWorkspace.projects.count == 1 {
            resolvedProject = resolvedWorkspace.projects.first
        }

        if resolvedWorkspace == nil && resolvedProject == nil && !(rawTarget?.hasSelection ?? false) {
            return nil
        }

        return CandidateTimeEntry.ClockifyTarget(
            workspaceName: resolvedWorkspace?.workspace.name ?? rawTarget?.workspaceName?.trimmed.nilIfBlank,
            workspaceId: resolvedWorkspace?.workspace.id,
            projectName: resolvedProject?.name ?? rawTarget?.projectName?.trimmed.nilIfBlank,
            projectId: resolvedProject?.id
        )
    }

    private static func resolveHarvestTarget(
        _ target: CandidateTimeEntry.HarvestTarget?,
        accounts: [HarvestAccountCatalog]
    ) -> CandidateTimeEntry.HarvestTarget? {
        guard !accounts.isEmpty else { return nil }

        let rawTarget = target
        let singleAccount = accounts.count == 1 ? accounts.first : nil
        var resolvedAccount = matchHarvestAccount(named: rawTarget?.accountName, accounts: accounts)
        var resolvedProject: HarvestProjectSummary?
        var resolvedTask: HarvestTaskSummary?

        if let projectName = rawTarget?.projectName?.trimmed.nilIfBlank {
            if let resolvedAccount {
                resolvedProject = matchHarvestProject(named: projectName, projects: resolvedAccount.projects)
            } else {
                let matches = allHarvestProjectMatches(named: projectName, accounts: accounts)
                if matches.count == 1, let match = matches.first {
                    resolvedAccount = match.account
                    resolvedProject = match.project
                }
            }
        }

        if let taskName = rawTarget?.taskName?.trimmed.nilIfBlank {
            if let resolvedProject {
                resolvedTask = matchHarvestTask(named: taskName, tasks: resolvedProject.taskAssignments)
            } else if let resolvedAccount {
                let matches = allHarvestTaskMatches(named: taskName, accounts: [resolvedAccount])
                if matches.count == 1, let match = matches.first {
                    resolvedProject = match.project
                    resolvedTask = match.task
                }
            } else {
                let matches = allHarvestTaskMatches(named: taskName, accounts: accounts)
                if matches.count == 1, let match = matches.first {
                    resolvedAccount = match.account
                    resolvedProject = match.project
                    resolvedTask = match.task
                }
            }
        }

        if resolvedAccount == nil {
            resolvedAccount = singleAccount
        }

        if resolvedProject == nil,
           let resolvedAccount,
           resolvedAccount.projects.count == 1 {
            resolvedProject = resolvedAccount.projects.first
        }

        if resolvedTask == nil,
           let resolvedProject,
           resolvedProject.taskAssignments.count == 1 {
            resolvedTask = resolvedProject.taskAssignments.first
        }

        if resolvedAccount == nil
            && resolvedProject == nil
            && resolvedTask == nil
            && !(rawTarget?.hasSelection ?? false) {
            return nil
        }

        return CandidateTimeEntry.HarvestTarget(
            accountName: resolvedAccount?.account.name ?? rawTarget?.accountName?.trimmed.nilIfBlank,
            accountId: resolvedAccount?.account.id,
            projectName: resolvedProject?.name ?? rawTarget?.projectName?.trimmed.nilIfBlank,
            projectId: resolvedProject?.id,
            taskName: resolvedTask?.name ?? rawTarget?.taskName?.trimmed.nilIfBlank,
            taskId: resolvedTask?.id
        )
    }

    private static func matchTogglWorkspace(
        named name: String?,
        workspaces: [TogglWorkspaceCatalog]
    ) -> TogglWorkspaceCatalog? {
        guard let normalizedName = normalized(name) else { return nil }
        return workspaces.first { normalized($0.workspace.name) == normalizedName }
    }

    private static func matchTogglProject(named name: String, projects: [ProjectSummary]) -> ProjectSummary? {
        let normalizedName = normalized(name)
        return projects.first { normalized($0.name) == normalizedName }
    }

    private static func allTogglProjectMatches(
        named name: String,
        workspaces: [TogglWorkspaceCatalog]
    ) -> [(workspace: TogglWorkspaceCatalog, project: ProjectSummary)] {
        let normalizedName = normalized(name)
        return workspaces.flatMap { workspace in
            workspace.projects.compactMap { project in
                guard normalized(project.name) == normalizedName else { return nil }
                return (workspace: workspace, project: project)
            }
        }
    }

    private static func matchClockifyWorkspace(
        named name: String?,
        workspaces: [ClockifyWorkspaceCatalog]
    ) -> ClockifyWorkspaceCatalog? {
        guard let normalizedName = normalized(name) else { return nil }
        return workspaces.first { normalized($0.workspace.name) == normalizedName }
    }

    private static func matchClockifyProject(
        named name: String,
        projects: [ClockifyProjectSummary]
    ) -> ClockifyProjectSummary? {
        let normalizedName = normalized(name)
        return projects.first { normalized($0.name) == normalizedName }
    }

    private static func allClockifyProjectMatches(
        named name: String,
        workspaces: [ClockifyWorkspaceCatalog]
    ) -> [(workspace: ClockifyWorkspaceCatalog, project: ClockifyProjectSummary)] {
        let normalizedName = normalized(name)
        return workspaces.flatMap { workspace in
            workspace.projects.compactMap { project in
                guard normalized(project.name) == normalizedName else { return nil }
                return (workspace: workspace, project: project)
            }
        }
    }

    private static func matchHarvestAccount(
        named name: String?,
        accounts: [HarvestAccountCatalog]
    ) -> HarvestAccountCatalog? {
        guard let normalizedName = normalized(name) else { return nil }
        return accounts.first { normalized($0.account.name) == normalizedName }
    }

    private static func matchHarvestProject(
        named name: String,
        projects: [HarvestProjectSummary]
    ) -> HarvestProjectSummary? {
        let normalizedName = normalized(name)
        return projects.first { normalized($0.name) == normalizedName }
    }

    private static func allHarvestProjectMatches(
        named name: String,
        accounts: [HarvestAccountCatalog]
    ) -> [(account: HarvestAccountCatalog, project: HarvestProjectSummary)] {
        let normalizedName = normalized(name)
        return accounts.flatMap { account in
            account.projects.compactMap { project in
                guard normalized(project.name) == normalizedName else { return nil }
                return (account: account, project: project)
            }
        }
    }

    private static func matchHarvestTask(
        named name: String,
        tasks: [HarvestTaskSummary]
    ) -> HarvestTaskSummary? {
        let normalizedName = normalized(name)
        return tasks.first { normalized($0.name) == normalizedName }
    }

    private static func allHarvestTaskMatches(
        named name: String,
        accounts: [HarvestAccountCatalog]
    ) -> [(account: HarvestAccountCatalog, project: HarvestProjectSummary, task: HarvestTaskSummary)] {
        let normalizedName = normalized(name)
        return accounts.flatMap { account in
            account.projects.flatMap { project in
                project.taskAssignments.compactMap { task in
                    guard normalized(task.name) == normalizedName else { return nil }
                    return (account: account, project: project, task: task)
                }
            }
        }
    }

    private static func normalized(_ value: String?) -> String? {
        value?
            .trimmed
            .nilIfBlank?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func normalized(_ value: String) -> String {
        normalized(Optional(value)) ?? ""
    }
}
