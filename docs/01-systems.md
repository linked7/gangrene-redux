# Liver Failure: systems record

These notes cover the gamemode as it stands in `gamemode/`. It also goes by Industrial Nightmare 3, Industrial Nightmare War and Gangrene Homefront.
Paths are relative to `gamemode/`. `LM/` means `gamemode/liverfailure-modules/`.

## 1. Shape of the codebase

| Area | Where | Size / notes |
|---|---|---|
| Boot | `init.lua`, `cl_init.lua`, `shared.lua` | Derives from **sandbox**. `GM:Initialize` sets convars, then calls `InitSQL`, `LoadBans` (again every 60 s), `LoadStocks`, `LoadWar` and `LoadWorkOrders`. |
| Loader | `loaderconfig.lua`, `module.lua`, `moduleloader.lua` | Each module folder has a `module_<name>.lua` descriptor. Files load by `sv_`/`sh_`/`cl_` prefix. The author calls it "the most overkill thing I've written". |
| Modules | `LM/*` | books, burdens, config, fates, fedhoria (ragdoll physics), framework, gprofiler, gui, items, logging, maps, mutations, objectives, potentials, races, replicate, rituals, soup, sql, surgeries, utilities, war. `loaderconfig` also lists a `statuses` module, but that folder doesn't exist. |
| Content | `entities/entities`, `entities/weapons` | About 200 entities and about 167 weapons. |
| Hot files | `LM/framework/player/sv_player.lua` (4060 lines), `LM/framework/sv_think.lua` (1703), `LM/framework/chat/sh_chat.lua` (1689), `LM/burdens/sh_burdens.lua` (1275), `shared.lua` (832) | Most of the game logic sits in a handful of giant files. |

## 2. Player lifecycle

```
connect ─► PlayerInitialSpawnSafe (bird model, noclip, waiting for SQL)
        ─► client sends nRequestPData ─► LoadPlayer(data): rank, stem cells, money, curses, bans, max-player kick
        ─► PlayerSpawn ─► always GHOST unless ply.reviving
GHOST ──use purpose_in_life / potential──► BecomeFate(f) ─► alive as a fate
alive ──damage──► consciousness 0 ─► PassOut (ragdoll clone)
      ──lethal──► DeathRagdoll + "bleedout" (downed corpse, can be revived)
           ├─ korpsman revive / DoRevive / BleedUp ─► same fate, keeps inventory and bones
           └─ finished off (GM:FinishOff) ─► GM:Judge (crime, stem and despair penalties) ─► GHOST
corpse ─► decomposes in stages (zombie → charple → skeleton → bloater)
```

- **Ghost** (`LM/fates/list/ghost.lua`):
  - No inventory and no collision. Has a *Suffering* meter.
  - Can haunt corpses and props. Can talk in OOC, and can't talk at all if cursed.
  - `OnSpawn` resets dozens of networked vars by hand. It also contains a hard-coded SteamID and a "DyingPrapor" hack.

## 3. Fates (roles)

Each fate is defined in `LM/fates/list/*.lua` as a `FATE` table, collected into `GM.Fates[id]`.

| Field / hook | Purpose |
|---|---|
| `Name`, `Description`, `IntroTexts`, sounds | Presentation |
| `Limit`, `DynamicLimits` | Slot count, which can scale with population |
| `Cost` | Stem cells spent to take the fate. Each one spent also gives 25 bones. |
| `DeathTimer` | Cooldown after dying as this fate |
| `Faction`, `Authority` (`AUTH_LEADER`…), `Police`, `Radio` | Social and legal standing |
| `ModelFunc`, `BodyFunc`, `SubmatFunc`, `HandsFunc` | Appearance |
| `OnSpawn`, `OnRevive`, `OnChange`, `OnDeath`, `FinishOffFunc`, `Think`, `Verify` | Behaviour hooks |

There are two ways in:

- **`purpose_in_life`** (`entities/entities/purpose_in_life.lua`) is a fixed station for one fate. Its `Use()` checks, in order:
  1. rank and insight
  2. `Verify`
  3. stem-cell cost
  4. `Limit` / `DynamicLimits`
  5. the per-fate death timer
  6. CountMax
- **`potential`** (`entities/entities/potential.lua`, `LM/potentials/`) is a timed group spawn of special fates: evil, party, refugee, gangrene, Kidneystan (Prohlada) or Arrhythmia (Rottingham).
  - It is weighted by rank, ghost count, rot level and population.
  - Ghosts browse potentials in the F2 fate menu (`sh_fatemenu.lua`), whose ENVISION button teleports them there.
  - **The remake doesn't need potentials.**

`BecomeFate` (`LM/fates/sh_fates.lua:246`) runs these steps:

1. `ResetScales`, then `SetFate`.
2. The old fate's `OnChange`.
3. The new fate's `OnSpawn`, then `ModelFunc`.
4. Set faction, then `InitializeBurdens`, `ResetOrgans` and `Citizen`.
5. `timer.Simple(0.05)`: race, body and submaterials.
6. Bonemerge torso/legs clothing.
7. `timer.Simple(0.1)`: broadcast `nSendBonemerge` with `WriteTable`.

`ReviveFate` (`:16`) is a near-copy of the same sequence.

### The four fates being kept

| | **Kaiser** (`kommandant.lua`) | **Sanitar** (`sanitator.lua`) | **Prole** (`proletariat.lua`) | **Korpsman** (`korpsman.lua`) |
|---|---|---|---|---|
| Slots | 1 | 2, scaling to 6 | unlimited | 2, scaling to 5 |
| Cost | 5 stem cells, plus rank `RANK_KOMMANDANT` | 2 | 1 | 1 |
| Authority | `AUTH_LEADER`, faction LF | Police, faction LF, radio, random codename | Citizen worker, random worker name | Citizen medic |
| Kit | 75 armor, novoluger pistol, war-strategy book | Baton and scope. Earns **Teeth** (an NWInt) for executing death-wanted criminals and spends them at sanitation stations. | `permit_tool`, a random scrap item, worse recoil and accuracy | Regenerates 3× faster. Surgery: fail chance 10, multiplier 1.25. Gets the `lovebox` heal tool only after the Kaiser buys the upgrade. |
| Verbs | Sets labor and sales tax (both 15 on spawn). **Sentence** (`nSentence` makes the target wanted for 300 s for "offending the Witch Kaiser", type 1–3). **Forgive** (`nForgive`; economic crimes cost 300). Buys upgrades: prole 125, korpsman 150, butcher 150, foreman 400. | Arrests, beats or executes wanted players. Sees evidence. | `nConstruct` builds a factory site (25) or a crate (35). Has unions/gangs and WorkTitle perks. | Revives the downed and takes half the patient's carried bones as a fee. Performs surgeries. Being mugged makes them drop blood. |
| Think / death | Every 300 s collects bourgeoisie tax and pays each sanitar health/4. On death taxes go to 50% with a global announcement. | | | |

## 4. Meta-progression

- **Stem cells** are the persistent currency, from 0 to 666 (`meta:AddStemCells`, `sh_player.lua`).
  - Fates cost stem cells.
  - Unjust kills take them away: −1 for an ordinary unjust kill, −10 for killing your own faction, −666 for killing your own leader.
  - A despair heart attack also costs one.
  - Losing the last one with `punishment` adds 50 despair.
- **Ranks** run Foolish → Friend → Kapitan → Liaison → Kaiser → Lockmaster → Necromancer.
  - Friend is auto-promoted to Kapitan at `KapitanRankCost` stem cells.
  - Foolish players are forced into the **Slave** fate (`fates/list/slave.lua`):
    - Barcode name ("Drone #1234…"), respirator and helmet, and the `weapon_cc_slave` hands.
    - Can't use weapons or harm others, and can't be made wanted or collect evidence.
    - The corpse decomposes in 30 s.
    - The intro tells them to find a Liaison who will teach them.
  - **Leaving slavery:** only the **trainer** fate could free a slave, with the context-menu `nCAscend` (`LM/framework/contextmenu/sv_context.lua:699`).
    - Ascending kills the slave and sets their rank to Friend.
    - It pays +1 stem cell to the slave, and +10 stem cells and 300 bones to the trainer.
    - It pays 100 bones to the Kaiser.
  - **Banishing:** the trainer could instead use `nCBanish` to ban the slave for 1 day.
  - **Rounds:** a round ends when the city hits Doom (`LM/framework/sv_doom.lua`). That means an end screen, a wipe, and a changelevel 2 minutes later.
  - Higher ranks gate fates and admin tools: the physgun/toolgun by trust, and noclip only for Necromancer.
- **Insight** is a set of thresholds derived from stem cells (25…666) that unlock fates.

## 5. Needs ("burdens") — `LM/burdens/sh_burdens.lua`

| Need | Effect |
|---|---|
| Emptiness (hunger) | Slows consciousness regeneration. High values hurt. |
| Dryness (thirst) | Hurts when high. |
| Despair | At 100: heart attack, death, and −1 stem cell. Rises from crimes, witnessing murder and failures. |
| Pox (sickness) | Lowers max HP. |
| Regen, Urine | Healing rate, and a bladder meter. |

- **Quirks:** about 40 weighted personality traits, rolled on fate spawn.
  - Some quirks restrict which sources may reduce a need (`DespairConQuirks`, `EmptinessConQuirks`, `PoxConQuirks`).
  - Some apply proximity effects to nearby players.
- **Also in this file:** parasites, organs (heart, liver, brain and eyes, with effects when missing), injuries (`:1105+`) and mutations.
- Each need has its own `Add<Need>(amt, source|max, max, ignorequirk)` function. The five copies are almost identical.

## 6. Health, consciousness, death — `LM/framework/sh_consciousness.lua`, `sv_player.lua`

- **Consciousness** runs from 0 to 100.
  - `TakeCDamage` lowers it; armor multiplies the damage by 0.75.
  - At 0 the player passes out: they turn into a ragdoll clone, become invisible and lose collision.
  - `ConsciousThink` regenerates 1 point every 0.3 s to 1.3 s, depending on Emptiness.
- **Damage:** `GM:EntityTakeDamage` is about 1100 lines (`sv_player.lua:932–2055`). `GM:ScalePlayerDamage` (`:2998`) carries a "refactor ASAP" comment.
- **Death:**
  - `DoPlayerDeath` is about 930 lines (`:2055–2988`).
  - `DeathRagdoll` makes a "bleedout" ragdoll that holds the player's inventory and bones (`recyclebones`).
  - It sends `nTotalDarkness` and a random last-thought line.
- **Revive:**
  - `meta:DoRevive(doctor)` (`:649`) is used by korpsmen and sets 10 HP. The doctor takes half the bones, or all of them if the doctor is a thug.
  - `GM:BleedUp` (`:592`) is a second near-identical revive path, used for self-recovery.
- **Finish off:** `GM:FinishOff` (`:768`) does the following:
  - Sells the victim's doors.
  - Scares nearby players: they gain despair, unless they have the "violent impulses" quirk.
  - Calls **`GM:Judge`** (`:912`), a hand-written decision tree that compares the attacker and victim by citizenship, faction, authority, police status, wanted type, gang and quirk. It names the crime (murder, policide, high assassination, lethal betrayal…), makes the attacker wanted and docks stem cells and despair.
  - The decision tree also awards sanitars Teeth for killing death-wanted criminals.

## 7. Crime and police — `LM/framework/player/sh_player.lua`

- **Wanted state:**
  - `MakeWanted(length, why, type, ptime)` (`:1491`). The types are 1 = TORMENT (beating), 2 = JUDGMENT (prison) and 3 = DEATH.
  - It broadcasts a big chat line and adds 1 despair unless the player is evil or cursed.
  - The fields are `Wanted`, `WantedSince`, `WantedUntil`, `WantedType`, `WantedReason` and `WantedPTime`.
  - Wanted status only expires while no police can see you; this uses CanSee traces in `sv_think.lua`.
- **Evidence:**
  - `AddEvidence(length, why, type)` (`:1540`) stores latent crimes as a table `why → {length, expires, type}`.
  - Police can act on evidence. Ghosts, slaves and the Kaiser are immune.
- **Police roles:** `CanPolice()` (`:1040`) checks a `policeFates` lookup and that the player is alive. `IsHOS()` is the head-of-state set: foreman, sekretar, kapitan and kommandant.

## 8. Economy

- **Money** is "Bones". `meta:AddMoney(money, src, silent)` (`sh_player.lua:466`) writes the new value straight to SQL **on every call** and sends a notification.
- **Taxes** live in `LM/framework/sv_business.lua`:
  - There are three rates: Labor, Sales and Sanitar. `SanitarTax = 100 − avg(labor, sales)`.
  - `GM:TaxThis(amount, type, ply, evade)` splits a payment into a tax share and a payout. The tax share goes to `LaborTaxStorage`, `SalesTaxStorage` or `SanitarTaxStorage`.
  - Evaders (the "moralis" shroom, or an `evade` flag) keep everything but risk tax-evasion evidence, and the Kaiser is notified.
- **Tax flow:** every 30 s, `sv_think.lua:1113` drains 20% of each storage to the Kaiser, or to the Sekretar if there is no Kaiser.
- **Treasury and inflation:** the ATM pays 1% bonds, with inflation tiers.
- **Markets:** dealer stocks, illegal stocks and a police contraband stash.
  - Each change broadcasts the whole table with `WriteTable`.
  - Stocks persist to a text file (`CombineControl/stocks.txt`, a name inherited from CombineControl).
- **Production:** foreman work orders (`sh_foreman.lua`, `sv_foreman.lua`), factories and machines, prole constructions, and cooking (`sv_cooking.lua`).

## 9. Inventory and items — `LM/framework/sh_inventory.lua`, `LM/items/`

- The inventory is a flat Lua list of item-ID strings. The weight limit is 20 plus bonuses from upgrades, fate-name substrings, a shroom, mutations and `CarryAdd` items.
- Inventory is **no longer saved** (`SaveInventory` is commented out), so it only lives as long as the character. On death it moves to the ragdoll.
- Items are defined in `LM/items/list/*`. `GM:GetItemByID` (`sh_items.lua:258`) is a **linear scan** over all items.

## 10. Chat and radio — `LM/framework/chat/sh_chat.lua`

- **Commands:** local chat, yell, whisper, `/me`, `/it`, OOC, LOOC, admin, PM, radio, event, advertise, invite and help.
  - Speech passes through `ModifySpeech`, `AutoGrammar` and `RacialQuirks`.
  - Hearing range comes from `GetRF` (range filter).
- **Radio:** `CC.CanRadio` checks the fate's `Radio` flag, then a hard-coded list of fate names, then a gang radio.

## 11. Surgery — `LM/surgeries/`

- **Validation:** `SurgeryValid` and `SurgeryFailChance` (fate base + tool + patient). Each procedure has `Steps`, a `Time`, `Success`/`Failure` callbacks and `ConsumesTool`.
- **Running a surgery** (`sv_surgery.lua`):
  - Freezes both players.
  - Shows staged progress bars, driven by a chain of `timer.Simple`.
  - Rolls for failure at the end.
- **Outcomes:**
  - Failure damages the patient, adds despair to the doctor and may lose the tool. Botching a police or LF patient leaves malpractice evidence.
  - Success heals the patient by 1 HP per step.

## 12. Persistence — `LM/sql/sv_sql.lua`

- The database is MySQL through `mysqloo`, using the `cc_players` table and others built by `InitSQLTables`.
- Every write is its own `UPDATE … SET field = '…' WHERE SteamID = '…'` (`UpdatePlayerField`, `:355`).
- `SQLThink` is empty.
- Bans are reloaded every 60 s.
- Stocks, war and work orders persist to text files.

## 13. Networking

- **`GM.PlayerAccessors`** (`sh_player.lua`) has about 110 entries of `{name, private, type, default, bits}`.
  - Each entry generates a getter, a setter and a dedicated `nSet<Name>` net message.
  - Public entries are broadcast to everyone, including every need value; table entries use `WriteTable`.
- **`SyncAllData` / `SyncAllOtherData`** (`:205`, `:226`) send one message per field per player when someone joins.
- **Two more systems run in parallel:** stock GMod `SetNW*` vars (used for Teeth, shroom, bleedout and upgrades) and a custom `LM/replicate` library.

## 13b. Nations and races (code name → lore name)

| Code | Lore |
|---|---|
| `FAC_LF`, "LF", "Liver Failure" | **Gangrene** (the Witch Kaiser's state) |
| `arrhythmian`, `POTTYPE_ARRHYTHMIA`, `rottingham_*`, `duke` | **Rottingham**. Race **Rottish**. Ruled by the corpse-king King Rottingham, and after the war by the Duke of the UR paramilitary. |
| `kidneystani`, `POTTYPE_KIDNEYSTAN`, `kidney_*`, `kommissar` | **Prohlada Union**. Race **Prohladian**. Ruled by a council of kommissars, and before that by Grozny the Terrible, a winter-lich. |
| race `liverman` | **Gangral** |
| race `skinless` | **Skinless** (stateless or undisclosed) |
| race `outsider` | **Outsider**: close kin of the Gangral who often live outside the main city, with no nation. Local migrants and cultists were Outsiders. |
| race `unimportant` | Not a race: a placeholder that shows no race |

- **Race code:** races are defined in `LM/races/list/*.lua` (`RACE.Name`, hands, speech mangling via `RacialQuirks`, and accent-letter tables in `LM/races/sh_races.lua`).
- **How fates use races:** each fate picks one from `FATE.RaceWeights`.

## 14. World simulation (out of scope for the core, recorded for completeness)

- **Weather:** a cycle with night every 15 min, plus yellow and meat weather.
- **Corpses:** decomposition stages, and bloaters.
- **Spawners:** about 10 resource spawners (boulders, trees, amoebas, capsules, wasteland metal…).
- **Faction systems:**
  - **Rot / Doom:** a city decay meter with end states (`DOOM_DYING`, `DOOM_DEAD`).
  - **War:** against Prohlada (code: Kidneystan) and Rottingham (code: Arrhythmia), with ceasefires and war machines (`LM/war`).
  - **Other systems:** Hogmode events, rituals, cults, gangs/unions, mutations, parasites, organs, races, objectives and the "prapor" contraband missions.
- All of this ticks from one function, `GM:Think` in `LM/framework/sv_think.lua`. Pitfall P-PERF-1 covers it.
