//
//  ContentView.swift
//  PackageSwitcher
//
//  Created by BlackRockCity on 7/2/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: PackageSwitcherViewModel

    @MainActor
    init(viewModel: PackageSwitcherViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? PackageSwitcherViewModel())
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusCard
                    profileRow
                    switchSection
                    actionSection
                    messagesSection
                    previewSection(
                        minHeight: max(250, geometry.size.height - 560)
                    )
                        .frame(maxHeight: .infinity)
                        .layoutPriority(1)
                    supportFooter
                }
                .padding(24)
                .frame(
                    minHeight: max(geometry.size.height - 48, 0),
                    alignment: .top
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 760, idealWidth: 860, minHeight: 720, idealHeight: 780)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "app.title"))
                .font(.largeTitle.weight(.semibold))
                .accessibilityIdentifier("appTitle")
            Text(String(localized: "app.subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "app.profile_helper"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusCard: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: statusSymbol)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 56, height: 56)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "status.current_manager"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("currentManagerHeading")
                Text(viewModel.activeManager.displayName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("activeManagerValue")
                Text(
                    String(
                        format: String(localized: "status.detected_from"),
                        viewModel.profilePath
                    )
                )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            StatusBadge(
                title: viewModel.hasPendingChanges
                    ? String(localized: "status.pending")
                    : String(localized: "status.no_pending"),
                systemImage: viewModel.hasPendingChanges ? "clock.arrow.circlepath" : "checkmark.circle.fill",
                tint: viewModel.hasPendingChanges ? .orange : .green
            )
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var profileRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            Text(String(localized: "profile.file"))
                .font(.headline)
                .accessibilityIdentifier("profileFileLabel")
            Text(viewModel.profilePath)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("profilePathValue")
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var switchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "switch.section"))
                .font(.title3.weight(.semibold))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    packageManagerCards
                }

                VStack(spacing: 14) {
                    packageManagerCards
                }
            }
        }
    }

    @ViewBuilder
    private var packageManagerCards: some View {
        PackageManagerCard(
            choice: .homebrew,
            description: String(localized: "card.homebrew.description"),
            symbolName: "mug.fill",
            isActive: viewModel.activeManager == .homebrew,
            isSelected: viewModel.selectedTarget == .homebrew,
            isInstalled: viewModel.isHomebrewInstalled,
            action: { viewModel.selectTarget(.homebrew) }
        )
        .accessibilityIdentifier("homebrewCard")

        PackageManagerCard(
            choice: .macPorts,
            description: String(localized: "card.macports.description"),
            symbolName: "shippingbox.fill",
            isActive: viewModel.activeManager == .macPorts,
            isSelected: viewModel.selectedTarget == .macPorts,
            isInstalled: viewModel.areMacPortsPathsPresent,
            action: { viewModel.selectTarget(.macPorts) }
        )
        .accessibilityIdentifier("macPortsCard")
    }

    private var actionSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                actionButtons
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                actionButtons
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: viewModel.applySelection) {
            Label(viewModel.primaryButtonTitle, systemImage: "arrow.triangle.2.circlepath")
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.canApply)
        .accessibilityIdentifier("applyButton")

        Button(action: viewModel.reloadFromDisk) {
            Label(String(localized: "action.reload"), systemImage: "arrow.clockwise")
                .fixedSize(horizontal: false, vertical: true)
        }
        .controlSize(.large)
        .accessibilityIdentifier("reloadButton")
    }

    @ViewBuilder
    private var messagesSection: some View {
        VStack(spacing: 10) {
            RestartNotice()
                .accessibilityIdentifier("restartNotice")

            if let successMessage = viewModel.successMessage {
                AlertCard(message: successMessage, systemImage: "checkmark.circle.fill", tint: .green)
                    .accessibilityIdentifier("successBanner")
            }

            if let errorMessage = viewModel.errorMessage {
                AlertCard(message: errorMessage, systemImage: "exclamationmark.triangle.fill", tint: .red)
            }

            if !viewModel.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .foregroundStyle(.orange)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func previewSection(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    previewHeading
                    Spacer()
                    previewPicker
                }

                VStack(alignment: .leading, spacing: 10) {
                    previewHeading
                    previewPicker
                        .frame(maxWidth: .infinity)
                }
            }

            ProfilePreview(
                mode: profilePreviewMode,
                content: viewModel.selectedPreviewText,
                currentContent: viewModel.currentContents
            )
        }
        .frame(minHeight: minHeight, maxHeight: .infinity)
    }

    private var previewHeading: some View {
        Text(String(localized: "preview.section"))
            .font(.title3.weight(.semibold))
            .accessibilityIdentifier("previewHeading")
    }

    private var supportFooter: some View {
        HStack {
            Spacer()
            Link(destination: AppLinks.support) {
                Label(
                    String(localized: "support.development"),
                    systemImage: "heart"
                )
            }
            .font(.callout)
            .accessibilityLabel(String(localized: "support.open_link"))
            .accessibilityIdentifier("supportLink")
        }
        .padding(.top, 2)
    }

    private var previewPicker: some View {
        Picker(String(localized: "access.preview_picker"), selection: $viewModel.previewMode) {
            ForEach(PackageSwitcherViewModel.PreviewMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(minWidth: 480, idealWidth: 560)
        .accessibilityLabel(String(localized: "access.preview_picker"))
        .accessibilityIdentifier("previewModePicker")
    }

    private var profilePreviewMode: ProfilePreviewMode {
        switch viewModel.previewMode {
        case .current:
            return .current
        case .preview:
            return .preview
        case .diff:
            return .diff
        }
    }

    private var statusSymbol: String {
        switch viewModel.activeManager {
        case .homebrew:
            return "mug.fill"
        case .macPorts:
            return "shippingbox.fill"
        case .mixed:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch viewModel.activeManager {
        case .homebrew:
            return .blue
        case .macPorts:
            return .teal
        case .mixed:
            return .orange
        case .unknown:
            return .secondary
        }
    }
}

private struct PackageManagerCard: View {
    let choice: PackageManagerChoice
    let description: String
    let symbolName: String
    let isActive: Bool
    let isSelected: Bool
    let isInstalled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Image(systemName: symbolName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        if isActive {
                            StatusBadge(
                                title: String(localized: "badge.active"),
                                systemImage: "checkmark.seal.fill",
                                tint: .green
                            )
                        }
                        if isSelected {
                            StatusBadge(
                                title: String(localized: "badge.selected"),
                                systemImage: "target",
                                tint: .accentColor
                            )
                        }
                        if !isInstalled {
                            StatusBadge(
                                title: String(localized: "badge.not_installed"),
                                systemImage: "xmark.circle.fill",
                                tint: .red
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(choice.displayName)
                        .font(.title2.weight(.semibold))
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        choice == .homebrew ? .blue : .teal
    }
}

private struct StatusBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct RestartNotice: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.title3.weight(.semibold))
            Text(String(localized: "notice.restart"))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(14)
        .foregroundStyle(.orange)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AlertCard: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(12)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
