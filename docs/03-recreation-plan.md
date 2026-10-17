# Liver Failure core remake: step-by-step plan

**Scope:**

- **Four fates:** Kaiser, Sanitar, Prole, Korpsman.
- **Plus Slave:** the probation fate for new players. It plays exactly like a Prole and is only marked differently. New players can only play Slave until they survive a round or another player commends them (step 11.5 and step 13).
- **Ghost** stays as the dead/lobby state. It isn't a fate you pick.
- **Round loop:** play is round-based (60 min). Each round the city has to feed itself from a fixed supply of bones, and every round starts fresh. A few simple pressures drive what players do:
  - Hunger and thirst (step 6).
  - Food that only exists because someone made it and hauled it to the stockpile (step 11.1).
  - An economy the Kaiser runs with a full toolkit (step 9).
  - Theft, and sanitars punishing it (steps 10 and 11.3).
  - There is no war (see Dropped).
- **Platform:** a Garry's Mod gamemode in Lua, with **SQLite** persistence through GMod's built-in `sql.*` library (replacing mysqloo).
- **Background:** `01-systems.md` explains what each system did, and `02-pitfalls.md` explains why it is rebuilt differently. IDs like P1, R3 and S2 refer to `02-pitfalls.md`.

## Ground rules (apply to every step)

1. **Fates are data.**
   - A fate only declares fields (`Police`, `Radio`, `Authority`, `CarryBonus`, `Slots`, `Cost`…) and optional hooks.
   - No code anywhere compares fate names (`ply:Fate() == "kommandant"`). Code asks about capabilities instead: `ply:FateHas("CanSentence")`. (D1, R9)
2. **One state registry.**
   - Every replicated player field is declared once, with a type and a scope:
     - `OWNER`: only that player's client.
     - `PUBLIC`: everyone.
     - `SERVER`: never sent.
   - Changes mark the field dirty, and dirty fields go out once per network tick, batched into one message per recipient.
   - There are no `SetNW*` calls and no per-field net messages. (P4, P5, R8)
3. **One scheduler.**
   - `Sched.Every(name, interval, fn)` and `Sched.EachPlayer(name, interval, fn)`.
   - Per-player work is spread across ticks, and each job runs inside `xpcall`, so one error can't stop other systems. (P1, B9)
4. **Every net receiver goes through `Net.Receive(name, {rate=…, alive=true, fate=…, range=…}, fn)`.**
   - The wrapper rate-limits each player and validates the sender, the target entity and the distance before calling `fn`. (S1, S2)
5. **Persistence is write-behind.**
   - Values change in memory and the row is marked dirty.
   - Dirty rows flush in one `BEGIN … COMMIT` every 60 s, on disconnect and on shutdown. (P6)
6. **Long actions are state, not timers.**
   - Surgery, reviving and building are `ply.Action = {kind, target, startedAt, duration}` records, checked by the scheduler and cancelled when someone moves away, dies or changes fate. (D3)
7. Each step ends with something you can run on a listen server with bots. Don't start step N+1 until step N's "done when" holds.

## The steps

### Step 0: Skeleton and loader

- **Build:**
  - A new gamemode folder. Derive from `base`, not `sandbox`, and add tools later only if they're wanted.
  - A loader of about 30 lines: walk `gamemode/core/` then `gamemode/systems/` in a fixed order listed in one file, and route files by `sv_`/`sh_`/`cl_` prefix. No module descriptors.
  - A `Log` helper and a developer convar for debug output.
- **Done when:** the server boots with an empty map, and a client joins and sees "hello" in chat.

### Step 1: SQLite persistence

- **Schema** (create it with `sql.Query` on Initialize, and version it with a `schema_version` table):
  - `players(steamid TEXT PRIMARY KEY, stem_cells INT, rank INT, playtime INT, created INT, last_seen INT)`
  - `bans(steamid, until, reason, by)`
  - `world(key TEXT PRIMARY KEY, value TEXT)` for the few values that outlive a round (e.g. the round number).
  - **Only stem cells, rank and playtime persist between rounds.** Bones, the treasury, the stockpile and inventory are per-round state and never touch the DB (step 9).
- **API:**
  - `DB.LoadPlayer(ply)` runs synchronously, because GMod's `sql` is synchronous and a single-row select is fast.
  - `DB.MarkDirty(ply, field)` and `DB.Flush()` (a transaction, every 60 s, plus `PlayerDisconnected` and `ShutDown`).
  - Every value goes through `sql.SQLStr`. (S4)
- **Bans** are checked once in `CheckPassword`. They are not reloaded on a timer.
- **Done when:**
  - Joining creates a row.
  - Changing stem cells in memory and reconnecting keeps the value.
  - Killing the server between flushes loses at most 60 s of changes, and that loss is the accepted trade-off.

### Step 2: State registry and networking

- **Declare fields once:**
  - `State.Field("StemCells", "UInt", 10, OWNER, 0, {persist="stem_cells"})`
  - `State.Field("Bones", "UInt", 24, OWNER, 0)` (per-round, not persisted)
  - `State.Field("Fate", "UInt", 4, PUBLIC, FATE_GHOST)`
  - and so on.
- **Generate** `ply:GetBones()` and `ply:SetBones(v)`. A setter does nothing if the value is unchanged, and marks the field dirty, plus DB-dirty if `persist` is set.
- **Network tick** (e.g. 10 Hz):
  - For each recipient, write the dirty fields they're allowed to see into one `net` message: entity index, field id, value.
  - A joining client gets a full snapshot in one message.
- **`State.Reset(ply)`** sets every non-persistent field back to its default. Ghost uses this instead of resetting by hand. (R11)
- **Done when:**
  - With 2 clients and 8 bots, `net_graph` shows one state message per tick.
  - Client A cannot see client B's OWNER fields (test by reading them on A).

### Step 3: Scheduler

- `Sched.Every` / `Sched.EachPlayer`, as in rule 3.
- **`EachPlayer` staggering:** with interval *I* and *n* players, run about *n / (I × tickrate)* players each tick, so a 1-second job is spread across the second.
- **`sched_debug 1`** prints the cost of each job.
- **Done when:** a job that deliberately errors logs once a second and every other job keeps running.

### Step 4: Ghost state and the fate registry

- **Fate definitions:** `fates/<id>.lua` returns a table, validated on load. Missing required fields are a load error.
- **Ghost:**
  - The fate everyone spawns into.
  - No collision, can't be damaged, sees other ghosts, and uses ghost chat.
  - Suffering and haunting are deferred.
- **`Fates.Apply(ply, id, {reason = "pick" | "revive"})`** is the **only** way to set a fate (R1). In one synchronous pass it:
  1. Calls the old fate's `OnLeave`.
  2. Runs `State.Reset`.
  3. Sets the fate field.
  4. Sets model and appearance (step 5).
  5. Gives the loadout and initialises needs (step 6).
  6. Calls the new fate's `OnEnter(ply, reason)`.
- **`Fates.CanTake(ply, id)`** is shared between server and client and returns `ok, reason`. It checks, in order:
  1. rank. A **Foolish** (new) player may only take fates marked `ForNewPlayers = true`, which is only Slave. Everyone else can't take Slave.
  2. stem cells ≥ cost
  3. free slots, where `Slots(pop)` is a function on the fate replacing `Limit`/`DynamicLimits`
  4. the player's death cooldown for this fate
- The HUD and the server both call `CanTake`, so they can't drift apart (R7). There is one error path: `Notify(ply, reason)` (R5).
- **`fate_station` entity:**
  - Replaces `purpose_in_life`. Its key value is the fate id, and it can only be used by ghosts.
  - On use it calls `CanTake`, then charges stem cells, then calls `Apply`.
  - Potentials are **dropped**.
- **Done when:**
  - A ghost can take each of five placeholder fates.
  - A Foolish player is refused everything except Slave, and a Friend is refused Slave.
  - Slot limits hold when 10 bots try at once.
  - Dying sends you back to ghost with a per-fate cooldown.

### Step 5: Character appearance

- **Names:** random from a list of names per fate (proles get worker names, sanitars get codenames).
- **Appearance:** body, model, skin and bodygroups come from a fate field `Appearance = {model, bodygroups, skin}`, or a function returning that table.
- **Clothing:** if bonemerged clothing comes back, it is a PUBLIC field holding a small integer outfit id. Clients build the bonemerge locally from it. No `WriteTable` broadcast and no timers. (P8)
- **Race:** an Appearance field (`race = "gangral"`). In the core every fate is **Gangral**, because the game is set in Gangrene.
  - Races are data in `races/<id>.lua` (hands, skin tones and an optional speech modifier), so **Outsider**, **Rottish**, **Prohladian** and **skinless** characters can be added later without code changes. Outsider is the likely first addition, for local migrants and cultists.
  - "No race shown" is `race = nil`, not a fake race (the original's `unimportant`).
  - Use the lore names in code. Don't use the old `liverman`, `arrhythmian` or `kidneystani` IDs.
- **Name validation:** one shared `ValidateName` with a correct character whitelist (B12). Only needed if players get to name themselves.
- **Pace and atmosphere:** the remake should feel darker and slower than the original.
  - Walk and run speeds come from one config table (slower than GMod defaults; start at walk 130, run 200). Speed = config × the fate's `SpeedMulti` × the needs weakness (step 6). Nothing else sets speed.
  - One client file, `cl_atmosphere.lua`, applies a desaturated colour correction and fog. It is presentation only and has no gameplay state.
- **Done when:** a fate change shows the right model on every client with no flicker. Test with 2 clients and lag simulated with `net_fakelag`. Movement uses the configured speeds, and the atmosphere is visible on every client.

### Step 6: Needs component

- **One table of definitions:**
  ```lua
  Needs.Define("Emptiness", {rate = 1/24, max = 100, field = OWNER, onTick = ..., thresholds = {[80] = "starving"}})
  ```
  - Core needs: **Emptiness, Dryness, Despair, Pox**. Pox (lowers max HP, but never below 5) is core because dirty water and full thirst cause it (step 8).
  - **Pace:** survival is meant to be hard. Dryness fills in about 25 min (`rate = 1/15`) and Emptiness in about 40 min (`rate = 1/24`). In a 60-minute round a player has to eat about twice and drink two or three times.
  - **Hunger and thirst never deal damage.** They wear the player down instead:
    - **Weakness:** from 50 to 100, the higher of Emptiness and Dryness scales the player down linearly: movement speed ×1.0 → ×0.7 (step 5), damage dealt ×1.0 → ×0.6 (a `Damage.Scale` hook), and consciousness regen ×1.0 → ×0.25.
    - **Full thirst:** while Dryness is 100, Pox slowly rises (+1 every 10 s).
    - **Full hunger:** a player downed while Emptiness is 100 can't be revived (step 7).
  - **Dropped:** urine, parasites, organs and mutations.
- **One mutator:** `Needs.Add(ply, name, amount, source)` with a fixed signature (R4).
  - Quirks and fates hook in through `Needs.Modifiers`: functions `(ply, name, amount, source) → amount`.
  - This is how a "can't be cheered by drink" quirk would work later.
- **One scheduled job:** `Needs.Tick` runs once a second per player and applies rates and threshold effects.
- **Despair at 100:** heart attack, death, −1 stem cell (kept from the original).
- **Food and drink** are items whose `Use` calls `Needs.Add`.
  - **Food is scarce by design.** There are no free food spawns. Rations only exist because a prole or slave made them (step 11.1). The only free drink is dirty water from the pump (step 8).
- **Done when:** the needs rise on their own, eating lowers Emptiness, and despair at 100 kills and costs a stem cell. Hunger and thirst never reduce HP directly. A bot with no food or water gets steadily slower and weaker from about minute 12, and its Pox starts rising once Dryness hits 100.

### Step 7: Damage, downed, death, corpse

- **Damage pipeline** (D4): `EntityTakeDamage` calls hooks in order:
  1. `Damage.Scale` (hitgroup and fate multipliers)
  2. `Damage.Armor`
  3. `Damage.Consciousness`
  4. `Damage.Health`
  - Fates and items register hooks; nothing is inlined.
- **Consciousness** runs 0–100. At 0 the player passes out into a ragdoll and wakes up later.
- **HP reaching 0 downs the player; it doesn't kill them.** Being knocked out is usually survivable. Only severe wounds kill without a korpsman.
  - The player becomes **downed**: a corpse ragdoll that holds the player's inventory and carried bones. They watch a dark screen with a timer.
  - The server sets a SERVER field `DownState` from the hit that downed them:
    - **`wounded`** (the normal case): the hit went less than `lethal_overkill` (default 30) past 0 HP.
    - **`dying`**: the hit went `lethal_overkill` or more past 0 HP. Any damage to a body that is already wounded also makes it dying.
  - The player who downed them is remembered (SERVER field) for judging later.
- **Corpse registry:** add on create, remove on `EntityRemoved` (P2). Decomposition beyond "despawn after N minutes" is deferred.
- **Leaving the downed state:**
  - **Get back up (wounded only):** after `wake_time` (default 45 s) the player gets up on their own as the same fate, with 25 HP and the **`Injured`** condition.
    - `Injured` is a PUBLIC field that caps max HP at 50. It does not wear off. A korpsman treats it (step 11.2).
    - Getting up is its own small wake-up path (like waking from a pass-out). It isn't a revive.
  - **Bleed out (dying only):** after `bleedout_time` (default 120 s) without a revive, the player dies and becomes a ghost. `Crime.Judge` runs against the player who downed them.
  - **Revive (either state):** a korpsman uses the body. **Exception:** a player downed while Emptiness is 100 can't be revived. The body has nothing left to bring back. A wounded starving player still gets up on their own; a dying one is lost. This is a timed action (rule 6) and calls `Fates.Apply(ply, sameFate, {reason="revive"})`. The fee comes from step 11.2. A revived player has no `Injured`. There is one revive function (R2).
  - **Finish off (either state):** an explicit context action on a downed body (a short timed action, about 3 s), not just stray damage. It calls `Crime.Judge` (step 10), and the player becomes a ghost. This is the only instant death.
- **Consciousness** stays separate: at 0 the player passes out into a short stun and wakes with no injury.
- **Done when:**
  - A bot downed by a light hit gets back up after 45 s at 25 HP, `Injured`, with max HP 50. A korpsman treatment clears it.
  - A bot downed by a hit 30 past 0 HP, or shot again while wounded, is dying, and becomes a ghost after 120 s unless revived. The downer is judged at that point.
  - Revive works in both states with inventory intact, and is refused for a body downed at full hunger. Finish off works in both states.
  - The corpse loop never calls `FindByClass`.

### Step 8: Inventory and items

- **Item definitions:** keyed by id. `Items.Get(id)` is O(1) (P7).
- **Inventory:** stored as a server-side **map `{itemId → count}`**.
  - The owner gets a delta message on change.
  - Weight is cached and recalculated on add and remove.
  - Carry limit = base + `fate.CarryBonus` + items' `CarryAdd`.
- **Persistence:** inventory is not persistent, as in the original. It belongs to the character's life and drops to the corpse on death.
- **Starting set:** about 10 items to start: ration, clean water, dirty water, scrap, medical tools, the baton, the pistol and permits.
- **`water_pump` entity:** one or two per map, usable by anyone. Each use gives one dirty water, with a short per-player cooldown. Dirty water lowers Dryness less than clean water and has a 25% chance to add Pox. Clean water is only sold from the stockpile (step 9).
- **Done when:** pick up, drop and use work, the weight limit holds, and the corpse holds the dead player's items. The pump gives dirty water, and drinking it sometimes adds Pox.

### Step 9: Economy (fixed bone supply, treasury, stockpile, prices)

- **A closed economy.** At round start (map load, later `Round.Start` in step 13) the treasury holds every bone that exists: `bones_supply` (convar, default 3000).
  - After that, bones only move. Nothing creates or destroys them: no minting, no sinks, no NPC buyers.
  - **Invariant:** players + corpses + disconnected holdings + upgrade fund + treasury = `bones_supply`, always. When a corpse despawns, its bones go to the treasury. `econ_audit` checks it on demand, and a scheduled job checks it every 60 s and logs any drift.
- **Bones** are a per-round OWNER field, not persisted (step 1).
  - There is one primitive: `Econ.Transfer(from, to, amount, source)`. `from` and `to` are each a player, a corpse or `TREASURY`. It refuses if `from` can't afford the amount.
  - A disconnecting player's bones are held in a SERVER table and restored if they rejoin this round.
- **The stockpile** is a map entity, `state_stockpile`. It holds counts, not entities: `{ration = n, clean_water = n}`, which are PUBLIC world state.
  - Delivering a crate (step 11.1) adds to the count and pays the deliverer that good's buy price from the treasury.
  - Anyone can buy at the counter for that good's sell price, and the bones go to the treasury. Purchases follow the ration limit and the reserve below.
  - Withdrawing for free needs `FateHas("StockpileAccess")` (Kaiser, Sanitar). It ignores the limit and the reserve.
- **The Kaiser runs the economy.** The challenge is keeping a working city fed and paid, not getting rich, so the Kaiser has many tools and no personal stake:
  - There is no Kaiser wage and no way to move treasury bones into their own pocket. The treasury is the Kaiser's budget.
  - There are no clamps on the Kaiser's choices. Values are only checked for sanity: never negative, and never above `bones_supply`.
- **The `Economy` table** holds every setting. It is one PUBLIC world-state table, described by a schema (`{key, type, min = 0, max = bones_supply, default}`), and it resets each round and when the Kaiser dies:

  | Setting | What it does | Default |
  |---|---|---|
  | `buy.<good>` | What the state pays per delivered crate, for each good (ration, clean water). | 20 / 20 |
  | `sell.<good>` | What the counter charges, for each good. | 15 / 15 |
  | `wage.<fate>` | Paid from the treasury to each living player of that fate every 300 s. It is a data table keyed by fate id, so no code compares fate names. | sanitar 40, others 0 |
  | `ration_limit` | How many counter purchases each player can make per 10 min (0 = unlimited). | 0 |
  | `reserve.<good>` | The counter stops selling when stock drops to this level. | 0 |
  | `breadline` | Minutes between free rations for each player at the counter (0 = off). Free rations also stop at the reserve. | 0 |
  | `revive_fee` | The percentage of a patient's carried bones a korpsman takes (step 11.2). | 50 |

- **Kaiser actions** (step 11.4):
  - **Set:** one validated receiver, `nKaiserEcon(key, value)`, checks the key and value against the schema. The same one-receiver pattern as R3.
  - **Grant:** pay any amount from the treasury to any living player.
  - **Fine:** take any amount from a player into the treasury, capped at what they carry. It uses the same target checks as Sentence.
  - **Ledger:** `Econ.Transfer` logs every movement with its source. The Kaiser's panel shows the treasury, stock levels, money in and out over the last 5 minutes broken down by source, and the most recent transfers. The panel shows this next to each setting, so the Kaiser can see what each change does.
- **Bad settings hurt on their own:**
  - A low buy price means proles can't afford food.
  - A high buy price or high wages drain the treasury, so payments stop.
  - A high sell price drives hoarding and theft.
  - A high reserve with no bread line starves the city while the stockpile sits full.
- Any payment the treasury can't cover isn't paid, and the people affected are told why ("The treasury is empty.").
- **Dropped from the original:** the labor, sales and sanitar tax storages, the 20% payout to the Kaiser, tax evasion, ATM bonds and inflation. This also removes the B11 bug.
- **Done when:**
  - A delivered crate moves bones from the treasury to the deliverer, and buying a ration moves them back.
  - Every `Economy` setting changes the next relevant payment or purchase. Grant and Fine move bones, and the ledger shows each one by source.
  - Out-of-schema values (negative, above supply, unknown key) are rejected.
  - An empty treasury stops crate payments and wages, with a notice.
  - `econ_audit` reports zero drift after a 30-bot soak with deaths, revives, disconnects and rejoins.

### Step 10: Crime and police

- **Wanted** is PUBLIC: `Wanted` (0 = none, 1 = torment, 2 = judgment, 3 = death), `WantedUntil` and `WantedReason`.
  - **Evidence** is SERVER-only, plus a short summary sent to police (OWNER-of-police scope, or one police broadcast).
- **Expiry while unseen:**
  - Once a second, take one wanted player per tick.
  - Prefilter police by distance and PVS, then do **one** trace per remaining pair (P3).
  - The timer only counts down while no police can see them.
- **`Crime.Judge(attacker, victim)`** is a **rules table** instead of nested ifs (R12). Each rule is `{when = predicate, crime, wanted, stem, despair}`, checked in order. The four-fate version:
  - Attacker is the Kaiser → no crime.
  - Victim is death-wanted and the attacker is a sanitar → no crime, +1 Teeth.
  - Victim is a sanitar → "policide", death-wanted for 450 s.
  - Victim is the Kaiser → "high assassination", death-wanted for 600 s.
  - Same faction and lower authority than the victim → big stem penalty (and −666 for killing your own leader).
  - Victim is a citizen → "murder", death-wanted for 300 s, −1 stem cell, +30 despair.
- **`Crime.Report(ply, act, ctx)`** judges crimes that aren't kills. It uses the same rules-table form as `Crime.Judge`. The theft rules:
  - **Theft, unseen:** delivering or opening a crate stamped as made by someone else adds *theft* evidence (300 s).
  - **Theft, caught in the act:** if any police can see the player at that moment (the same prefiltered trace as wanted expiry), they become torment-wanted for 180 s, with the reason "theft from the People".
  - **Stockpile break-in:** finishing a stockpile pry (step 11.1) makes the player judgment-wanted for 300 s. Starting one sends an alarm on the `"state"` radio channel with the stockpile's location.
- **Done when:** each rule fires in a scripted bot scenario, and wanted status counts down only while out of sight. Each theft rule also fires in a bot scenario.

### Step 11: The fates

Build them in this order, so each one has something to act on.

1. **Prole**: the economic base.
   - Kit: `permit_tool` and a random scrap item. Worse aim (`AccuracyMulti 1.25`, `RecoilMulti 1.3`).
   - **Work loop (food is the product):**
     - Using a `ration_press` work station is a timed action (rule 6, about 30 s). When it finishes, a physical **ration crate** entity (`ent_crate`, kind `ration` or `clean_water`) appears next to the station.
     - Each crate carries a SERVER-only `MadeBy` stamp (the maker's SteamID).
     - Each station allows at most 3 crates waiting in the world, so the map can't fill with entities.
     - Crates are carried by hand (physics pickup). Carrying one slows the carrier.
     - Touching a crate to the `state_stockpile` delivers it: the crate is removed, the count goes up, and the **deliverer** is paid that good's buy price (step 9). So crates left lying around are worth stealing.
     - A crate can also be opened on the spot, which gives its contents to the person who opened it.
     - Delivering or opening a crate someone else made goes through `Crime.Report(ply, "theft", …)` (step 10).
   - **Stockpile pry:** anyone without `StockpileAccess` can pry the stockpile open. This is a 60 s timed action, cancelled by moving away or taking damage. It sends the step 10 alarm when it starts, and when it finishes it drops 3 rations and runs the break-in rule.
   - **Construction:** the C-menu `Build` places a factory site (25) or a storage crate (35). The cost goes to the treasury through `Econ.Transfer`. Validate placement range on the server.
   - Unions and WorkTitles are deferred.
2. **Korpsman**: the revive and healing loop.
   - Regenerates 3× faster.
   - Revive is the timed action from step 7. The fee is `revive_fee` percent of the patient's carried bones (default 50, set by the Kaiser in step 9).
   - **Surgery:** a small set of 2–3 procedures (heal, which also **treats `Injured`** from step 7; cure Pox; remove a bullet). Treating the injured is the korpsman's everyday work. Each is a timed action with a server-rolled failure chance; `autoFail` is never read from the client (B19).
   - `lovebox` heal tool: only after the Kaiser upgrade.
3. **Sanitar**: enforcement.
   - Police flag, radio, codename, baton and scope.
   - **Teeth** is an OWNER field, spent at a `sanitation_station` entity on weapons.
   - Can see wanted status and evidence summaries.
   - Paid `wage.sanitar` from the treasury (step 9). If the treasury is empty, they aren't paid.
   - Has `StockpileAccess`, so guarding the stockpile is part of the job.
   - **Inspect:** a context-menu action on a living player within 100 units. It is a validated receiver (rate-limited, sender is police and alive, target in range).
     - It reveals whether the target is carrying a crate stamped by someone else, and shows their evidence summary.
     - If the target has theft evidence, the inspection turns it into torment-wanted for 180 s.
   - Beating or arresting a theft-wanted player earns +1 Teeth.
   - Slots: `Slots = function(pop) return math.Clamp(2 + math.floor(pop / 10), 2, 6) end`.
4. **Kaiser**: the head of state.
   - 1 slot, no rank requirement for now (any non-Foolish player; rank gates are undecided, see step 13), costs 5 stem cells, 75 armor, the novoluger pistol and the strategy book.
   - **Economy panel:** Set, Grant, Fine and the Ledger from step 9. There are no taxes, no clamps and no Kaiser wage.
   - Has `StockpileAccess`.
   - **Sentence and forgive:**
     - Both are validated receivers: target valid, alive, not a ghost, in range or visible.
     - Forgiving a theft costs 300. The forgiven player pays it to the treasury through `Econ.Transfer`, and the forgiveness fails if they can't afford it.
   - **Upgrades:** **one** receiver `nKaiserUpgrade(targetFate)` reading a data table `{prole = 125, korpsman = 150}` (R3). It is paid from the treasury, and the bones are held in an upgrade fund that is part of the step 9 invariant. They are not destroyed.
   - **On death:** the `Economy` table goes back to its defaults, with a global announcement and a 600 s cooldown for the role.
5. **Slave**: probation for new players. It has **full parity with Prole**: build it as a variant of the Prole definition, `Fates.Define("slave", {Base = "prole", ...})`, that only overrides presentation and who may take it.
   - **Who:** every Foolish-rank player, and only them. Cost 0, unlimited slots, a short death cooldown (15 s, like Prole).
   - **Same as Prole, in every rule:**
     - The Prole kit and aim, the work loop (making and delivering crates for the buy price), Construction, needs, inventory, and being revived by korpsmen.
     - Can deal damage, steal and pry the stockpile.
     - Can be made wanted and collect evidence.
     - Killing a slave is judged exactly like killing a prole (murder of a citizen).
     - The corpse decays like a prole's.
   - **Different from Prole (presentation only):**
     - Barcode name: `"<Drone|Serf|Peon…> #<last digits of SteamID>"`.
     - Slave model and clothing, plus a PUBLIC marker so everyone can see who is new.
   - **Dropped from the original slave:** `weapon_cc_slave`, the zero-damage hook, immunity from wanted and evidence, the ban on building, and the 30 s corpse decay. No gameplay code may check for Slave; anything that applies to slaves applies to proles.
   - **Leaving slavery** (both paths call `Rank.Free(ply, how)`):
     - **Survive a round:** at `Round.End`, every player who is a Slave, alive and not downed, and has spent at least `slave_min_round_time` (default 20 min) as a Slave this round, is freed. The time adds up across deaths (a SERVER field), but the player must be alive at the end. Joining just before the round ends doesn't count.
     - **Commendation:** a non-slave uses the context-menu "Commend" on a slave. This is a validated receiver:
       - The commender is alive, not a ghost and not a slave.
       - The commender's rank is at least Friend.
       - The target is a Slave within 200 units.
       - Each commender gets **one commendation per round**, stored as a SERVER field, to limit alt-account farming. Every commendation is logged.
     - `Rank.Free` does the following:
       - Sets the player's rank to Friend and flushes it to the DB straight away. This is the one exception to write-behind, so freedom is never lost.
       - Broadcasts the big chat line *"<name> has been freed by <commender / surviving the round>!"*.
       - Gives the freed player +1 stem cell.
       - Gives a commender +1 stem cell.
       - If the freed slave is alive, they stay a Slave until they die. On the ghost screen they can then pick any fate (no forced kill, unlike the original's ascend).
   - Banishing is dropped. Kicking and banning are admin tools (step 14).
- **Done when:** a 4-player session (Kaiser, Sanitar, Korpsman, Prole) can play one full loop:
  1. The prole makes a ration crate, hauls it to the stockpile and is paid the buy price. Someone buys a ration at the counter.
  2. The Kaiser changes a price, grants bones to the korpsman, fines a player, and sentences the prole. The ledger shows each movement.
  3. The sanitar executes the prole and earns Teeth.
  4. The korpsman revives someone for a fee.
  5. A second prole delivers another player's crate in sight of the sanitar and becomes wanted. An unseen theft becomes wanted when the sanitar inspects the thief.
  6. A fresh account joins as a Slave, makes and delivers crates, and is freed by a commendation. A second fresh account steals a crate in sight of the sanitar, becomes wanted like a prole would, and is still freed at the end of the round if alive.

### Step 12: Chat and radio

- **Local chat:** say, yell, whisper, `/me` and OOC, with ranges from one table.
- **Radio:** `/r` reaches everyone whose fate's `Radio` channel list shares a channel with yours (e.g. `"state"` for Kaiser and Sanitar, `"medic"` for Korpsman). Fate names are never hard-coded (R9).
- **Dead players:** ghosts talk only to ghosts.
- Defer speech mangling (`ModifySpeech`, `AutoGrammar`, racial quirks) until the core feels right.
- **Done when:** radio reaches exactly the right people and ranges hold.

### Step 13: Meta-progression

- **Stem cells:**
  - Earned from playtime ticks and objectives.
  - Lost to unjust kills and despair deaths.
  - Spent on fates.
  - Spending them gives no bones. The original gave 25 per stem cell, but that would mint bones into the fixed supply (step 9).
- **Ranks:**
  - Foolish, Friend, Kapitan and Kaiser are enough for the core.
  - **Rank gates on fates are undecided.** For now no fate needs a rank above Friend; the only rank rule is that Foolish players can only be Slave. Which fates later need which rank is an open decision for the user.
  - New accounts start at **Foolish**, which can only play Slave (step 11.5). Friend comes from `Rank.Free`.
  - Keep auto-promotion from Friend to Kapitan at the stem-cell threshold.
  - Admin ranks are separate from the game's ranks.
- **Rounds:** the round is the unit of play. Keep it simpler than the original, which only ended a round through Doom.
  - `Round.Start` happens on map load. It seeds the treasury with `bones_supply`, sets the prices to their defaults and empties the stockpile (step 9). Everyone starts the round with 0 bones.
  - `Round.End(reason)` fires when the round timer (`round_length`, default 60 min) runs out or an admin ends it. It frees surviving slaves, flushes the DB, shows an end screen, then changes level.
  - Only stem cells, rank and playtime carry over to the next round.
  - The Kaiser's fall may trigger `Round.End` later. There is no Doom or war end state.
- **Done when:**
  - A new player starts as a Slave and is freed either by commendation or by surviving to `Round.End`.
  - Once freed, the player can take any fate, Kaiser included, with stem cells alone.

### Step 14: Hardening and playtest

- **Audit every `Net.Receive`:** rate limit, sender checks and target checks (S1–S2).
- **Bot soak:** 30 bots cycling through fates for an hour. Watch the `sched_debug` costs, the net bytes per second and the DB flush time. `econ_audit` must report zero drift at the end.
- **Admin basics:** kick, ban, set rank, set fate and noclip for staff.
- **Then playtest with people.** Only after that, pick what to bring back from the deferred list below.

## Deferred (not in the core)

These are ordered by how much they add to the feel compared with their cost:

1. Quirks, through `Needs.Modifiers` and fate hooks.
2. Corpse decomposition stages.
3. Day/night weather.
4. Ghost haunting and Suffering.
5. Unions and gangs.
6. Dealer stocks and contraband.
7. Foreman work orders and factories.
8. Organs, parasites and mutations.
9. Rot and Doom.
10. Potentials and antagonists.

## Dropped outright

- `fedhoria`, gprofiler, `replicate` and the old module loader.
- Hogmode, `SpawnerThink` and copy-pasted resource spawners.
- Hard-coded SteamIDs.
- Text-file persistence.
- mysqloo.
- War with Rottingham and the Prohlada Union, nation potentials and refugee waves. The remake uses several simple pressures instead (see Scope). The nations stay as lore, and as races that could be added later (step 5).
- Taxes (labor, sales and sanitar storages), tax evasion, ATM bonds and inflation. The Kaiser's `Economy` table replaces them (step 9).
- Free food spawns. Food comes from labor only (step 11.1).
