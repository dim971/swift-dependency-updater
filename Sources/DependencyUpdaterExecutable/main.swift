import Foundation

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write(Data("Usage: DependencyUpdaterExecutable <projectRoot> <dependenciesPath>\n".utf8))
    exit(1)
}

let projectRoot = CommandLine.arguments[1]
let dependenciesPath = CommandLine.arguments[2]

try DependencyUpdaterTool().run(
    projectRoot: projectRoot,
    dependenciesPath: dependenciesPath
)
