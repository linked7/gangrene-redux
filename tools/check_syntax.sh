#!/usr/bin/env bash
# Parse every Lua file with LuaJIT (the same Lua 5.1 dialect GMod runs).
# GMod-only syntax (!=, //, continue, &&) is not allowed in this repo, so plain LuaJIT must accept everything.
cd "$(dirname "$0")/.." || exit 1
fail=0
while IFS= read -r -d '' f; do
	if ! out=$(luajit -bl "$f" 2>&1 >/dev/null); then
		echo "$out"
		fail=1
	fi
done < <(find gamemode entities tests -name '*.lua' -print0 2>/dev/null)
# P2: nothing searches the world for entities each tick; keep a registry instead (step 7 corpses).
if grep -rnE --include='*.lua' '^([^-]|-[^-])*FindByClass' gamemode entities; then
	echo "FindByClass is not allowed (P2): keep a registry"
	fail=1
fi
[ "$fail" = 0 ] && echo "syntax ok"
exit "$fail"
