#!/bin/bash
# A LAN play server for real-client checks: a snapshot of this checkout on a shadow install
# (like tools/soak.sh, so it never touches srv.sh's lock or files), no bots, no soak.
# Usage: tools/play.sh [start|stop|log] [map=gm_construct]. Clients connect to <deck-ip>:$PORT.
# Extra server args via GR_PLAY_ARGS, e.g. GR_PLAY_ARGS="+gr_uitour 1" for the hands-free UI tour.
set -u
CMD=${1:-start}; MAP=${2:-gm_construct}
DS=${GR_DS:-$HOME/gmod-ds}
PLAY=${GR_PLAY_DS:-$HOME/gmod-ds-play}
PORT=${GR_PLAY_PORT:-27135}
REPO=$(cd "$(dirname "$0")/.." && pwd)
GM=$PLAY/garrysmod
PIDFILE=$PLAY/play.pid

stop() {
	[ -f "$PIDFILE" ] || return 0
	local pid; pid=$(cat "$PIDFILE")
	kill -TERM -- "-$pid" 2>/dev/null; sleep 1; kill -KILL -- "-$pid" 2>/dev/null
	rm -f "$PIDFILE"
}
case $CMD in
	stop) stop; exit 0 ;;
	log) exec tail -n "${3:-60}" "$GM/console.log" ;;
	start) ;;
	*) echo "usage: $0 [start|stop|log] [map]"; exit 2 ;;
esac
[ -x "$DS/srcds_run" ] || { echo "no dedicated server at $DS"; exit 2; }

mkdir -p "$GM/gamemodes" "$GM/data"
for e in "$DS"/*; do
	n=$(basename "$e")
	case $n in garrysmod|srcds_run|srcds_linux|gr-logs) ;; *) ln -sfn "$e" "$PLAY/$n" ;; esac
done
cp -f "$DS/srcds_run" "$DS/srcds_linux" "$PLAY/"
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

stop
rm -f "$GM/console.log"
( cd "$PLAY" && exec setsid ./srcds_run -game garrysmod -norestart -console -condebug \
	-port "$PORT" +clientport $((PORT + 1)) +tv_port $((PORT + 2)) \
	+sv_lan 1 +maxplayers 8 ${GR_PLAY_ARGS:-} +gamemode gangreneredux +map "$MAP" >/dev/null 2>&1 ) &
echo $! >"$PIDFILE"
echo "play server: $MAP on port $PORT, log $GM/console.log"
