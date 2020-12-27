import ArgumentParser

/// A command that analyzes a given Swift Package
struct SwiftPackageInfo: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Check the estimated size of a Swift Package.",
        discussion: """
        Check key information about a Swift Package, such as "ArgumentParser".
        Estimation of binary size it will contribute to your app,
        its dependency graph, and more...
        """,
        version: "1.0"
    )

    @Option(
        name: [
            .short,
            .long,
            .customLong("for"),
            .customLong("package")
        ],
        help: "URL of the Swift Package to generate analyzes for"
    )
    var packageURL: String

    @Option(
        name: [
            .short,
            .long
        ],
        help: "Semantic version of the Swift Package"
    )
    var version: String?

    @Option(
        name: [
            .short,
            .long,
            .customLong("library-named"),
            .customLong("library-name")
        ],
        help: "Name of the library to run analyzes for. If not passed in, the Package's first declared library will be used instead"
    )
    var library: String?

    @Flag(
        name: .long,
        help: "Output all steps of a running analyzes"
    )
    var verbose = false

    func run() throws {
        guard CommandLine.argc > 1 else { throw CleanExit.helpRequest() }

        debugPrint(
            """
            -packageURL: \(packageURL),
            -version: \(version ?? ""),
            -library: \(library ?? "")
            """
        )

        Shell.run(arguments: "xcodebuild", "--help")

        Shell.run("xcodebuild --help")

        Shell.run(
            """
            xcodebuild
            --help
            """
        )
    }
}

SwiftPackageInfo.main()