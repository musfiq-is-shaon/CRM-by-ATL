# UI Consistency Checklist

Use this checklist before merging UI-heavy changes.

## Theme and Colors

- Use `AppThemeColors.appBarTitle()` for top-level page app bars.
- Prefer `AppThemeColors.pagePaddingAll` / `pagePaddingTop` over ad-hoc paddings.
- Avoid hardcoded colors like `Colors.red`; use semantic `ColorScheme` roles.
- Prefer `surfaceContainer*` roles for panels/cards instead of custom blends.

## Typography and Spacing

- Prefer `Theme.of(context).textTheme.*` styles over one-off `TextStyle` sizes.
- Use `AppSpacing` and `AppRadius` tokens where possible.
- Keep vertical rhythm on the 8px grid.

## Lists and States

- For loading/error/empty/content on list pages, use `ListPageState`.
- For search/filter headers, use `AppSearchFilterBar`.
- Keep pull-to-refresh behavior consistent where data is remote.

## Semantic Labels and Status

- Use `AppSemanticPill` for role/status chips instead of custom colored containers.
- Add semantics/tooltips for icon-only actions (`IconButton`, filter buttons).
- Keep warning/danger tones reserved for actual risk/error signals.

## Accessibility

- Ensure text contrast on custom surfaces in both light and dark themes.
- Keep tap targets reasonably sized (~44px or larger).
- Use clear labels for abbreviated column headers (add legend/hint if needed).

## QA Pass

- Check each changed screen in:
  - Light mode
  - Dark mode
  - At least one non-default accent color
- Verify no overflow warnings in logs.
- Run `dart analyze` before finalizing.
