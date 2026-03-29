# Attendance Restructuring TODO

## Completed: 0/8

- [x] 1. Create `crm_app/lib/presentation/pages/attendance/attendance_records_page.dart` - full page for records using RecordsList.
- [x] 2. Update `today_attendance_card.dart` → independent ConsumerWidget with internal location dialog.
- [x] 3. Update `attendance_page.dart` → redirect to AttendanceRecordsPage.
- [x] 4. Update `shell_page.dart` - remove Attendance tab (index 4), shift More to 4, remove nav item/case.
- [x] 5. Update `dashboard_page.dart` - add TodayAttendanceCardWidget after welcome, loadToday() in refresh.
 - [x] 6. Update `more_page.dart` - add 'Attendance Records' menu in Management section → AttendanceRecordsPage.
- [ ] 7. Update shell_page.dart & dashboard initState - ensure loadToday() on dashboard.
- [ ] 8. Test: flutter run, verify dashboard checkin, More→Records, no Attendance tab.

**Next: User confirm each step success before next.**
