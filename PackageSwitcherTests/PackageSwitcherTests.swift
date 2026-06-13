//
//  PackageSwitcherTests.swift
//  PackageSwitcherTests
//
//  Created by BlackRockCity on 7/2/24.
//

import XCTest
@testable import PackageSwitcher

final class PackageSwitcherTests: XCTestCase {
    func testHomebrewOutputExactlyMatchesOriginalWorkingBlock() {
        XCTAssertEqual(PackageSwitcherService.profileBlock(for: .homebrew), Self.homebrewBlock)
    }

    func testMacPortsOutputExactlyMatchesOriginalWorkingBlock() {
        XCTAssertEqual(PackageSwitcherService.profileBlock(for: .macPorts), Self.macPortsBlock)
    }

    func testInfoPathKeepsOriginalSlashSyntax() {
        let result = PackageSwitcherService.previewContent(for: .macPorts, currentContent: Self.homebrewBlock)

        XCTAssertTrue(result.contains(#"export INFOPATH="/opt/local/share/info/$INFOPATH""#))
        XCTAssertFalse(result.contains(#"export INFOPATH="/opt/local/share/info:$INFOPATH""#))
    }

    func testManagedBlockMarkersAreNotInserted() {
        let result = PackageSwitcherService.previewContent(for: .macPorts, currentContent: "export EDITOR=vim\n")

        XCTAssertFalse(result.contains("# >>> PackageSwitcher >>>"))
        XCTAssertFalse(result.contains("# <<< PackageSwitcher <<<"))
    }

    func testDefaultProfileURLTargetsBashProfile() {
        XCTAssertEqual(PackageSwitcherService.defaultProfileURL.lastPathComponent, ".bash_profile")
    }

    func testDefaultProfileURLIsInsideCurrentUsersHomeDirectory() {
        XCTAssertEqual(
            PackageSwitcherService.defaultProfileURL.deletingLastPathComponent(),
            FileManager.default.homeDirectoryForCurrentUser
        )
    }

    func testCustomProfileURLCanBeInjected() {
        let profileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PackageSwitcher-injected-profile")

        XCTAssertEqual(PackageSwitcherService(profileURL: profileURL).profileURL, profileURL)
    }

    func testDetectsHomebrewFromOriginalUncommentedEvalLine() {
        XCTAssertEqual(PackageSwitcherService.detectActiveManager(in: Self.homebrewBlock), .homebrew)
    }

    func testDetectsMacPortsFromOriginalMacPortsBlock() {
        XCTAssertEqual(PackageSwitcherService.detectActiveManager(in: Self.macPortsBlock), .macPorts)
    }

    func testDetectsUnknownWhenNeitherOriginalStateIsPresent() {
        XCTAssertEqual(PackageSwitcherService.detectActiveManager(in: "export EDITOR=vim\n"), .unknown)
    }

    func testDetectsMixedWhenBothManagersAreUncommented() {
        let content = """
        eval "$(/opt/homebrew/bin/brew shellenv)"
        export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
        export MANPATH="/opt/local/share/man:$MANPATH"
        export INFOPATH="/opt/local/share/info/$INFOPATH"
        """

        XCTAssertEqual(PackageSwitcherService.detectActiveManager(in: content), .mixed)
    }

    func testSwitchingToHomebrewUsesOriginalReplacementBehavior() {
        let original = """
        export EDITOR=vim
        \(Self.macPortsBlock)
        alias ll="ls -la"
        """

        let result = PackageSwitcherService.previewContent(for: .homebrew, currentContent: original)

        XCTAssertTrue(result.contains(Self.homebrewBlock))
        XCTAssertFalse(result.contains(Self.macPortsBlock))
        XCTAssertTrue(result.contains("export EDITOR=vim"))
        XCTAssertTrue(result.contains("alias ll=\"ls -la\""))
    }

    func testSwitchingToMacPortsUsesOriginalReplacementBehavior() {
        let original = """
        export EDITOR=vim
        \(Self.homebrewBlock)
        alias ll="ls -la"
        """

        let result = PackageSwitcherService.previewContent(for: .macPorts, currentContent: original)

        XCTAssertTrue(result.contains(Self.macPortsBlock))
        XCTAssertFalse(result.contains(Self.homebrewBlock))
        XCTAssertTrue(result.contains("export EDITOR=vim"))
        XCTAssertTrue(result.contains("alias ll=\"ls -la\""))
    }

    func testPreviewMatchesContentThatWouldBeWritten() throws {
        let directory = try makeTemporaryDirectory()
        let profile = directory.appendingPathComponent(".bash_profile")
        try Self.homebrewBlock.write(to: profile, atomically: true, encoding: .utf8)
        let service = PackageSwitcherService(profileURL: profile)

        XCTAssertEqual(try service.previewSwitch(to: .macPorts), PackageSwitcherService.previewContent(for: .macPorts, currentContent: Self.homebrewBlock))
    }

    func testRepeatedSwitchesDoNotDuplicateOriginalBlocks() {
        let once = PackageSwitcherService.previewContent(for: .macPorts, currentContent: Self.homebrewBlock)
        let twice = PackageSwitcherService.previewContent(for: .macPorts, currentContent: once)

        XCTAssertEqual(twice.components(separatedBy: Self.macPortsBlock).count - 1, 1)
        XCTAssertEqual(twice.components(separatedBy: Self.homebrewBlock).count - 1, 0)
    }

    func testUnrelatedProfileContentIsPreserved() {
        let original = """
        export EDITOR=nano
        \(Self.homebrewBlock)
        alias gs="git status"
        """

        let result = PackageSwitcherService.previewContent(for: .macPorts, currentContent: original)

        XCTAssertTrue(result.contains("export EDITOR=nano"))
        XCTAssertTrue(result.contains("alias gs=\"git status\""))
    }

    func testCreatesBackupBeforeWriting() throws {
        let directory = try makeTemporaryDirectory()
        let profile = directory.appendingPathComponent(".bash_profile")
        try Self.homebrewBlock.write(to: profile, atomically: true, encoding: .utf8)
        let service = PackageSwitcherService(profileURL: profile)

        _ = try service.applySwitch(to: .macPorts)

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix(".bash_profile.PackageSwitcherBackup-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent(backups[0])), Self.homebrewBlock)
    }

    func testProfilePreviewClassifiesActivePackageManagerLines() {
        let content = """
        eval "$(/opt/homebrew/bin/brew shellenv)"
        export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
        export MANPATH="/opt/local/share/man:$MANPATH"
        export INFOPATH="/opt/local/share/info/$INFOPATH"
        """

        let lines = ProfilePreviewPresentation.lines(
            for: .current,
            content: content,
            currentContent: content
        )

        XCTAssertEqual(lines.map(\.role), [.active, .active, .active, .active])
    }

    func testProfilePreviewClassifiesCommentedPackageManagerLinesAsInactive() {
        let content = """
        #eval "$(/opt/homebrew/bin/brew shellenv)"
        #export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
        #export MANPATH="/opt/local/share/man:$MANPATH"
        #export INFOPATH="/opt/local/share/info/$INFOPATH"
        """

        let lines = ProfilePreviewPresentation.lines(
            for: .current,
            content: content,
            currentContent: content
        )

        XCTAssertEqual(lines.map(\.role), [.inactive, .inactive, .inactive, .inactive])
    }

    func testProfilePreviewLeavesUnrelatedProfileLinesNeutral() {
        let lines = ProfilePreviewPresentation.lines(
            for: .current,
            content: "export EDITOR=vim\nalias ll=\"ls -la\"",
            currentContent: ""
        )

        XCTAssertEqual(lines.map(\.role), [.neutral, .neutral])
    }

    func testProfilePreviewMarksPreviewOnlyRowsAsChangedWithoutChangingText() {
        let preview = """
        eval "$(/opt/homebrew/bin/brew shellenv)"
        export EDITOR=vim
        """

        let lines = ProfilePreviewPresentation.lines(
            for: .preview,
            content: preview,
            currentContent: "export EDITOR=vim"
        )

        XCTAssertEqual(lines[0].text, #"eval "$(/opt/homebrew/bin/brew shellenv)""#)
        XCTAssertTrue(lines[0].differsFromCurrent)
        XCTAssertFalse(lines[1].differsFromCurrent)
    }

    func testProfilePreviewConsumesMatchingCurrentLineOccurrencesInPreviewOrder() {
        let lines = ProfilePreviewPresentation.lines(
            for: .preview,
            content: "alias ll=\"ls -la\"\nalias ll=\"ls -la\"",
            currentContent: "alias ll=\"ls -la\""
        )

        XCTAssertEqual(lines.map(\.text), ["alias ll=\"ls -la\"", "alias ll=\"ls -la\""])
        XCTAssertEqual(lines.map(\.differsFromCurrent), [false, true])
    }

    func testProfilePreviewClassifiesDiffHeadersBeforeChangeMarkers() {
        let content = """
        --- Current profile
        +++ Preview after applying
        - old line
        +new line
          context line
        """

        let lines = ProfilePreviewPresentation.lines(
            for: .diff,
            content: content,
            currentContent: ""
        )

        XCTAssertEqual(
            lines.map(\.role),
            [.diffHeader, .diffHeader, .removed, .added, .neutral]
        )
        XCTAssertEqual(lines[2].marker, "-")
        XCTAssertEqual(lines[2].displayText, "old line")
        XCTAssertEqual(lines[3].marker, "+")
        XCTAssertEqual(lines[3].displayText, "new line")
    }

    func testProfilePreviewPreservesBlankLines() {
        let lines = ProfilePreviewPresentation.lines(
            for: .current,
            content: "first\n\nthird\n",
            currentContent: ""
        )

        XCTAssertEqual(lines.map(\.text), ["first", "", "third", ""])
    }

    func testProfilePreviewClassifiesCRLFLinesAndPreservesBlankAndTrailingLines() {
        let content = "eval \"$(/opt/homebrew/bin/brew shellenv)\"\r\n\r\n"
            + "export INFOPATH=\"/opt/local/share/info/$INFOPATH\"\r\n"

        let lines = ProfilePreviewPresentation.lines(
            for: .current,
            content: content,
            currentContent: content
        )

        XCTAssertEqual(
            lines.map(\.text),
            [
                #"eval "$(/opt/homebrew/bin/brew shellenv)""#,
                "",
                #"export INFOPATH="/opt/local/share/info/$INFOPATH""#,
                ""
            ]
        )
        XCTAssertEqual(lines.map(\.role), [.active, .neutral, .active, .neutral])
    }

    func testStringCatalogContainsEveryRequiredLocaleForEveryKey() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PackageSwitcher/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let requiredLocales = Set([
            "en", "zh-Hans", "es", "fr", "de", "ja", "ko", "pt", "ar", "hi"
        ])

        XCTAssertEqual(catalog["sourceLanguage"] as? String, "en")
        XCTAssertFalse(strings.isEmpty)

        for (key, value) in strings {
            let entry = try XCTUnwrap(value as? [String: Any], "Invalid entry: \(key)")
            let localizations = try XCTUnwrap(
                entry["localizations"] as? [String: Any],
                "Missing localizations: \(key)"
            )
            XCTAssertEqual(
                Set(localizations.keys),
                requiredLocales,
                "Incomplete locales for \(key)"
            )
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PackageSwitcherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let homebrewBlock = """
    eval "$(/opt/homebrew/bin/brew shellenv)"
    #export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
    #export MANPATH="/opt/local/share/man:$MANPATH"
    #export INFOPATH="/opt/local/share/info/$INFOPATH"
    """

    private static let macPortsBlock = """
    #eval "$(/opt/homebrew/bin/brew shellenv)"
    export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
    export MANPATH="/opt/local/share/man:$MANPATH"
    export INFOPATH="/opt/local/share/info/$INFOPATH"
    """
}
