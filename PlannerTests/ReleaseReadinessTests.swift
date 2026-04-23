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
    func shortcutPhrasesUseApplicationNamePlaceholder() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let providerURL = repoRoot
            .appendingPathComponent("Planner")
            .appendingPathComponent("Intents")
            .appendingPathComponent("PlannerShortcutsProvider.swift")
        let source = try String(contentsOf: providerURL, encoding: .utf8)

        let phrases = Self.extractShortcutPhrases(from: source)

        let enoughPhrases: Comment = "Expected to find shortcut phrases in PlannerShortcutsProvider.swift."
        #expect(phrases.count >= 10, enoughPhrases)

        for phrase in phrases {
            let placeholderMessage: Comment = "Shortcut phrase should use the \\(.applicationName) placeholder so Siri substitutes the release brand automatically, got: \"\(phrase)\""
            #expect(phrase.contains(#"\(.applicationName)"#), placeholderMessage)

            let legacyMessage: Comment = "Shortcut phrase must not reference the legacy Planner name: \"\(phrase)\""
            #expect(!phrase.contains("Planner"), legacyMessage)

            let hardcodedMessage: Comment = "Shortcut phrase should defer to \\(.applicationName) rather than hard-coding the brand: \"\(phrase)\""
            #expect(!phrase.contains("Tajnica"), hardcodedMessage)
        }
    }

    @Test
    func repositoryDocsUseReleaseNameAndDescribeCurrentFeatureSet() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let readme = try String(contentsOf: repoRoot.appendingPathComponent("README.md"), encoding: .utf8)
        let privacyPolicy = try String(
            contentsOf: repoRoot.appendingPathComponent("PRIVACY_POLICY.md"),
            encoding: .utf8
        )

        let readmeHeading: Comment = "README must lead with a release-branded H1."
        #expect(readme.hasPrefix("# \(AppConfiguration.displayName)"), readmeHeading)

        let privacyHeading: Comment = "Privacy policy must lead with the release-branded heading."
        #expect(privacyPolicy.hasPrefix("# Privacy Policy for \(AppConfiguration.displayName)"), privacyHeading)

        // The README should continuously describe the shipped feature surface. If any of these
        // topic keywords drops out, the doc is drifting from the current feature set.
        let requiredTerms: [String] = [
            "Apple Intelligence",
            "Apple Foundation Models",
            "Gemini",
            "Claude",
            "ChatGPT",
            "Toggl",
            "Clockify",
            "Harvest",
            "Capture",
            "Review",
            "Diary",
            "Settings",
            "Export",
            "Keychain",
            "iCloud"
        ]
        for term in requiredTerms {
            let message: Comment = "README must describe the current feature set by referencing \(term)."
            #expect(readme.contains(term), message)
        }
    }

    @Test
    func intentSourceFilesDoNotLeakLegacyBrand() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let intentsRoot = repoRoot
            .appendingPathComponent("Planner")
            .appendingPathComponent("Intents")

        var violations: [String] = []
        for file in try swiftFiles(under: intentsRoot) {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in contents.components(separatedBy: "\n").enumerated() {
                guard stringLiteralsContainPlanner(in: line) else { continue }
                let relative = file.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                violations.append("\(relative):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }

        let message: Comment = "Legacy Planner copy in Siri/Shortcuts intent sources:\n\(violations.joined(separator: "\n"))"
        #expect(violations.isEmpty, message)
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

    private static func extractShortcutPhrases(from source: String) -> [String] {
        let blockPattern = try! NSRegularExpression(
            pattern: #"phrases:\s*\[(.*?)\]"#,
            options: [.dotMatchesLineSeparators]
        )
        let literalPattern = try! NSRegularExpression(pattern: #""([^"]*)""#)

        var phrases: [String] = []
        let sourceRange = NSRange(source.startIndex..., in: source)
        for blockMatch in blockPattern.matches(in: source, range: sourceRange) {
            guard let blockRange = Range(blockMatch.range(at: 1), in: source) else { continue }
            let block = String(source[blockRange])
            let blockNSRange = NSRange(block.startIndex..., in: block)
            for literalMatch in literalPattern.matches(in: block, range: blockNSRange) {
                guard let literalRange = Range(literalMatch.range(at: 1), in: block) else { continue }
                phrases.append(String(block[literalRange]))
            }
        }
        return phrases
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
