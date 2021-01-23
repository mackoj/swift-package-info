//
//  RunTests.swift
//  
//
//  Created by Marino Felipe on 28.12.20.
//

import XCTest
import Foundation

@available(macOS 10.13, *)
final class RunTests: XCTestCase {
    func testWithInvalidRepositoryURL() throws {
        try runToolProcessAndAssert(
            command: "--repository-url somethingElse --package-version 6.0.0 --product RxSwift",
            expectedOutput: """
            Error: Invalid argument \'--repository-url <repository-url>\'\nUsage: The URL must be a valid git repository URL that contains a `Package.swift`, e.g. `https://github.com/Alamofire/Alamofire`.

            """,
            expectedError: ""
        )
    }

    func testWithInexistentTag() throws {
        try runToolProcessAndAssert(
            command: "--repository-url https://github.com/ReactiveX/RxSwift --package-version 8.0.0 --product RxSwift",
            expectedOutput: """
            [1/6] Generating archive for empty app...
            [2/6] Calculating binary size...
            [3/6] Adding RxSwift as dependency...
            [4/6] Generating archive for updated app...
            [5/6] Calculating updated binary size...
            [6/6] Reseting app...

            """,
            expectedError: ""
        )
    }

    func testWithInvalidProduct() throws {
        try runToolProcessAndAssert(
            command: "--repository-url https://github.com/ReactiveX/RxSwift --package-version 8.0.0 --product some",
            expectedOutput: """
            Error: Invalid argument \'--product <product>\'
            Usage: The product should match one of the declared products on https://github.com/ReactiveX/RxSwift.
            Found available products: [\"RxSwift\", \"RxCocoa\", \"RxRelay\", \"RxBlocking\", \"RxTest\"].

            """,
            expectedError: ""
        )
    }

    func testWhenAllParametersAreValid() throws {
        try runToolProcessAndAssert(
            command: "--repository-url https://github.com/ReactiveX/RxSwift --package-version 6.0.0 --product RxSwift",
            expectedOutput: """
            [1/6] Generating archive for empty app...
            [2/6] Calculating binary size...
            [3/6] Adding RxSwift as dependency...
            [4/6] Generating archive for updated app...
            [5/6] Calculating updated binary size...
            [6/6] Reseting app...

            """,
            expectedError: ""
        )
    }

    func testWhenVerboseFlagIsSet() throws {
        // All values are expected to be logged via Console
        try runToolProcessAndAssert(
            command: "--repository-url https://github.com/ReactiveX/RxSwift --package-version 6.0.0 --product RxSwift --verbose",
            expectedOutput: "",
            expectedError: ""
        )
    }

    func testWithMissingParameters() throws {
        // assert when only --repository-url is passed in
        try runToolProcessAndAssert(
            command: "--repository-url https://github.com/ReactiveX/RxSwift",
            expectedOutput: "",
            expectedError: """
            Error: Missing expected argument \'--package-version <package-version>\'\nUsage: swift-package-info full-analyzes --repository-url <repository-url> --package-version <package-version> --product <product> [--verbose]
              See \'swift-package-info full-analyzes --help\' for more information.

            """
        )

        // assert when --product is missing
        try runToolProcessAndAssert(
            command: "--repository-url https://github.com/ReactiveX/RxSwift --package-version 6.0.0",
            expectedOutput: "",
            expectedError: """
            Error: Missing expected argument \'--product <product>\'\nUsage: swift-package-info full-analyzes --repository-url <repository-url> --package-version <package-version> --product <product> [--verbose]
              See \'swift-package-info full-analyzes --help\' for more information.

            """
        )
    }

    func testHelp() throws {
        let expectedOutput = """
        OVERVIEW: A tool for analyzing Swift Packages

        Provides valuable information about a given Swift Package,\nthat can be used in your favor when deciding whether to\nadopt or not a Swift Package as a dependency on your app.

        USAGE: swift-package-info <subcommand>

        OPTIONS:
          --version               Show the version.
          -h, --help              Show help information.\n\nSUBCOMMANDS:
          binary-size             Check the estimated size of a Swift Package.
          full-analyzes (default) Get all available information about a Swift Package

          See \'swift-package-info help <subcommand>\' for detailed help.

        """

        try runToolProcessAndAssert(
            command: "--help",
            expectedOutput: expectedOutput,
            expectedError: ""
        )
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
        #else
        return Bundle.main.bundleURL
        #endif
    }

    static var allTests = [
        ("testHelp", testHelp),
    ]

    // MARK: - Helpers

    private func runToolProcessAndAssert(
        _ file: StaticString = #file,
        _ function: StaticString = #function,
        _ line: UInt = #line,
        command: String,
        expectedOutput: String,
        expectedError: String
    ) throws {
        let commands = command.split(whereSeparator: \.isWhitespace)

        let arguments: [String]
        if commands.count > 1 {
            arguments = commands.map { String($0) }
        } else {
            arguments = command
                .split { [" -", " --"].contains(String($0)) }
                .map { String($0) }
        }

        let executableURL = productsDirectory.appendingPathComponent("swift-package-info")

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let outputContent = String(data: outputData, encoding: .utf8)
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorContent = String(data: errorData, encoding: .utf8)

        XCTAssertEqual(outputContent, expectedOutput)
        XCTAssertEqual(errorContent, expectedError)
    }
}
