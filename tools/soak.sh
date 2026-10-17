#!/usr/bin/env bash
# Bot soak (plan step 14): tools/soak.sh [minutes=60] [bots=30] [seed] [pace=1] [skip,list]
# pace and skip are for hunting crashes: bots act pace times as often; skip names activities to leave
# out (see Soak.Start in gamemode/systems/sv_soak.lua).
#
# Runs gamemode/systems/sv_soak.lua on a SECOND dedicated server, so an hour-long soak never holds
# tools/srv.sh's lock or touches the shared server's files. Two srcds instances can't share one
# garrysmod/ folder (console.log, data/, sv.db, the gamemode symlink srv.sh repoints per run), so this
# builds a shadow install in $GR_SOAK_DS (default ~/gmod-ds-soak): symlinks to the big read-only parts of
# ~/gmod-ds, and its own copies of the binaries' launchers, cfg/, data/, sv.db and a snapshot of this
# checkout's gamemode. Lua autorefresh is off, so editing the checkout mid-soak changes nothing.
#
# Output: $GR_SOAK_DS/garrysmod/data/gr_soak/{metrics.csv,sched.csv,summary.txt}, copied with the
# console log to ~/gmod-ds/gr-logs/soak-<stamp>/. Exits 0 only if the summary says "DONE pass" and
# the console log has no Lua errors.
set -u
MINUTES=${1:-60}; BOTS=${2:-30}; SEED=${3:-$(date +%s)}; PACE=${4:-1}; SKIP=${5:--}
DS=${GR_DS:-$HOME/gmod-ds}
SOAK=${GR_SOAK_DS:-$HOME/gmod-ds-soak}
PORT=${GR_SOAK_PORT:-27125}
REPO=$(cd "$(dirname "$0")/.." && pwd)
GM=$SOAK/garrysmod
OUT=$DS/gr-logs/soak-$(date +%Y%m%d-%H%M%S)

[ -x "$DS/srcds_run" ] || { echo "no dedicated server at $DS"; exit 2; }

# The shadow install ---------------------------------------------------------------------------
mkdir -p "$GM/gamemodes" "$GM/data"
for e in "$DS"/*; do
	n=$(basename "$e")
	case $n in garrysmod|srcds_run|srcds_linux|gr-logs) ;; *) ln -sfn "$e" "$SOAK/$n" ;; esac
done
# Real copies: srcds_run cd's to its own directory and the engine finds its base dir from there.
cp -f "$DS/srcds_run" "$DS/srcds_linux" "$SOAK/"
for e in "$DS/garrysmod"/*; do
	n=$(basename "$e")
	case $n in data|cfg|gamemodes|console.log|sv.db|cache|modelsounds.cache) ;; *) ln -sfn "$e" "$GM/$n" ;; esac
done
rm -rf "$GM/cfg" && cp -r "$DS/garrysmod/cfg" "$GM/cfg"
for e in "$DS/garrysmod/gamemodes"/*; do
	n=$(basename "$e")
	[ "$n" = gangreneredux ] || ln -sfn "$e" "$GM/gamemodes/$n"
done
rm -rf "$GM/gamemodes/gangreneredux"
mkdir -p "$GM/gamemodes/gangreneredux"
cp -r "$REPO/gamemode" "$REPO/entities" "$REPO/gangreneredux.txt" "$GM/gamemodes/gangreneredux/"
rm -f "$GM/sv.db" # a fresh database every soak: nothing shared with the test server's

# Run ------------------------------------------------------------------------------------------
PIDFILE=$SOAK/soak.pid
stop() {
	[ -f "$PIDFILE" ] || return 0
	local pid; pid=$(cat "$PIDFILE")
	kill -TERM -- "-$pid" 2>/dev/null; sleep 1; kill -KILL -- "-$pid" 2>/dev/null
	rm -f "$PIDFILE"
}
stop
trap 'stop; exit 130' INT TERM

rm -rf "$GM/data/gr_soak" "$GM/console.log"
echo "$MINUTES $BOTS $SEED $PACE $SKIP" >"$GM/data/gr_soak.txt"
( cd "$SOAK" && exec setsid ./srcds_run -game garrysmod -norestart -console -condebug -disableluarefresh \
	-port "$PORT" +clientport $((PORT + 1)) +tv_port $((PORT + 2)) \
	+sv_lan 1 +sv_hibernate_think 1 +maxplayers $((BOTS + 2)) +gamemode gangreneredux +map gm_construct >/dev/null 2>&1 ) &
echo $! >"$PIDFILE"
echo "soak: $MINUTES min, $BOTS bots, seed $SEED, port $PORT, log $GM/console.log"

summary=$GM/data/gr_soak/summary.txt
deadline=$(( $(date +%s) + MINUTES * 60 + 300 ))
while ! grep -q '^DONE' "$summary" 2>/dev/null; do
	kill -0 "$(cat "$PIDFILE")" 2>/dev/null || { echo "server exited early"; break; }
	[ "$(date +%s)" -ge "$deadline" ] && { echo "soak timed out"; break; }
	sleep 10
done
stop

mkdir -p "$OUT"
cp "$GM/console.log" "$OUT/console.log" 2>/dev/null
cp "$GM"/data/gr_soak/* "$OUT/" 2>/dev/null
[ -f "$summary" ] && cat "$summary" || echo "no summary (log: $OUT/console.log)"
errs=$(grep -nE '\] ERROR: |\[gr\] loader:|\[ERROR\]|Lua Error|attempt to (call|index|perform|compare|concatenate)|^\s*[0-9]+\. .+ - [a-z_/]+\.lua:[0-9]+' "$OUT/console.log" 2>/dev/null)
[ -n "$errs" ] && { echo "--- Lua errors in $OUT/console.log:"; echo "$errs" | head -40; }
echo "files: $OUT"
grep -q '^DONE pass$' "$summary" 2>/dev/null && [ -z "$errs" ]
