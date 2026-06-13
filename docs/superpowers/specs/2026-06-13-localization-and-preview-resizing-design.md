# Localization And Preview Resizing Design

## Goal

Localize every user-visible PackageSwitcher string into English, Simplified Chinese, Spanish, French, German, Japanese, Korean, Portuguese, Arabic, and Hindi. Also make the bottom Current Profile, Preview After Applying, and Diff area grow vertically with the app window.

The shell-switching implementation remains behaviorally identical.

## Localization Architecture

Add one `Localizable.xcstrings` String Catalog containing:

- `en`
- `zh-Hans`
- `es`
- `fr`
- `de`
- `ja`
- `ko`
- `pt`
- `ar`
- `hi`

Use stable semantic localization keys instead of English source text as identifiers. SwiftUI views use localized keys directly where no interpolation is needed and `String(localized:)` or localized format resources where dynamic values are inserted.

Keep these terms unchanged in every translation:

- Homebrew
- MacPorts
- `.bash_profile`
- Shell commands and file paths
- PATH
- MANPATH
- INFOPATH
- Other environment variables

## User-Visible Coverage

Localize:

- Header title, subtitle, and helper text.
- Current manager labels and detected-profile text.
- Profile file and switch-section labels.
- Package-manager card descriptions and status badges.
- Action buttons and no-change state.
- Restart notice.
- Success, error, read failure, missing installation, mixed, and unknown warnings.
- Preview section title and segmented labels.
- Empty current/preview/diff states.
- Diff headers.
- Preview-row accessibility roles and blank-line description.
- Any other string surfaced by `LocalizedError` or the view model.

System image names, accessibility identifiers, enum identities, and test hooks remain unlocalized.

## Model And Service Boundaries

`PackageManagerChoice` keeps its existing enum cases and raw values. Its user-facing `displayName` and `switchVerb` become localized computed properties.

`PackageSwitcherViewModel.PreviewMode` stops using English raw values for display. Enum identity remains `current`, `preview`, and `diff`; a localized `displayName` property supplies picker text.

`PackageSwitcherService` may change only where a user-visible message is constructed:

- Unsupported-choice error.
- Profile read failure.
- Homebrew/MacPorts path warnings.
- Mixed and unknown state warnings.

The following remain byte-for-byte unchanged:

- `defaultProfileURL`.
- `previewContent`.
- `applySwitch`.
- `createBackup`.
- `detectActiveManager`.
- Homebrew and MacPorts shell-line constants and blocks.
- Export paths and INFOPATH syntax.

## Layout

The app’s outer layout must consume available window height. The preview section receives higher layout priority and its code container uses a reasonable minimum height without a fixed maximum height.

`ProfilePreview` retains:

- Horizontal and vertical scrolling.
- Monospaced selectable text.
- Existing Current/Preview/Diff styling.
- Rounded semantic container styling.

Long localized content may wrap in headers, notices, cards, badges, and actions. Fixed widths that prevent translated strings from fitting are removed or changed to flexible maximum widths. Technical profile content does not wrap and remains horizontally scrollable.

SwiftUI supplies right-to-left layout automatically under Arabic. Deliberate left-to-right forcing is not added to general UI. Shell/profile text remains naturally displayed as monospaced technical content.

## UI Testing

UI tests identify controls and important regions using accessibility identifiers rather than English visible text. Add identifiers for localized labels where an existence assertion is useful.

Unit tests continue protecting:

- Exact shell blocks and export strings.
- INFOPATH slash syntax.
- No managed block markers.
- Dynamic current-user `.bash_profile`.
- Custom profile URL injection.
- Comment/uncomment replacement behavior.
- Backup behavior.

Add localization safety checks where practical:

- String Catalog parses as valid JSON.
- All required locale codes are present.
- All catalog entries include every requested locale.
- Technical terms that must remain unchanged are preserved where they appear.

## Verification

Verify:

1. All Swift and XCTest sources compile.
2. The app and test targets build, using a verification-only resource exclusion if the unrelated `AppIcon.icon` issue remains.
3. Existing shell behavior tests remain unchanged and compile.
4. `PackageSwitcherService` protected methods/constants match their pre-localization hashes or exact extracted text.
5. No `/Users/murph`, `.zprofile`, `.zshrc`, or managed block system is introduced.
6. The String Catalog contains all ten locales for every entry.
7. English and at least one non-Latin locale can launch when the local environment permits.
8. The preview area has no fixed maximum height and expands with the window.
