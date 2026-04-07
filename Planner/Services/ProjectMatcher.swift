import Foundation

enum ProjectMatcher {
    static func assignProjects(
        from projects: [ProjectSummary],
        to entries: [CandidateTimeEntry]
    ) -> [CandidateTimeEntry] {
        let lookup = Dictionary(uniqueKeysWithValues: projects.map { project in
            (normalized(project.name), project)
        })

        return entries.map { entry in
            guard let projectName = entry.projectName?.trimmed,
                  let project = lookup[normalized(projectName)] else {
                return entry
            }

            var copy = entry
            copy.projectName = project.name
            copy.projectId = project.id
            copy.workspaceId = project.workspaceId
            return copy
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
