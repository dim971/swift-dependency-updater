import Foundation
import Yams

typealias Dependency = [String: String]

struct DependencyUpdaterTool {

    // MARK: - Properties
    private let excludedDirectories = ["Build", ".git", ".build", "DerivedData"]

    func run(projectRoot: String, dependenciesPath: String) throws {
        let deps = loadDependencies(at: dependenciesPath)

        let packageFiles = findPackageFiles(at: projectRoot)
        updatePackages(at: packageFiles, with: deps)

        let pbxprojFiles = findPBXProjFiles(at: projectRoot)
        updatePBXProjFiles(at: pbxprojFiles, with: deps)

        log("\n🎉 All done.")
    }
}

private extension DependencyUpdaterTool {

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

    func normalizeRequirementKeyword(in line: String) -> String {
        let pattern = #/(branch|from):/#
        return line.replacing(pattern, with: "exact:")
    }

    func updatingPackageLine(_ line: String, forDep name: String, toVersion newVersion: String) -> String {
        let marker = "// @dep \(name)"
        guard line.contains(marker) else {
            return line
        }

        let workingLine = normalizeRequirementKeyword(in: line)

        let pattern = #/exact:\s*"([^"]+)"/#

        guard let _ = workingLine.firstMatch(of: pattern) else {
            return workingLine
        }

        return workingLine.replacing(pattern) { _ in
            "exact: \"\(newVersion)\""
        }
    }

    func updatePackageContent(_ content: String, with deps: [String: String]) -> String {
        var lines = content.components(separatedBy: .newlines)

        for index in lines.indices {
            var updatedLine = lines[index]
            for (name, newVersion) in deps {
                updatedLine = updatingPackageLine(updatedLine, forDep: name, toVersion: newVersion)
            }
            lines[index] = updatedLine
        }

        return lines.joined(separator: "\n")
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
