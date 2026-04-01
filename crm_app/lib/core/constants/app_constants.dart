class AppConstants {
  AppConstants._();

  // API Base URL - Update this to your production URL
  static const String baseUrl = 'https://be-crm-production-a948.up.railway.app';

  // API Endpoints
  static const String authLogin = '/api/auth/login';
  static const String authLogout = '/api/auth/logout';
  static const String authChangePassword = '/api/auth/change-password';

  static const String users = '/api/users';
  static const String usersMe = '/api/users/me';
  static const String usersMeDeactivate = '/api/users/me/deactivate';

  static const String companies = '/api/companies';
  static const String contacts = '/api/contacts';
  static const String tasks = '/api/tasks';
  static const String sales = '/api/sales';
  static const String statusConfig = '/api/status-config';
  static const String companyProfile = '/api/company-profile';
  static const String currencies = '/api/currencies';
  static const String expenses = '/api/expenses';
  static const String expensePurposes = '/api/expense-purposes';
  static const String notifications = '/api/notifications';
  static const String notificationsReadAll = '/api/notifications/read-all';
  static String notificationRead(String notificationId) =>
      '/api/notifications/$notificationId/read';
  static String notificationById(String notificationId) =>
      '/api/notifications/$notificationId';

  // Attendance endpoints
  static const String attendanceToday = '/api/attendance/today';
  static const String attendanceCheckIn = '/api/attendance/check-in';
  static const String attendanceCheckOut = '/api/attendance/check-out';
  static const String attendanceRecords = '/api/attendance/records';

  // Shifts (HR — required for check-in/out; see Postman "Shifts")
  static const String shifts = '/api/shifts';
  static const String shiftsAssign = '/api/shifts/assign';
  static String shiftById(String shiftId) => '/api/shifts/$shiftId';

  /// Leave requests (base path used by backend sub-routes).
  /// "My leaves" — backend route is `/my` (not `/me`).
  static const String leavesMy = '/api/leaves/my';
  static const String leavesTeam = '/api/leaves/team';
  static const String leavesAll = '/api/leaves/all';
  static const String leavesApply = '/api/leaves/apply';
  static const String leavesTypes = '/api/leaves/types';
  static const String leavesTypesAll = '/api/leaves/types/all';
  static const String leavesReportingManager = '/api/leaves/is-reporting-manager';
  static const String leavesCalculateDays = '/api/leaves/calculate-days';

  static String leavesTypeById(String leaveTypeId) =>
      '/api/leaves/types/$leaveTypeId';
  static String leavesBalances(String userId) =>
      '/api/leaves/balances/$userId';
  static const String leavesWeekends = '/api/leaves/weekends';
  static String leavesWeekendById(String weekendId) =>
      '/api/leaves/weekends/$weekendId';
  static const String leavesHolidays = '/api/leaves/holidays';
  static String leavesHolidayById(String holidayId) =>
      '/api/leaves/holidays/$holidayId';

  static String leavesById(String leaveId) => '/api/leaves/$leaveId';
  static String leavesApprove(String leaveId) => '/api/leaves/$leaveId/approve';
  static String leavesReject(String leaveId) => '/api/leaves/$leaveId/reject';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String refreshTokenKey = 'refresh_token';

  // Timeouts
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int sendTimeout = 30000;

  // Retry
  static const int maxRetries = 3;
}
