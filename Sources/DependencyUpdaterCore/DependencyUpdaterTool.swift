import Foundation
import Yams

public typealias Dependency = [String: String]

public struct DependencyUpdaterTool {

    // MARK: - Properties
    private let excludedDirectories = ["Build", ".git", ".build", "DerivedData"]

    public init() {}

    public func run(projectRoot: String, dependenciesPath: String) throws {
        let deps = loadDependencies(at: dependenciesPath)

        let packageFiles = findPackageFiles(at: projectRoot)
        updatePackages(at: packageFiles, with: deps)

        let pbxprojFiles = findPBXProjFiles(at: projectRoot)
        updatePBXProjFiles(at: pbxprojFiles, with: deps)

        log("\n🎉 All done.")
    }
}

extension DependencyUpdaterTool {

    func log(_ message: String) {
        print(message)
    }

    func logError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    func loadDependencies(at dependenciesPath: String) -> Dependency {

        guard let yamlString = try? String(contentsOfFile: dependenciesPath, encoding: .utf8) else {
            logError("❌ Unable to read \(dependenciesPath)")
            exit(1)
        }

        do {
            let dependencies = try YAMLDecoder().decode(Dependency.self, from: yamlString)
            log("✅ Versions loaded:")
            for (name, version) in dependencies {
                log("  - \(name): \(version)")
            }
            return dependencies
        } catch {
            logError("❌ YAML decoding error in \(dependenciesPath): \(error)")
            exit(1)
        }
    }

    func findFiles(named fileName: String, at projectRoot: String) -> [String] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: projectRoot)

        var foundFiles: [String] = []

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")

            let shouldExclude = excludedDirectories.contains { excluded in
                relativePath.contains("/\(excluded)/") || relativePath.hasPrefix("\(excluded)/")
            }

            if shouldExclude {
                enumerator.skipDescendants()
                continue
            }

            if fileURL.lastPathComponent == fileName {
                foundFiles.append(fileURL.path)
            }
        }

        return foundFiles
    }

    func findPackageFiles(at projectRoot: String) -> [String] {
        let packageFiles = findFiles(named: "Package.swift", at: projectRoot)

        if packageFiles.isEmpty {
            log("⚠️ No Package.swift found in the repo (excluding ignored directories).")
            return []
        }

        log("\n🔍 Package.swift found:")
        packageFiles.forEach { log("  - \($0)") }

        return packageFiles
    }

    func findClosingParenthesis(in content: String, from start: String.Index) -> String.Index? {
        var depth = 1
        var inString = false
        var index = start

        while index < content.endIndex {
            let char = content[index]

            if char == "\"" {
                inString.toggle()
            } else if !inString {
                if char == "(" {
                    depth += 1
                } else if char == ")" {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }

            index = content.index(after: index)
        }

        return nil
    }

    func extractPackageName(from url: String) -> String? {
        guard let lastComponent = url.split(separator: "/").last else { return nil }
        var name = String(lastComponent)
        if name.hasSuffix(".git") {
            name = String(name.dropLast(4))
        }
        return name.isEmpty ? nil : name
    }

    func updatePackageContent(_ content: String, with deps: [String: String]) -> String {
        var result = content
        let packagePattern = #/\.package\(/#

        var searchStart = result.startIndex
        while let match = result[searchStart...].firstMatch(of: packagePattern) {
            let blockStart = match.range.lowerBound
            let afterOpen = match.range.upperBound

            guard let closingIndex = findClosingParenthesis(in: result, from: afterOpen) else {
                searchStart = afterOpen
                continue
            }

            let blockEnd = result.index(after: closingIndex)
            let block = String(result[blockStart..<blockEnd])

            let urlPattern = #/url:\s*"([^"]*)"/#
            guard let urlMatch = block.firstMatch(of: urlPattern),
                  let packageName = extractPackageName(from: String(urlMatch.1)),
                  let newVersion = deps[packageName] else {
                searchStart = blockEnd
                continue
            }

            let exactPattern = #/exact:\s*"([^"]*)"/#
            guard let _ = block.firstMatch(of: exactPattern) else {
                searchStart = blockEnd
                continue
            }

            let updatedBlock = block.replacing(exactPattern) { _ in
                "exact: \"\(newVersion)\""
            }

            result.replaceSubrange(blockStart..<blockEnd, with: updatedBlock)
            searchStart = result.index(blockStart, offsetBy: updatedBlock.count)
        }

        return result
    }

    func updatePackages(at paths: [String], with deps: [String: String]) {
        guard !paths.isEmpty else { return }

        for packagePath in paths {
            guard let content = try? String(contentsOfFile: packagePath, encoding: .utf8) else {
                log("⚠️ Unable to read \(packagePath)")
                continue
            }

            let newContent = updatePackageContent(content, with: deps)

            guard newContent != content else {
                log("ℹ️ No changes for Package.swift: \(packagePath)")
                continue
            }

            do {
                try newContent.write(toFile: packagePath, atomically: true, encoding: .utf8)
                log("📝 Updated Package.swift: \(packagePath)")
            } catch {
                log("❌ Write error for Package.swift \(packagePath): \(error)")
            }

        }
    }

    func findPBXProjFiles(at projectRoot: String) -> [String] {
        let pbxprojFiles = findFiles(named: "project.pbxproj", at: projectRoot)

        if pbxprojFiles.isEmpty {
            log("⚠️ No project.pbxproj found in the repo (excluding ignored directories).")
            return []
        }

        log("\n🔍 project.pbxproj found:")
        pbxprojFiles.forEach { log("  - \($0)") }

        return pbxprojFiles
    }

    func replacingPBXVersion(in line: String, key: String, with newValue: String) -> String {
        let quotedPattern = "(\(NSRegularExpression.escapedPattern(for: key))\\s*=\\s*\")([^\"]+)(\")"
        let unquotedPattern = "(\(NSRegularExpression.escapedPattern(for: key))\\s*=\\s*)([^;]+)(;)"

        // Try quoted pattern first: key = "value"
        if let regex = try? NSRegularExpression(pattern: quotedPattern, options: []) {
            let nsRange = NSRange(line.startIndex..., in: line)
            if regex.firstMatch(in: line, options: [], range: nsRange) != nil {
                let replaced = regex.stringByReplacingMatches(
                    in: line,
                    options: [],
                    range: nsRange,
                    withTemplate: "$1\(newValue)$3"
                )
                return replaced
            }
        }

        // Try unquoted pattern: key = value;
        if let regex = try? NSRegularExpression(pattern: unquotedPattern, options: []) {
            let nsRange = NSRange(line.startIndex..., in: line)
            if regex.firstMatch(in: line, options: [], range: nsRange) != nil {
                let replaced = regex.stringByReplacingMatches(
                    in: line,
                    options: [],
                    range: nsRange,
                    withTemplate: "$1\(newValue)$3"
                )
                return replaced
            }
        }

        return line
    }

    func updatePBXProjContent(_ content: String, with deps: [String: String]) -> String {
        var lines = content.components(separatedBy: .newlines)

        var currentDep: String? = nil

        for index in lines.indices {
            var line = lines[index]

            if currentDep == nil {
                for depName in deps.keys {
                    if line.contains(depName) {
                        currentDep = depName
                        break
                    }
                }
            }

            if let currentDep, let newVersion = deps[currentDep] {
                line = replacingPBXVersion(in: line, key: "minimumVersion", with: newVersion)
                line = replacingPBXVersion(in: line, key: "version", with: newVersion)
            }

            if line.contains("};") {
                currentDep = nil
            }

            lines[index] = line
        }

        return lines.joined(separator: "\n")
    }

    func updatePBXProjFiles(at paths: [String], with deps: [String: String]) {
        guard !paths.isEmpty else { return }

        for pbxPath in paths {
            guard let content = try? String(contentsOfFile: pbxPath, encoding: .utf8) else {
                log("⚠️ Unable to read \(pbxPath)")
                continue
            }

            let newContent = updatePBXProjContent(content, with: deps)

            guard newContent != content else {
                log("\nℹ️ No changes for pbxproj: \(pbxPath)")
                return
            }

            do {
                try newContent.write(toFile: pbxPath, atomically: true, encoding: .utf8)
                log("📝 Updated pbxproj: \(pbxPath)")
            } catch {
                log("❌ Write error for pbxproj \(pbxPath): \(error)")
            }
        }
    }
}
