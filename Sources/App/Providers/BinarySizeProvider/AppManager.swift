//
//  AppManager.swift
//  
//
//  Created by Marino Felipe on 29.12.20.
//

import Foundation
import Core
import XcodeProj

// MARK: - Constants

fileprivate enum Constants {
    static let appName: String = "MeasurementApp"
    static let clonedRepoName: String = "swift-package-info"
    static let xcodeProjName: String = "\(appName).xcodeproj"
    static let xcodeProjPath: String = "\(clonedRepoName)/\(xcodeProjName)"
    static let archiveName: String = "archive.xcarchive"
}

// MARK: - App manager

/// Provides API to work with the `measurement app`.
/// Can `generate archive`, `calculate its binary size` and `mutate the project` with a given Swift Package dependency`.
final class AppManager {
    private lazy var appPath: String = fileManager.currentDirectoryPath
        .appending("/")
        .appending(Constants.xcodeProjPath)

    private var archivedProductPath: String {
        fileManager.temporaryDirectory
            .path
            .appending("/")
            .appending(Constants.archiveName)
            .appending("/Products/Applications/MeasurementApp.app")
    }

    private let fileManager: FileManager
    private let console: Console
    private let verbose: Bool

    init(
        fileManager: FileManager = .default,
        console: Console = .default,
        verbose: Bool
    ) {
        self.fileManager = fileManager
        self.console = console
        self.verbose = verbose
    }

    func cloneEmptyApp() throws {
        do {
            try Shell.performShallowGitClone(
                repositoryURLString: "https://github.com/marinofelipe/swift-package-info",
                branchOrTag: "main",
                verbose: verbose
            )
        } catch {
            throw BinarySizeProviderError.unableToCloneEmptyApp(errorMessage: error.localizedDescription)
        }
    }

    func generateArchive() throws {
        let command: ConsoleMessage = """
        xcodebuild \
        archive \
        -project \(Constants.xcodeProjPath) \
        -scheme \(Constants.appName) \
        -archivePath \(fileManager.temporaryDirectory.path)/\(Constants.archiveName) \
        -derivedDataPath \(fileManager.temporaryDirectory.path) \
        -configuration Release \
        -arch arm64 \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        ENABLE_BITCODE=NO
        """

        if verbose {
            console.lineBreakAndWrite(command)
        }

        let output = try Shell.run(
            command.text,
            verbose: verbose,
            timeout: nil
        )

        if output.succeeded == false {
            if verbose {
                console.lineBreakAndWrite(
                    .init(
                        text: "Command failed...",
                        color: .red
                    )
                )
            }

            let errorMessage = String(data: output.errorData, encoding: .utf8) ?? ""
            throw BinarySizeProviderError.unableToGenerateArchive(errorMessage: errorMessage)
        }
    }

    func calculateBinarySize() throws -> SizeOnDisk {
        do {
            let url = URL(fileURLWithPath: archivedProductPath)
            let appSize = try url.sizeOnDisk()

            if verbose { console.lineBreakAndWrite(appSize.message) }

            return appSize
        } catch {
            throw BinarySizeProviderError.unableToGetBinarySizeOnDisk(underlyingError: error as NSError)
        }
    }

    func add(
        asDependency swiftPackage: SwiftPackage,
        isDynamic: Bool
    ) throws {
        let xcodeProj = try XcodeProj(path: .init(appPath))

        guard let appProject = xcodeProj.pbxproj.projects.first else {
            throw BinarySizeProviderError.unableToRetrieveAppProject(atPath: appPath)
        }

        let xcSwiftPackageReference = try appProject.add(swiftPackage: swiftPackage)
        xcodeProj.pbxproj.add(object: xcSwiftPackageReference)

        try xcodeProj.write(path: .init(appPath))

        if isDynamic {
            let packageDependency = appProject.targets.first?.packageProductDependencies.first
            let packageBuildFile = PBXBuildFile(product: packageDependency)

            let embedFrameworksBuildPhase = appProject.targets.first?.embedFrameworksBuildPhases().first
            embedFrameworksBuildPhase?.files?.append(packageBuildFile)

            try xcodeProj.write(path: .init(appPath))
        }
    }

    func cleanupClonedApp() throws {
        try Shell.run(
            "rm -rf swift-package-info",
            verbose: verbose
        )
    }
}

// MARK: - PBXProject: add(swiftPackage:targetName:)

private extension PBXProject {
    func add(swiftPackage: SwiftPackage, targetName: String = Constants.appName) throws -> XCRemoteSwiftPackageReference {
        try addSwiftPackage(
            repositoryURL: swiftPackage.repositoryURL.absoluteString,
            productName: swiftPackage.product,
            versionRequirement: .upToNextMinorVersion(swiftPackage.version),
            targetName: targetName
        )
    }
}
