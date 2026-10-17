#!/usr/bin/env bash
# Syntax check, then every scenario in order (some depend on the one before: step1a -> step1b).
cd "$(dirname "$0")/.." || exit 1
tools/check_syntax.sh || exit 1
SCENARIOS=(step0 step1a step1b step2 step3 step4 step5 step6 step6b step7 step8 step9 step10 step12 step11d)
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
