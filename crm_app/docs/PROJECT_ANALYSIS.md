# CRM Mobile App — Full Project Analysis

**Generated:** June 2026  
**App version:** `1.2.5+3` (`pubspec.yaml`)  
**Package path:** `CRM-Mobile-App/crm_app`  
**Backend:** `https://crm.apptriangle.com`

---

## Table of contents

1. [Executive summary](#1-executive-summary)
2. [Tech stack](#2-tech-stack)
3. [Architecture](#3-architecture)
4. [App entry & navigation](#4-app-entry--navigation)
5. [Authentication & RBAC](#5-authentication--rbac)
6. [Feature modules](#6-feature-modules)
7. [All pages & screens](#7-all-pages--screens)
8. [API surface](#8-api-surface)
9. [State management](#9-state-management)
10. [Shared UI & theme](#10-shared-ui--theme)
11. [Services & platform integrations](#11-services--platform-integrations)
12. [Configuration & environment](#12-configuration--environment)
13. [Tests & quality](#13-tests--quality)
14. [Orphan / unwired screens](#14-orphan--unwired-screens)
15. [Known quirks & gaps](#15-known-quirks--gaps)

---

## 1. Executive summary

The CRM Mobile App is a **Flutter** client for a multi-module business CRM. It covers sales pipeline, contacts, tasks, expenses, attendance, leave, lunch ordering, notifications, and user profile/settings.

| Aspect | Choice |
|--------|--------|
| Language | Dart 3.11+ |
| UI framework | Flutter (Material 3) |
| State | Riverpod (`StateNotifierProvider`, `Provider`, families) |
| HTTP | Dio with Bearer auth + secure token storage |
| Navigation | **Imperative** (`Navigator.push`); `go_router` is in deps but **unused** |
| Auth | JWT + server RBAC (`GET /api/rbac/me`) |
| Layout | Single `ShellPage` with RBAC-filtered bottom tabs + `PageView` |

The codebase follows a **lightweight layered architecture**: `core` → `data` (models + repositories) → `presentation` (providers + pages + widgets).

---

## 2. Tech stack

### Core dependencies

| Category | Packages |
|----------|----------|
| State | `flutter_riverpod`, `riverpod_annotation` |
| Network | `dio` |
| Storage | `flutter_secure_storage` |
| UI | `google_fonts`, `dynamic_color`, `shimmer`, `flutter_slidable`, `cached_network_image`, `flutter_svg`, `confetti` |
| Maps / location | `geolocator`, `geocoding`, `flutter_map`, `latlong2`, `permission_handler` |
| Notifications | `flutter_local_notifications`, `timezone`, `flutter_timezone`, `firebase_core`, `firebase_messaging` |
| Documents | `pdf`, `printing`, `file_picker` |
| Utilities | `intl`, `url_launcher`, `vibration`, `app_tracking_transparency` |

### Dev tooling

`build_runner`, `freezed`, `json_serializable`, `riverpod_generator`, `flutter_lints`, `flutter_launcher_icons`

> Models are mostly **hand-written `fromJson`** (with `core/json_parse.dart` helpers), not Freezed-generated.

---

## 3. Architecture

```text
lib/
├── main.dart                 # Firebase init, ProviderScope, CRMApp
├── app.dart                  # Auth gate → LoginPage | ShellPage
├── firebase_options.dart
├── core/
│   ├── constants/            # API URLs, RBAC keys, storage keys
│   ├── navigation/           # Global navigator key
│   ├── network/              # ApiClient (Dio), interceptors
│   ├── services/             # FCM, location, notifications, geocoding
│   ├── theme/                # Material 3 theme, tokens, colors
│   └── json_parse.dart       # Shared JSON helpers
├── data/
│   ├── models/               # Domain / API models
│   └── repositories/         # HTTP + parsing; *RepositoryProvider each
└── presentation/
    ├── providers/            # Riverpod notifiers & derived providers
    ├── pages/                # Feature screens (65+ files)
    └── widgets/              # Shared UI components
```

**Data flow:** Page → `ref.watch(provider)` → Repository → `ApiClient` → Backend  
**Session:** Token in secure storage; 401 clears session and returns to login.

---

## 4. App entry & navigation

### Root routing (`app.dart`)

| Auth state | Screen |
|------------|--------|
| `initial` / `loading` | Loading scaffold |
| `authenticated` | `ShellPage` |
| `unauthenticated` | `LoginPage` |

No declarative router file. All secondary screens use `Navigator.push(MaterialPageRoute(...))`.

### Shell bottom navigation (`shell_page.dart`)

Tabs are built dynamically from **JWT admin** + **RBAC nav keys**:

| Tab | Page | Visibility |
|-----|------|------------|
| Dashboard | `DashboardPage` | Always |
| Attendance | `AttendanceHubPage` | Admin **or** RBAC nav `attendance` / `hr` |
| Lunch | `LunchHubPage` | Admin **or** RBAC nav `lunch` |
| Expenses | `ExpensesListPage` | Admin **or** RBAC nav `expenses` |
| More | `MorePage` | Always |

**Shell behaviors:**

- `PageView` with swipe between tabs (keep-alive children)
- Lazy tab data load via `loadedTabsProvider`
- RBAC foreground poll every **20 seconds** while app resumed
- Prefetch CRM lookup data when RBAC grants module access

### Navigation map (reachable screens)

```text
LoginPage
 └── ForgotPasswordPage

ShellPage
 ├── DashboardPage
 │    ├── NotificationsPage
 │    ├── SaleFormPage (quick action)
 │    ├── ExpenseFormPage (quick action)
 │    ├── TasksListPage (quick action)
 │    └── TaskDetailPage
 │
 ├── AttendanceHubPage
 │    ├── My requests / History / Team attendance* / Reconciliation*
 │    └── LiveLocationOsmMapPage (from dashboard TodayAttendanceCard)
 │
 ├── LunchHubPage
 │    ├── (user) My Lunch only
 │    └── (admin) My Lunch | Polls | Order Summary | Employees
 │         ├── showLunchPollFormSheet (create/edit poll)
 │         └── showLunchVoteHistorySheet (vote history modal)
 │
 ├── ExpensesListPage → ExpenseDetailPage → ExpenseFormPage
 │
 └── MorePage
      ├── ProfilePage → EditProfilePage, CompanyProfileEditPage
      ├── ContactsListPage* → ContactDetailPage → ContactFormPage
      ├── LeaveListPage* → LeaveApplyPage, LeaveBalancesPage,
      │                    LeaveHrAdminPage, LeaveDetailPage → LeaveEditPage
      ├── SettingsPage
      ├── ChangePasswordPage
      ├── NotificationSettingsPage → ReminderReliabilityGuidePage
      └── HelpSupportPage

* RBAC-gated from More menu
```

---

## 5. Authentication & RBAC

### Authentication

| Action | API / behavior |
|--------|----------------|
| Login | `POST /api/auth/login` → JWT stored in secure storage |
| Logout | `POST /api/auth/logout` + local clear |
| Session restore | `GET /api/users/me` on launch |
| Change password | `POST /api/auth/change-password` |
| Deactivate account | `POST /api/users/me/deactivate` |
| Remember me | Saved accounts JSON in secure storage |

### Two-layer roles

1. **JWT role:** `User.isAdmin` when `role == 'admin'`
2. **Server RBAC:** `GET /api/rbac/me` → `RbacMe` with:
   - `navPageKeys` — which modules appear in navigation
   - `effective` map — per-module `none` | `user` | `admin`

### RBAC page keys (`rbac_page_keys.dart`)

`sales`, `tasks`, `expenses`, `contacts`, `companies`, `leaves`, `hr`, `attendance`, `lunch`

### Common access rules

| Rule | Logic |
|------|--------|
| Shell tab visible | JWT admin **or** `hasNav(pageKey)` |
| Module admin | JWT admin **or** `effective[pageKey] == 'admin'` |
| Contacts in More | Requires `contacts` nav (not `companies` alone) |
| Leave elevated | Admin **or** leaves admin **or** `hr` nav |
| Company profile edit | Admin **or** companies RBAC admin |
| Dashboard quick actions | Nav + `hasModuleAccess` per module |

---

## 6. Feature modules

| Module | Model | Repository | Provider(s) | Primary UI |
|--------|-------|------------|-------------|------------|
| **Auth** | `user_model` | `auth_repository`, `user_repository` | `authProvider`, `isAdminProvider` | Login, profile, password |
| **RBAC** | `rbac_model` | `rbac_repository` | `rbacMeProvider`, `rbacModuleAdminProvider`, … | Shell, More, gates |
| **Dashboard** | — | — | `dashboardVisitLiveLocationRefreshTickProvider` | `DashboardPage` |
| **Sales** | `sale_model`, `activity_model` | `sale_repository` | `salesProvider`, `saleDetailProvider`, … | Deals*, detail, forms |
| **Orders** | `order_model` | `order_repository` | `ordersProvider` | Order detail/form |
| **Renewals** | `renewal_model` | `renewal_repository` | `renewalsProvider` | Renewal detail/form |
| **Contacts** | `contact_model` | `contact_repository` | `contactsProvider`, `contactDetailProvider` | List, detail, form |
| **Companies** | `company_model` | `company_repository` | `companiesProvider` | List*, dropdowns |
| **Company profile** | `company_profile_model` | `company_profile_repository` | `companyProfileProvider` | Profile, edit |
| **Tasks** | `task_model` | `task_repository` | `tasksProvider`, `taskDetailProvider`, … | List, detail, form |
| **Expenses** | `expense_model` | `expense_repository` | `expensesProvider`, `expensePurposesProvider` | Shell tab, detail, form |
| **Attendance** | `attendance_model` | `attendance_repository` | `attendanceProvider`, `attendanceWeekRollupProvider` | Hub, today card |
| **Reconciliation** | (attendance) | `attendance_repository` | `attendanceReconciliationProvider` | Hub tabs |
| **Shifts** | `shift_model` | `shift_repository` | `shiftProvider`, `userShiftTimingsProvider` | Shifts admin* |
| **Leave** | `leave_model` | `leave_repository` | `leaveProvider`, `leaveHrAdminProvider` | Leave pages |
| **Lunch** | `lunch_model` | `lunch_repository` | `lunchProvider`, `lunchAdminProvider` | Lunch hub |
| **Notifications** | `notification_model` | `notification_repository` | `notificationsProvider` | Inbox |
| **Lookups** | `status_config`, `currency` | respective repos | `statusConfigProvider`, `currenciesProvider` | Form dropdowns |
| **Theme** | — | `StorageService` | `themeProvider`, `accentColorProvider`, `amoledDarkProvider` | Settings |

---

## 7. All pages & screens

### Auth (`presentation/pages/auth/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `login_page.dart` | `LoginPage` | Email/password login, remember-me, saved accounts sheet |
| `forgot_password_page.dart` | `ForgotPasswordPage` | UI-only reset flow (no API) |

### Main shell (`presentation/pages/main/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `shell_page.dart` | `ShellPage` | Bottom nav, PageView, RBAC poll, tab prefetch |
| `more_page.dart` | `MorePage` | Profile card, RBAC menu, settings, logout |
| `notifications_page.dart` | `NotificationsPage` | In-app inbox, mark read |
| `notification_settings_page.dart` | `NotificationSettingsPage` | Task alerts, FCM toggles |
| `reminder_reliability_guide_page.dart` | `ReminderReliabilityGuidePage` | Battery/alarm troubleshooting |
| `help_support_page.dart` | `HelpSupportPage` | FAQ, email support |

### Dashboard (`presentation/pages/dashboard/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `dashboard_page.dart` | `DashboardPage` | Greeting, notifications, theme toggle, quick actions, today attendance, tasks |

### Sales & deals (`presentation/pages/sales/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `deals_page.dart` | `DealsPage` | Tabbed hub: Sales funnel \| Orders \| Renewals |
| `sales_list_page.dart` | `SalesListPage` | Typedef alias → `DealsPage` |
| `sales_funnel_tab.dart` | `SalesFunnelTab` | Pipeline stages, deal list |
| `sale_detail_page.dart` | `SaleDetailPage` | Deal detail, status, activities, logs |
| `order_detail_page.dart` | `OrderDetailPage` | Order detail, workflow |
| `order_form_page.dart` | `OrderFormPage` | Create order for a deal |
| `renewal_detail_page.dart` | `RenewalDetailPage` | Renewal detail |
| `renewal_form_page.dart` | `RenewalFormPage` | Create/edit renewal |

### Contacts (`presentation/pages/contacts/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `contacts_list_page.dart` | `ContactsListPage` | Search, filter, create |
| `contact_detail_page.dart` | `ContactDetailPage` | Profile, call/email, edit |

### Companies (`presentation/pages/companies/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `companies_list_page.dart` | `CompaniesListPage` | Company list + create |
| `company_detail_page.dart` | `CompanyDetailPage` | Detail, KAM, linked users |

### Tasks (`presentation/pages/tasks/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `tasks_list_page.dart` | `TasksListPage` | My/All filter, FAB create |
| `task_detail_page.dart` | `TaskDetailPage` | Detail, status, logs, edit |

### Expenses (`presentation/pages/expenses/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `expenses_list_page.dart` | `ExpensesListPage` | Shell tab; list + purposes (admin) |
| `expense_detail_page.dart` | `ExpenseDetailPage` | Detail, edit, delete |
| `expense_form_page.dart` | `ExpenseFormPage` | Create/edit, attachments, confetti |

### Attendance (`presentation/pages/attendance/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `attendance_hub_page.dart` | `AttendanceHubPage` | Main module: requests, history, team, reconciliation |
| `attendance_page.dart` | `AttendancePage` | Legacy redirect shim |
| `attendance_records_page.dart` | `AttendanceRecordsPage` | Standalone records (hub embeds list instead) |
| `reconciliation_team_page.dart` | `AttendanceTeamReconciliationTab` | Reviewer queue |
| `team_attendance_tab.dart` | `TeamAttendanceTab` | Admin all-users view |

**Attendance widgets:**

| File | Purpose |
|------|---------|
| `today_attendance_card.dart` | Dashboard check-in/out, GPS, late reconciliation |
| `attendance_hub_header.dart` | Week rollup stats |
| `records_list.dart` | History list embedded in hub |
| `live_location_osm_map_page.dart` | OpenStreetMap live location |
| `attendance_location_row.dart`, `attendance_place_label.dart` | Location display |

### Shifts (`presentation/pages/shifts/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `shifts_admin_page.dart` | `ShiftsAdminPage` | Shift CRUD + roster |
| `shift_form_page.dart` | `ShiftFormPage` | Create/edit shift template |

### Leave (`presentation/pages/leave/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `leave_list_page.dart` | `LeaveListPage` | My / Team / All, filters, apply FAB |
| `leave_apply_page.dart` | `LeaveApplyPage` | Apply leave, attachments |
| `leave_detail_page.dart` | `LeaveDetailPage` | Detail, approve/reject |
| `leave_edit_page.dart` | `LeaveEditPage` | Edit pending leave |
| `leave_balances_page.dart` | `LeaveBalancesPage` | User balances |
| `leave_hr_admin_page.dart` | `LeaveHrAdminPage` | Types, weekends, holidays |

### Lunch (`presentation/pages/lunch/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `lunch_hub_page.dart` | `LunchHubPage` | Shell tab; 1 or 4 admin tabs |
| `lunch_my_lunch_page.dart` | `LunchMyLunchPage` | Today's poll, vote, balance, view all votes |
| `lunch_polls_admin_page.dart` | `LunchPollsAdminPage` | Poll list, create/edit, close |
| `lunch_order_summary_page.dart` | `LunchOrderSummaryPage` | KPIs, menu breakdown, employee votes, PDF |
| `lunch_employees_page.dart` | `LunchEmployeesPage` | Employee balances, adjust balance |
| `lunch_poll_form_page.dart` | `LunchPollFormSheet` | Create/edit poll (bottom sheet) |
| `lunch_vote_history_sheet.dart` | Modal | Personal vote history by date range |
| `lunch_poll_option_row.dart` | Widget | Poll option row, avatars, type chips |
| `lunch_ui_helpers.dart` | Helpers | Formatting, badges, PDF export, voting rules |
| `lunch_hub_chrome.dart` | Widgets | Page title, filter chips |
| `lunch_settings_page.dart` | `LunchSettingsPage` | Default cost, vote-change settings *(orphan)* |
| `lunch_balance_page.dart` | `LunchBalancePage`, `LunchHistoryPage` | Standalone balance/history *(orphan)* |

#### Lunch module — user flow

1. Open **Lunch** tab → `LunchMyLunchPage`
2. See today's poll, vote on options, view balance card
3. **View all votes** sheet — grouped by menu option
4. **Vote history** teaser → bottom sheet with date presets

#### Lunch module — admin flow

| Tab | Features |
|-----|----------|
| My Lunch | Same as user |
| Polls | List polls, vote counts, create/edit/close |
| Order Summary | Choose poll, stats, menu breakdown, employee votes, PDF export |
| Employees | Search, date filter, balance per employee, adjust balance |

#### Lunch voting rules (client)

- `isVotingOpen` — active status, not cancelled, not past `endTime`
- Closed / past end time → options greyed out, `AbsorbPointer`, snackbar on tap
- `effectiveStatus` — shows CLOSED when end time passed even if API says active

### Profile & settings

| File | Widget | Functionality |
|------|--------|---------------|
| `profile/profile_page.dart` | `ProfilePage` | User + company overview |
| `settings/settings_page.dart` | `SettingsPage` | Theme, accent, notifications |
| `settings/edit_profile_page.dart` | `EditProfilePage` | PATCH `/api/users/me` |
| `settings/change_password_page.dart` | `ChangePasswordPage` | Change password |
| `settings/company_profile_edit_page.dart` | `CompanyProfileEditPage` | Org profile (RBAC admin) |

### Admin (`presentation/pages/admin/`)

| File | Widget | Functionality |
|------|--------|---------------|
| `users_page.dart` | `UsersPage` | User list + create dialog *(orphan)* |

---

## 8. API surface

All paths are relative to `AppConstants.baseUrl`. Full collection: `CRM-Mobile-App/CRM_API_Postman_Collection.json`.

### Auth & users

```
POST   /api/auth/login
POST   /api/auth/logout
POST   /api/auth/change-password
GET    /api/users
POST   /api/users
GET    /api/users/{id}
PATCH  /api/users/{id}
DELETE /api/users/{id}
PATCH  /api/users/{id}/password
GET    /api/users/me
PATCH  /api/users/me
POST   /api/users/me/deactivate
GET    /api/hr/info/{userId}
```

### RBAC

```
GET    /api/rbac/me
```

### CRM core

```
Companies, contacts, tasks, sales, orders, renewals, expenses, expense-purposes,
status-config, currencies, company-profile, notifications
```

### Attendance & shifts

```
GET/POST  /api/attendance/today, check-in, check-out, records, all
GET/POST  /api/attendance/reconciliations
POST      /api/attendance/reconciliations/{id}/review
GET/POST  /api/shifts, assign
```

### Leave

```
GET  /api/leaves/my, /team, /all
POST /api/leaves/apply
GET/PATCH /api/leaves/{id}
POST /api/leaves/{id}/approve, /reject
Types, balances, weekends, holidays, calculate-days, is-reporting-manager
```

### Lunch

```
GET/PATCH  /api/lunch/settings
GET        /api/lunch/dashboard
GET        /api/lunch/polls/today
GET/POST   /api/lunch/polls
GET/PATCH/DELETE /api/lunch/polls/{id}
PATCH      /api/lunch/polls/{id}/status
POST       /api/lunch/polls/{id}/vote
GET        /api/lunch/polls/{id}/summary
GET        /api/lunch/votes/history
GET        /api/lunch/balance/me, /transactions, /employees
POST       /api/lunch/balance/adjust
```

### HTTP client (`api_client.dart`)

- Bearer token on every request
- 401 with Authorization header → clear session → login
- Timeouts: 30s connect/receive/send

---

## 9. State management

### Repository providers (18)

`authRepositoryProvider`, `userRepositoryProvider`, `rbacRepositoryProvider`, `companyRepositoryProvider`, `companyProfileRepositoryProvider`, `contactRepositoryProvider`, `taskRepositoryProvider`, `saleRepositoryProvider`, `orderRepositoryProvider`, `renewalRepositoryProvider`, `expenseRepositoryProvider`, `attendanceRepositoryProvider`, `shiftRepositoryProvider`, `leaveRepositoryProvider`, `lunchRepositoryProvider`, `notificationRepositoryProvider`, `statusConfigRepositoryProvider`, `currencyRepositoryProvider`

### Notable feature providers

| Area | Key providers |
|------|----------------|
| Auth | `authProvider`, `currentUserIdProvider`, `isAdminProvider` |
| RBAC | `rbacMeProvider`, `rbacModuleAdminProvider`, `rbacAccessDigestProvider` |
| Shell | `selectedTabProvider`, `loadedTabsProvider` |
| Lunch | `lunchProvider`, `lunchAdminProvider`, `lunchModuleVisibleProvider` |
| Theme | `themeProvider`, `accentColorProvider`, `amoledDarkProvider` |
| Notifications | `notificationsProvider`, `notificationSettingsProvider`, `taskDeadlineNotifierProvider` |

### Prefetch

`prefetchCrmLookupData()` in `rbac_prefetch.dart` loads companies/users when RBAC grants modules that need dropdown data.

---

## 10. Shared UI & theme

### Widgets (`presentation/widgets/`)

| Widget | Purpose |
|--------|---------|
| `CRMCard` | Primary card container |
| `CRMButton` | Styled buttons |
| `CRMTextField` | Form fields |
| `LoadingWidget` | Spinner + message |
| `ErrorWidget` / `EmptyStateWidget` | Error / empty states |
| `ListPageState` | List loading/error/content wrapper |
| `AppSearchFilterBar` | Search + filter bar |
| `SearchableDropdown` | Searchable pickers |
| `StatusBadge` | Status pills |
| `AvatarWidget` | User avatars |
| `KpiCard` | Metric cards |
| `CelebrationShell` | Confetti on success |
| `ProfileOverviewBody` | Profile sections |

### Theme (`core/theme/`)

Material 3 with `AppThemeColors`, `DesignTokens`, dynamic accent color, OLED black mode option, semantic color extensions.

---

## 11. Services & platform integrations

| Service | File / package | Purpose |
|---------|----------------|---------|
| FCM push | `firebase_messaging`, `fcm_background.dart` | Remote notifications |
| Local notifications | `flutter_local_notifications` | Task deadline reminders |
| Location | `geolocator`, `geocoding` | Attendance check-in GPS |
| Maps | `flutter_map`, OSM tiles | Live location map |
| Geocoding | `nominatim_reverse_geocoding_service.dart` | Place labels |
| PDF | `pdf`, `printing` | Lunch order summary export |
| Secure storage | `flutter_secure_storage` | Tokens, prefs |
| URL launcher | `url_launcher` | Mail, tel, links |

---

## 12. Configuration & environment

| Item | Location | Notes |
|------|----------|-------|
| API base URL | `lib/core/constants/app_constants.dart` | Hardcoded production URL |
| RBAC poll interval | `app_constants.dart` | 20 seconds |
| Currency symbol | `app_constants.dart` | `৳` (BDT) |
| `.env` | `crm_app/.env` | Nanonets keys only; **not loaded by app** |
| Firebase | `firebase_options.dart` | Platform FCM config |
| Postman | `../CRM_API_Postman_Collection.json` | API reference |

---

## 13. Tests & quality

| File | Coverage |
|------|----------|
| `test/widget_test.dart` | Smoke: `CRMApp` mounts under `ProviderScope` |
| `test/lunch_model_test.dart` | Lunch JSON parsing, vote derivation |

No integration tests, repository tests, or broad widget tests.

### Other docs in `docs/`

- `ui-smoke-test-plan.md`
- `ui-regression-notes.md`
- `ui-consistency-checklist.md`
- `superpowers/specs/2026-06-22-lunch-module-design.md`

---

## 14. Orphan / unwired screens

These are **implemented** but have **no navigation entry** in the current app:

| Screen | Notes |
|--------|-------|
| `DealsPage` | Full sales/orders/renewals hub; only `SaleFormPage` reachable via dashboard |
| `UsersPage` | Admin user management |
| `ShiftsAdminPage` | Shift CRUD |
| `CompaniesListPage` | Company list (companies used in dropdowns only) |
| `LunchSettingsPage` | Lunch default settings |
| `LunchBalancePage` / `LunchHistoryPage` | Superseded by My Lunch inline UI |
| `AttendancePage` | Redirect shim to hub |

---

## 15. Known quirks & gaps

| Issue | Detail |
|-------|--------|
| `go_router` unused | All navigation is imperative; no deep links |
| Deals hub hidden | `DealsPage` built but not in bottom nav or More |
| Duplicate `usersProvider` | `admin/users_page.dart` shadows `user_provider.dart` |
| Version string mismatch | `pubspec` `1.2.5+3` vs More page may show older version |
| `.env` not wired | Flutter app does not use `flutter_dotenv` |
| Forgot password | UI only; no backend call |
| Lunch list vote counts | Requires summary API hydration when poll list omits counts |
| Test coverage | Minimal unit/widget tests |

---

## Appendix: File counts

| Area | Approx. files |
|------|----------------|
| `lib/presentation/pages/` | 65+ |
| `lib/presentation/providers/` | 25+ |
| `lib/data/repositories/` | 18 |
| `lib/data/models/` | 20+ |
| `lib/presentation/widgets/` | 18 |
| `test/` | 2 |

---

*This document reflects the codebase as of the analysis date. For API request/response shapes, use the Postman collection and backend source.*
