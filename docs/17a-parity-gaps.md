# Step 17a: parity gap list (docs/05 §7–§14, gameplay and server only)

This audit leaves out the client HUD, screen effects, menus, chat box drawing, fonts, footsteps, music and ghost visuals (§1–§5, §11, §13). The UI worker owns those.

## Already done before 17a
| Item | Where |
|---|---|
| Chat ranges, LOOC/OOC, radio refusals, dead and downed speech, kill sentences, thoughtcrime, AutoGrammar, babble, gestures | `systems/sh_chat.lua` |
| Holster (B, Use+Reload), MovementMult and no sprint, 115 kg holstered pickup, spread (bug kept), Recoil/AccuracyMulti, heavy swings and block, MeleeResistScale, head burst, shove | `systems/sh_weapons.lua`, `weapon_gr_base` |
| Leg-shot jump lock, no jumping while reloading, frozen, jumping cancels surgery, dragging with a 128-unit snap, third person | `systems/sh_movement.lua` |
| Ghost rules: no damage, no pickup, only fate stations usable, invisible to the living, no footsteps | `systems/sh_ghost.lua` |
| Verbatim fate descriptions (Korpsman, Ghost, Slave) | `fates/*.lua` |

## Gaps found, closed in 17a
| # | Item | Was | Now |
|---|---|---|---|
| 1 | Wanted big line: "TORMENT/JUDGMENT/DEATH to X for Y!", 3 alarms, +1 Despair, "You should hide for …" | missing | `systems/sh_crime.lua:89` (`Crime.Announce`), shouted only when the news makes things worse |
| 2 | Get-up / revive area line "X gets up." (1 in 10 special lines), jump.wav | missing | `systems/sh_parity.lua:94` |
| 3 | "Got/Lost N Bones" notices | missing | `sv_econ.lua:130` hook, `sh_parity.lua:75`; sent on net `gr_notice`, which the HUD can take over through `GR_Notice` |
| 4 | Call Korpsman (50 Bones): refusals, alert sound, big line, pay on full heal | missing | `sh_parity.lua:112`, `sh_medicine.lua:203,221` (`GR_Treated`); net `gr_call_korpsman` / concommand for the context menu |
| 5 | Spit side effects: despair cap at 80, Kaiser's 8-despair spit and line, evidence for spitting on the Kaiser (300 s) or a sanitar (180 s), a 5% chance to put out a fire | partial | `sh_weapons.lua:233`, `sh_crime.lua:229`, `fates/kaiser.lua` (`SpitDespair`, `SpitLine`) |
| 6 | Unholster warning for poor shots (AccuracyMulti > 1): sound, "X prepares to fire!", 1.5 s fire delay, 3 s cooldown | missing | `sh_weapons.lua:165` hook, `sh_parity.lua:155` |
| 7 | Ghosts on TEAM_SPECTATOR, the living on TEAM_CITIZEN | missing | `sh_parity.lua:12,53` |
| 8 | `resource.AddWorkshop("3067207405")` | missing | `sh_parity.lua:38` |
| 9 | Pain grunts (fate `PainSounds`, else default grunts by hit area, 1–3 s cooldown) | missing | `sh_parity.lua:183-196`, `core/sh_fates.lua` schema |
| 10 | Death screams on going down (not after a head hit) and at final death (not with `NoFinalDeathSound` or when headless) | missing | `sh_parity.lua:199,208`, `sh_corpse.lua:231` (`GR_CorpseDied`) |
| 11 | Fate intro texts (`IntroTexts`, told on "pick") | missing | `sh_parity.lua:217`, `fates/*.lua` |

## Closed by plan decision (Feature Creep)
- No gun-ban fate key. Slaves have full Prole parity (step 11.5).
- No injury levels 1 and 2. Step 7 keeps only `Injured` (×1.3 spread).

Test: `gamemode/tests/sv_step17a.lua` (bot prefix `t17a_`).
