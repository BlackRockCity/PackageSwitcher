# Preview Area Clarity Design

## Goal

Improve the bottom profile preview so each mode communicates its purpose clearly:

- Current profile answers, "What state is this file in now?"
- Preview after applying answers, "What state will this file be in?"
- Diff answers, "What changed?"

This work changes presentation only. It must not alter profile detection, shell-switching behavior, export lines, backup behavior, atomic writes, or the `.bash_profile` target.

## Architecture

Keep the existing segmented `PreviewMode` picker and introduce a reusable SwiftUI code container that renders profile content as individual rows. A small presentation model will classify each row for styling without changing or replacing the service's shell-profile logic.

The presentation model will operate on strings already supplied by `PackageSwitcherViewModel`:

- Current mode receives `currentContents`.
- Preview mode receives `previewContents` and may compare each row with `currentContents`.
- Diff mode receives the existing diff text.

Classification is display-only. It must not be used to detect the active package manager or generate profile output.

## Line Roles

### Current Profile

Recognized uncommented Homebrew and MacPorts lines are classified as active package-manager lines. They receive a subtle semantic accent tint and slightly stronger foreground emphasis.

Recognized commented Homebrew and MacPorts lines are classified as inactive package-manager lines. They use secondary foreground styling and a faint neutral background.

All unrelated `.bash_profile` content remains visually normal.

Current mode must not use red or green diff colors.

### Preview After Applying

The final `previewContents` string remains the source of truth.

Recognized uncommented package-manager lines receive the same subtle active-state emphasis as Current mode. Recognized commented lines receive muted inactive-state styling.

Rows whose exact text does not appear in `currentContents` receive an additional very light accent-color tint. This tint remains neutral in meaning and must not resemble an error, warning, addition, or removal state.

Preview mode must not use red or green diff colors.

### Diff

The `--- Current profile` and `+++ Preview after applying` header rows are classified first and remain neutral. After that header check, diff rows beginning with `+` are additions. They receive:

- A green plus marker.
- Green-tinted foreground emphasis.
- A low-opacity semantic green row background.

Rows beginning with `-` after the header check are removals. They receive:

- A red minus marker.
- Red-tinted foreground emphasis.
- A low-opacity semantic red row background.

Diff headers and context lines remain neutral or secondary. Green and red backgrounds must be subtle enough for comfortable use in both light and dark mode.

## Code Container

All modes use a shared rounded code container with:

- Monospaced body text.
- Comfortable horizontal and vertical row padding.
- Increased line spacing compared with the current single text block.
- Horizontal and vertical scrolling.
- A semantic text background and low-contrast border.
- Text selection to preserve copyability where SwiftUI permits it.

Rows fill the available width so background emphasis reads clearly. Content remains leading-aligned and does not imitate a terminal window.

## Color And Accessibility

Use SwiftUI semantic colors such as `Color.accentColor`, `Color.green`, `Color.red`, `Color.primary`, and `Color.secondary`, combined with low opacity for backgrounds. Do not introduce fixed RGB colors that assume a light or dark appearance.

Color is not the only diff indicator: added and removed rows retain visible `+` and `-` markers. Active and inactive state also differs through foreground weight and muting.

## Testing

Add focused tests for the presentation model:

- Active Homebrew and MacPorts lines are classified as active.
- Commented Homebrew and MacPorts lines are classified as inactive.
- Unrelated profile lines remain neutral.
- Added and removed diff lines are classified correctly.
- Diff headers and context lines remain neutral, including headers whose text begins with `---` or `+++`.
- Preview rows that differ from current content can be identified without changing their text.

Existing service tests remain unchanged except where compilation requires access to shared line constants. The tests must continue to prove that shell output and switching behavior are unchanged.

## Scope Boundaries

This change will not:

- Modify `PackageSwitcherService.previewContent`.
- Change Homebrew or MacPorts export strings.
- Change `INFOPATH` syntax.
- Add managed blocks.
- Add zsh profile detection.
- Change profile backup or atomic-write behavior.
- Redesign package-manager cards, actions, warnings, or other app sections.
