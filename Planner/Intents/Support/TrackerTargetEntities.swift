import AppIntents
import Foundation

struct TogglWorkspaceEntity: AppEntity, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Toggl Workspace"
    static let defaultQuery = TogglWorkspaceQuery()

    let id: Int
    let name: String

    init(workspace: WorkspaceSummary) {
        id = workspace.id
        name = workspace.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct TogglProjectEntity: AppEntity, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Toggl Project"
    static let defaultQuery = TogglProjectQuery()

    let id: String
    let workspaceID: Int
    let projectID: Int
    let workspaceName: String
    let projectName: String

    init(workspace: WorkspaceSummary, project: ProjectSummary) {
        id = Self.makeID(workspaceID: workspace.id, projectID: project.id)
        workspaceID = workspace.id
        projectID = project.id
        workspaceName = workspace.name
        projectName = project.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: projectName),
            subtitle: LocalizedStringResource(stringLiteral: workspaceName)
        )
    }

    private static func makeID(workspaceID: Int, projectID: Int) -> String {
        "\(workspaceID)|\(projectID)"
    }
}

struct ClockifyWorkspaceEntity: AppEntity, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Clockify Workspace"
    static let defaultQuery = ClockifyWorkspaceQuery()

    let id: String
    let name: String

    init(workspace: ClockifyWorkspaceSummary) {
        id = workspace.id
        name = workspace.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct ClockifyProjectEntity: AppEntity, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Clockify Project"
    static let defaultQuery = ClockifyProjectQuery()

    let id: String
    let workspaceID: String
    let projectID: String
    let workspaceName: String
    let projectName: String

    init(workspace: ClockifyWorkspaceSummary, project: ClockifyProjectSummary) {
        id = Self.makeID(workspaceID: workspace.id, projectID: project.id)
        workspaceID = workspace.id
        projectID = project.id
        workspaceName = workspace.name
        projectName = project.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: projectName),
            subtitle: LocalizedStringResource(stringLiteral: workspaceName)
        )
    }

    private static func makeID(workspaceID: String, projectID: String) -> String {
        "\(workspaceID)|\(projectID)"
    }
}

struct HarvestTaskEntity: AppEntity, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Harvest Task"
    static let defaultQuery = HarvestTaskQuery()

    let id: String
    let accountID: Int
    let projectID: Int
    let taskID: Int
    let accountName: String
    let projectName: String
    let taskName: String

    init(
        account: HarvestAccountSummary,
        project: HarvestProjectSummary,
        task: HarvestTaskSummary
    ) {
        id = Self.makeID(accountID: account.id, projectID: project.id, taskID: task.id)
        accountID = account.id
        projectID = project.id
        taskID = task.id
        accountName = account.name
        projectName = project.name
        taskName = task.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: taskName),
            subtitle: LocalizedStringResource(stringLiteral: "\(projectName) • \(accountName)")
        )
    }

    private static func makeID(accountID: Int, projectID: Int, taskID: Int) -> String {
        "\(accountID)|\(projectID)|\(taskID)"
    }
}

struct TogglWorkspaceQuery: EnumerableEntityQuery {
    func entities(for identifiers: [TogglWorkspaceEntity.ID]) async throws -> [TogglWorkspaceEntity] {
        let entities = try await PlannerIntentTrackerEntityLoader.togglWorkspaceEntities()
        let lookup = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        return identifiers.compactMap { lookup[$0] }
    }

    func allEntities() async throws -> [TogglWorkspaceEntity] {
        try await PlannerIntentTrackerEntityLoader.togglWorkspaceEntities()
    }
}

struct TogglProjectQuery: EnumerableEntityQuery {
    func entities(for identifiers: [TogglProjectEntity.ID]) async throws -> [TogglProjectEntity] {
        let entities = try await PlannerIntentTrackerEntityLoader.togglProjectEntities()
        let lookup = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        return identifiers.compactMap { lookup[$0] }
    }

    func allEntities() async throws -> [TogglProjectEntity] {
        try await PlannerIntentTrackerEntityLoader.togglProjectEntities()
    }
}

struct ClockifyWorkspaceQuery: EnumerableEntityQuery {
    func entities(for identifiers: [ClockifyWorkspaceEntity.ID]) async throws -> [ClockifyWorkspaceEntity] {
        let entities = try await PlannerIntentTrackerEntityLoader.clockifyWorkspaceEntities()
        let lookup = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        return identifiers.compactMap { lookup[$0] }
    }

    func allEntities() async throws -> [ClockifyWorkspaceEntity] {
        try await PlannerIntentTrackerEntityLoader.clockifyWorkspaceEntities()
    }
}

struct ClockifyProjectQuery: EnumerableEntityQuery {
    func entities(for identifiers: [ClockifyProjectEntity.ID]) async throws -> [ClockifyProjectEntity] {
        let entities = try await PlannerIntentTrackerEntityLoader.clockifyProjectEntities()
        let lookup = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        return identifiers.compactMap { lookup[$0] }
    }

    func allEntities() async throws -> [ClockifyProjectEntity] {
        try await PlannerIntentTrackerEntityLoader.clockifyProjectEntities()
    }
}

struct HarvestTaskQuery: EnumerableEntityQuery {
    func entities(for identifiers: [HarvestTaskEntity.ID]) async throws -> [HarvestTaskEntity] {
        let entities = try await PlannerIntentTrackerEntityLoader.harvestTaskEntities()
        let lookup = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        return identifiers.compactMap { lookup[$0] }
    }

    func allEntities() async throws -> [HarvestTaskEntity] {
        try await PlannerIntentTrackerEntityLoader.harvestTaskEntities()
    }
}

@MainActor
private enum PlannerIntentTrackerEntityLoader {
    static func togglWorkspaceEntities() async throws -> [TogglWorkspaceEntity] {
        let model = try await makeStartedAppModel()
        return model.togglWorkspaceCatalogs.map { TogglWorkspaceEntity(workspace: $0.workspace) }
    }

    static func togglProjectEntities() async throws -> [TogglProjectEntity] {
        let model = try await makeStartedAppModel()
        return model.togglWorkspaceCatalogs.flatMap { catalog in
            catalog.projects.map { project in
                TogglProjectEntity(workspace: catalog.workspace, project: project)
            }
        }
    }

    static func clockifyWorkspaceEntities() async throws -> [ClockifyWorkspaceEntity] {
        let model = try await makeStartedAppModel()
        return model.clockifyWorkspaceCatalogs.map { ClockifyWorkspaceEntity(workspace: $0.workspace) }
    }

    static func clockifyProjectEntities() async throws -> [ClockifyProjectEntity] {
        let model = try await makeStartedAppModel()
        return model.clockifyWorkspaceCatalogs.flatMap { catalog in
            catalog.projects.map { project in
                ClockifyProjectEntity(workspace: catalog.workspace, project: project)
            }
        }
    }

    static func harvestTaskEntities() async throws -> [HarvestTaskEntity] {
        let model = try await makeStartedAppModel()
        return model.harvestAccountCatalogs.flatMap { account in
            account.projects.flatMap { project in
                project.taskAssignments.map { task in
                    HarvestTaskEntity(account: account.account, project: project, task: task)
                }
            }
        }
    }

    private static func makeStartedAppModel() async throws -> PlannerAppModel {
        let persistenceController = try PlannerPersistenceController.live()
        let appModel = PlannerAppModel.live(
            syncRepository: persistenceController.repository,
            storageSyncMode: persistenceController.syncMode
        )
        await appModel.start()

        return appModel
    }
}
