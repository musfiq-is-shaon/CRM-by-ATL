# UI Regression Notes Template

Use this checklist before each release to validate recent UI/theme changes.

## Release Metadata

- Release version:
- Build number:
- Test date:
- Tester:
- Device(s):
- OS version(s):
- Theme mode(s) tested: Light / Dark

## Navigation and App Bars

- App bars use consistent title style (`AppThemeColors.appBarTitle`) on key flows.
- Back/close actions are visible and work correctly.
- App bar actions (refresh/save/edit) remain aligned and tappable.

## Spacing and Layout

- Page body paddings follow shared constants (`AppThemeColors.pagePaddingAll` / top variants).
- No horizontal overflow or clipped controls on small screens.
- Dialogs/sheets feel consistent in spacing and corner radius.

## Typography and Colors

- Body/heading text uses `TextTheme` or shared theme helpers where expected.
- Warning/error/success semantics use theme-aware colors (no hardcoded conflict colors).
- Contrast is readable in both light and dark theme.

## Core Flow Smoke Checks

- Leave: list, apply, detail, and edit screens render correctly.
- Contacts: detail + create/edit form render correctly and inputs are legible.
- Companies: detail + edit/delete dialogs render correctly and buttons are clear.
- Shifts: admin list + shift form render correctly and weekend chips are usable.
- Attendance records: page title, background, and list spacing are correct.

## State Handling

- Loading states are visible and non-blocking where expected.
- Empty states are informative and aligned with theme.
- Error states/snackbars use semantic error styling and readable text.

## Responsive and Accessibility Checks

- 200% text scaling does not break primary layout.
- TalkBack/VoiceOver reads key controls with meaningful labels.
- Touch targets are usable for primary actions.

## Findings

### Critical

- [ ] None
- Notes:

### Major

- [ ] None
- Notes:

### Minor

- [ ] None
- Notes:

## Sign-off

- QA result: Pass / Pass with notes / Fail
- Blockers:
- Follow-up tickets:
