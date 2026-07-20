# Lunch Module — Mobile Design Spec

**Date:** 2026-06-22  
**Scope:** Option A — full module (user + admin)  
**API base:** `https://crm.apptriangle.com`  
**Lunch prefix:** `/api/lunch`  
**RBAC pageKey:** `lunch`

---

## Goal

Implement the complete Lunch module in the Flutter CRM app, matching the Postman collection (17 endpoints) and existing patterns (Leave module, Riverpod, repository layer, RBAC gating).

---

## Approaches Considered

### A — Tabbed hub (recommended)

Single **Lunch Hub** screen with tabs: **Today**, **Balance**, **History** (+ admin tabs when elevated).

- Pros: Matches Leave list + HR admin pattern; one entry point from More menu; scales for admin features.
- Cons: Slightly more initial scaffolding.

### B — Flat navigation stack

Separate top-level pages linked from More menu (Today, Balance, Admin…).

- Pros: Simpler first screen.
- Cons: Too many menu items; harder to discover related flows.

### C — Dashboard-first

Today's poll card on dashboard + deep link to detail.

- Pros: High visibility for voting.
- Cons: Does not cover admin/balance/history well; partial Option A.

**Decision:** Approach **A** — tabbed hub, entry from **More → Lunch** (RBAC `lunch` in `navPageKeys`).

---

## Architecture

```
lib/
├── core/constants/
│   ├── app_constants.dart          # + lunch endpoint constants
│   └── rbac_page_keys.dart         # + lunch = 'lunch'
├── data/
│   ├── models/lunch_model.dart     # settings, poll, vote, balance, history, dashboard
│   └── repositories/lunch_repository.dart
└── presentation/
    ├── providers/
    │   ├── lunch_provider.dart           # user: today polls, vote, balance, history
    │   └── lunch_admin_provider.dart     # admin: polls CRUD, settings, dashboard, balances
    └── pages/lunch/
        ├── lunch_hub_page.dart           # TabController + RBAC admin tabs
        ├── lunch_today_tab.dart          # today's polls + vote UI
        ├── lunch_poll_detail_page.dart   # single poll + summary (admin)
        ├── lunch_poll_form_page.dart     # create/edit poll (admin)
        ├── lunch_balance_tab.dart        # my balance + transactions
        ├── lunch_history_tab.dart        # vote history (user + admin filters)
        ├── lunch_admin_dashboard_tab.dart
        ├── lunch_admin_polls_tab.dart    # list polls by date range
        ├── lunch_admin_balances_tab.dart # employee balances + adjust
        └── lunch_settings_page.dart      # settings (admin)
```

**State:** Manual Riverpod `StateNotifierProvider` (same as Leave/Attendance).  
**Navigation:** Imperative `Navigator.push` (existing app pattern).  
**Currency:** Use `AppConstants.currencySymbol` (৳) for amounts.

---

## RBAC Rules

| Role | Detection | Capabilities |
|------|-----------|--------------|
| No access | `lunch` not in `navPageKeys` / `effective.none` | Hide Lunch menu item |
| User | `hasNav(lunch)` + `effective.user` | Today polls, vote, my balance, own history |
| Admin | JWT `admin` OR `effective.lunch == admin` | All user features + poll CRUD, settings, dashboard, employee balances, adjust, poll summary |

Provider: `lunchAdminProvider` = `rbacModuleAdminProvider(RbacPageKey.lunch)`.

---

## API Endpoints (17)

### Settings & Dashboard
| Method | Path | Mobile screen |
|--------|------|---------------|
| GET | `/api/lunch/settings` | Settings page (load), Today tab (default cost) |
| PUT | `/api/lunch/settings` | Settings page (admin) |
| GET | `/api/lunch/dashboard` | Admin dashboard tab |

### Polls
| Method | Path | Mobile screen |
|--------|------|---------------|
| GET | `/api/lunch/polls/today` | Today tab |
| GET | `/api/lunch/polls?from=&to=&status=` | Admin polls tab |
| POST | `/api/lunch/polls` | Poll form (create) |
| GET | `/api/lunch/polls/:id` | Poll detail |
| PUT | `/api/lunch/polls/:id` | Poll form (edit) |
| PATCH | `/api/lunch/polls/:id/status` | Poll detail (close/cancel) |
| DELETE | `/api/lunch/polls/:id` | Admin polls tab |
| POST | `/api/lunch/polls/:id/vote` | Today tab / poll detail |
| GET | `/api/lunch/polls/:id/summary` | Poll detail (admin section) |

### Vote history
| Method | Path | Mobile screen |
|--------|------|---------------|
| GET | `/api/lunch/votes/history?from=&to=&optionType=` | History tab |

### Balance
| Method | Path | Mobile screen |
|--------|------|---------------|
| GET | `/api/lunch/balance/me?month=` | Balance tab |
| GET | `/api/lunch/balance/transactions?userId=&from=&to=` | Balance tab (admin: pick user) |
| GET | `/api/lunch/balance/employees?from=&to=` | Admin balances tab |
| POST | `/api/lunch/balance/adjust` | Admin balances tab (dialog) |

---

## Data Models

### LunchSettings
- `defaultCostAmount` (num)
- `allowVoteChange` (bool)

### LunchPoll
- `id`, `date`, `title`, `costAmount`, `allowVoteChange`, `endTime`, `status` (active|closed|cancelled)
- `options[]`: `{ id, label, optionType: yes|no }`
- `myVote` (optional): `{ optionId, ... }`
- `results[]` (optional counts per option)

### LunchTodayResponse
- Handles backward compat: `{ items[], poll, myVote, results }` OR list at root

### LunchVoteHistoryRow
- `pollTitle`, `pollDate`, `optionType`, `userId`, `userName`, `votedAt`

### LunchBalanceMe
- `balance`, `monthNetChange`, optional `month`

### LunchBalanceTransaction
- `amount`, `reason`, `type`, `createdAt`, `pollId?`

### LunchEmployeeBalance
- `userId`, `userName`, `netChange`, `balance`

### LunchDashboard
- Summary stats (flexible JSON — parse known fields, ignore unknown)

All models: hand-written `fromJson` + `core/json_parse.dart` helpers (existing convention).

---

## Screen Designs

### 1. Lunch Hub (`LunchHubPage`)

**Tabs (user):** Today | Balance | History  
**Extra tabs (admin):** Admin | Polls | Balances | Settings (icon action or tab)

App bar: "Lunch" + refresh + settings gear (admin only).

### 2. Today Tab

- Pull-to-refresh → `GET /polls/today`
- Card per poll: title, date, cost, end time, status badge
- Vote buttons: Yes / No (or dynamic options from API)
- Disable vote if closed/cancelled or past end time
- Show current vote + change vote if `allowVoteChange`
- FAB (admin): Create poll → form page
- Empty state: "No lunch polls today"

### 3. Poll Detail Page

- Full poll info + live results (bar or pill counts)
- Vote section (same as today)
- Admin: Summary button → expandable admin summary from `/summary`
- Admin actions: Edit, Close, Cancel, Delete

### 4. Poll Form Page (admin)

- Fields: date, title, costAmount, allowVoteChange, endTime (HH:mm)
- Options: default Yes/No with optionType
- Create → POST `/polls`; Edit → PUT `/polls/:id`
- Optional: extendMinutes on edit

### 5. Balance Tab

- Month picker → `GET /balance/me?month=YYYY-MM`
- Show balance + month net change
- Transaction list → `GET /balance/transactions` (self; admin can filter user)

### 6. History Tab

- Date range filter (default: current month)
- Optional optionType filter (yes/no/all)
- Admin: user filter (self vs all vs specific user if API supports)
- List: poll title, date, choice, timestamp

### 7. Admin Dashboard Tab

- KPI cards from `GET /dashboard`
- Link to create poll

### 8. Admin Polls Tab

- Date range + status filter
- List polls → tap detail
- Swipe or menu: edit / close / delete

### 9. Admin Balances Tab

- Date range → employee balances table
- Tap employee → transactions
- FAB/dialog: manual adjust (userId, amount, reason)

### 10. Settings Page (admin)

- defaultCostAmount, allowVoteChange toggles
- Save → PUT `/settings`

---

## Integration Points

| File | Change |
|------|--------|
| `rbac_page_keys.dart` | Add `lunch` |
| `app_constants.dart` | Add all lunch endpoint constants |
| `more_page.dart` | Lunch menu item when `hasNav(lunch)` |
| `dashboard_page.dart` | Optional quick action "Lunch vote" if active poll today |
| `rbac_provider.dart` | Optional `dashboardLunchModuleProvider` |

---

## Error Handling

- 401/403: show snackbar; rely on global session handler
- 422: show server message (e.g. vote closed, no option)
- Network: `ListPageState` / `ErrorDisplayWidget` + retry
- Optimistic vote update with rollback on failure

---

## Testing

- Unit: `LunchPoll.fromJson` with today response shapes (items + legacy top-level)
- Widget: Today tab renders poll cards from mock provider
- Manual: login as lunch user + lunch admin; vote, change vote, create poll, adjust balance

---

## Out of Scope

- Push notification deep link to lunch (FCM already notifies; no new handler in v1)
- Offline vote queue
- Web/desktop layout

---

## Implementation Phases

1. **Foundation** — constants, models, repository (all 17 endpoints)
2. **User flows** — provider, hub, today/balance/history tabs, voting
3. **Admin flows** — admin provider, poll CRUD, settings, dashboard, balances
4. **Integration** — More menu, optional dashboard card
5. **Polish** — loading/empty/error states, pull-to-refresh, manual QA
