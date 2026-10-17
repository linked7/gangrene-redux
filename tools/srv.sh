#!/usr/bin/env bash
# Drive the headless GMod dedicated server (SteamCMD app 4020) for this gamemode.
#   tools/srv.sh test <scenario> [timeout_s]   run gamemode/tests/sv_<scenario>.lua, print results, exit 0 on pass
#   tools/srv.sh start                          start a server and leave it running (connect to 127.0.0.1:27115)
#   tools/srv.sh stop                           stop it
# The live log is $DS/garrysmod/console.log; test runs copy it to $DS/gr-logs/<scenario>.log. Any Lua error in the log fails a test run.
set -u
DS=${GR_DS:-$HOME/gmod-ds}
REPO=$(cd "$(dirname "$0")/.." && pwd)
PORT=${GR_PORT:-27115}
DATA=$DS/garrysmod/data
LOGS=$DS/gr-logs
PIDFILE=$LOGS/server.pid

[ -x "$DS/srcds_run" ] || { echo "no dedicated server at $DS (install app 4020 with SteamCMD)"; exit 2; }
mkdir -p "$DATA/gr_tests" "$LOGS"
ln -sfn "$REPO" "$DS/garrysmod/gamemodes/gangreneredux"

start_server() { # $1 = log file
	stop_server
	# stdout is block-buffered when redirected, so the log we read is -condebug's console.log.
	rm -f "$DS/garrysmod/console.log"
	( cd "$DS" && exec setsid ./srcds_run -game garrysmod -norestart -console -condebug -port "$PORT" \
		+sv_lan 1 +sv_hibernate_think 1 +maxplayers 24 +gamemode gangreneredux +map gm_construct >/dev/null 2>&1 ) &
	echo $! >"$PIDFILE"
}

stop_server() {
	[ -f "$PIDFILE" ] || return 0
	local pid; pid=$(cat "$PIDFILE")
	kill -TERM -- "-$pid" 2>/dev/null; sleep 1; kill -KILL -- "-$pid" 2>/dev/null
	rm -f "$PIDFILE"
}

lua_errors() { grep -nE '\[gr\] loader:|\[ERROR\]|Lua Error|attempt to (call|index|perform|compare|concatenate)|^\s*[0-9]+\. .+ - [a-z_/]+\.lua:[0-9]+' "$1"; }

case "${1:-}" in
test)
	name=${2:?scenario name}; timeout=${3:-120}
	log=$LOGS/$name.log; result=$DATA/gr_tests/$name.txt
	rm -f "$result"; echo "$name" >"$DATA/gr_autotest.txt"
	start_server "$log"
	for ((i = 0; i < timeout; i++)); do
		grep -q '^DONE' "$result" 2>/dev/null && break
		kill -0 "$(cat "$PIDFILE")" 2>/dev/null || { echo "server exited early"; break; }
		sleep 1
	done
	stop_server
	cp "$DS/garrysmod/console.log" "$log" 2>/dev/null
	if [ -f "$result" ]; then cat "$result"; else echo "FAIL no result after ${timeout}s (log: $log)"; fi
	errs=$(lua_errors "$log")
	[ -n "$errs" ] && { echo "--- Lua errors in $log:"; echo "$errs" | head -40; }
	grep -q '^DONE pass=[0-9]* fail=0$' "$result" 2>/dev/null && [ -z "$errs" ]
	;;
start)
	start_server "$LOGS/interactive.log"; echo "server starting on 127.0.0.1:$PORT, log $DS/garrysmod/console.log" ;;
stop)
	stop_server ;;
*)
	sed -n '2,6p' "$0"; exit 2 ;;
esac
