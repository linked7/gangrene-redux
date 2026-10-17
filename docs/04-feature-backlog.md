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
| Workplace accidents (from the original's machines: operator error, misuse, rust, haunting, waste spills) | `idea` | Raised 2026-10-17 by the analysis session. Proposed slice: rust plus accidents on the ration press, sanitar upkeep that pays bones. Haunting waits for ghost Suffering (Deferred 4), and the factory cards wait for the foreman (Deferred 7). Their suggestion that slaves be immune conflicts with Slave parity. Original refs: entities/entities/machine_*.lua, machine_gears.lua:681. |
| Rank gates on fates (who may take Kaiser etc.) | `idea` | Raised 2026-10-17. User will choose later; for now no gate above Friend. |

## Accepted

| Feature | Plan location | Date |
|---|---|---|
| Korpsman loop remake | `accepted` | Step 7 revive + Step 11.2: 3-press revive, drag, no cot, tool picks treatment. |
| Shop goods from the stockpile | `accepted` | Step 9: loaf = ration at sell.ration; beer/spirits/knife seeded stock (shop_stock 10), sold out until next round. |
| Slave fate: new players are slaves until they survive a round or are commended | Step 11 item 5, Step 13 (Rounds) | 2026-10-17 |
| Round-based play: 60-min rounds, only stem cells/rank/playtime persist | `accepted → Step 13` (also Scope, Step 1, Step 2) | 2026-10-17 |
| Darker, slower feel; scarce food and water | `accepted → Step 5` (pace/atmosphere), `Step 6` (needs rates, Pox core), `Step 8` (pump, dirty water) | 2026-10-17 |
| Fixed bone supply; the Kaiser's three prices can wreck the economy | `accepted → Step 9` (also Step 11.4, Step 13) | 2026-10-17 |
| Made goods (ration crates) appear in the world and are hauled to the stockpile | `accepted → Step 11.1` (also Step 9) | 2026-10-17 |
| Theft: stamps, caught-in-the-act, stockpile pry, sanitar Inspect | `accepted → Step 10` (`Crime.Report`), `Step 11.3` | 2026-10-17 |
| No war; several simple pressures drive player action | `accepted → Dropped` (War removed from Deferred item 9) | 2026-10-17 |
| Slaves lose their protection: full parity with Prole, only the mark differs | `accepted → Step 11.5` (also Scope, 00-vibe Slave paragraph) | 2026-10-17 |
| Kaiser runs the economy with a full toolkit; no clamps, no self-enrichment | `accepted → Step 9` (`Economy` table, Set/Grant/Fine/Ledger), `Step 11.2`, `11.3`, `11.4` | 2026-10-17 |
| Knocked out isn't death: wounded get back up `Injured`; only dying (severe) bleed out to ghost | `accepted → Step 7`, `Step 11.2` | 2026-10-17 |
| Kaiser has no rank gate for now | `accepted → Step 11.4`, `Step 13` | 2026-10-17 |
| Hunger/thirst never damage: progressive weakness, full thirst raises Pox, no revive at full hunger | `accepted → Step 6`, `Step 7`, `Step 5` (speed) | 2026-10-17 |
| Crates as a real physical thing | `accepted → Step 11.1`, `Step 5` (speed) | 2026-10-17 |
| Construction: storage crates only; no player-built production | `accepted → Step 11.1`, Dropped | 2026-10-17 |
| Map layouts, with `rp_slumtown` as the core map from the original's positions | `accepted → Step 4` | 2026-10-17 |
| Client UI (HUD, F2, TAB, F1, economy panel) recorded as built | `accepted → Step 15` | 2026-10-17 |
| UI and effect parity with the original, with optimisation exceptions | `accepted → ground rule 8`, `Step 15`, `05-ui-effects-parity.md` | 2026-10-17 |
| Rendering line: fleshgrowths, water barrels, hopper/valve-boiler/press, crew stamps and split pay; replaces the ration press | `accepted → Step 11.1` (also Steps 4, 6, 8, 9, 10, Dropped) | 2026-10-17 (superseded by the lunch machine) |
| Physical work: hit, shoot, toss, press, turn; no timed work actions; cut steps that aren't interesting | `accepted → Step 11.1` (lunch machine, lock-breaking) | 2026-10-17 |
| Lunch machine: bone capsules, water barrels, valve boiler, the original's button panel, empty-gauge explosion; replaces the rendering line | `accepted → Step 11.1` (also Steps 4, 8) | 2026-10-17 |
| Sanitar and Kaiser guns ported 1:1 from the original | `accepted → Step 11` (Sanitar Weapons; Kaiser novoluger) | 2026-10-17 |
| Corpse rot stages and corpse recycling as in the original | `accepted → Step 7` (Deferred 2 and part of 9, Dropped) | 2026-10-17 |
| Shop open to everyone: the dealer's buy menu (Soylent Loaf, Fear Beer, Spirits, Knife) for the time being | `accepted → Step 9` (shop) | 2026-10-17 |
| Ported entities keep the original's model and material; `fate_station` is the sawblade, no hologram | `accepted → ground rule 9`, `Step 4` | 2026-10-17 |

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
| 2026-10-17 | Slave rules | Slave has full parity with Prole: they can fight, steal, build and be made wanted, and killing one is murder. Only the barcode name, model and PUBLIC marker differ, plus Foolish-only access and the two ways out. The zero-damage hook, `weapon_cc_slave`, wanted immunity, the building ban, 30 s corpse decay and the earlier "slaves can't steal" rule are all dropped. Survive-the-round time adds up across deaths, but the slave must be alive at the end. | User's choice: slaves lose their protection. The visible mark replaces the rule as the guard against new players killing at random. |
| 2026-10-17 | Kaiser economic control (replaces the "Kaiser levers" row) | One PUBLIC `Economy` table with a schema: buy and sell price per good, a wage per fate, a ration limit, a reserve per good, a bread line and the revive fee. One `nKaiserEcon(key, value)` receiver, plus Grant and Fine. A ledger built from `Econ.Transfer`. Only sanity checks (never negative, never above supply). No Kaiser wage and no pocket withdrawal. The table resets each round and when the Kaiser dies. | User's choice: the Kaiser's challenge is running a working economy, so they get many tools and no checks that restrict control or invite getting rich. |
| 2026-10-17 | Kaiser rank gate | Removed for now. Kaiser needs no rank, only stem cells and the free slot. Rank gates on fates are an open decision. | User: "don't limit access just yet"; will choose gates later. |
| 2026-10-17 | Downed states | HP 0 downs the player. `wounded` (hit less than 30 past 0 HP): gets up after 45 s at 25 HP with `Injured` (max HP 50) until a korpsman treats it. `dying` (30 or more past 0 HP, or hit again while down): bleeds out over 120 s to a ghost unless revived, and the downer is judged then. Finish off is an explicit ~3 s action. Revive clears `Injured`. | User: being knocked out shouldn't kill you; only severe wounds without treatment do. Keeps korpsmen essential without making every fall a death. |
| 2026-10-17 | Hunger and thirst effects (replaces "at 100 drains HP") | No direct damage. Weakness from 50 to 100 (higher of the two): speed ×0.7, damage dealt ×0.6, consciousness regen ×0.25 at worst. Dryness 100: Pox slowly rises (+1 per 10 s). Downed at Emptiness 100: no revive. Despair at 100 is the only need that kills outright. Pox can lower max HP to a floor of 5, never below. | User's choice. Also ends the wounded/starving loop Rewrite found. |
| 2026-10-17 | Rewrite's implementation choices | One speed function: config × `SpeedMulti` × registered modifiers. Suicide is disabled, and the despair heart attack stays an outright death. A second attacker who makes a wounded body dying is the one judged. Crate carrying is being reshaped (see Open). | User's choices. |
| 2026-10-17 | Crate carrying (replaces the ×0.6 carry slowdown) | A ~30 kg physics prop carried with GMod +use pickup. Hands full (weapon holstered), walk only (one speed modifier), drops when the carrier is hit, downed or jumps, and can be pushed along the ground. | User: crates should be a real physical thing. Physics does the work and it creates moments for theft. |
| 2026-10-17 | Construction | Only the storage crate: 35 bones, 8 items, lockable, a 30 s pry reported as theft, cleared at round reset. Factory sites and any player-built presses are dropped. | User: building more production that easily is a no-go. Food scarcity depends on fixed presses. |
| 2026-10-17 | Core map | `rp_slumtown`. Its layout is converted from the original's map file: fate stations, `machine_lunch` → ration press, `faucet` → pump candidates. Staff place the stockpile, the slave station and the sanitation station. | User's choice. The old file already holds the positions. |
| 2026-10-17 | Plan matches code | Map layouts go in Step 4, and the client UI becomes Step 15 (done before Step 14's playtest with people). | Rewrite built both, so the plan should record them. |
| 2026-10-17 | Factory system (replaces the single-person ration press) | One rendering line per map at the old `machine_lunch` room. **Gathering:** fleshgrowth nodes (cleaver, 15 s, regrow 8 min) drop mass sacks. **Water:** blue plastic `water_barrel`s fill on touching map water and pour 4 cycles into the hopper on touch; the map spawns a few, proles build more (15 bones, cap 8). **Posts:** the hopper (load on touch); the boiler, whose drifting pressure is kept at 40–70 with a turnable valve (stalls under 40, scalding vent over 90); the press (held use). A 30 s cycle: mass + water makes a ration, water makes clean water. Crates carry a crew stamp, and delivery splits the pay across the crew; a non-crew deliverer is paid but reported for theft. Pumps are for drinking only. A **Give bones** action lets players pay each other. Corpses are never an input. | User: novel gathering and a multi-step process that needs several people working together. The valve and barrels are the user's design. |
| 2026-10-17 | Rewrite's rp_slumtown layout choices | Confirmed: 2 pumps enabled (town centre and arms break room), the other 2 are staff-enabled candidates. Missing stations warn on load. The 2 ration plus 2 clean-water presses are a stopgap until the rendering line replaces them. | User's yes. |
| 2026-10-17 | Content pack | The original assets (Smash font, `placenta/*` sounds, `models/IN`) come from Workshop item 3067207405, added with `resource.AddWorkshop`. | User supplied the link; answers the analysis session's open question in 05. |
| 2026-10-17 | Lunch machine (replaces the rendering line) | Rebuilt from the original `machine_lunch`, with the boiler in place of the generator. **Raw material:** `bone_capsule`s copied from the original `fleshcapsule` (spawn every 15–20 s at the 12 `GM.Capsules` points, cap 12, 15 min life; smash for 2 chunks or carry whole). **Boiler:** barrels fill it; a two-handle valve wheel (instant notches) keeps drifting pressure at 40–70; 70–90 the panel shocks, over 90 it vents. **Machine:** the maw swallows chunks/capsules, a product lever picks ration or clean water, and the original 8-button symbol panel makes one crate per clear (wrong button shocks). Finishing a ration with no biomass blows it up. The hopper, the press, fleshgrowths, mass sacks and the cleaver are cut. Crew stamp = correct panel presses and valve turns. | User: like the original lunch factory but with more interesting steps; keep the boiler; no timed actions for work; cut steps that aren't interesting. |
| 2026-10-17 | Physical, loud lock-breaking (replaces timed pries) | Locks have Integrity and are beaten open by any melee hit or bullet: stockpile about 40 baton hits, storage crate about 15. Every hit is a far-carrying clang with screen shake. Locks recover after 10 s untouched. The stockpile's first hit sends the state-radio alarm and starts a klaxon; breaking it drops 3 rations and runs the break-in rule. | User: make prying physical too, but very loud. |
| 2026-10-17 | Parity rulings on Rewrite's interpretations | Melee matches the original's real behaviour (no heavy-swing bonus, no block reduction). Head burst at about 6 units. No leg-shot jump lock. OOC off by default. Kill sentences: dropped, replaced by a give-up button (below). | User's answers to Rewrite's five interpretations. |
| 2026-10-17 | Give-up button while dying | The bleed-out screen shows *"click ->HERE<- to die instantly!!"*; clicking bleeds out at once (same death and `Crime.Judge`). Replaces the kill sentences; `CanPlayerSuicide` stays false. | User: the downed suicide only existed to escape a hopeless revive wait. |
| 2026-10-17 | Cross-texts, valve wheels, barrel size | Entity info goes in cross-texts; only machine gauges and panels stay 3D2D. The boiler's valves are two valvewheel001 wheels, held with Use at 8 pressure a second (red vents, black builds). One barrel fills half the boiler (8 of 16 water). | User confirmed Rewrite's three rulings (already merged as 3a3a37a). |
| 2026-10-17 | Guns | Every gun used by sanitars or the Kaiser is a 1:1 port of the original `weapon_cc_*` files: same stats, sounds, models and ammo. Covers the sanitator, scout, support and crusader loadouts, the sanitation-station weapons and the novoluger. | The user, as relayed by Rewrite. |
| 2026-10-17 | Rotting | Corpse rot stages and corpse recycling come back, as they were in the original (step 7). The original overrides "corpses are never an input" where it differs. The lunch machine stays corpse-free unless the original's took corpses. Doom and wider Rot pressure stay open. | The user, as relayed by Rewrite. |
| 2026-10-17 | War | Dropped. The nations stay as lore and possible races. Rot/Doom stay deferred. | The user wants several simple pressures instead of a war. |
| 2026-10-17 | UI and effects | Parity with the original Gangrene: HUD, menus, fonts, sounds and screen effects as listed in `05-ui-effects-parity.md`. The only exception is optimisation, where the implementation may differ but the look stays the same. Ground rule 8, Step 15. | User's choice. |
| 2026-10-17 | Parity scope extended | Parity also covers speech and chat, weapon feel, wording, sound, movement, ghosts and controls (05 §8–§14). **Race speech modification (`Accent`, `RacialQuirks`) is not kept:** everyone speaks as typed. | User's choice. |
| 2026-10-17 | Fates kept | Kaiser, Sanitar, Prole, Korpsman, plus Slave; Ghost as the dead/lobby state | User's choice |
| 2026-10-17 | Shop | The dealer's buy menu, open to every fate, as a C-menu list for now: Soylent Loaf 50, Fear Beer 35, Spirits 85, Knife 40, paid to the treasury. Seed Bank, Sanitar Surplus and the Wishbone dropped. | User's choice. Seed bank redundant, surplus not relevant, Wishbone never used. |
| 2026-10-17 | Entity models | Ported entities use the original's model and material. `fate_station` is the purpose in life sawblade; no charple hologram. | User's choice. The hologram hasn't worked since the bonemerged playermodels. |
| 2026-10-17 | Korpsman loop | 3 separate Use presses to revive (no bar), drag the body, no cot; tool in hand picks the treatment. | User: "yes". |
| 2026-10-17 | Shop stock | Shop goods come out of the stockpile; Soylent Loaf is the ration; other goods get a fixed per-round stock. | User: tie shop goods into the stockpile. |
