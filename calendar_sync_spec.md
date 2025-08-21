# Calendar Sync Onboarding & Safe Sync --- Technical Spec (Kuna iOS)

## 1) Scope & Goals

-   Add an **onboarding flow** when enabling Calendar Sync.
-   Create and use **Kuna‑owned calendars only** (never write to
    existing user calendars).
-   Support two modes:
    -   **Single Calendar** ("Kuna")
    -   **Per Project** ("Kuna -- `<ProjectName>`{=html}")
-   Allow **project selection** (filter) in either mode.
-   Sync only **Kuna‑tagged events** and **delete only Kuna‑tagged
    events**.
-   Be resilient to missing/changed calendar sources, identifiers, and
    EventKit changes.

Non‑goals (v1): - Recurring tasks → recurring events mapping (optional
future). - Editing non‑Kuna events. - Cross‑device calendar ID sync (IDs
are per‑device; we handle with fallbacks).

------------------------------------------------------------------------

## 2) User Flow

### Entry points

-   Settings → "Calendar Sync" toggle.
-   If first enable: show **onboarding**.
-   If re‑enable: skip to **Confirmation** with previous choices
    pre‑filled (editable).

### Onboarding screens

1.  **Intro**
    -   Copy: "Kuna creates its own calendars and never edits your
        existing ones."
    -   CTA: "Set up Calendar Sync"
2.  **Sync Mode Choice**
    -   Radio: "Single calendar (Kuna)" vs "Calendar per project"
3.  **Project Selection**
    -   Multi‑select of projects (Search + Select All)
    -   Visible even in "Single calendar" mode (acts as a filter)
4.  **Confirmation**
    -   Summary of mode + selected projects
    -   CTA: "Enable Sync"

### Disable flow

-   Options:
    -   Keep calendars & events (default)
    -   Remove **Kuna events** only
    -   Archive (rename calendars to "Kuna (Archive)") and stop syncing
-   Never delete non‑Kuna events.

------------------------------------------------------------------------

## 3) Data Model & Persistence

``` swift
enum CalendarSyncMode: String, Codable { case single, perProject }

struct KunaCalendarRef: Codable, Hashable {
    var name: String
    var identifier: String
}

struct CalendarSyncPrefs: Codable, Equatable {
    var isEnabled: Bool
    var mode: CalendarSyncMode
    var selectedProjectIDs: Set<String>        // Vikunja project IDs
    var singleCalendar: KunaCalendarRef?       // present in .single
    var projectCalendars: [String: KunaCalendarRef] // projectID -> ref (in .perProject)
    var version: Int                           // schema version (start at 1)
}

// Persist in AppSettings / UserDefaults as JSON blob
// Key suggestion: "calendarSync.prefs"
```

**Invariants** - When `mode == .single`, `singleCalendar != nil` and
`projectCalendars.isEmpty == false` is allowed (kept as historical map)
but not used. - When `mode == .perProject`, `projectCalendars` entries
exist for selected projects; `singleCalendar == nil`. -
`selectedProjectIDs` always reflects the filter (used in both modes).

------------------------------------------------------------------------

## 4) Event Provenance (Tagging)

-   `EKEvent.url` → `kuna://task/<taskID>?project=<projectID>`
-   `EKEvent.notes` includes a line starting with:\
    `KUNA_EVENT: task=<taskID> project=<projectID>`

**Deletion rule:** only delete events where
`event.url?.scheme == "kuna"` **or** notes contain `KUNA_EVENT:`.

------------------------------------------------------------------------

## 5) EventKit Source & Calendars

### Writable source selection

Preferred order: 1. iCloud CalDAV 2. Local 3.
`defaultCalendarForNewEvents?.source` (fallback)

### Calendar naming

-   Single: `Kuna`
-   Per project: `Kuna – <ProjectName>`

### Color

-   Optional: set a system color; not critical to function.

------------------------------------------------------------------------

## 6) Sync Algorithm

**Inputs:** - Current `CalendarSyncPrefs` - Tasks fetched from API
(filtered to `selectedProjectIDs`) - EventKit access + calendars
resolved from prefs

**Process (idempotent):** 1. **Resolve calendars** for current mode: -
If single: ensure/create "Kuna". - If per‑project: ensure/create each
`Kuna – <ProjectName>` for selected projects. - Store/update identifiers
in prefs as needed. 2. **Build desired set**: - For each task →
`(calendarRef, taskID, eventFields)` 3. **Fetch existing Kuna events**
only from the resolved calendars within a wide time window (e.g. −1y to
+2y). 4. **Diff**: - **Upsert** events for tasks that are new/changed
(match by exact `kuna://task/<id>` URL). - **Delete** stale Kuna events
where their task no longer exists or is out of filter. 5. **Commit**
batched changes.

**Mapping rules (task → event):** - `title` ← task.title - `isAllDay` ←
task.isAllDay (else false) - Dates: - If task has both `startDate` and
`dueDate`: use those. - If only `dueDate` and `isAllDay`: make all‑day
on `dueDate`. - If only `dueDate`: event `[dueDate - 1h, dueDate]`
(default 1h) - If only `startDate`: `[startDate, startDate + 1h]` -
`location` ← none (or from task metadata if present later) - `notes` ←
`KUNA_EVENT…` + optional task url + description - `url` ←
`kuna://task/<id>?project=<pid>`

**Done tasks:** - Option A (recommended v1): still show if within the
past N days; otherwise allow cleanup of done events beyond a horizon
(configurable). - Option B: don't create events for tasks with
`done == true`.

------------------------------------------------------------------------

## 7) Mode Switches

**Per‑project → Single** - Ensure single calendar. - For each existing
Kuna event in any per‑project calendar, **move** to single calendar
(copy‑then‑remove).

**Single → Per‑project** - Ensure per‑project calendars for current
selection. - For each Kuna event in single calendar, **move** into its
project calendar (derive projectID from `event.url` or notes).

> Note: EventKit doesn't truly "move" cross‑calendar; do: save copy in
> target, then remove original, within a single commit.

------------------------------------------------------------------------

## 8) Public API (for the rest of the app)

``` swift
// MARK: - Protocols to enable DI & testing
protocol EventKitClient {
    func requestAccess() async throws
    func writableSource() -> EKSource?
    func ensureCalendar(named: String, in source: EKSource) throws -> EKCalendar
    func calendars(for identifiers: [String]) -> [EKCalendar]
    func events(in calendars: [EKCalendar], start: Date, end: Date) -> [EKEvent]
    func save(event: EKEvent) throws
    func remove(event: EKEvent) throws
    func commit() throws
    var store: EKEventStore { get } // exposed if needed for advanced ops
}

protocol CalendarSyncEngineType: AnyObject {
    func onboardingBegin() async
    func onboardingComplete(mode: CalendarSyncMode, selectedProjectIDs: Set<String>) async throws
    func enableSync() async throws
    func disableSync(disposition: DisableDisposition) async throws
    func resyncNow() async
    func handleEventStoreChanged() async
}

enum DisableDisposition {
    case keepEverything
    case removeKunaEvents
    case archiveCalendars // rename and stop using
}
```

**Concrete types** - `EventKitClientLive`: real EKEventStore
implementation. - `CalendarSyncEngine`: actor or @MainActor class
implementing `CalendarSyncEngineType`. - `CalendarRegistry`: helpers to
resolve/create calendars + store refs. - `CalendarDiffer`: pure
functions to diff tasks vs events.

------------------------------------------------------------------------

## 9) Swift Implementation Skeleton (key parts)

... (rest of spec remains same as above)
