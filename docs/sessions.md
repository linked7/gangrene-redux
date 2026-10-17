# Working in parallel sessions

Gangrene Redux is built by several Claude sessions at once. This file is the shared protocol.

## Roles
- **Git keeper**: the only session that merges into `main` and pushes. It merges worker branches,
  resolves conflicts, runs the full `tools/test_all.sh` once per merge, pushes, and removes the
  merged worktree and branch. It doesn't write features.
- **Workers**: each works in its own git worktree on a branch `gr/<topic>`, never on `main`.
  When the work is done and the full suite passes on the branch, the worker commits (no push)
  and messages the Git keeper with the branch name and a short report.
- **Feature Creep** and **Liver failure gamemode analysis** own the plan
  (`/home/deck/Documents/liverfailurewar/remake/*.md`). The keeper copies the plan into `docs/`.

## Ground rules for workers
Read `docs/03-recreation-plan.md` (ground rules), `docs/05-ui-effects-parity.md` and
`docs/04-feature-backlog.md` first.
- LuaJIT 5.1 syntax only. Run `tools/check_syntax.sh`.
- Use these mechanisms and no others:
  - fates are data (FateHas), never compared by name
  - replicated values go through State.Field
  - receivers go through Net.Receive(name, opts, fn)
  - one scheduler (Sched)
  - long actions go through Actions.Start
  - bones move only through Econ.Transfer
  - entity actions go through Interact.Add
  - speed comes only from Fates.ApplySpeed and its SpeedMods
  - player damage goes through Damage.Add, because sv_damage's EntityTakeDamage swallows hits
- No FindByClass without a comment. Use registries.
- `gamemode/manifest.lua` and `tools/test_all.sh` SCENARIOS are append-only; add to the end only.
- Each feature gets a headless scenario `gamemode/tests/sv_<name>.lua`, using a unique bot prefix.
- `tools/srv.sh test <name>` runs one scenario. `tools/test_all.sh` runs everything. They share one
  server through a lock, so runs queue. Don't start other servers on port 27115.
- `tools/play.sh` runs a LAN play server (port 27135) for real-client checks.
  `GR_PLAY_ARGS="+gr_uitour 1"` turns on the hands-free UI tour.
- Soak runs are 10 minutes at most.
- The laptop (Remote Control session "Laptop Picnic Control") is weak. Use it only as one GMod
  client, and only when needed.
