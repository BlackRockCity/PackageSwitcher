//
//  PackageSwitcherService.swift
//  PackageSwitcher
//
//  Created by BlackRockCity on 7/2/24.
//

import Foundation

enum PackageManagerChoice: String, CaseIterable, Identifiable {
    case homebrew
    case macPorts
    case unknown
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .homebrew:
            return String(localized: "manager.homebrew")
        case .macPorts:
            return String(localized: "manager.macports")
        case .unknown:
            return String(localized: "manager.unknown")
        case .mixed:
            return String(localized: "manager.mixed")
        }
    }

    var switchVerb: String {
        switch self {
        case .homebrew:
            return String(localized: "action.switch_homebrew")
        case .macPorts:
            return String(localized: "action.switch_macports")
        case .unknown, .mixed:
            return String(localized: "action.switch")
        }
    }
}

struct ShellProfileState {
    let profileURL: URL
    let contents: String
    let activeManager: PackageManagerChoice
    let previewContents: String
    let warnings: [String]
}

final class PackageSwitcherService {
    enum ServiceError: LocalizedError {
        case unsupportedChoice

        var errorDescription: String? {
            switch self {
            case .unsupportedChoice:
                return String(localized: "error.choose_manager")
            }
        }
    }

    static var defaultProfileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".bash_profile")
    }

    let fileManager: FileManager
    let profileURL: URL

    init(
        fileManager: FileManager = .default,
        profileURL: URL = PackageSwitcherService.defaultProfileURL
    ) {
        self.fileManager = fileManager
        self.profileURL = profileURL
    }

    func loadState(selectedChoice: PackageManagerChoice? = nil) -> ShellProfileState {
        let contents: String
        let readWarning: String?

        do {
            contents = try String(contentsOf: profileURL, encoding: .utf8)
            readWarning = nil
        } catch {
            contents = ""
            readWarning = String(
                format: String(localized: "error.profile_read"),
                error.localizedDescription
            )
        }

        let active = Self.detectActiveManager(in: contents)
        let target = selectedChoice?.isSwitchable == true ? selectedChoice! : Self.defaultTarget(for: active)
        let preview = Self.previewContent(for: target, currentContent: contents)

        return ShellProfileState(
            profileURL: profileURL,
            contents: contents,
            activeManager: active,
            previewContents: preview,
            warnings: warnings(for: active, readWarning: readWarning)
        )
    }

    func previewSwitch(to choice: PackageManagerChoice) throws -> String {
        guard choice.isSwitchable else { throw ServiceError.unsupportedChoice }
        let contents = try String(contentsOf: profileURL, encoding: .utf8)
        return Self.previewContent(for: choice, currentContent: contents)
    }

    func applySwitch(to choice: PackageManagerChoice) throws -> ShellProfileState {
        guard choice.isSwitchable else { throw ServiceError.unsupportedChoice }

        let currentContent = try String(contentsOf: profileURL, encoding: .utf8)
        try createBackup(for: currentContent)

        let newContent = Self.previewContent(for: choice, currentContent: currentContent)
        try newContent.write(to: profileURL, atomically: true, encoding: .utf8)
        return loadState(selectedChoice: choice)
    }

    func createBackup(for contents: String, now: Date = Date()) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        let backupName = "\(profileURL.lastPathComponent).PackageSwitcherBackup-\(formatter.string(from: now))"
        let backupURL = profileURL.deletingLastPathComponent().appendingPathComponent(backupName)
        try contents.write(to: backupURL, atomically: true, encoding: .utf8)
    }

    static func profileBlock(for choice: PackageManagerChoice) -> String {
        switch choice {
        case .homebrew:
            return homebrewBlock
        case .macPorts:
            return macPortsBlock
        case .unknown, .mixed:
            return ""
        }
    }

    static func detectActiveManager(in content: String) -> PackageManagerChoice {
        let lines = content
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let activeLines = lines.filter { !$0.hasPrefix("#") }
        let hasActiveHomebrew = activeLines.contains(homebrewEvalLine)
        let hasCommentedHomebrew = lines.contains(commentedHomebrewEvalLine)
        let hasActiveMacPorts = activeLines.contains(macPortsPathLine)
            && activeLines.contains(macPortsManpathLine)
            && activeLines.contains(macPortsInfopathLine)

        if hasActiveHomebrew && hasActiveMacPorts {
            return .mixed
        }
        if hasActiveHomebrew {
            return .homebrew
        }
        if hasCommentedHomebrew && hasActiveMacPorts {
            return .macPorts
        }
        return .unknown
    }

    static func previewContent(for choice: PackageManagerChoice, currentContent: String) -> String {
        guard choice.isSwitchable else { return currentContent }

        let targetBlock = profileBlock(for: choice)
        let oppositeBlock = profileBlock(for: choice == .homebrew ? .macPorts : .homebrew)
        var newContent = currentContent.replacingOccurrences(of: oppositeBlock, with: targetBlock)

        if !newContent.contains(targetBlock) {
            newContent = targetBlock + "\n" + newContent
        }

        return newContent
    }

    static func defaultTarget(for active: PackageManagerChoice) -> PackageManagerChoice {
        switch active {
        case .homebrew:
            return .homebrew
        case .macPorts:
            return .macPorts
        case .unknown, .mixed:
            return .homebrew
        }
    }

    private func warnings(for active: PackageManagerChoice, readWarning: String?) -> [String] {
        var warnings: [String] = []

        if let readWarning {
            warnings.append(readWarning)
        }
        if !fileManager.fileExists(atPath: "/opt/homebrew/bin/brew") {
            warnings.append(String(localized: "warning.homebrew_missing"))
        }
        if !fileManager.fileExists(atPath: "/opt/local/bin") || !fileManager.fileExists(atPath: "/opt/local/sbin") {
            warnings.append(String(localized: "warning.macports_missing"))
        }
        if active == .mixed {
            warnings.append(String(localized: "warning.mixed"))
        }
        if active == .unknown {
            warnings.append(String(localized: "warning.unknown"))
        }

        return warnings
    }

    private static let homebrewEvalLine = #"eval "$(/opt/homebrew/bin/brew shellenv)""#
    private static let commentedHomebrewEvalLine = #"#eval "$(/opt/homebrew/bin/brew shellenv)""#
    private static let macPortsPathLine = #"export PATH="/opt/local/bin:/opt/local/sbin:$PATH""#
    private static let macPortsManpathLine = #"export MANPATH="/opt/local/share/man:$MANPATH""#
    private static let macPortsInfopathLine = #"export INFOPATH="/opt/local/share/info/$INFOPATH""#

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

extension PackageManagerChoice {
    var isSwitchable: Bool {
        self == .homebrew || self == .macPorts
    }
}
