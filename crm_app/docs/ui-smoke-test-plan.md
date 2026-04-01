# UI Smoke Test Plan

Run this quick pass before release or after major UI/theme updates.

## Environment Matrix

- Theme: Light + Dark
- Accent: Default + one alternate accent
- Device sizes: small phone + large phone

## Core Navigation

- Login flow reaches dashboard.
- Bottom tabs switch without layout jumps.
- Back navigation works from detail/forms.

## Global Visual Checks

- App bars: consistent height, title style, and actions color.
- Page paddings: no cramped or overly spaced content.
- Cards/panels: border/surface consistent with theme.
- No overflow warnings in console.

## State Checks (per major list screen)

- Loading: spinner/state placeholder appears.
- Error: retry action visible and works.
- Empty: friendly empty message appears.
- Content: list rows align and are tappable.

## Search/Filter Screens

- Search input clears correctly.
- Filter button opens dialog/sheet.
- Active filter badge count updates accurately.
- Clearing filters resets the list.

## Leave Module

- Balance table shows Cred/Rem/Add clearly.
- Additional values are alert-colored only when > 0.
- Overlap validation blocks conflicting dates.
- Zero remaining still allows apply (additional leave path).

## Accessibility and Interaction

- Icon-only actions have tooltip/semantic meaning.
- Tap targets are easy to press.
- Text contrast remains readable in both themes.

## Final Verification

- Run `dart analyze` and ensure zero issues.
- Perform one end-to-end user flow:
  - create/edit item,
  - view detail,
  - return to list,
  - verify refresh/state.
