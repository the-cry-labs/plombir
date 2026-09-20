#!/usr/bin/env bash
# Warn-only perf regression check (roadmap Phase 6, item 3).
#
# Times release-binary cold builds of a minimal site and a generated
# 200-page site against the `roadmap.md` §11.7 budgets. Prints OK/WARN
# lines and always exits 0: thresholds become hard failures only after
# a month of same-runner data (warn-only first month per roadmap).
# Usage: ./scripts/bench.sh [bin/plombir]
set -u

BIN="${1:-bin/plombir}"
MINIMAL_BUDGET_MS=300
PAGES200_BUDGET_MS=1000

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "$BIN" in
/*) ;;
*) BIN="$ROOT/$BIN" ;;
esac

if [ ! -x "$BIN" ]; then
  echo "bench: WARN: binary $BIN missing or not executable (run shards build --release first)"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ms_now() { date +%s%N; }

cold_build_ms() {
  local site="$1"
  rm -rf "$site/dist"
  local start end
  start="$(ms_now)"
  (cd "$site" && "$BIN" build >/dev/null 2>&1)
  end="$(ms_now)"
  echo $(( (end - start) / 1000000 ))
}

check() {
  local name="$1" ms="$2" budget="$3"
  if [ "$ms" -lt "$budget" ]; then
    echo "bench: OK: $name ${ms}ms (budget <${budget}ms)"
  else
    echo "bench: WARN: $name ${ms}ms exceeds budget <${budget}ms"
  fi
}

cp -r "$ROOT/spec/fixtures/minimal-site" "$WORK/min"
mkdir -p "$WORK/many/content/posts" "$WORK/many/layouts"
echo '<main>{{ content }}</main>' >"$WORK/many/layouts/default.html"
i=1
while [ "$i" -le 200 ]; do
  n="$(printf 'page-%03d' "$i")"
  printf -- '---\ntitle: %s\ndate: 2026-09-13\n---\n\n# %s\n\nBody %s.\n' "$n" "$n" "$n" >"$WORK/many/content/posts/$n.md"
  i=$((i + 1))
done

check "minimal cold build (wall)" "$(cold_build_ms "$WORK/min")" "$MINIMAL_BUDGET_MS"
check "200-page cold build (wall)" "$(cold_build_ms "$WORK/many")" "$PAGES200_BUDGET_MS"

echo "bench: done (warn-only, exit 0)"
