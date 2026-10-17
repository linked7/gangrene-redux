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

| Feature | Status | Notes |
|---|---|---|
_(none)_

## Accepted

| Feature | Plan location | Date |
|---|---|---|
| Slave fate: new players are slaves until they survive a round or are commended | Step 11 item 5, Step 13 (Rounds) | 2026-10-17 |
| Round-based play: 60-min rounds, only stem cells/rank/playtime persist | `accepted → Step 13` (also Scope, Step 1, Step 2) | 2026-10-17 |
| Darker, slower feel; scarce food and water | `accepted → Step 5` (pace/atmosphere), `Step 6` (needs rates, Pox core), `Step 8` (pump, dirty water) | 2026-10-17 |
| Fixed bone supply; the Kaiser's three prices can wreck the economy | `accepted → Step 9` (also Step 11.4, Step 13) | 2026-10-17 |
| Made goods (ration crates) appear in the world and are hauled to the stockpile | `accepted → Step 11.1` (also Step 9) | 2026-10-17 |
| Theft: stamps, caught-in-the-act, stockpile pry, sanitar Inspect | `accepted → Step 10` (`Crime.Report`), `Step 11.3` | 2026-10-17 |
| No war; several simple pressures drive player action | `accepted → Dropped` (War removed from Deferred item 9) | 2026-10-17 |

## Decisions log

| Date | Question | Decision | Why |
|---|---|---|---|
| 2026-10-17 | Persistence backend | SQLite (GMod `sql.*`), write-behind flush | User's choice |
| 2026-10-17 | Nations and races naming | Gangrene/Gangral, Rottingham/Rottish, Prohlada Union/Prohladian, plus Outsider (stateless kin of the Gangral, for migrants and cultists) and the skinless. `unimportant` becomes `race = nil`. Use lore names in code, not the old organ names. Core is Gangral-only. | User's lore |
| 2026-10-17 | Round length and persistence | 60-min rounds. Bones, treasury, stockpile and inventory reset each round; only stem cells, rank and playtime persist. `bones` removed from the schema. | Round-based and simple. A fixed supply only works if it resets. |
| 2026-10-17 | Economy model | Closed supply: the treasury is seeded with `bones_supply` (3000) at round start, and `Econ.Transfer` is the only primitive. Taxes, the 20% Kaiser payout, the 25-bones-per-stem-cell mint, bonds and inflation are dropped. | The Kaiser's mistakes have to be able to hurt. Simpler than taxes, and removes B11. |
| 2026-10-17 | Kaiser levers | Crate price (20), ration price (15), sanitar wage (40), plus taking bones from the PUBLIC treasury. Prices reset when the Kaiser dies. | Three numbers that are easy to get wrong. Greed is visible. |
| 2026-10-17 | Food source | No free food spawns. Proles and slaves make ration and clean-water crates at a `ration_press`. One free pump gives dirty water (25% Pox chance). Pox becomes core. | Scarcity drives stories; food only exists through labor. |
| 2026-10-17 | Needs pace | Dryness full in about 25 min, Emptiness in about 40 min. Either one at 100 drains HP. | Survival should be hard in a 60-min round. |
| 2026-10-17 | Pace and atmosphere | Slower walk/run (130/200) from one config table, fates may use `SpeedMulti`. `cl_atmosphere.lua` adds a desaturated colour grade and fog. | Darker, slower feel without new systems. |
| 2026-10-17 | Crates and stockpile | Physical crates with a SERVER `MadeBy` stamp, at most 3 waiting per station, slow to carry. Whoever delivers is paid. The stockpile is a counter; Kaiser and Sanitar have `StockpileAccess`. | Trust and theft come from goods sitting in the world. |
| 2026-10-17 | Theft rules | `Crime.Report` rules table. Unseen theft gives evidence. Theft seen by police gives torment-wanted for 180 s. A stockpile pry (60 s, alarms state radio) gives judgment-wanted. Sanitar Inspect turns theft evidence into wanted, and punishing a thief earns +1 Teeth. Slaves can't steal. Forgiving a theft costs the thief 300 bones, paid to the treasury. | Prevention (guarding, alarm) and punishment (inspect, wanted) both belong to sanitars. Slaves can't be punished, so they can't steal. |
| 2026-10-17 | War | Dropped. The nations stay as lore and possible races. Rot/Doom stay deferred. | The user wants several simple pressures instead of a war. |
| 2026-10-17 | Fates kept | Kaiser, Sanitar, Prole, Korpsman, plus Slave; Ghost as the dead/lobby state | User's choice |
