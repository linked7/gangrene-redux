# Liver Failure remake: feature backlog

New ideas come here first, before anything changes `03-recreation-plan.md`. The Feature Creep chat looks after this file.

**Statuses:**

| Status | Meaning |
|---|---|
| `idea` | Raised but not yet discussed. |
| `shaping` | Being discussed. |
| `accepted → Step N` | Written into the plan at Step N. |
| `deferred` | Moved to the plan's Deferred list. |
| `rejected` | Not doing it; the reason is recorded. |

## Open

_(none yet)_

## Accepted

| Feature | Plan location | Date |
|---|---|---|
| Slave fate: new players are slaves until they survive a round or are commended | Step 11 item 5, Step 13 (Rounds) | 2026-10-17 |

## Decisions log

| Date | Question | Decision | Why |
|---|---|---|---|
| 2026-10-17 | Persistence backend | SQLite (GMod `sql.*`), write-behind flush | User's choice |
| 2026-10-17 | Nations and races naming | Gangrene/Gangral, Rottingham/Rottish, Prohlada Union/Prohladian, plus Outsider (stateless kin of the Gangral, for migrants and cultists) and the skinless. `unimportant` becomes `race = nil`. Use lore names in code, not the old organ names. Core is Gangral-only. | User's lore |
| 2026-10-17 | Fates kept | Kaiser, Sanitar, Prole, Korpsman, plus Slave; Ghost as the dead/lobby state | User's choice |
