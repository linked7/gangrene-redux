# Corpse rotting and recycling in the original (research notes)
Source root: /home/deck/Documents/liverfailurewar/ (paths below relative to it).
Scope: corpse rot only. sh_rot.lua (global Rot pressure 0-100, rituals) and Doom are OUT of scope.

## Corpse state (NW ints/bools on the ragdoll)
corpse, alive, bleedout, fate, lootid, decompose (1-5), decomposestart, decomposefinish, recyclebones.
Created at gamemode/liverfailure-modules/framework/sh_consciousness.lua:360-395.
- decompose=1, decomposestart=now, decomposefinish=now+60 (decaytimer).
- Fates[fate].DecayOverride replaces 60 (kidney_crusader.lua:30 = 20). Slave = 30.

## Stage timings (framework/sv_think.lua:960-1100)
When CurTime() >= decomposefinish: decomp = min(4, decompose+1) (stage 5 only via fire).
Stage 1 fresh: 60 s (fate override). Each later stage lasts 120 s.
Replacement ragdoll model per new stage:
- 2: models/player/zombie_fast.mdl (bloated/early rot)
- 3: charple.mdl
- 4: skeleton.mdl (terminal; finish = math.huge)
- 5: Humans/Charple02-04 (burnt; only by fire)
New ragdoll: COLLISION_GROUP_WEAPON, decomposefinish = now+120, recyclebones = floor(old*0.75),
copies Inventory, AutopsyInfo, fate, lootid, harvested, molested; alive=false; head bone scale 0 if headless.
Sound on stage change: ambient/creatures/flies1-5.wav. Physics frozen 1 s then re-enabled (settles pose).
Zombifying / haunted player corpse at stage 2 becomes fate zombie (npc/fast_zombie/fz_alert_far1.wav) - fate system, not built here.
Fire: sv_think.lua:111 burning check on decompose<2; burned non-bleedout corpse jumps to stage 5.
Bleedout (still dying) corpses never rot; they bleed (BleedUp) instead.

## Effects on players
No disease aura, no spread found. Only: a COP who submits a corpse to the washer gets +2 despair (morguewasher.lua).
Examine text per stage: sv_context.lua:664-669. HUD: cl_hud.lua:2063-2200 shows a rot progress bar
(CurTime()-decomposestart over finish-start) and stage word (decompose+1 index) above the corpse,
quirk-dependent lines (necromance, cannibalism, death fetish) - quirks out of scope.
Own-corpse HUD while dead: cl_hud.lua:1186-1201, 3891-3903.

## Bloaters (sv_think.lua:1210-1240)
Every 600 s a random corpse with decompose>=4 is removed, effect cc_rotgas plays, a "bloater" NPC spawns, barnacle_die2.wav.
Bloater NPC = out of scope (report only).

## Recycling
Done by MACHINES, not hands.
### morguewasher (entities/entities/morguewasher.lua:55-195) - the recycler
- Input: corpse touches it. Needs corpse=true, not bleedout, not Washed, machine not busy.
- Submitter must be a living cop (CanPolice).
- Reward val = clamp(recyclebones, 30, 500), taxed (TaxThis "sanitar"); max 150 paid, overflow to RecycleBonesStorage
  (sv_think.lua:1113-1206; leader gets it as "Recycled Income", decays x0.9 per tax cycle).
- Cop cut = floor(reward/4)+30 to the rewarded cop.
- Clean time math.random(28,32) s; loop sound ambient/levels/canals/toxic_slime_loop1.wav, start sizzle toxic_slime_sizzle1-4.
- Effect VortDispel scale 0.5 at end. Biomass += 5 - decompose (clamped).
- Inventory items: contraband -> contraband reward (max 200) + stock; useful items -> half price recycled (max 200) + stock;
  materials/fuel/organs eject at WasherOutputPos 2 s apart.
- Dead fake player respawned; corpse removed.
### morgueanalyzer (morgueanalyzer.lua:130-150): madscientist only, val = 20+(decompose-4)*-5, marks Washed.
### fertmaker (fertmaker.lua:120-160): battery reward 30+(decompose-4)*-5, gibs by stage (cc_gored). Evidence "body farming".
### Other consumers: weapon_cc_hands.lua:139-174 (thug loot 5-15 recyclebones), ray_decay (advance), vampire (<2 only).

## Forced rot
sv_doom.lua:89, fates vampire.lua:110, ray_decay:147 set decomposefinish = CurTime().

## Decisions for the remake
- One Sched.Every job over the corpse registry; stage by timestamps; stage 1 60 s, stages 2/3 120 s, 4 terminal.
- recyclebones = floor(prev*0.75) per stage, floor of corpse bones at death for stage 1.
- Recycler pays through Econ.Transfer (treasury -> player), bones in a corpse go to treasury when removed.
- Left out: bloater NPC, zombie fate, fire stage 5, quirks, analyzer/fertmaker, RecycleBonesStorage tax overflow.
