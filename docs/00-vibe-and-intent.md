# Liver Failure: vibe, feeling and intent

This is my reading of the gamemode from its code, fate texts, chat lines and the mechanics they support. Read it before the systems doc: it is the reason those systems exist.

## The one-line pitch

> **A rotting, bureaucratic industrial city where everyone is a small, replaceable part, and the systems are designed to make people's choices (obedience, cruelty, mercy, greed) visible and costly.**

## The setting

- **Gangrene** is a city named after dying flesh, under a ruler called the **Witch Kaiser**.
- **Everything is body horror turned into bureaucracy:**
  - Money is **Bones**.
  - Life force is **Stem Cells**.
  - Sanitars are paid in **Teeth**.
  - Enemy nations are named after organ failures: **Kidneystan** and **Arrhythmia**.
  - Weather can be *meat weather*.
  - Corpses visibly rot through stages.
  - The state slogan voice (*"our belovungure"*) is mock-propaganda: earnest, broken and threatening.
- **The tone is grim, deadpan black comedy.**
  - Fate blurbs undercut themselves: the Sanitar is *"the keeper of all things moral, safe, and clean... hopefully."*, the Kaiser has *"the most stressful job in Gangrene."*, and the Prole is *"the body and blood of our town"* but also *"an unpatriotic resident"* of *"this shithole"*.
  - Getting up from death can print *"…'s body says 'Not yet.'"*.
- **The aesthetic is Soviet / Eastern Bloc industrial decay**, with an occult edge: ghosts, rituals, the Rot, a "Necromancer" admin rank. It sits somewhere between *Pathologic*, *Papers, Please* and a grimy HL2 RP server.

## What it's meant to feel like

1. **You are a cog, and you know it.**
   - You don't choose a hero. You queue as a ghost and take whatever *purpose in life* is free.
   - Proles are deliberately worse shots. The state takes a cut of your labor. Your name is assigned (`the %name to the People`).
2. **Hierarchy is real and enforced by other players.**
   - The Kaiser can mark anyone for torment, judgment or death with one click.
   - Sanitars execute and get paid in teeth for it.
   - Authority levels decide whether killing someone is murder, "a bad dog put down", or a crime so great it costs 666 stem cells. The law is a game system, not a guideline.
3. **Violence is cheap to do and expensive to live with.**
   - Murder makes you Wanted, and you have to physically hide from police line of sight until it expires. Hiding is a mechanic.
   - Killing has costs:
     - Unjust killing drains stem cells and piles on Despair.
     - Witnesses nearby are "disturbed" and gain despair.
     - Despair at 100 is a heart attack.
   - The game wants you to *feel* what you did, not just respawn.
4. **Death is a state, not a loading screen.**
   - You go down first: there is a bleed-out, someone can revive you, or someone can finish you off.
   - A korpsman reviving you takes half your bones. Medicine is a business: *"prioritize those who are... valuable."*
   - If you die properly, you become a ghost who watches, haunts and waits. Death timers keep you from instantly retaking an important role.
5. **Scarcity drives stories.**
   - Hunger, thirst, sickness and despair tick constantly.
   - Taxes flow up to the Kaiser, and the Kaiser decides how much pay flows back to the sanitars.
   - Everyone needs something someone else controls, so people have to talk, trade, bribe, steal or obey.
6. **Roleplay first, and serious about it.**
   - The intro texts warn that abusing a role or breaking character is *"very likely to have you receive a harsh punishment."*
   - There are OOC/LOOC channels, `/me`, speech mangling by race and quirk, and assigned names.
   - The mechanics exist to give roleplay consequences, not to replace it.
7. **The city is alive without you.**
   - Weather cycles, corpses rot, the Rot meter climbs, wars break out and enemy refugees arrive.
   - Elections happen. (There is a vote system: *"…won the election with N% of the vote!"*)
   - The intent is a *living, breathing* city where events happen to players.

## The four kept fates as a social machine

```
          taxes ▲                     sentences / forgives
   PROLE ───────┼──────► KAISER ─────────────────────────┐
   (works,      │        (sets taxes, pays sanitars,     │
    builds,     │         upgrades proles & korpsmen)    ▼
    pays tax)   │                pay ▼              WANTED players
      ▲         │             SANITAR ─── hunts, beats, executes ──► earns TEETH
      │ revives │                ▲
   KORPSMAN ◄───┴── fees (half your bones) ── everyone who goes down
```

Each fate exists to create a relationship:

- **Prole ↔ Kaiser** is exploitation (labor tax).
- **Kaiser ↔ Sanitar** is patronage (the Kaiser pays them).
- **Sanitar ↔ everyone** is fear.
- **Korpsman ↔ everyone** is dependency (they get paid for keeping you alive).

Even with only four fates, the core loop has the full shape of the original.

**Slave** is how you enter this machine.

- Every new player starts at the bottom: harmless, named by barcode, working for wages, and visibly marked as new.
- **The point:** it is in-fiction probation. It protects the city from newcomers who kill at random, and it puts newcomers below everyone else, which fits the setting.
- **Ways out:**
  - Endure a whole round.
  - Have someone vouch for you. Being commended turns "teach the new guy" into a social act that is part of the game.


## Things to preserve in the remake

- **The vocabulary:** bones, stem cells, teeth, despair, Gangrene, Witch Kaiser, sanitar, korpsman, prole, "purpose in life", ghost suffering. Half the vibe is in the names.
- **Deadpan system messages:**
  - Big red chat for crimes (*"DEATH to X for policide!"*).
  - Small cruel flavour lines on death, revive and despair.
  - Inner-voice lines after unjust kills (*"My overseer!! What have I done!!!"*).
- **Consequences you feel in your body:** despair, witnesses being disturbed, a dark screen while bleeding out, the ghost wait.
- **Line-of-sight hiding while wanted.** It's one of the most distinctive mechanics.
- **Medicine for money.** Korpsmen taking a cut of the dead is perfect for the setting.
- **The ghost state as a lobby.** Waiting in the city as a spirit keeps dead players in the world.

## Things to leave behind

- **Grimness that's only shock value.**
  - Some quirks and quirk "treatments" reference sexual violence and cannibalism as mechanics (`sh_burdens.lua` around lines 60–90).
  - These add little to the core loop, they narrow who will play, and they create moderation and platform-policy risk.
  - The setting is bleak enough without them. Leave them out of the remake.
- **Punishing the player for its own bugs.**
  - Much of the original's harshness is accidental: broken gates (B2), timers that never apply (B4), and a Think that aborts (B9).
  - In the remake, cruelty should come from players and deliberate rules, never from bugs.
- **Hard-coded in-jokes** (special SteamIDs, named-player hacks). They belong to the original community, not the design.
