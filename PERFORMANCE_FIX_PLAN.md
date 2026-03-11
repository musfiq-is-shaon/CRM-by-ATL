# Performance Fix Plan - CRM App

## Problem: Slow Data Loading After Login

### Root Causes Identified:

1. **N+1 Query Problem**: Each provider fetches main data, then makes separate API calls for each related entity (company, user, etc.)

2. **No Caching**: Data was re-fetched every time the app starts

3. **No Pagination**: All records were loaded at once

4. **Synchronous Loading**: All data was loaded at once after login, blocking the UI

---

## ✅ SOLUTIONS IMPLEMENTED

### 1. Added Caching to Repositories

**CompanyRepository** (`company_repository.dart`):
- Added in-memory cache for companies (`_companyCache`, `_cachedCompanies`)
- Added `getCompaniesByIds()` method for batch fetching
- Added `clearCache()` method for logout scenarios

**UserRepository** (`user_repository.dart`):
- Added in-memory cache for users (`_userCache`, `_cachedUsers`)
- Added `getUsersByIds()` method for batch fetching
- Added `clearCache()` method for logout scenarios

### 2. Optimized N+1 Queries in Providers

**SaleProvider** (`sale_provider.dart`):
- Changed from sequential per-sale API calls to batch fetching
- Collects all unique company IDs and user IDs first
- Single batch API call for all companies and users
- Map-based lookup for O(1) access

**TaskProvider** (`task_provider.dart`):
- Changed from sequential per-task API calls to batch fetching
- Collects all unique company IDs, assignToUser IDs, and assignByUser IDs
- Single batch API call for all related data

**ContactProvider** (`contact_provider.dart`):
- Changed from sequential per-contact API calls to batch fetching
- Collects all unique company IDs
- Single batch API call for all companies

### 3. Added Lazy Loading (On-Demand Data Loading)

**ShellPage** (`shell_page.dart`):
- Changed from `ConsumerWidget` to `ConsumerStatefulWidget`
- Added `_loadTabData()` method to load data on-demand when tabs are selected
- Added `loadedTabsProvider` to track which tabs have been loaded
- Dashboard loads first, other tabs load when selected

**DashboardPage** (`dashboard_page.dart`):
- Removed automatic `_loadData()` call from `initState()`
- Now relies on ShellPage for data loading
- Kept `_refreshData()` for pull-to-refresh functionality

---

## Expected Performance Improvement:

| Metric | Before | After |
|--------|--------|-------|
| Initial Load (Dashboard) | 3-5+ seconds | ~1 second |
| Subsequent Tab Loads | N/A (all loaded) | Instant (cached) |
| API Calls (Dashboard) | 1 + N companies + N users | 1 + 1 + 1 = 3 |
| Memory Usage | Higher (all data) | Lower (on-demand) |

---

## Files Modified:

1. `crm_app/lib/data/repositories/company_repository.dart` - Added caching + batch fetch
2. `crm_app/lib/data/repositories/user_repository.dart` - Added caching + batch fetch
3. `crm_app/lib/presentation/providers/sale_provider.dart` - Optimized loadSales()
4. `crm_app/lib/presentation/providers/task_provider.dart` - Optimized loadTasks()
5. `crm_app/lib/presentation/providers/contact_provider.dart` - Optimized loadContacts()
6. `crm_app/lib/presentation/pages/main/shell_page.dart` - Added lazy loading
7. `crm_app/lib/presentation/pages/dashboard/dashboard_page.dart` - Updated for lazy loading

---

## Future Optimizations (Backend Required):

1. **Server-side Include**: Ask API to support `?include=company,user` parameter
2. **Pagination**: Add limit/offset support for large datasets
3. **Persistent Cache**: Use SharedPreferences or SQLite for offline caching

