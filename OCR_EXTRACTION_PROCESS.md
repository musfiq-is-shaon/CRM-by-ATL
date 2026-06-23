# SLI App — OCR Extraction Process (Agent Implementation Guide)

This document describes the **complete OCR extraction pipeline** used in the SLI Flutter app (`sli-app/SLI_APP`). It is written so an AI agent (or developer) can **reimplement the same flow in another project** without reading the entire codebase.

**Source project:** `/home/atl-musfiq/Projects/sli-app-01/sli-app/SLI_APP`

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Prerequisites & Configuration](#3-prerequisites--configuration)
4. [Phase 1 — Document Capture (Native Scanner)](#4-phase-1--document-capture-native-scanner)
5. [Phase 2 — Preview & OCR Trigger](#5-phase-2--preview--ocr-trigger)
6. [Phase 3 — Nanonets DocStrange Extraction](#6-phase-3--nanonets-docstrange-extraction)
7. [Phase 4 — Local Persistence (Sidecars)](#7-phase-4--local-persistence-sidecars)
8. [Phase 5 — Canonicalization](#8-phase-5--canonicalization)
9. [Phase 6 — Unified Submit Payload](#9-phase-6--unified-submit-payload)
10. [Phase 7 — Backend Upload](#10-phase-7--backend-upload)
11. [RFD (Request For Documents) Variant](#11-rfd-request-for-documents-variant)
12. [Module Reference Map](#12-module-reference-map)
13. [JSON Shapes & Field Contracts](#13-json-shapes--field-contracts)
14. [Business Rules & Edge Cases](#14-business-rules--edge-cases)
15. [Porting Checklist for Another Project](#15-porting-checklist-for-another-project)
16. [Test Fixtures & Verification](#16-test-fixtures--verification)
17. [Known Pitfalls](#17-known-pitfalls)

---

## 1. Executive Summary

The SLI OCR pipeline has **three layers**:

| Layer | Technology | Output |
|-------|------------|--------|
| **Capture** | Google ML Kit (Android) / VisionKit (iOS) via Flutter platform channel | Ordered JPEG file paths |
| **Extraction** | Nanonets DocStrange API (`output_format=json`) | Raw JSON per page |
| **Transformation** | Dart canonicalization + merge | Single `ocr_extracted_data` JSON for backend |

**Documents that get OCR:**

| Document type | Pages OCR'd | Mode |
|---------------|-------------|------|
| `application_form` | Pages 0 and 1 (first two pages) | Structured form fields |
| `nid` | All pages (typically front + back) | Identity canonical |
| `birth_certificate` | Page 0 only | Identity canonical |
| All others (photo, signature, etc.) | None | Images only |

**Critical design choice:** Raw Nanonets JSON is stored on disk first. Canonicalization and unified merge happen at **save/submit time**, not immediately after OCR.

---

## 2. Architecture Overview

### End-to-end flow (checklist capture → proposal submit)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ USER: taps checklist document slot                                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ DocumentCaptureFlowScreen                                                   │
│   NativeDocumentScannerService.scan()                                       │
│   → ML Kit / VisionKit UI → JPEG paths in app cache                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ DocumentPreviewScreen                                                       │
│   User reviews pages; on Confirm:                                           │
│     • Auto-extract OCR for pages per slot policy (if not already extracted) │
│     • DocumentExtractionService.extractJsonPerPageBatch()                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ ProposalRepository.saveSlotDocuments()                                      │
│   Images  → proposal_drafts/<id>/slot_<n>/page_XXX.jpg                      │
│   OCR     → proposal_drafts/<id>/slot_<n>/page_XXX.jpg.ocr.json (raw JSON)  │
│   If no OCR yet → scheduleBackgroundSlotJsonExtraction() (async fallback)   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ On proposal submit (TrackProposalScreen)                                    │
│   ProposalRepository.buildOcrExtractedData(proposalId)                      │
│     For each OCR slot/page:                                                 │
│       prepareChecklistOcrForSubmit() → buildOcrPageWireData()               │
│     buildUnifiedOcrExtractedDataRoot() → single Postman-shaped object         │
│   jsonEncode → AgentProposalApiService.createProposalWithSectionedUploads     │
│     multipart field: ocr_extracted_data = JSON string                         │
│     files in sectioned fields (application_documents[], etc.)               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Transformation pipeline (per page)

```
Raw Nanonets JSON (.ocr.json sidecar)
        │
        ▼
prepareChecklistOcrForSubmit()          ← checklist_ocr_prepare.dart
   ├─ application_form → age injection → canonicalizeProposalFormOcrJson()
   ├─ nid              → prepareNidOcrForSubmit() → canonicalizeNidOcrJson()
   └─ birth_certificate → prepareBirthCertificateOcrForSubmit()
        │
        ▼
buildOcrPageWireData()                  ← ocr_wire_payload.dart (strips meta keys)
        │
        ▼
buildUnifiedOcrExtractedDataRoot()      ← unified_ocr_extracted_data.dart
   • Form sections → bare top-level keys (insured, personal_information, …)
   • Other docs    → namespaced keys (applicant_nid_front_personal_information, …)
        │
        ▼
jsonEncode → POST ocr_extracted_data
```

---

## 3. Prerequisites & Configuration

### Environment variables

File: `sli-app/SLI_APP/.env.example`

| Variable | Required | Purpose |
|----------|----------|---------|
| `NANONETS_API_KEY` | **Yes** (for OCR) | DocStrange Bearer token |
| `NANONETS_OCR_KEY` | Fallback alias | Same as above if primary empty |
| `NANONETS_JSON_OPTIONS` | No | Optional JSON schema passed to DocStrange |
| `NANONETS_CUSTOM_INSTRUCTIONS` | No | **Markdown OCR only** — do NOT use with JSON mode |
| `SLI_API_BASE_URL` | Yes (for submit) | Backend base URL |

Load order (highest priority first):
1. `--dart-define=KEY=value`
2. `--dart-define-from-file=.env`
3. Bundled `.env` asset via `flutter_dotenv`

Config reader: `lib/config/sli_env_config.dart`

```bash
# Run with OCR enabled
flutter run --dart-define-from-file=.env
```

### Dart dependencies (OCR-related)

From `pubspec.yaml`:

| Package | Role |
|---------|------|
| `http` | Nanonets + backend multipart |
| `http_parser` | MIME types for multipart |
| `image_picker` | `XFile` type for scanned pages |
| `path` / `path_provider` | Draft storage paths |
| `flutter_dotenv` | `.env` secrets |

**Not used in live pipeline:** Scanbot SDK, on-device Tesseract. Scanning is native OS UI only.

### Android native dependency

`android/app/build.gradle.kts`:

```kotlin
implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0")
implementation("androidx.activity:activity-ktx:1.9.3")
```

---

## 4. Phase 1 — Document Capture (Native Scanner)

### Flutter service

**File:** `lib/services/native_document_scanner_service.dart`

| Item | Value |
|------|-------|
| Platform channel | `app.atl.sli_app/document_scanner` |
| Methods | `isSupported` → bool; `scan` → `List<String>` paths |
| Return type | `NativeDocumentScanSuccess(files)` / `Cancelled` / `Error` |
| Output format | JPEG `XFile` paths in app cache |

### Android implementation

**File:** `android/app/src/main/kotlin/com/example/sli_app/MainActivity.kt`

- Uses `GmsDocumentScanning.getClient()` with:
  - `SCANNER_MODE_FULL`
  - `setGalleryImportAllowed(true)`
  - `RESULT_FORMAT_JPEG`
- Copies scanned URI → cache as `scan_<uuid>.jpg` (quality 92)
- **Does NOT** call `setPageLimit()` — page limits enforced in Dart after scan returns

### iOS implementation

**File:** `ios/Runner/DocumentScannerHandler.swift`

- VisionKit `VNDocumentCameraViewController`
- Same channel name: `app.atl.sli_app/document_scanner`

### Page capacity rules

Enforced in `DocumentCaptureFlowScreen` (not in native scanner):

- Each checklist slot has `maxPages` (from `DocumentChecklistSlot`)
- After scan, `capNewPages(files, remaining)` trims excess pages
- NID slots typically allow 2 pages (front/back via `pageSides`)

### Agent implementation steps

1. Create platform channel with methods `isSupported` and `scan`.
2. On Android: integrate ML Kit Document Scanner; return ordered JPEG paths.
3. On iOS: integrate VisionKit document camera; return ordered JPEG paths.
4. Wrap in Dart sealed class outcome (`Success` / `Cancelled` / `Error`).
5. Enforce max pages in app layer after scan completes.

---

## 5. Phase 2 — Preview & OCR Trigger

### Entry screen

**File:** `lib/screens/document_capture_flow_screen.dart`

State held during capture:

| State variable | Purpose |
|----------------|---------|
| `_previewFiles` | `List<XFile>` scanned pages |
| `_batchOcrJson` | `List<Map<String, dynamic>>` — one raw Nanonets JSON per page |
| `_savedPageCount` | Pages already on disk (for capacity math) |
| `_formInsights` | Parsed proposal form intelligence |

Key methods:

```dart
// Calls Nanonets sequentially — one JSON map per file
Future<List<Map<String, dynamic>>> _runOcrForFiles(List<XFile> files)

// Persists images + optional .ocr.json sidecars
Future<void> _onConfirmProceedAndPop(List<XFile> files)
```

### Preview screen

**File:** `lib/screens/document_preview_screen.dart`

OCR mode per slot (`lib/models/document_checklist_config.dart`):

```dart
enum DocumentPreviewOcrMode {
  none,
  applicationFormFirstTwoPages,  // application_form
  nidExtractAll,                 // nid — all pages
  birthCertificateExtractPage,   // birth_certificate — page 0 only
}
```

**Auto-extract on Confirm:** If mode ≠ `none` and required pages lack OCR, parent callbacks run extraction before proceed:

| Mode | Pages sent to DocStrange |
|------|--------------------------|
| `applicationFormFirstTwoPages` | `[0]` if 1 page; `[0, 1]` if ≥2 pages |
| `nidExtractAll` | All page indices `0..n-1` |
| `birthCertificateExtractPage` | `[0]` only |

Helper functions:

```dart
DocumentPreviewOcrMode previewOcrModeForSlot(DocumentChecklistSlot? slot)
bool checklistSlotSupportsOcr(DocumentChecklistSlot slot)
List<int> checklistSlotOcrPageIndices(DocumentChecklistSlot slot, int totalPages)
```

### Agent implementation steps

1. Show preview UI with per-page OCR status badges.
2. On confirm, determine which page indices need OCR via slot policy.
3. Call extraction service for only those indices (or all pages for NID).
4. Store results in memory aligned 1:1 with preview page list.
5. On final confirm, pass `ocrJsonPerPage` to persistence layer.

---

## 6. Phase 3 — Nanonets DocStrange Extraction

### Service

**File:** `lib/services/document_extraction_service.dart`

### API endpoints

| Endpoint | Method | Use |
|----------|--------|-----|
| `https://extraction-api.nanonets.com/api/v1/extract/sync` | POST | Single image (primary for OCR) |
| `https://extraction-api.nanonets.com/api/v1/extract/async` | POST | PDFs (async + poll) |
| `https://extraction-api.nanonets.com/api/v1/extract/batch` | POST | Markdown batch only (NOT used for JSON OCR) |
| `https://extraction-api.nanonets.com/api/v1/extract/results/{record_id}` | GET | Poll async jobs |

### Authentication

```
Authorization: Bearer {NANONETS_API_KEY}
```

### JSON extraction request

Multipart POST to `/extract/sync` (or `/extract/async` for PDF):

| Field | Value |
|-------|-------|
| `output_format` | `json` |
| `json_options` | Optional — from `NANONETS_JSON_OPTIONS` env |
| `file` | Image bytes |

**Do NOT send `custom_instructions` with JSON mode** — markdown-oriented prompts break checkbox/nominee parsing on the proposal form.

### Response parsing

Extracted JSON lives at **`result.json.content`** (object or JSON string).

Parser: `_jsonPayloadFromCompleted()` drills into:
- `result.json.content`
- Fallback keys: `json`, `data`, `extracted_data`, `output`

### Primary method used by app

```dart
Future<List<Map<String, dynamic>>> extractJsonPerPageBatch(List<XFile> files)
```

**Implementation:** Sequential per-file calls via `extractJsonWithRetry()` (3 retries, 650ms backoff multiplier).

**Why NOT batch endpoint for JSON:** Batch `/extract/batch` record order was unreliable — caused OCR from wrong page assigned to wrong image.

### Retry & rate limiting

- 429 responses: exponential backoff (1s, 2s, 4s, …) up to 5 attempts
- Async poll: every 2s, max 180 rounds (6 minutes)
- Per-file retry: 3 attempts with 650ms × attempt delay

### Agent implementation steps

1. Implement HTTP client with Bearer auth.
2. POST each image individually with `output_format=json`.
3. Parse `result.json.content` into `Map<String, dynamic>`.
4. Return list of maps in **same order as input files**.
5. Add retry logic for transient failures and 429.
6. For PDFs, use async endpoint + poll until `status=completed`.

---

## 7. Phase 4 — Local Persistence (Sidecars)

### Storage layout

**File:** `lib/data/proposal_repository.dart`

```
proposal_drafts/
  <proposalId>/
    meta.json                          ← ProposalFormInsights
    slot_<slotIndex>/
      page_000.jpg
      page_000.jpg.ocr.json            ← raw Nanonets JSON (NOT canonical)
      page_001.jpg
      page_001.jpg.ocr.json
```

### saveSlotDocuments

```dart
Future<void> saveSlotDocuments(
  String proposalId,
  int slotIndex,
  List<XFile> files, {
  List<Map<String, dynamic>>? ocrJsonPerPage,  // must match files.length
})
```

Behavior:
- Replaces entire slot directory on save
- Copies images with zero-padded names `page_XXX.jpg`
- Writes non-empty OCR maps as `<image>.ocr.json`
- If `ocrJsonPerPage` omitted → no sidecars written yet

### Background extraction fallback

```dart
static void scheduleBackgroundSlotJsonExtraction(String proposalId, int slotIndex)
```

Triggered when user confirms without running Extract Text but slot supports OCR:
1. Reads page files for slot
2. Determines OCR page indices via `checklistSlotOcrPageIndices()`
3. Calls `extractJsonPerPageBatch()` in background
4. Writes `.ocr.json` sidecars
5. Refreshes `ProposalFormInsights` in `meta.json`

### ProposalFormInsights (meta.json)

**File:** `lib/models/proposal_form_insights.dart`

Parsed from proposal form OCR pages:

```json
{
  "applicant_dob_iso": "1977-10-16",
  "applicant_age": 48,
  "is_adult": true,
  "nominee_count": 1,
  "nominee_count_detected": true,
  "has_page1_ocr": true,
  "has_page2_ocr": true,
  "applicant_document_types": ["nid"],
  "nominee_document_types": [["nid"], [], []]
}
```

Used for: dynamic checklist requirements, age injection, background re-extraction triggers.

### Agent implementation steps

1. Store raw Nanonets JSON per image as `{imagePath}.ocr.json`.
2. Never overwrite raw JSON with canonical form at storage time.
3. Implement background job for slots saved without OCR.
4. Parse form insights after page 1/2 OCR and persist to draft meta.

---

## 8. Phase 5 — Canonicalization

### Entry point

**File:** `lib/utils/checklist_ocr_prepare.dart`

```dart
Map<String, dynamic> prepareChecklistOcrForSubmit(
  Map<String, dynamic> raw, {
  required DocumentChecklistSlot slot,
  required int pageOrder,
  ProposalFormInsights? insights,
})

Map<String, dynamic> buildOcrWireDataForSubmit(...) 
  // = buildOcrPageWireData(prepareChecklistOcrForSubmit(...))
```

Routing by document type:

| `slot.apiDocumentType` | Handler |
|------------------------|---------|
| `application_form` | Age injection → `canonicalizeProposalFormOcrJson()` |
| `nid` | `prepareNidOcrForSubmit()` → `canonicalizeNidOcrJson()` |
| `birth_certificate` | `prepareBirthCertificateOcrForSubmit()` |
| default | Passthrough raw JSON |

### Shared utilities

**File:** `lib/utils/ocr_canonical_common.dart`

Key functions:

| Function | Purpose |
|----------|---------|
| `ocrSearchRoots(raw)` | Unwrap DocStrange wrappers; collect search roots |
| `unwrapDocstrangeContent` | Drill into `result.json.content` |
| `orderedCheckboxMap` | Scalar "Female" / map → `{male: false, female: true}` |
| `normalizeOcrBoolForPostman` | bool/string → submit types |
| `attachCanonicalMetadata` | Adds `ocrCanonicalVersion`, `lines`, `page_side` |
| `resolveApplicantNameEnFromOcrRoots` | Bengali/English name disambiguation |

### Proposal form canonicalization

**File:** `lib/utils/proposal_form_ocr_canonical.dart`

Only pages 0 and 1 of the filled proposal form slot (`kFilledProposalFormSlotIndex`).

**Page 1 (pageOrder=0) sections:**

```
document_header
personal_information
contact_information
communication_address_present
policy_information
footer
```

**Page 2 (pageOrder=1) sections:**

```
nominee_information
health_information
lifestyle_information
additional_questionnaire_for_female
signature_section
```

Reference fixtures: `scan_1fc24f3f-5b79-4b31-a811-27231a8da28c.json` (page 1), `scan_cb4910ae-40ac-4b5f-9a7a-6d83233a089c.json` (page 2) — expected at repo root alongside `SLI_APP/`.

### Identity document canonicalization

**File:** `lib/utils/identity_document_ocr_canonical.dart`

**NID:**
- Page 0 (front): `personal_information`
- Page 1 (back): `address_information`, `identity_details`

**Birth certificate:**
- Page 0: `registration_information`, `personal_information`, `parent_information`

Strips boilerplate keys: seals, disclaimers, form chrome (`kIdentityDocumentBoilerplateKeys`).

### Age injection

**Files:** `lib/utils/ocr_applicant_age_injection.dart`, `lib/utils/applicant_age_from_dob.dart`

| When | Action |
|------|--------|
| Proposal form page 0 | Inject calculated applicant age from DOB if Age field blank |
| Proposal form page 1 | Inject calculated nominee ages from their DOBs |
| Submit gate | Block if applicant is minor (`isApplicantKnownMinor`) |

DOB parsing supports: ISO, DMY, DDMMYYYY compact (SLI form style e.g. `16101977`).

### Wire payload (meta stripping)

**File:** `lib/utils/ocr_wire_payload.dart`

Stripped before merge/submit:

```
ocrCanonicalVersion, ocrCanonicalPage, ocrCanonicalDocumentType, lines, page_side
```

```dart
Map<String, dynamic> buildOcrPageWireData(Map<String, dynamic> canonical)
```

### Agent implementation steps

1. Implement document-type router (`prepareChecklistOcrForSubmit`).
2. Build canonical mappers with alias tables for Nanonets key variance.
3. Normalize checkboxes to `{male, female, others}` style maps.
4. Inject calculated ages before canonicalization on form pages.
5. Strip internal metadata keys before merge.
6. Keep per-page wire separate until unified merge step.

---

## 9. Phase 6 — Unified Submit Payload

### Builder

**File:** `lib/utils/unified_ocr_extracted_data.dart`

```dart
Map<String, dynamic> buildUnifiedOcrExtractedDataRoot({
  required ProposalFormInsights? insights,
  required List<UnifiedOcrPageInput> pagesInChecklistOrder,
  String? faNumber,
})
```

### Merge rules

| Source | Destination in unified object |
|--------|-------------------------------|
| Application form sections | **Bare top-level keys** (filtered — no headers/footers at submit root) |
| NID, birth cert, other OCR docs | **Namespaced keys** at end of object |

**Namespacing pattern** (`resolveUnifiedOcrSectionKey`):

```
{apiSection}_{documentType}_{side}_{sectionKey}

Examples:
  applicant_nid_front_personal_information
  applicant_nid_back_address_information
  nominee_0_nid_front_personal_information
```

Segments:
1. `nominee_{index}` if nominee slot, else `apiSection` (e.g. `applicant`)
2. `apiDocumentType` (e.g. `nid`)
3. `page_side` if defined (`front` / `back`)
4. Original section key (e.g. `personal_information`)

### Top-level key order (form fields)

```dart
const kPostmanOcrExtractedDataKeyOrder = [
  'insured',
  'fa_number',
  'application_date',
  'fa_id',
  'applicant_id',
  'policy_id',
  'personal_information',
  'contact_information',
  'communication_address_present',
  'policy_information',
  'nominee_information',
  'health_information',
  'lifestyle_information',
  'female_questionnaire',
  'signature',
  // ... then namespaced other-document keys sorted alphabetically
];
```

### Sections filtered OUT at submit root

These exist in per-page wire but are **not** promoted to unified submit root for form docs:

- `document_header`, `footer`, `signature_section` (mapped to `signature` instead)
- Internal metadata keys

### Nominee structure

Submit uses numbered keys, **not** a raw array:

```json
"nominee_information": {
  "1st_nominee": { "name": "...", "relation_with_applicant": "...", ... },
  "2nd_nominee": { ... },
  "3rd_nominee": { ... }
}
```

### Example unified submit object (abbreviated)

```json
{
  "insured": "SHAH MOHAMMAD HABIBUL HASAN",
  "fa_number": "FA-14176791",
  "application_date": "08062026",
  "fa_id": "9852689",
  "applicant_id": "90526809",
  "policy_id": "0000009",
  "personal_information": {
    "document_type": "nid",
    "document_id": "1934656438",
    "date_of_birth": "16101977",
    "age": 48,
    "applicant_name_en": "SHAH MOHAMMAD HABIBUL HASAN",
    "applicant_name_bn": "শাহ মোহাম্মদ হাবিবুল হাসান",
    "gender": { "male": true, "female": false, "others": false },
    "marital_status": { "single": false, "married": true, "spouse_name": null }
  },
  "contact_information": {
    "primary_mobile": "01520959899"
  },
  "nominee_information": {
    "1st_nominee": {
      "name": "MD TAFIUL ALAM",
      "relation_with_applicant": "Brother"
    }
  },
  "lifestyle_information": {
    "weight_kg": "72",
    "have_you_lose_or_gained_weight_in_last_1_year": false,
    "years_of_smoking": "0"
  },
  "signature": { "applicant_signature": "present" },
  "applicant_nid_front_personal_information": {
    "name_en": "...",
    "nid_number": "..."
  }
}
```

### Repository orchestration

**File:** `lib/data/proposal_repository.dart`

```dart
Future<Map<String, dynamic>> buildOcrExtractedData(String proposalId) async {
  // 1. Load insights + faNumber
  // 2. Iterate checklistSlotsInDocumentOrder (OCR slots only)
  // 3. For each page with .ocr.json:
  //      prepareChecklistOcrForSubmit → buildOcrPageWireData
  // 4. buildUnifiedOcrExtractedDataRoot
}
```

### Agent implementation steps

1. Collect all OCR pages in checklist order (slot index, then page order).
2. Canonicalize each page independently.
3. Merge form sections into bare top-level keys with Postman field name mapping.
4. Namespace non-form document sections.
5. Order keys: known form keys first, then sorted namespaced keys.
6. Exclude `extractedText` and header/footer sections from submit root.

---

## 10. Phase 7 — Backend Upload

### API service

**File:** `lib/services/agent_proposal_api_service.dart`

**Critical:** `ocr_extracted_data` is a **text form field** (JSON string), NOT a file part.

```dart
req.fields['ocr_extracted_data'] = jsonEncode(unifiedObject);
```

OCR is **not** attached to individual file upload parts.

### Endpoints

| Method | Path | OCR field |
|--------|------|-----------|
| POST | `/api/agent/proposals` | Top-level `ocr_extracted_data` |
| POST | `/api/agent/proposals/{id}/documents` | Top-level `ocr_extracted_data` |
| POST | `/api/agent/proposals/{id}/submit-rfd-documents` | Top-level + per-item `rfd_documents[i][ocr_extracted_data]` |

### Create proposal multipart (files only — separate from OCR)

```
application_documents[i][document_type]
application_documents[i][file]

applicant_documents[i][document_type]
applicant_documents[i][side]          ← front/back for NID
applicant_documents[i][file]

nominees[n][documents][m][document_type]
nominees[n][documents][m][side]
nominees[n][documents][m][file]

guardian_documents[i][document_type]
guardian_documents[i][file]

fa_number, policy_type, submission_date, note (optional)
ocr_extracted_data                    ← JSON string
```

### Expected response

```json
{
  "success": true,
  "data": {
    "proposal": { ... },
    "documents": [ ... ]
  }
}
```

### Agent implementation steps

1. Build unified OCR object before multipart assembly.
2. `jsonEncode` into `ocr_extracted_data` text field.
3. Upload images in sectioned file fields without per-file OCR.
4. Keep OCR JSON and file ordering consistent with checklist slot order.

---

## 11. RFD (Request For Documents) Variant

When underwriter requests additional documents, a parallel flow applies.

**Files:**
- `lib/screens/rfd_document_capture_flow_screen.dart`
- `lib/utils/rfd_ocr_policy.dart`

### Differences from checklist flow

| Aspect | Checklist | RFD |
|--------|-----------|-----|
| Persistence | Saves to draft slot on disk | Returns `(filePaths, ocrWires)` to caller |
| OCR requirement | Per slot policy | NID and birth certificate labels only |
| Submit | Single unified `ocr_extracted_data` on create | Per-item `rfd_documents[i][ocr_extracted_data]` |

### RFD OCR labels

```dart
bool rfdLabelRequiresOcr(String label)
// true for NID and birth certificate labels (incl. legacy strings)
```

Wire building:

```dart
Map<String, dynamic> buildRfdOcrWireFromRaw(
  Map<String, dynamic> raw, {
  required String requestedLabel,
  int pageOrder = 0,
})
```

Merge into existing unified object:

```dart
Map<String, dynamic> buildRfdMergedOcrExtractedData({
  Map<String, dynamic>? existingUnified,
  required List<({DocumentChecklistSlot slot, int pageOrder, Map wire})> rfdPages,
})
```

---

## 12. Module Reference Map

```
Screens (entry points)
├── document_capture_flow_screen.dart     Scan → preview → save slot
├── rfd_document_capture_flow_screen.dart RFD variant
└── document_preview_screen.dart          Shared preview + OCR UX

Services
├── native_document_scanner_service.dart  Platform channel scanner
├── document_extraction_service.dart      Nanonets DocStrange client
└── agent_proposal_api_service.dart       Backend multipart upload

Data
├── proposal_repository.dart              Draft storage, buildOcrExtractedData
└── proposal_detail_loader.dart         Loads persisted OCR for display

Utils (transformation pipeline)
├── checklist_ocr_prepare.dart            Per-page prepare router
├── proposal_form_ocr_canonical.dart      Form page 1/2 canonical shape
├── identity_document_ocr_canonical.dart  NID + birth cert canonical
├── ocr_canonical_common.dart             Shared normalization
├── ocr_wire_payload.dart                 Meta key stripping
├── unified_ocr_extracted_data.dart       Final merge + Postman mapping
├── ocr_applicant_age_injection.dart      Age injection into raw JSON
├── applicant_age_from_dob.dart           DOB parsing + age calc
├── proposal_form_insights_parser.dart    Parse form OCR → insights
├── rfd_ocr_policy.dart                   RFD label → slot/OCR rules
├── ocr_extracted_text_payload.dart       Legacy markdown sidecar format
└── ocr_submit_payload.dart               Internal slot/page wrappers

Models
├── document_checklist_config.dart        Slots, OCR modes, page indices
└── proposal_form_insights.dart           Parsed form intelligence

Config
└── sli_env_config.dart                   API keys and URLs

Native
├── android/.../MainActivity.kt           ML Kit scanner
└── ios/Runner/DocumentScannerHandler.swift VisionKit scanner
```

---

## 13. JSON Shapes & Field Contracts

### Raw Nanonets sidecar (stored on disk)

Structure varies by document; typically section-keyed maps:

```json
{
  "document_header": { "fa_id": "9852689", "application_date": "08062026" },
  "personal_information": { "dob": "16101977", "age": null },
  "contact_information": { "mobile": "01520959899" }
}
```

May also be wrapped:

```json
{
  "result": {
    "json": {
      "content": { ... actual fields ... }
    }
  }
}
```

Canonicalizers call `ocrSearchRoots()` to handle both.

### Per-page wire (after canonicalization, before unified merge)

Same section keys as canonical output. Meta keys stripped by `buildOcrPageWireData`.

### Legacy markdown sidecar (fallback)

**File:** `lib/utils/ocr_extracted_text_payload.dart`

```json
{
  "formatVersion": 1,
  "source": "docstrange",
  "lines": [{ "line": 0, "text": "...", "sourceKey": "full_document_text" }],
  "payload": { }
}
```

Not included in final Postman submit root.

### DocStrange API response (completed)

```json
{
  "success": true,
  "status": "completed",
  "record_id": "...",
  "result": {
    "json": {
      "content": { ... extracted key-value JSON ... }
    }
  }
}
```

---

## 14. Business Rules & Edge Cases

| Rule | Implementation |
|------|----------------|
| Sequential JSON extraction only | Never use batch endpoint for JSON — page order must match |
| No markdown instructions with JSON | `custom_instructions` breaks checkbox parsing |
| Form pages 0–1 only for OCR | Page 2+ of multi-page form slots not sent to DocStrange |
| Birth cert page 0 only | Only first page OCR'd |
| NID all pages | Front and back both OCR'd and namespaced by side |
| Minor applicant block | `isApplicantKnownMinor` prevents submit |
| Age blank on form | Calculated from DOB and injected before canonicalization |
| Save without extract | Background job fills `.ocr.json` later |
| Retake single page | Clears that page's OCR in `_batchOcrJson` |
| Headers/footers on submit | Kept in per-page wire for debug; filtered from unified submit root |
| Checkbox normalization | Scalars like `"Female"` → `{male: false, female: true}` |
| Lifestyle field aliases | Multiple Nanonets keys map to single submit key |
| Nominee count | Parsed from form page 2; drives dynamic checklist slots |

---

## 15. Porting Checklist for Another Project

Use this ordered checklist when reimplementing in a new codebase:

### Phase A — Infrastructure

- [ ] Environment config for `NANONETS_API_KEY`, optional `NANONETS_JSON_OPTIONS`
- [ ] Draft storage: `{draftId}/slot_{n}/page_XXX.jpg` + `.ocr.json` sidecars
- [ ] Document type enum matching backend: `application_form`, `nid`, `birth_certificate`, etc.

### Phase B — Capture

- [ ] Native document scanner platform channel (Android ML Kit + iOS VisionKit)
- [ ] Return ordered JPEG paths; enforce max pages in app layer
- [ ] Preview screen with retake/add-page support

### Phase C — Extraction

- [ ] Nanonets DocStrange client with `output_format=json`
- [ ] Sequential per-file extraction preserving page order
- [ ] Retry + 429 backoff
- [ ] Parse `result.json.content`

### Phase D — Policy

- [ ] OCR mode per document type (form first 2 pages, NID all, birth cert page 0)
- [ ] Auto-extract on preview confirm for required pages
- [ ] Background extraction fallback when user skips manual extract

### Phase E — Transform

- [ ] `prepareChecklistOcrForSubmit` router by document type
- [ ] Proposal form canonicalizer (page 1 + page 2 sections)
- [ ] NID / birth certificate canonicalizer with boilerplate stripping
- [ ] Age injection from DOB
- [ ] Wire meta stripping
- [ ] Unified merge with form bare keys + namespaced identity keys
- [ ] Postman key ordering

### Phase F — Submit

- [ ] `buildOcrExtractedData(draftId)` as single source of truth
- [ ] Multipart upload with `ocr_extracted_data` JSON string field
- [ ] Sectioned file uploads without per-file OCR

### Phase G — Quality

- [ ] Golden JSON fixtures for form pages 1 and 2
- [ ] Tests asserting submit root excludes headers/footers
- [ ] Tests asserting nominee structure uses `1st_nominee` keys
- [ ] Tests asserting namespaced NID keys

---

## 16. Test Fixtures & Verification

### Key test files

| Test file | Validates |
|-----------|-----------|
| `test/checklist_ocr_policy_test.dart` | OCR modes, page index rules |
| `test/ocr_submit_structure_test.dart` | Full pipeline → Postman shape |
| `test/unified_ocr_extracted_data_test.dart` | Field mapping, namespacing |
| `test/proposal_form_ocr_canonical_test.dart` | Page 1/2 section ordering |
| `test/identity_document_ocr_canonical_test.dart` | NID front/back, birth cert |
| `test/nanonets_ocr_filter_test.dart` | Headers kept in wire, stripped on submit |
| `test/ocr_applicant_age_injection_test.dart` | Age injection |
| `test/applicant_age_from_dob_test.dart` | DOB format parsing |
| `test/proposal_form_insights_parser_test.dart` | Nominee count, doc type ticks |
| `test/rfd_ocr_policy_test.dart` | RFD label → slot/OCR requirements |

### Golden fixtures (repo root, sibling to `SLI_APP/`)

```
scan_1fc24f3f-5b79-4b31-a811-27231a8da28c.json   ← proposal form page 1
scan_cb4910ae-40ac-4b5f-9a7a-6d83233a089c.json   ← proposal form page 2
```

### Verification command

```bash
cd sli-app/SLI_APP
flutter test test/ocr_submit_structure_test.dart
flutter test test/unified_ocr_extracted_data_test.dart
```

### Expected assertions from integration test

After saving form sidecars and calling `buildOcrExtractedData`:

- `ocr.keys.first == 'insured'`
- `ocr.containsKey('document_header') == false`
- `ocr.containsKey('footer') == false`
- `ocr.containsKey('extractedText') == false`
- `ocr['nominee_information']['1st_nominee']` exists (not `nominees` array)
- `ocr['personal_information']['age']` is computed integer

---

## 17. Known Pitfalls

1. **Batch JSON extraction misaligns pages** — Always extract JSON one file at a time sequentially.

2. **Markdown custom instructions break JSON mode** — Never send `NANONETS_CUSTOM_INSTRUCTIONS` with `output_format=json`.

3. **Canonicalizing at OCR time** — Store raw Nanonets JSON; canonicalize at submit so insights/age injection can use latest meta.

4. **ML Kit page limits in native code** — Enforcing limits in scanner breaks "add page" UX; cap in Dart instead.

5. **OCR on file parts** — Backend expects one JSON blob in `ocr_extracted_data`, not per-upload OCR.

6. **Proposal form page 3+** — Only pages 0–1 are OCR'd even if form has more pages.

7. **Missing API key silent failure** — Background extraction skips quietly; preview extract throws user-visible error.

8. **camScan module** — Standalone Android demo in `camScan/`; NOT integrated into Flutter app build.

9. **DocumentScanEnhancer** — Exists in codebase but unused in live capture flow.

---

## Quick Reference: Function Call Chain at Submit

```
TrackProposalScreen._submit()
  └─ ProposalRepository.buildOcrExtractedData(proposalId)
       └─ for each OCR slot/page:
            prepareChecklistOcrForSubmit(raw, slot, pageOrder, insights)
              └─ [form] injectCalculatedApplicantAgeIntoDocstrangeJson
              └─ canonicalizeProposalFormOcrJson / canonicalizeNidOcrJson / ...
            buildOcrPageWireData(prepared)
       └─ buildUnifiedOcrExtractedDataRoot(insights, pagesInOrder, faNumber)
  └─ jsonEncode(ocrMap)
  └─ AgentProposalApiService.createProposalWithSectionedUploads(
       ocrExtractedData: jsonString,
       uploads: [...images...],
     )
```

---

*Generated from SLI App codebase analysis. Primary source: `sli-app/SLI_APP`.*
