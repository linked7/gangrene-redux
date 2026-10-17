# Liver Failure remake: UI, effects and feel parity

**Rule (decided 2026-10-17 by the user):** the remake's UI and effects must match the original Gangrene look and feel. The only exception is optimisation. An effect may be *implemented* differently, or offered as an option, if the original way is costly, but what the player sees and hears stays the same.

**Scope:** §1–§7 cover the UI and screen effects. §8–§14 cover the rest of the feel: speech and chat, weapon feel, wording, sound, movement, ghosts and controls.

- Paths below are relative to `gamemode/liverfailure-modules/`. Almost all of the HUD lives in `gui/cl_hud.lua` (3939 lines).
- **When to build each item:** with the step that adds the system it shows. Example: the needs bars come with Step 6.
- **Effects of deferred systems** (drugs, haruspicy, war, doom) come back with those systems.

## 1. Assets and fonts (match exactly)

- **Font family "Smash"** (`GM.FontFace`) for every `CombineControl.*` font.
  - Sizes: Window 14, LabelTiny 16, LabelSmall 20, LabelMedium 24, LabelBig 30, LabelGiant 36, LabelMassive 44, LabelStupid 60, ChatSmall 20, ChatNormal 24, ChatBig 32, ChatHuge 40, PlayerFont 17, HUDAmmo 50/30/15, WepSelectHeader 20.
  - Chat body uses **Verdana**. Radio uses **Lucida Console 16**.
- **Content:** models (`models/IN/...`, everyman), materials (vignette, hallucination overlays, clothes) and sounds (`placenta/...`: UI hover, speech, ascension, screams) come from the original content packs.
  - The active `resource.AddWorkshop` is only the magick-hand addon (2751041637). The rest are commented out in `config/sv_resource.lua`, so the real content collection was probably set on the server.
  - **Answered 2026-10-17 by the user:** the content pack is Workshop item 3067207405 (https://steamcommunity.com/sharedfiles/filedetails/?id=3067207405). Add it with `resource.AddWorkshop("3067207405")`.

## 2. HUD (`gui/cl_hud.lua`)

| Element | What it looks like | Original location |
|---|---|---|
| **Crosshair** | Three small squares orbiting the aim point, colour cycling through hue (`HSVToColor(CurTime()*23)`), drifting on a slow sine wobble. Radius shrinks to 5 while aiming (attack2) and grows to 15 while charging a heavy melee hit. It brightens and speeds up when hovering something usable. Hidden while scoped, and can be turned off (`cc_nocrosshair`). | `HUDPaint` ~3095–3145 |
| **Cross-texts** | Info about the aimed-at entity, drawn *under the crosshair*: plain lines, multi-line text, and labelled progress bars (240×28 dark box). Fades in and drifts sideways. Plays `placenta/ui/cross_hover.wav` on hover. All text goes through **Stutter**. | ~3165–3285 |
| **Weapon select** | Shown inside the cross-texts, not as a separate panel. Slot 1 dark red, slot 2 red, slot 3 rainbow. The selected weapon pulses magenta and is wrapped as `-name-`. Plays `placenta/ui/weapon_hover.wav`. | ~3146–3165 |
| **Status bars** | Top centre, 40% of screen width, the whole block drifting ±5 px on a sine. Bars lerp smoothly: health, Emptiness, Dryness, Despair, Pox, Regen, armor ("carapace"), Suffering (ghosts), urine and others. Colours are rainbow and pulsing. Special states replace the bars with stuttered big text, e.g. "CURSED". | `DrawHealthBars` 767–1283 |
| **Vignette** | A dark edge vignette that gets heavier indoors (a trace 512 up, once a second; alpha 100 outdoors, 235 indoors) and slowly breathes. | `HUDPaint` ~3030 |
| **Menu blur** | The background blurs in (lerped) while the player menu is open. | `HUDPaint` ~3018 |
| **Notifications** | A stacked list of short coloured lines ("Got 25 Bones", green or red), plus the **big red/green centre-chat lines** for global events ("DEATH to X for policide!"). | `DrawNotifications`, `nAddChatFont` |
| **Timed progress bars** | Bars for surgery, revive and building steps, labelled with the step text. | `DrawTimedProgress` |
| **Evidence / wanted** | Shows crimes and wanted type as TORMENT / IMPRISONMENT / DEATH. | `DrawEvidence` 2905 |
| **Ammo** | Large ammo counter (HUDAmmo fonts). | `DrawAmmo` 2313 |
| **World labels** | 3D2D and screen labels on entities within 1024 units (`HUDRender`/`Render3D2D` per entity), door names and owners, and "REBIRTH" over revivable bodies for medics. | `DrawEntities` 1471, `DrawDoors` |
| **Death / bleed-out screen** | Total darkness with a blur. In giant rainbow text: the last-thought line, then *"Eventually you will get up, assuming nothing finishes you off."*, then *"Speak 'MOTHER OF DEATH, I CALL ON THEE' if you wish to perish, instead."* (a chat phrase that gives up and dies). The text fades in very slowly and is stuttered while faint. | `DrawConsciousness` 582 |

### Stutter (signature text effect)

Every HUD string passes through `GM:Stutter` (`cl_hud.lua:1426`).

- Each character has a `1 + 5×despair%` chance to be upper-cased.
- At despair ≥ 50 it can instead be scrambled into `@#!$%^&*`.
- **The result:** text gets visibly more broken as the player despairs.

## 3. Screen effects (`RenderScreenspaceEffects`, 3778)

| Effect | Behaviour |
|---|---|
| **Constant bloom** | Always on, gently breathing on sines. This is the base look. |
| **Fate colour grading** | Each fate can define `ColorMod` (a table or a function) and `MotionBlur`. Ghost overrides the rest. |
| **Aberrations** | Every 90–300 s, a random colour-grade "aberration" kicks in for 1–3 s. |
| **Despair** | Sharpen jitter scaled by despair (plus Stutter, above). |
| **Low health** | Under 50 HP, motion blur grows as health falls. |
| **Poison** | Red and green colour shift that fades over the poison duration. |
| **Damage flash** | A red full-screen flash of 0.6 s on hit. |
| **Head wound** | Blur plus sharpen that decays. |
| **Frighten** | A full-screen hallucination image flash (random from `GM.Hallucinations`), a contrast spike, a ghost "become" sound and **DSP 28** audio distortion for 0.3 s. Variants are Jumpscare, Sotlascare and Clownscare (the latter two are deferred with the cults). |
| **Map colour filter** | A per-map `MapColorFilter`. |
| **Corpse view** | While dead, decomposition grading by stage (`DrawDecomposeEffects`). |
| **Weather particles** | `entities/effects/sw_*`: rain, snow, blizzard, sandstorm and acid rain, plus splashes. |
| **Gore and particles** | `cc_blood`, `cc_gored`, `cc_gunsmoke`, `cc_spit` and others in `entities/effects/`. Surgery sprays blood. |
| *(Deferred)* | Haruspicy and autostitcher psychedelic modes, drug visuals (`framework/drugs/cl_drugs.lua`), rot gas, and the doom end screen (`cl_doom.lua`). |

## 4. View

- **Head bob and smoothed view angles** (`CalcView` 288). Head bob can be turned off (`cc_noheadbob`).
- **HeadCam:** the camera follows the model's head during animations (getting up, surgery).
- **Bodies:**
  - First-person legs come from the Gmod Legs 3 addon in the original.
  - Ragdoll clones are used when passed out.

## 5. Menus and panels

| Panel | Key | Notes |
|---|---|---|
| **Player menu** | F3 (`showspare1`) | A DFrame with inventory, bio, and needs drawn as "burden renders". It has a **custom hand cursor** (`getHandframe`) and blurs the world behind it. Not available to ghosts or robots. (`gui/cl_playermenu.lua`) |
| **Fate menu** | F2 (`showteam`) | Ghosts only, and not Foolish. In the remake this lists fate stations rather than potentials. |
| **Help** | F1 | Opens the Steam guide (workshop file 2433399988). |
| **Context menu** | C (`+menu_context`) | A DermaMenu built per target entity with `icon16` icons. Includes surgery submenus (difficulty and chance text such as *"You got nothin', kid."*), Kaiser sentencing (TORMENT / DEATH), forgive, "Call Korpsman (50 Bones)" and construction. (`framework/contextmenu/cl_context.lua`) |
| **Scoreboard** | Tab | Rank icons per player (Foolish icon and so on). |
| **Chat box** | | A custom box (`gui/cl_ccchat.lua`, `framework/chat/cl_chat.lua`) with coloured lines, big-font event lines and a monospace radio. |
| **Character creation** | | A tinted, pulsing full-screen backdrop. |
| **Skin** | | A custom Derma skin (`gui/cl_skin.lua`) and widgets: CCFrame, CCLabel, CCProgBar, CCTree, DButton and DTooltip. |

## 6. Optimisation exceptions (the look is the same, the implementation differs)

| Original | Cost | Remake |
|---|---|---|
| `Stutter` rebuilds every string per character every frame, calling `table.GetKeys` per character | A large amount of garbage and string building per frame | Cache each stuttered string for about 0.1 s, keyed by text and despair band. It looks the same. |
| `DrawEntities` walks `ents.GetAll()` every 2 s, and the "REBIRTH"/"TARGET" pass walks `ents.GetAll()` **every frame** | O(entities) per frame | Keep a client registry of HUD-drawable entities (add on `Initialize`, remove on `OnRemove`) and a client corpse registry. |
| `cl_hud.lua:2031` calls `ents.FindByClass("prop_ragdoll")` every frame | Same | Use the corpse registry. |
| HUD values are kept in **leaked globals** (`health`, `despair`…), and `RenderScreenspaceEffects` reads the global `despair` that `DrawHealthBars` happens to set | Fragile: effects break if the HUD is hidden | Keep module-local smoothed values, updated once per frame in one place. |
| HUD reads NW vars and accessors every frame | Many lookups per frame | Read from the state registry's client cache (Step 2). |
| `CreateFontCC` makes regular, italic *and* bold variants of every font (about 75 fonts) | Memory and load time | Create only the variants that are used. Same faces and sizes. |
| Constant full-screen bloom, sobel and motion blur | GPU cost on weak machines | Keep them **on by default**. Add a `gr_lowfx` client option that turns off only the costliest passes. |
| Effects started by timer chains (`timer.Simple` for DSP, flashes) | Fine at small scale | Keep the timings, but drive them from a client effect queue so overlapping scares don't fight each other. |

## 7. Parity checklist per plan step

| Step | UI and effects that must match |
|---|---|
| Step 2 | Notification list and the big centre-chat event lines (the network side). |
| Step 4 | F2 fate menu, ghost colour grading, ghost HUD (Suffering bar). |
| Step 5 | Models, clothing and hands. |
| Step 6 | Status bars (Emptiness, Dryness, Despair, Pox), Stutter, and the despair sharpen. |
| Step 7 | Damage flash, head wound, low-health blur, the bleed-out/death screen with its lines, HeadCam getting up, ragdoll clones, and corpse labels. |
| Step 8 | F3 player menu (inventory, hand cursor, blur) and cross-texts for items. |
| Step 9 | Bones notifications. |
| Step 10 | Evidence/wanted HUD and big crime announcements. |
| Step 11 | Context menu (surgery, sentence, forgive, construct, "Call Korpsman"), timed progress bars, and surgery blood. |
| Step 12 | Chat box, fonts and radio styling. |
| Step 13 | Scoreboard rank icons. |
| Step 5 (also) | Third-person option, ghost look and hearing (§13), fate footsteps and chat babble (§11). |
| Step 7 (also) | Leg-shot no-jump, getting-up animation, body dragging (§12). |
| Step 8 (also) | Holster, pickup and the keys in §14. |
| Step 12 (also) | Chat ranges, commands, messages, thoughtcrime and kill sentences (§8). |
| Weapons step | Weapon feel (§9). |
| Throughout | Crosshair, weapon select in the cross-texts, vignette, constant bloom, aberrations, Frighten, the font family and UI sounds, and wording (§10). |

## 8. Speech and chat (`framework/chat/sh_chat.lua`)

**Not kept (user, 2026-10-17):** race speech modification (`GM:Accent`, `GM:RacialQuirks`). Players of every race speak exactly what they type. Quirk speech mods (`speech inspedimence`, the missing-brain symbol speech, the amoeba stutter) come back only with quirks and organs, if at all.

- **Ranges.** `GetRF(range, muffled)`: if the speaker can't see the listener, the muffled range is used instead.

  | Mode | Command | Range / muffled | How it shows |
  |---|---|---|---|
  | Say | (plain text) | 512 / 256 | `Name says, "…"`, gold (180,150,0) |
  | Yell | `/y` | 1024 / 768 | `Name yells, "…"` in ChatBig, red |
  | Whisper | `/w` | 128 / 0 | `Name whispers, "…"` in ChatSmall, grey |
  | Me | `/me` | 512 / 256 | `Name …`, green (132,198,118) |
  | LOOC | `.//`, `[[`, `/looc` | 512 / 256 | `[LOOC] name: …` |
  | OOC | `//`, `/ooc` | global, with a cooldown, and can be disabled ("Consider using our discord or LOOC with .// instead.") | `[OOC] name: …` |
  | Radio | `/r`, `/radio` | fates with `Radio` channels only | `Name says over the radio, "…"`, Lucida Console, grey. Nearby people hear the speaker locally. Listeners see `[CHANNEL] Name crackles, "…"`. |
  | Admin, PM | `/a`, `/pm` | staff / one person | `[NECROMANCER] …`, orange PM |
  | Roll | `/roll` | local | red |
  | Help | `/help`, `/content` | self | |

- **The dead and the downed:**
  - Plain chat while bleeding out becomes a whisper.
  - Dead with a body: *"Your tongue has all but rotted away."*
  - Yelling while dead: *"The dead must speak quietly and politely."*
  - Whispering while dead: *"Noone will hear your whimpers anymore."*
  - Unconscious: *"You're unconscious. You can't talk."*
- **Radio refusals:** *"You need a radio for this."*, *"Your radio refuses to work."*, *"Your feeble voice isn't picked up by the radio."*
- **Kill sentences.** While bleeding out, typing `MOTHER OF DEATH, I CALL ON THEE` or `I GIVE MY SOUL ETERNALLY` (spaces ignored) gives *"SO BE IT"* and the head bursts (`config/sh_config.lua:99`).
- **Thoughtcrime.**
  - Typing a word from `GM.BadWords`, or a sentence from `GM.BadSentences`, means the message is not sent.
  - The speaker gets a **Jumpscare** and their own words echoed back in red.
  - They become wanted for 60 s for `thoughtcrime`, and staff see *"X (nick) wanted to say '…'"*.
  - Text is de-obfuscated first (`Circumventions`).
  - The list mixes slurs, modern memes and out-of-setting words. Keep the mechanic, but keep the list in config for the user to review: the original also bans "admin", "font" and Cyrillic letters.
- **Auto-grammar** (`AutoGrammar`, `GM.StupidMistakes`). Common chat-speak is corrected into proper words before sending. This is not race-related, so it stays.
- **Talking body:**
  - Each fate's `ChatSounds` (or `ChatSoundFunc`) plays a short babble sound at pitch 80–120 on every line. For example, the korpsman uses `placenta/speech/korps*.wav` and the slave uses poison-headcrab chatter.
  - With the weapon holstered, there is a 1-in-3 chance of a talking gesture, with a 5–15 s cooldown.
- **Voice chat is off on dedicated servers** (`PlayerCanHearPlayersVoice` returns `not game.IsDedicated()`, `sv_player.lua:3317`). The game is text-only roleplay. Keep that.
- **Name display:** chat uses the RP name (`VisibleRPName`), never the Steam name. The `prosopagnosia` quirk shows the fate name instead (comes back with quirks).

## 9. Weapon feel (`entities/weapons/weapon_cc_base/`)

- **Holstering is central.**
  - **Keys:** `B` (or the `rp_toggleholster` bind) toggles. Use + Reload holsters and checks ammo (`cl_binds.lua:159, 280, 348`).
  - **While holstered:** right-click picks up props up to 115 kg within 84 units (`SecondaryHolstered`).
  - **Weapon out:** move speed ×0.5 and no sprinting (`MovementMult`, `SprintUnholstered`). Talking gestures only happen while holstered.
- **No default sway or bob** (`SwayScale = 0`, `BobScale = 0`). The view model moves with the base's own lerped offset (`CalcIron`, `GetViewModelPosition`) and yaw/pitch drag (`dynaset`).
- **Melee (`sh_melee.lua`):**
  - **Hit trace:** a hull trace (8³) of the weapon's `Length`. Ghosts are skipped.
  - **Heavy attack:** hold attack to charge, release to swing. Damage ×1.5, and the swing sound plays at pitch 20 (a deep whoosh).
  - **Blocking:** hold right-click with a weapon out on `SecondaryBlock` weapons; the defender takes damage × `BlockMul`.
  - **On hit:**
    - Players and NPCs get flesh sounds and a sparks effect.
    - The victim gets the red flash.
    - Knockback is aim-horizontal.
    - Fate `MeleeResistScale` applies.
    - A hit within 40 units of a ragdoll's head has a 10% chance to burst it.
  - **Bare fists on a wall:** they hurt you. The attacker takes the damage and gets the red flash.
  - **On miss:** the miss animation and `MissDelay`.
  - **Melee shove** (`MeleeShove`): a 70-unit shove with claw sounds and a big view punch for the target.
- **Firearms (`sh_firing.lua`):**
  - **Recoil:** a view punch scaled by `Primary.Recoil` and the fate's `RecoilMulti`, plus the view model kicking back (`RecoilZ`).
  - **Spread:** base ×0.7, then:
    - The fate's `AccuracyMulti` (korpsman 1.3, and proles are worse shots).
    - ×5 in the air.
    - Injuries add more spread: recovering ×1.3, injury 1 ×1.1, injury 2 ×1.7.
    - Moving ×1.5.
    - Crouched ×0.65.
  - **Original bug:** the "moving fast ×2.5" branch can never run (`> 10` is checked before `> 80`, `sh_firing.lua:95`). Parity means ×1.5 for any movement. Don't "fix" it into ×2.5 without asking.
  - **Aim:** right-click zooms FOV to ×0.9. Scoped weapons use `SightFOV` 20 with matching mouse sensitivity and the scope overlay.
- **Spit** (`G`): spit on someone (`cc_spit` effect, cooldown `NextSpit`). Weapons with a special attack use G for it instead.
- **Remake note:** the kept fates' weapons only need the base behaviour above plus their own stats. Weapon *count* is not parity; *feel* is.

## 10. Wording

Copy the original text word for word wherever the thing it describes is kept:

- Fate descriptions:
  - Korpsman: *"The healer of all maladies physical and pathological. Only Gangrene's finest should be treated for free."*
  - Slave: *"An almost-worker."*
  - Ghost: *"A dead, useless thing."*
- Death, revive and despair lines; *"…'s body says 'Not yet.'"*; the inner voice after unjust kills; the big red crime lines.
- Chat refusals (§8), the bleed-out lines (§2), and context-menu labels (surgery chance text, "Call Korpsman (50 Bones)").
- Names: `the %name to the People`, and slave barcodes.
- Small jokes that fit: the invite refusal *"Gangrene practices slavery."*
- **Where the remake changes a system, write new lines in the same voice:** deadpan, a bit broken, state-propaganda. Don't write modern or neutral UI text.

## 11. Sound

- **Footsteps:**
  - Each fate can define `Footstep(ply, foot)`. The korpsman and the slave have their own.
  - Ghosts make no footsteps (`sh_player.lua:1161`).
  - The material-based footstep table in the original is switched off (`if (false and …)`), so it is **not** parity.
- **Chat babble and gestures** (§8).
- **Per-fate looping sounds** (`CreateSound` in fate files), for the kept fates where they exist.
- **Hits, pain and screams:** the melee sounds in §9, the scream on going down, the ghost's "become" sound, and DSP (ghost DSP 4, scare DSP 28).
- **Music** (`framework/cl_music.lua`):
  - A client music patch with fade-in and fade-out.
  - Auto-plays while alive, with a gap of 5 s after each track.
  - Volume is set with `cc_musicvolume` (default 50, 0 = off), and "Now playing …" goes to the console.
  - The track list comes with the content pack.
- **UI sounds:** cross-text hover and weapon hover (§2).

## 12. Movement and body

- **Speeds:** the remake's slower speeds are a decided change (backlog). Keep the original *modifiers*:
  - Weapon out: no sprint, ×0.5.
  - Leg shot: no jumping for `6 + 10 × Emptiness%` seconds.
  - Reloading: no jumping.
  - Frozen: no jump or crouch.
  - Jumping during surgery interrupts it.
- **Dragging bodies** (`PulledBy` / `Pulling`): drag a player or body behind you. If you get more than 128 units away, it snaps free with a barnacle-tongue sound.
- **Getting up:** ragdoll while unconscious, then a getting-up animation with HeadCam (§4). First-person legs (§4).
- **Third person:** `cc_thirdperson` client option. Ghosts are always third person. Some held items (light, cigarettes) force it.

## 13. Ghosts

- **Look:**
  - Skeleton model (`models/player/skeleton.mdl`) with a glowing eye material and a render effect.
  - Invisible to the living (`PrePlayerDraw`). Ghosts can see each other.
- **Feel:**
  - Muffled hearing (DSP 4).
  - Colour grade: high contrast, breathing on a sine. Colour returns and the red tint drains as Suffering rises.
  - Motion blur `{0.08, 0.8, 0.05}`.
- **Talk:** the ghost radio channel "Suffering Eternal", with no radio sound. The dead-speech rules in §8 apply.
- **Rules:** no inventory, no collision with others, spectator team, and everything (wanted, evidence, money, gang) cleared on becoming a ghost.

## 14. Controls (`framework/cl_binds.lua`)

| Key | Action |
|---|---|
| F1 | Help |
| F2 | Fate menu (ghosts) |
| F3 | Player menu |
| C (hold) | Context menu |
| B | Toggle holster |
| Use + Reload | Holster and check ammo |
| G | Spit / special attack |
| Mouse wheel / slot keys | Weapon select in the cross-texts; attack confirms |
| Use on a player | Fate- and quirk-specific use actions (robot repair, blood-sucking quirk come back with their systems) |
| Jump | Blocked while leg-shot, reloading or frozen; interrupts surgery |

Keep the same keys so returning players' muscle memory works.
