# Liver Failure core remake: step-by-step plan

**Scope:**

- **Four fates:** Kaiser, Sanitar, Prole, Korpsman.
- **Plus Slave:** the probation fate for new players. It works like a Prole with restrictions. New players can only play Slave until they survive a round or another player commends them (step 11.5 and step 13).
- **Ghost** stays as the dead/lobby state. It isn't a fate you pick.
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
  - `players(steamid TEXT PRIMARY KEY, stem_cells INT, rank INT, bones INT, playtime INT, created INT, last_seen INT)`
  - `bans(steamid, until, reason, by)`
  - `world(key TEXT PRIMARY KEY, value TEXT)` for the treasury and tax rates.
- **API:**
  - `DB.LoadPlayer(ply)` runs synchronously, because GMod's `sql` is synchronous and a single-row select is fast.
  - `DB.MarkDirty(ply, field)` and `DB.Flush()` (a transaction, every 60 s, plus `PlayerDisconnected` and `ShutDown`).
  - Every value goes through `sql.SQLStr`. (S4)
- **Bans** are checked once in `CheckPassword`. They are not reloaded on a timer.
- **Done when:**
  - Joining creates a row.
  - Changing bones in memory and reconnecting keeps the value.
  - Killing the server between flushes loses at most 60 s of changes, and that loss is the accepted trade-off.

### Step 2: State registry and networking

- **Declare fields once:**
  - `State.Field("Bones", "UInt", 24, OWNER, 0, {persist="bones"})`
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
- **Name validation:** one shared `ValidateName` with a correct character whitelist (B12). Only needed if players get to name themselves.
- **Done when:** a fate change shows the right model on every client with no flicker. Test with 2 clients and lag simulated with `net_fakelag`.

### Step 6: Needs component

- **One table of definitions:**
  ```lua
  Needs.Define("Emptiness", {rate = 1/30, max = 100, field = OWNER, onTick = ..., thresholds = {[80] = "starving"}})
  ```
  - Core needs: **Emptiness, Dryness, Despair**. Pox is optional.
  - **Dropped:** urine, parasites, organs and mutations.
- **One mutator:** `Needs.Add(ply, name, amount, source)` with a fixed signature (R4).
  - Quirks and fates hook in through `Needs.Modifiers`: functions `(ply, name, amount, source) → amount`.
  - This is how a "can't be cheered by drink" quirk would work later.
- **One scheduled job:** `Needs.Tick` runs once a second per player and applies rates and threshold effects.
- **Despair at 100:** heart attack, death, −1 stem cell (kept from the original).
- **Food and drink** are items whose `Use` calls `Needs.Add`.
- **Done when:** the needs rise on their own, eating lowers Emptiness, and despair at 100 kills and costs a stem cell.

### Step 7: Damage, downed, death, corpse

- **Damage pipeline** (D4): `EntityTakeDamage` calls hooks in order:
  1. `Damage.Scale` (hitgroup and fate multipliers)
  2. `Damage.Armor`
  3. `Damage.Consciousness`
  4. `Damage.Health`
  - Fates and items register hooks; nothing is inlined.
- **Consciousness** runs 0–100. At 0 the player passes out into a ragdoll and wakes up later.
- **Lethal damage:**
  - The player becomes **downed**: a corpse ragdoll in the `bleedout` state that holds the player's inventory and carried bones.
  - The player watches a dark screen with a bleed-out timer.
- **Corpse registry:** add on create, remove on `EntityRemoved` (P2). Decomposition beyond "despawn after N minutes" is deferred.
- **Leaving the downed state:**
  - **Revive:** a korpsman uses the corpse. This is a timed action (rule 6) and calls `Fates.Apply(ply, sameFate, {reason="revive"})`.
  - **Finish off:** someone uses a weapon on the downed body. This calls `Crime.Judge` (step 10), and the player becomes a ghost.
  - **Bleed-out timer ends:** the player becomes a ghost.
  - There is one revive function (R2).
- **Done when:**
  - A bot shot down can be revived with its inventory intact, or finished off.
  - The corpse loop never calls `FindByClass`.

### Step 8: Inventory and items

- **Item definitions:** keyed by id. `Items.Get(id)` is O(1) (P7).
- **Inventory:** stored as a server-side **map `{itemId → count}`**.
  - The owner gets a delta message on change.
  - Weight is cached and recalculated on add and remove.
  - Carry limit = base + `fate.CarryBonus` + items' `CarryAdd`.
- **Persistence:** inventory is not persistent, as in the original. It belongs to the character's life and drops to the corpse on death.
- **Starting set:** about 10 items to start: bread, water, scrap, medical tools, the baton, the pistol and permits.
- **Done when:** pick up, drop and use work, the weight limit holds, and the corpse holds the dead player's items.

### Step 9: Economy (bones, taxes, treasury)

- **Bones** are a persistent OWNER field. `Econ.Pay(ply, amount, source)` and `Econ.Charge(ply, amount, source)` use the batched DB writes.
- **Taxes:** `Econ.Tax(amount, kind, ply)` keeps the original's split (labor, sales, sanitar = 100 − avg).
  - Tax goes into the treasury.
  - Rates and the treasury are PUBLIC world state stored in the `world` table.
  - Fix the precedence bug B11.
  - Tax evasion is deferred.
- **Treasury payouts** (scheduled every 30 s): 20% of the treasury goes to the Kaiser. If there is no Kaiser, it stays in the treasury.
- **Sanitar pay:** every 300 s the Kaiser's Think pays sanitars from the treasury.
- **Done when:** a prole sale moves bones into the treasury, the Kaiser receives payouts, and reconnecting keeps balances.

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
- **Done when:** each rule fires in a scripted bot scenario, and wanted status counts down only while out of sight.

### Step 11: The fates

Build them in this order, so each one has something to act on.

1. **Prole**: the economic base.
   - Kit: `permit_tool` and a random scrap item. Worse aim (`AccuracyMulti 1.25`, `RecoilMulti 1.3`).
   - **Work loop (minimal):** a "work station" entity turns scrap into a product. Selling it pays bones through `Econ.Tax(…, "labor")`.
   - **Construction:** the C-menu `Build` places a factory site (25) or a crate (35). Validate placement range on the server.
   - Unions and WorkTitles are deferred.
2. **Korpsman**: the revive and healing loop.
   - Regenerates 3× faster.
   - Revive is the timed action from step 7. The fee is half the patient's carried bones.
   - **Surgery:** a small set of 2–3 procedures (heal, cure Pox, remove a bullet). Each is a timed action with a server-rolled failure chance; `autoFail` is never read from the client (B19).
   - `lovebox` heal tool: only after the Kaiser upgrade.
3. **Sanitar**: enforcement.
   - Police flag, radio, codename, baton and scope.
   - **Teeth** is an OWNER field, spent at a `sanitation_station` entity on weapons.
   - Can see wanted status and evidence summaries.
   - Slots: `Slots = function(pop) return math.Clamp(2 + math.floor(pop / 10), 2, 6) end`.
4. **Kaiser**: the head of state.
   - 1 slot, needs Kaiser rank, costs 5 stem cells, 75 armor, the novoluger pistol and the strategy book.
   - **Tax panel:** sets labor and sales rates; both start at 15 on spawn.
   - **Sentence and forgive:**
     - Both are validated receivers: target valid, alive, not a ghost, in range or visible.
     - Forgiving an economic crime costs 300.
   - **Upgrades:** **one** receiver `nKaiserUpgrade(targetFate)` reading a data table `{prole = 125, korpsman = 150}` (R3).
   - **On death:** taxes go to 50% with a global announcement and a 600 s cooldown for the role.
5. **Slave**: probation for new players. It is a Prole with restrictions, so build it as a variant of the Prole definition: `Fates.Define("slave", {Base = "prole", ...})`.
   - **Who:** every Foolish-rank player, and only them. Cost 0, unlimited slots, a short death cooldown (15 s, like Prole).
   - **Same as Prole:** the work loop, wages and labor tax, needs, inventory, and being revived by korpsmen.
   - **Different from Prole:**
     - Barcode name: `"<Drone|Serf|Peon…> #<last digits of SteamID>"`.
     - Slave model and clothing, plus a PUBLIC marker so everyone can see who is new.
     - Gets `weapon_cc_slave` (hands/tool only). **Can't deal damage to players**: a `Damage.Scale` hook zeroes it (from the original).
     - **Can't build Constructions.** New players can't spend bones on world objects.
     - **Can't be made wanted or collect evidence** (from the original). Killing a slave is still judged as murder of a citizen, so they are protected.
     - The corpse decomposes in 30 s.
   - **Leaving slavery** (both paths call `Rank.Free(ply, how)`):
     - **Survive a round:** at `Round.End`, every player who is a Slave, alive and not downed, and has been a Slave for at least `slave_min_round_time` (default 20 min of this round), is freed. Joining just before the round ends doesn't count.
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
  1. The prole works and pays tax.
  2. The Kaiser is paid and sentences the prole.
  3. The sanitar executes the prole and earns Teeth.
  4. The korpsman revives someone for a fee.
  5. A fresh account joins as a Slave, works for wages, can't hurt anyone, and is freed by a commendation. A second fresh account is freed at the end of the round.

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
  - Each one spent gives 25 bones.
- **Ranks:**
  - Foolish, Friend, Kapitan and Kaiser are enough for the core.
  - New accounts start at **Foolish**, which can only play Slave (step 11.5). Friend comes from `Rank.Free`.
  - Keep auto-promotion from Friend to Kapitan at the stem-cell threshold.
  - Admin ranks are separate from the game's ranks.
- **Rounds (minimal):** the slave rule needs a round end, and the original only had one through Doom (deferred).
  - `Round.Start` happens on map load.
  - `Round.End(reason)` fires when the round timer (`round_length`, default 3 h) runs out or an admin ends it. It frees surviving slaves, flushes the DB, shows an end screen, then changes level.
  - Doom, war and the Kaiser's fall can trigger `Round.End` later.
- **Done when:**
  - A new player starts as a Slave and is freed either by commendation or by surviving to `Round.End`.
  - The new player can then, over time, unlock and take the Kaiser fate.

### Step 14: Hardening and playtest

- **Audit every `Net.Receive`:** rate limit, sender checks and target checks (S1–S2).
- **Bot soak:** 30 bots cycling through fates for an hour. Watch the `sched_debug` costs, the net bytes per second and the DB flush time.
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
9. Rot, Doom and War.
10. Potentials and antagonists.

## Dropped outright

- `fedhoria`, gprofiler, `replicate` and the old module loader.
- Hogmode, `SpawnerThink` and copy-pasted resource spawners.
- Hard-coded SteamIDs.
- Text-file persistence.
- mysqloo.
