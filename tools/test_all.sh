#!/usr/bin/env bash
# Syntax check, then every scenario in order (some depend on the one before: step1a -> step1b).
cd "$(dirname "$0")/.." || exit 1
tools/check_syntax.sh || exit 1
SCENARIOS=(step0 step1a step1b step2 step3 step4 step5 step6 step6b step7 step8 step9 step9shop step10 step12 step11b step11c step11d step11e step13 step11a step14a step15a step15b step16a step16b step16d step16c step16e step16f step17a step14b spawnmany step14c modelparity rotting korpsman guns munitionizer ghoststart weaponuse devtools gunpermit shop stockpile brewing sanitarwork kaiserexport autostitcher trashpile)
failed=()
for s in "${SCENARIOS[@]}"; do
	if tools/srv.sh test "$s" 120 >/tmp/gr_test_$$.txt 2>&1; then
		echo "ok   $s ($(grep -c '^PASS' /tmp/gr_test_$$.txt) checks)"
	else
		echo "FAIL $s"; sed 's/^/     /' /tmp/gr_test_$$.txt | grep -v '^     PASS'
		failed+=("$s")
	fi
done
rm -f /tmp/gr_test_$$.txt
[ ${#failed[@]} -eq 0 ] && echo "all passed" || { echo "failed: ${failed[*]}"; exit 1; }
