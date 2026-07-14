import Foundation
import SwiftUI

enum ProfilePreviewMode {
    case current
    case preview
    case diff
}

enum ProfilePreviewLineRole: Equatable {
    case active
    case inactive
    case neutral
    case diffHeader
    case added
    case removed
}

struct ProfilePreviewLine: Identifiable, Equatable {
    let id: Int
    let text: String
    let role: ProfilePreviewLineRole
    let differsFromCurrent: Bool

    var marker: String? {
        switch role {
        case .added:
            return "+"
        case .removed:
            return "-"
        case .active, .inactive, .neutral, .diffHeader:
            return nil
        }
    }

    var displayText: String {
        guard role == .added || role == .removed else { return text }

        let withoutMarker = text.dropFirst()
        return withoutMarker.first == " "
            ? String(withoutMarker.dropFirst())
            : String(withoutMarker)
    }
}

enum ProfilePreviewPresentation {
    private static let activePackageManagerLines: Set<String> = [
        "eval \"$" + "(/opt/homebrew/bin/brew shellenv)\"",
        "export PATH=\"/opt/local/bin:/opt/local/sbin:$PATH\"",
        "export MANPATH=\"/opt/local/share/man:$MANPATH\"",
        "export INFOPATH=\"/opt/local/share/info/$INFOPATH\""
    ]

    private static let inactivePackageManagerLines: Set<String> = [
        "#eval \"$" + "(/opt/homebrew/bin/brew shellenv)\"",
        "#export PATH=\"/opt/local/bin:/opt/local/sbin:$PATH\"",
        "#export MANPATH=\"/opt/local/share/man:$MANPATH\"",
        "#export INFOPATH=\"/opt/local/share/info/$INFOPATH\""
    ]

    static func lines(
        for mode: ProfilePreviewMode,
        content: String,
        currentContent: String
    ) -> [ProfilePreviewLine] {
        var currentLineCounts = splitLines(currentContent).reduce(into: [String: Int]()) {
            $0[$1, default: 0] += 1
        }

        return splitLines(content).enumerated().map { index, text in
            let differsFromCurrent: Bool
            if mode == .preview, currentLineCounts[text, default: 0] > 0 {
                currentLineCounts[text, default: 0] -= 1
                differsFromCurrent = false
            } else {
                differsFromCurrent = mode == .preview
            }

            return ProfilePreviewLine(
                id: index,
                text: text,
                role: role(for: text, mode: mode),
                differsFromCurrent: differsFromCurrent
            )
        }
    }

    private static func splitLines(_ content: String) -> [String] {
        content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    private static func role(
        for text: String,
        mode: ProfilePreviewMode
    ) -> ProfilePreviewLineRole {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        if mode == .diff {
            if trimmed.hasPrefix("--- ") || trimmed.hasPrefix("+++ ") {
                return .diffHeader
            }
            if trimmed.hasPrefix("+") {
                return .added
            }
            if trimmed.hasPrefix("-") {
                return .removed
            }
            return .neutral
        }

        if activePackageManagerLines.contains(trimmed) {
            return .active
        }
        if inactivePackageManagerLines.contains(trimmed) {
            return .inactive
        }
        return .neutral
    }
}

struct ProfilePreview: View {
    let mode: ProfilePreviewMode
    let content: String
    let currentContent: String

    private var lines: [ProfilePreviewLine] {
        ProfilePreviewPresentation.lines(
            for: mode,
            content: content,
            currentContent: currentContent
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(lines) { line in
                        ProfilePreviewRow(line: line, mode: mode)
                    }
                }
                .textSelection(.enabled)
                .padding(10)
                .frame(
                    minWidth: max(geometry.size.width - 20, 0),
                    alignment: .topLeading
                )
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .frame(minHeight: 130, idealHeight: 240, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 7)
        .accessibilityIdentifier("profilePreviewCode")
    }
}

private struct ProfilePreviewRow: View {
    let line: ProfilePreviewLine
    let mode: ProfilePreviewMode

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if mode == .diff {
                Text(line.marker ?? "")
                    .foregroundStyle(markerColor)
                    .fontWeight(.semibold)
                    .frame(width: 14, alignment: .center)
            }

            Text(line.displayText)
                .foregroundStyle(foregroundColor)
                .fontWeight(fontWeight)
                .frame(minHeight: 20, alignment: .leading)
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var foregroundColor: Color {
        switch line.role {
        case .active:
            return .accentColor
        case .inactive, .diffHeader:
            return .secondary
        case .added, .removed:
            return .primary
        case .neutral:
            return mode == .diff ? .secondary : .primary
        }
    }

    private var markerColor: Color {
        switch line.role {
        case .added:
            return .green
        case .removed:
            return .red
        case .active, .inactive, .neutral, .diffHeader:
            return .secondary
        }
    }

    private var fontWeight: Font.Weight {
        switch line.role {
        case .active, .added, .removed:
            return .medium
        case .inactive, .neutral, .diffHeader:
            return .regular
        }
    }

    private var accessibilityLabel: String {
        let roleDescription: String
        switch line.role {
        case .active:
            roleDescription = String(localized: "access.active_line")
        case .inactive:
            roleDescription = String(localized: "access.inactive_line")
        case .added:
            roleDescription = String(localized: "access.added_line")
        case .removed:
            roleDescription = String(localized: "access.removed_line")
        case .diffHeader:
            roleDescription = String(localized: "access.diff_header")
        case .neutral:
            roleDescription = String(localized: "access.profile_line")
        }

        return line.differsFromCurrent
            ? String(
                format: String(localized: "access.preview_changed_format"),
                roleDescription
            )
            : roleDescription
    }

    private var accessibilityValue: String {
        line.displayText.isEmpty ? String(localized: "access.blank_line") : line.displayText
    }

    private var backgroundColor: Color {
        switch line.role {
        case .added:
            return Color.green.opacity(0.10)
        case .removed:
            return Color.red.opacity(0.10)
        case .active:
            return Color.accentColor.opacity(line.differsFromCurrent ? 0.10 : 0.06)
        case .inactive:
            return line.differsFromCurrent
                ? Color.accentColor.opacity(0.06)
                : Color.primary.opacity(0.035)
        case .neutral:
            return line.differsFromCurrent
                ? Color.accentColor.opacity(0.045)
                : Color.clear
        case .diffHeader:
            return Color.primary.opacity(0.035)
        }
    }
}
