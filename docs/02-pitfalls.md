# Liver Failure: pitfalls

Paths are relative to `gamemode/`, and `LM/` means `gamemode/liverfailure-modules/`.
Each pitfall is marked **[remake]** if the remake must avoid it by design, or **[legacy]** if it only matters for fixing the old code.

## A. Bugs that silently change behaviour

These are mostly Lua precedence mistakes: `not x == y` parses as `(not x) == y`, and `a or b` inside a comparison picks the first truthy value.

| # | Where | What happens |
|---|---|---|
| B1 | `LM/potentials/sh_fatemenu.lua:285` | `if not ent:GetClass() == "potential"` is never true, so the ENVISION teleport receiver accepts **any entity** as a target. Clients can teleport their ghost anywhere there is an entity. |
| B2 | `entities/entities/potential.lua:165,168` | `not GAMEMODE.Doom == DOOM_DYING` is always false, so the NoAntags/AntagRatio gates never fire. `POTYPE_EVIL` is a typo for `POTTYPE_EVIL` and evaluates to nil. |
| B3 | `potential.lua:164` | Reads `.PotType`, but the defaults in `sh_potentials.lua` set `.Type`. |
| B4 | `potential.lua:226-228` | Indexes `plyDeathTimer[fid]` with `fid` undefined (nil), so death timers never apply to potentials. |
| B5 | `potential.lua:184-185` | `CurTime() + X.SpawnTime or 10`: the `or 10` fallback never applies, and a nil SpawnTime errors. |
| B6 | `LM/framework/sv_think.lua:291` | `not q:GetMoveType() ~= MOVETYPE_NOCLIP` is always true, so noclipping admins are not excluded. |
| B7 | `sv_think.lua:552` | `Quirk() == ("plague" or "medical waste" or …)` only ever compares against "plague". |
| B8 | `sv_think.lua:288` | `AntagCooldown + 1` runs inside an inner per-player loop, so it grows n times per pass instead of once. |
| B9 | `sv_think.lua` corpse loop (~938) | A `return` inside the corpse loop aborts **the whole Think** for that tick: every system after it is skipped. |
| B10 | `sv_think.lua:1458,1531` | `SafeRemoveEntityDelayed(newTumor, …)` uses an undefined variable. |
| B11 | `sv_think.lua:1113` | Mixes `or`/`and` without parentheses: the first tax tick fires even when storage is empty, and a mistyped storage stalls forever. |
| B12 | `shared.lua:216` | `CheckCharacterValidity` checks whether the *whole name* appears inside the allowed-character string, which is backwards. The same idea is re-implemented, correctly or not, in `sv_charcreate.lua:47`, `cl_charcreate.lua:21` and `cl_playermenu.lua:576`. |
| B13 | `LM/fates/list/proletariat.lua:74,116` | `FATE.OnRevive` is defined twice; the second silently overwrites the first. |
| B14 | `LM/fates/list/sanitator.lua:4,32` | `FATE.DeathTimer` is set to 60, then overwritten with 120. |
| B15 | `LM/framework/chat/sh_chat.lua:944,953` | `CC.Curse` is defined twice. |
| B16 | `LM/framework/sh_consciousness.lua:649` (`DoRevive`) | Reads `skipanim`, which is never declared: it is a global and is nil unless something else leaked it. |
| B17 | `LM/framework/sh_inventory.lua:199` | `n = n or 1` leaks a global `n`. `SaveInventory` returns `str`, an undefined global. `InventoryMaxWeight` has the condition `a and b or c`, so `UpgradedForeman` bypasses the `CanUseMachines` check. |
| B18 | `LM/fates/list/kommandant.lua:164` (`nSentence`) | There is no `IsValid(who)` or `IsPlayer` check. The Kaiser does not have to be alive or nearby. The `or … and … and` precedence means the victim's alive check only applies in some cases. |
| B19 | `LM/surgeries/sv_surgery.lua:6` | `autoFail` is read from the client. The success branch edits `ply:Evidence()` in place, so the change is never networked or set. |
| B20 | `sh_burdens.lua` and others | Globals leak (`tab`, `mult`, `friends`) and are shared between unrelated functions. |

## B. Performance

| # | Where | Problem | **[remake]** fix |
|---|---|---|---|
| P1 | `sv_think.lua` (all of it) | **One monolithic `GM:Think`** checks dozens of `Next*` timestamps every tick. A Lua error or early `return` anywhere stops everything after it (see B9). | A scheduler: named jobs, each with its own interval, error isolation and per-player staggering. |
| P2 | `sv_think.lua:938,1220`, `cl_hud.lua:2031` | Runs `ents.FindByClass("prop_ragdoll")` **every tick** on the server, and every frame in the HUD. | Keep a corpse registry: add a corpse on creation and remove it on removal. |
| P3 | `sv_think.lua` ~285 | Every 10 s, each player is checked against every other player with `CanSee` traces, which is O(n²). | Spatial prefilter (PVS or distance), interested pairs only, and spread the work across ticks. |
| P4 | `sh_player.lua` accessors | About 110 fields with **one net message each**. Public fields (all needs, wanted state…) are broadcast to everyone. Tables go through `WriteTable`. | One state registry with scopes (owner / public / server). Collect dirty fields and send them in one batched message per tick per recipient. |
| P5 | `sh_player.lua:205,226` | Joining sends players × 110 messages. | A full snapshot in one message. |
| P6 | `sv_sql.lua:355`, `AddMoney`, `AddStemCells` | **One SQL UPDATE per change**: every bone earned is a query. | Mark the player dirty in memory and flush every 30–60 s, on disconnect and on shutdown, all inside one transaction. |
| P7 | `sh_items.lua:258` | `GetItemByID` scans every item linearly. `InventoryWeight` calls it once per carried item, which is O(inventory × items). | Key items by ID and cache weight on add and remove. |
| P8 | `sh_fates.lua` | Bonemerge setup is driven by `timer.Simple(0.05/0.1)` chains, then broadcast with `WriteTable`. | Apply appearance in one pass when the player spawns, and send it as compact fields. |
| P9 | `sv_business.lua` | Stocks and contraband broadcast the whole table with `WriteTable` on every +1. | Send a delta, and only to the people who can see that market. |
| P10 | `sv_think.lua:1683` | `SpawnerThink` is commented by the authors as causing "incredible net lag". About 10 resource spawners are copy-pasted. | Drop it for the core. If it comes back later, use one generic spawner configured with data. |
| P11 | various | `ents.FindInBox(v, v)` (a zero-size box) is used as a point test. `FindInBox` with ±300 is used to find nearby players. | `player.Iterator()` with `DistToSqr`. |

## C. Redundancy

| # | What | Where |
|---|---|---|
| R1 | `BecomeFate` and `ReviveFate` are about 80% the same. | `sh_fates.lua:16,246` |
| R2 | `DoRevive` and `GM:BleedUp` are two revive paths. | `sh_consciousness.lua:592,649` |
| R3 | Four near-identical `nUpgrade*` receivers, plus a commented-out fifth. | `kommandant.lua:196–450` |
| R4 | Five near-identical `Add<Need>` functions with an overloaded `(amt, source\|max, max, ignorequirk)` signature. | `sh_burdens.lua` |
| R5 | About 15 copy-pasted "frighten + red chat" error blocks. | `purpose_in_life.lua`, `potential.lua` |
| R6 | The `HandTorso` alphabet hack is pasted into every fate file. | `LM/fates/list/*` |
| R7 | Slot and limit logic is written once for the HUD and once for the server, and the two copies have drifted apart. | `purpose_in_life.lua` |
| R8 | **Three networking systems**: accessors, `SetNW*` and `LM/replicate`. | everywhere |
| R9 | Fate checks use hard-coded name lists or substrings (`string.find(fate, "kidney_")`, `CanRadio`'s list, `policeFates`, `hosFates`) instead of fields on the fate. | `sh_inventory.lua`, `sh_chat.lua:1191`, `sh_player.lua:1033` |
| R10 | Two near-duplicate music lists. The `allowedChars` check is written four times. | `shared.lua` and others |
| R11 | Ghost `OnSpawn` resets dozens of fields by hand. With a state registry this is a single call: reset everything to its defaults. | `ghost.lua` |
| R12 | `GM:Judge` is about 200 lines of nested ifs that encode a rules table. | `sh_consciousness.lua:912` |
| R13 | Dead code: large commented-out blocks, an `unused/` folder, a `statuses` module listed in `loaderconfig` that doesn't exist, the stubbed `AntagRatio`, and an empty `SQLThink`. | throughout |

## D. Security and trust

- **S1.** `nRequestPlayerData` and `nRequestPData` have no rate limit. Any client can make the server send N×110 messages on demand.
- **S2.** Several receivers trust the client: B1 (teleport), B18 (sentence) and B19 (`autoFail`). The rule for the remake: **every net receiver checks that the sender is valid, alive, holds the right fate, is within range of the target, and passes a rate limit.**
- **S3.** Hard-coded SteamIDs appear in fate code (`ghost.lua`). Permissions should come from the rank stored in the database.
- **S4.** SQL is built by string concatenation. `field` is escaped, but the SteamID is not. With SQLite, use `sql.SQLStr` everywhere, or a single query helper.

## E. Design debt that makes the above hard to fix

- **D1.** Fates are identified by **string comparison throughout the codebase**, so renaming or removing a fate breaks code far away. In the remake, behaviour should hang off fields on the fate (`Police`, `Radio`, `CarryBonus`, `Authority`…), never off the fate's name.
- **D2.** Gameplay state is spread across accessors, NW vars and plain Lua fields on the player (`ply.InSurgery`, `ply.reviving`, `ply.WantedPTime`), so there is no single place to reset or persist it.
- **D3.** Timers are tied to players by SteamID strings (`SteamID64().."_SurgeryTimer"`) and outlive the state they act on. Long actions should be state machines checked by the scheduler.
- **D4.** Hooks such as `EntityTakeDamage` and `DoPlayerDeath` hold all the special cases for every fate inline, instead of dispatching to fate or item hooks.
