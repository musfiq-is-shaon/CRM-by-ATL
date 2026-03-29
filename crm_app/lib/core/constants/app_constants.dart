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

  // Attendance endpoints
  static const String attendanceToday = '/api/attendance/today';
  static const String attendanceCheckIn = '/api/attendance/check-in';
  static const String attendanceCheckOut = '/api/attendance/check-out';
  static const String attendanceRecords = '/api/attendance/records';

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
