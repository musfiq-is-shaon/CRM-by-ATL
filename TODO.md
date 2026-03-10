# TODO - Contact Filter Page Fix

## Task: Fix contact filter page positioning issue

### Issue:
The contact filter page is positioned too low in the screen, causing the company dropdown to not show fully when clicked.

### Steps to Complete:

- [x] 1. Modify `contacts_list_page.dart` - Update `_showFilterDialog` to constrain bottom sheet height
- [x] 2. Modify `searchable_dropdown.dart` - Add logic to show dropdown above if space below is insufficient

### Files Edited:
1. `crm_app/lib/presentation/pages/contacts/contacts_list_page.dart`
2. `crm_app/lib/presentation/widgets/searchable_dropdown.dart`

### Changes Made:
1. **contacts_list_page.dart**: 
   - Added `ConstrainedBox` with max height of 70% of screen
   - Wrapped content in `SingleChildScrollView` for scrollability
   - Updated padding to handle keyboard

2. **searchable_dropdown.dart**:
   - Added logic to calculate available space above/below dropdown
   - Shows dropdown above if there's not enough space below
   - Uses calculated `offsetY` for proper positioning

### Testing:
Build and run the app to verify the fix
- Navigate to Contacts page
- Click on filter icon
- Verify the filter dialog is properly positioned
- Click on company dropdown and verify options are visible

