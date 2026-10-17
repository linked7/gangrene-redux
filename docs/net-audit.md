# Net.Receive audit (plan step 14, pitfalls S1/S2)

Every client->server message goes through `Net.Receive` (sh_net.lua): a token bucket per player and
name (burst 2x rate), then the `alive` / `ghost` / `fate` / `target` / `range` checks, then the
handler under xpcall. A raw `net.Receive` is banned by tools/check_syntax.sh and caught by the
step14a test. `Net.Receive` now refuses at registration a missing opts table, a rate <= 0, an unknown
`target` kind, or a `range` without a `target`. Test: `step14b` asserts every entry of
`Net.Receivers` has an explicit positive rate, a known target kind, and a range wherever it has a
target (exceptions below).

| Receiver | File | Opts | Reads | Verdict |
|---|---|---|---|---|
| gr_ready | core/sh_net.lua | rate 1 | nothing | ok; once per player |
| gr_take_fate | core/sh_fates.lua | rate 2, ghost | fate id string | ok; Fates.Request re-validates |
| nKaiserSentence | systems/sh_kaiser.lua | rate 2, alive, fate CanSentence, target player | player | ok; canJudge: living, not self, within 600 or Crime.CanSee |
| nKaiserForgive | systems/sh_kaiser.lua | same | player | ok; same |
| nKaiserUpgrade | systems/sh_kaiser.lua | rate 2, alive, fate Upgrades | upgrade id | ok; checked against the fate's Upgrades |
| nKaiserLedger | systems/sh_kaiser.lua | rate 1, alive, fate RunsEconomy | nothing | ok |
| gr_counter | systems/sv_econ.lua | rate 4, alive, entity, range COUNTER_RANGE | UInt 2, string | ok; class state_stockpile checked |
| nKaiserEcon | systems/sv_econ.lua | rate 4, alive, fate RunsEconomy | setting name, number | ok; ValidateSetting rejects NaN/inf/non-integer |
| nKaiserGrant | systems/sv_econ.lua | rate 4, alive, fate RunsEconomy, target player | player, UInt 24 | ok; treasury gift, self-grant refused |
| nKaiserFine | systems/sv_econ.lua | same | player, UInt 24 | ok; range 600 or visible, amount clamped |
| gr_valve | systems/sh_lunch.lua | rate 4, alive, entity, range 120 | string (<= 8) | ok; class and direction checked |
| gr_interact | systems/sh_interact.lua | rate 4, alive, any, range 400 | 2 strings | ok; goes through `allowed` |
| gr_inv_use / gr_inv_drop | systems/sh_inventory.lua | rate 4, alive | item index, count | ok; Items.ByIndex, count clamped |
| gr_holster | systems/sh_weapons.lua | rate 6, alive | UInt 2 | ok |
| gr_spit | systems/sh_weapons.lua | rate 4, alive | nothing | ok |
| gr_give_up | systems/sh_corpse.lua | rate 1 | nothing | ok; no `alive` on purpose, the sender is dying |
| gr_build | systems/sh_build.lua | rate 1, alive | kind string, Vector | ok; Net.Finite, RANGE, sight trace, cap, Econ.Transfer |
| gr_call_korpsman | systems/sh_parity.lua | rate 1, alive | nothing | ok |
| properties, editvariable | GMod, adopted in sv_admin.lua | rate 2 | engine | ok; GM:CanProperty off, edit is admin-only |

## Documented exceptions (target without range)

nKaiserSentence, nKaiserForgive: sight is enough, not reach. nKaiserGrant, nKaiserFine: money
moves through the treasury, reach is irrelevant (Fine checks its own range). All four
re-validate the target in their handler.

Client-only receivers (gr_state, gr_fx, gr_notify, gr_inv, gr_corpse, gr_world, gr_announce, and
others) are not reachable from clients.

## Admin (sv_admin.lua)

Kick, ban, set rank, set fate, noclip; staff only, every action logged under "admin". A player
(not the console) can't kick or ban themselves or other staff; reasons are cut to 120 characters.
Tests: step14a, step14b.
