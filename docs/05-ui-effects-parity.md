# Liver Failure remake: UI and effects parity

**Rule (decided 2026-10-17 by the user):** the remake's UI and effects must match the original Gangrene look and feel. The only exception is optimisation. An effect may be *implemented* differently, or offered as an option, if the original way is costly, but what the player sees and hears stays the same.

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
| Throughout | Crosshair, weapon select in the cross-texts, vignette, constant bloom, aberrations, Frighten, the font family and UI sounds. |
