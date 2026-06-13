//
//  PackageSwitcherViewModel.swift
//  PackageSwitcher
//
//  Created by BlackRockCity on 7/2/24.
//

import Foundation

@MainActor
final class PackageSwitcherViewModel: ObservableObject {
    enum PreviewMode: String, CaseIterable, Identifiable {
        case current = "Current profile"
        case preview = "Preview after applying"
        case diff = "Diff"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .current:
                return String(localized: "preview.current")
            case .preview:
                return String(localized: "preview.after")
            case .diff:
                return String(localized: "preview.diff")
            }
        }
    }

    @Published private(set) var profilePath: String = ""
    @Published private(set) var currentContents: String = ""
    @Published private(set) var previewContents: String = ""
    @Published private(set) var activeManager: PackageManagerChoice = .unknown
    @Published var selectedTarget: PackageManagerChoice = .homebrew {
        didSet { refreshPreview() }
    }
    @Published var previewMode: PreviewMode = .preview
    @Published private(set) var warnings: [String] = []
    @Published private(set) var successMessage: String?
    @Published private(set) var errorMessage: String?

    private let service: PackageSwitcherService

    init(service: PackageSwitcherService = PackageSwitcherService()) {
        self.service = service
        reloadFromDisk()
    }

    var hasPendingChanges: Bool {
        selectedTarget != activeManager && selectedTarget.isSwitchable
    }

    var canApply: Bool {
        hasPendingChanges
    }

    var primaryButtonTitle: String {
        hasPendingChanges ? selectedTarget.switchVerb : String(localized: "action.no_changes")
    }

    var isHomebrewInstalled: Bool {
        FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
    }

    var areMacPortsPathsPresent: Bool {
        FileManager.default.fileExists(atPath: "/opt/local/bin")
            && FileManager.default.fileExists(atPath: "/opt/local/sbin")
    }

    var selectedPreviewText: String {
        switch previewMode {
        case .current:
            return currentContents.isEmpty ? String(localized: "empty.profile") : currentContents
        case .preview:
            return previewContents.isEmpty ? String(localized: "empty.preview") : previewContents
        case .diff:
            return diffText(from: currentContents, to: previewContents)
        }
    }

    func reloadFromDisk() {
        let state = service.loadState(selectedChoice: selectedTarget)
        profilePath = state.profileURL.path
        currentContents = state.contents
        activeManager = state.activeManager
        warnings = state.warnings
        errorMessage = nil
        successMessage = nil

        if !hasUserSelectedDifferentTarget {
            selectedTarget = PackageSwitcherService.defaultTarget(for: state.activeManager)
        }
        refreshPreview()
    }

    func selectTarget(_ choice: PackageManagerChoice) {
        guard choice.isSwitchable else { return }
        selectedTarget = choice
        successMessage = nil
        errorMessage = nil
    }

    func applySelection() {
        guard canApply else { return }

        do {
            let state = try service.applySwitch(to: selectedTarget)
            profilePath = state.profileURL.path
            currentContents = state.contents
            activeManager = state.activeManager
            warnings = state.warnings
            previewContents = state.previewContents
            successMessage = String(
                format: String(localized: "success.switched"),
                selectedTarget.displayName
            )
            errorMessage = nil
        } catch {
            successMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private var hasUserSelectedDifferentTarget: Bool {
        selectedTarget != .homebrew || activeManager == .homebrew
    }

    private func refreshPreview() {
        previewContents = PackageSwitcherService.previewContent(for: selectedTarget, currentContent: currentContents)
    }

    private func diffText(from old: String, to new: String) -> String {
        if old == new {
            return String(localized: "empty.diff")
        }

        let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var output: [String] = []
        output.append(String(localized: "diff.current_header"))
        output.append(String(localized: "diff.preview_header"))

        for line in oldLines where !newLines.contains(line) {
            output.append("- \(line)")
        }
        for line in newLines where !oldLines.contains(line) {
            output.append("+ \(line)")
        }

        return output.joined(separator: "\n")
    }
}
