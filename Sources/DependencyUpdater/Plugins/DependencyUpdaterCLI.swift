import PackagePlugin
import Foundation

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin
#endif

@main
struct DependencyUpdaterPlugin: CommandPlugin {

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try run(
            context: context,
            projectRootURL: URL(fileURLWithPath: context.package.directoryURL.path),
            arguments: arguments
        )
    }
}

#if canImport(XcodeProjectPlugin)
extension DependencyUpdaterPlugin: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let hostProjectRoot = context.xcodeProject.directoryURL
        try run(
            context: context,
            projectRootURL: hostProjectRoot,
            arguments: arguments
        )
    }
}
#endif

// MARK: - Shared

private protocol ToolProviding {
    func tool(named name: String) throws -> PluginContext.Tool
}

extension PluginContext: ToolProviding {}

#if canImport(XcodeProjectPlugin)
extension XcodePluginContext: ToolProviding {}
#endif

private extension DependencyUpdaterPlugin {

    func run(context: some ToolProviding, projectRootURL: URL, arguments: [String]) throws {
        let projectRoot = projectRootURL.path

        var dependenciesPath = projectRootURL
            .appendingPathComponent("Dependencies/dependencies.yaml")
            .path

        if let idx = arguments.firstIndex(of: "--dependencies-path"),
           arguments.indices.contains(idx + 1) {
            let arg = arguments[idx + 1]
            if arg.hasPrefix("/") {
                dependenciesPath = arg
            } else {
                dependenciesPath = projectRootURL.appendingPathComponent(arg).path
            }
        }

        let tool = try context.tool(named: "DependencyUpdaterExecutable")

        let process = Process()
        process.executableURL = tool.url
        process.arguments = [projectRoot, dependenciesPath]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            Diagnostics.error("DependencyUpdaterExecutable exited with code \(process.terminationStatus)")
            return
        }
    }
}
