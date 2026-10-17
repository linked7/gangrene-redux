# Net receiver audit (step 14)

Every client-to-server message goes through `Net.Receive` in `gamemode/core/sh_net.lua`. Before a handler runs, the wrapper checks:

- that the sender is valid;
- a per-player token bucket (`rate` per second, burst twice that);
- `alive` (alive and not a ghost), `ghost` and `fate` (`ply:FateHas`);
- `target`: one entity read first, which must be valid, a player when asked, and within `range` when given.

The handler then checks the payload, usually by calling a server function that tests also call directly.

Guards added in this audit:

- **No raw receivers.** `tools/check_syntax.sh` fails on any uncommented `net.Receive(` outside `core/sh_net.lua`.
- **Opts are required.** A server `Net.Receive` without an opts table errors at load.
- **Registry.** `Net.Receivers` and `Net.Pools` list every receiver and pooled name. The `step14a` test checks that every entry in GMod's `net.Receivers` came through `Net.Receive` with a rate.
- **GMod's own receivers.** The base libraries' `properties` and `editvariable` receivers are wrapped with `Net.Adopt`, so they get the same rate limit (2/s). They were already closed by the base gamemode: `GM:CanProperty` returns false, and `GM:CanEditVariable` is admin-only.
- **Helpers.** `Net.ReadString( max )` returns nil for a string over `max` (default 64). `Net.Finite( n | Vector )` rejects NaN and infinities, which would otherwise pass every `>` range comparison.

Server-to-client messages (`gr_hello`, `gr_state`, `gr_notify`, `gr_chat`, `gr_inv`, `gr_world`, `gr_crime_evidence`, `gr_kaiser_ledger`, `gr_announce`, `gr_round_end`) have no server receiver and are out of scope.

## Receivers

| Receiver | File | Wrapper checks | Payload checks in the handler or the function it calls | Fixes made |
|---|---|---|---|---|
| `gr_ready` | core/sh_net.lua | rate 1 | no payload; only runs once per player (`GR_Ready`) | none |
| `gr_build` | systems/sh_build.lua | rate 1, alive | `kind` must be in `Build.KINDS`; must hold a `Builds`-tagged item; spot within `Build.RANGE` of the eyes and in sight; cost paid with `Econ.Transfer` | kind read with `Net.ReadString`; non-finite spot refused (a NaN vector passed both distance checks and reached `SetPos`) |
| `nKaiserSentence` | systems/sh_kaiser.lua | rate 2, alive, fate `CanSentence`, target player | `canJudge`: re-checks the fate, target is a living non-ghost other player, in `Kaiser.RANGE` or in sight; level is a 2-bit uint that must be in `Kaiser.SENTENCES` | none |
| `nKaiserForgive` | systems/sh_kaiser.lua | rate 2, alive, fate `CanSentence`, target player | `canJudge` as above; the price is moved with `Econ.Transfer` | none |
| `nKaiserUpgrade` | systems/sh_kaiser.lua | rate 2, alive, fate `Upgrades` | fate id must be a key of the sender's `Upgrades` table and a real fate; once per round; treasury pays with `Econ.Transfer` | id read with `Net.ReadString` |
| `nKaiserLedger` | systems/sh_kaiser.lua | rate 1, alive, fate `RunsEconomy` | no payload | none |
| `gr_inv_use` | systems/sh_inventory.lua | rate 4, alive | item index must be in `Items.ByIndex`; must hold at least one; `OnUse` re-checks its own conditions | none |
| `gr_inv_drop` | systems/sh_inventory.lua | rate 4, alive | item index must be in `Items.ByIndex`; count is floored and clamped to what is held; less than 1 is refused | none |
| `gr_counter` | systems/sv_econ.lua | rate 4, alive, target entity, range `Econ.COUNTER_RANGE` | target class must be `state_stockpile`; action is a 2-bit uint in `COUNTER_*`; good must be in `Econ.GOOD_DEFAULTS`; Withdraw re-checks `FateHas( "StockpileAccess" )`; reserves, ration limit and bread-line cooldown are applied | good read with `Net.ReadString` |
| `nKaiserEcon` | systems/sv_econ.lua | rate 4, alive, fate `RunsEconomy` | `Econ.KaiserSet` re-checks the fate; `ValidateSetting` requires a schema key and a whole number between min and max (NaN fails the whole-number test, ±inf fails the bounds) | key read with `Net.ReadString` |
| `nKaiserGrant` | systems/sv_econ.lua | rate 4, alive, fate `RunsEconomy`, target player | re-checks the fate; target alive and not a ghost; amount is a uint24 moved from the treasury with `Econ.Transfer` | **refuses a grant to oneself.** The Kaiser could pay themselves from the treasury, which the backlog rules out ("no self-enrichment", "no pocket withdrawal") |
| `nKaiserFine` | systems/sv_econ.lua | rate 4, alive, fate `RunsEconomy`, target player | re-checks the fate; target alive, not a ghost and not the sender; in `Econ.FINE_RANGE` or in sight; amount clamped to the target's bones | none |
| `gr_interact` | systems/sh_interact.lua | rate 4, alive, target any, range 400 | the id must be registered; `Interact.Run` re-runs that option's `range` and `show( ply, ent )` on the server before `run` | id read with `Net.ReadString` |
| `properties` (GMod) | lua/includes/modules/properties.lua | rate 2 (`Net.Adopt`, systems/sv_admin.lua) | the base `GM:CanProperty` returns false | adopted behind the rate limit |
| `editvariable` (GMod) | lua/includes/extensions/entity.lua | rate 2 (`Net.Adopt`) | the base `GM:CanEditVariable` is admin-only | adopted behind the rate limit |

## Interact options (all reached through `gr_interact`)

| Option | File | `show` (re-checked on the server) | `run` |
|---|---|---|---|
| `inspect` | systems/sh_police.lua | `FateHas( "Police" )`; target is a living non-ghost other player | `Police.Inspect` |
| `arrest` | systems/sh_police.lua | Police; on the server the corpse record must be unconscious or bleeding out, with a valid owner | `Police.Arrest` |
| `station_<item>` | systems/sh_police.lua | Police; target class `sanitation_station` | `Police.Buy` with a fixed offer |
| `commend` | systems/sh_rank.lua | target is a slave; sender is not a ghost | `Rank.Commend` re-checks everything: rank, range, once per round |
| `surgery_<proc>` | systems/sh_medicine.lua | `FateHas( "Surgeon" )`; target is a living non-ghost other player | `Medicine.StartSurgery` |
| `lovebox` | systems/sh_medicine.lua | `FateHas( "Lovebox" )` and upgraded; target is a living non-ghost other player | `Medicine.Lovebox` (has a cooldown) |
| `press_work` | systems/sh_crates.lua | class `ration_press`; not a ghost | `Crates.Work` |
| `crate_open` | systems/sh_crates.lua | class `ent_crate`; not a ghost | `Crates.Open` |
| `stockpile_pry` | systems/sh_crates.lua | class `state_stockpile`; not a ghost; no `StockpileAccess` | `Crates.StartPry` (an Action) |
