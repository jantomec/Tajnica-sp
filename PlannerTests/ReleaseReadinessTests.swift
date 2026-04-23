import Foundation
import Testing

@testable import Tajnica_sp

struct ReleaseReadinessTests {
    @Test
    func disabledLLMCopyUsesReleaseName() {
        #expect(LLMProvider.disabled.tradeoffSummary.contains(AppConfiguration.displayName))
        #expect(!LLMProvider.disabled.tradeoffSummary.contains("Planner will use"))
        #expect(LLMProvider.disabled.configurationHint?.contains(AppConfiguration.displayName) == true)
        #expect(LLMProvider.disabled.configurationHint?.contains("do not want Planner") == false)
    }

    @Test
    func exportFilenamePrefixMatchesReleaseBrand() {
        #expect(AppConfiguration.exportFilenamePrefix == "tajnica-sp-time-tracker")
        #expect(!AppConfiguration.exportFilenamePrefix.contains("planner"))
    }

    @Test
    func appSourcesDoNotLeakLegacyPlannerIntoStringLiterals() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSources = repoRoot.appendingPathComponent("Planner")

        // Storage namespaces and bundle-identifier fallbacks that
        // RELEASE_CHECKLIST.md records as intentionally preserved.
        let allowedLinePatterns: [String] = [
            "?? \"Planner\"",
            "static let appName = \"Planner\"",
            "\"PlannerSync\"",
            "\"PlannerSyncInMemory\""
        ]

        var violations: [String] = []
        for file in try swiftFiles(under: appSources) {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in contents.components(separatedBy: "\n").enumerated() {
                guard stringLiteralsContainPlanner(in: line) else { continue }
                if allowedLinePatterns.contains(where: { line.contains($0) }) { continue }
                let relative = file.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                violations.append("\(relative):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }

        let message: Comment = "Legacy Planner copy in user-facing sources:\n\(violations.joined(separator: "\n"))"
        #expect(violations.isEmpty, message)
    }

    private func swiftFiles(under url: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var files: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            files.append(fileURL)
        }
        return files
    }

    private func stringLiteralsContainPlanner(in line: String) -> Bool {
        var cleaned = line
        while let match = cleaned.range(of: #"\\\([^)]*\)"#, options: .regularExpression) {
            cleaned.replaceSubrange(match, with: "")
        }

        var inString = false
        var escape = false
        var literal = ""
        for ch in cleaned {
            if escape {
                escape = false
                if inString { literal.append(ch) }
                continue
            }
            if ch == "\\" {
                escape = true
                continue
            }
            if ch == "\"" {
                if inString {
                    if literal.contains("Planner") { return true }
                    literal = ""
                }
                inString.toggle()
                continue
            }
            if inString { literal.append(ch) }
        }
        return false
    }
}
