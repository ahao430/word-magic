#!/usr/bin/env bash
# One-shot regression runner for Word Magic (AGENTS.md §15).
#
# Discovers every tests/*_test.gd, runs each headless with a watchdog
# (macOS has no `timeout` command), prints a per-suite line plus a
# summary, and exits non-zero on any failure. Use before every commit
# (docs/pre-commit-checklist.md).
#
#   tools/dev/run_tests.sh                     # full regression
#   tools/dev/run_tests.sh --filter weather    # substring match
#   tools/dev/run_tests.sh --list              # show what would run
#   tools/dev/run_tests.sh --timeout 300       # per-suite cap (seconds)
#
# Logs land in a fresh /tmp dir; failed suites print their FAIL/ERROR
# tail and the log survives for inspection.

set -u
cd "$(dirname "$0")/../.." || exit 1

TIMEOUT="${TEST_TIMEOUT:-180}"
FILTER=""
LIST_ONLY=0

usage() {
	sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
	case "$1" in
		--filter) FILTER="${2:-}"; shift 2 ;;
		--timeout) TIMEOUT="${2:-180}"; shift 2 ;;
		--list) LIST_ONLY=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
	esac
done

SUITES="$(ls tests/*_test.gd 2>/dev/null | xargs -n1 basename | sed 's/_test\.gd$//' | sort)"
if [ -z "$SUITES" ]; then
	echo "no tests/*_test.gd found" >&2
	exit 1
fi
if [ -n "$FILTER" ]; then
	SUITES="$(printf '%s\n' "$SUITES" | grep -i -- "$FILTER" || true)"
	if [ -z "$SUITES" ]; then
		echo "no suite matches filter: $FILTER" >&2
		exit 1
	fi
fi

if [ "$LIST_ONLY" -eq 1 ]; then
	printf '%s\n' "$SUITES"
	exit 0
fi

LOGDIR="$(mktemp -d /tmp/wm-tests.XXXXXX)"
PASS=0; FAIL=0; TIMEOUTS=0
declare -a FAILED=()
START=$SECONDS

printf '== Word Magic regression: %d suites, %ds watchdog each ==\n\n' \
		"$(printf '%s\n' "$SUITES" | wc -l | tr -d ' ')" "$TIMEOUT"

for t in $SUITES; do
	LOG="$LOGDIR/$t.log"
	godot --headless --path . -s "res://tests/${t}_test.gd" >"$LOG" 2>&1 &
	PID=$!
	T0=$SECONDS
	KILLED=0
	# Poll our own PID only — never pkill stray Godots (the user's
	# editor session must survive this script).
	while kill -0 "$PID" 2>/dev/null; do
		if [ $((SECONDS - T0)) -ge "$TIMEOUT" ]; then
			kill -9 "$PID" 2>/dev/null
			KILLED=1
			wait "$PID" 2>/dev/null
			break
		fi
		sleep 1
	done
	CODE=0
	wait "$PID" 2>/dev/null || CODE=$?
	DUR=$((SECONDS - T0))
	TAG="BAD"
	if [ "$KILLED" -eq 1 ]; then
		# The watchdog killed it: the suite hung (SCRIPT ERROR mid-await).
		TIMEOUTS=$((TIMEOUTS + 1)); TAG="HANG"
		FAILED+=("$t (hang)")
	elif grep -q "ALL PASS" "$LOG"; then
		PASS=$((PASS + 1)); TAG="OK "
		if [ "$CODE" -ne 0 ]; then TAG="OK?"; fi
	else
		FAIL=$((FAIL + 1))
		FAILED+=("$t")
	fi
	printf '%s %-22s %2ds  %s\n' "$TAG" "$t" "$DUR" "$(grep -c '^PASS' "$LOG") passes"
	if [ "$TAG" = "BAD" ] || [ "$TAG" = "HANG" ]; then
		grep -m 6 "FAIL\|SCRIPT ERROR\|Parse Error" "$LOG" | sed 's/^/      /'
		# Crashes print no FAIL lines: show the raw tail so the abort
		# point is visible in CI logs.
		tail -n 6 "$LOG" | sed 's/^/      > /'
	fi
done

DURATION=$((SECONDS - START))
printf '\n== %d/%d suites ALL PASS, %d fail, %d hang — %ds total ==\n' \
		"$PASS" "$(printf '%s\n' "$SUITES" | wc -l | tr -d ' ')" "$FAIL" "$TIMEOUTS" "$DURATION"
if [ "$FAIL" -eq 0 ] && [ "$TIMEOUTS" -eq 0 ]; then
	rm -rf "$LOGDIR"
	printf 'logs cleaned (all green)\n'
	exit 0
fi
printf 'failed suites: %s\n' "${FAILED[*]}"
printf 'logs kept at: %s\n' "$LOGDIR"
exit 1
