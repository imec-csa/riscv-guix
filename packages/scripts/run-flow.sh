#!/bin/sh
# Generic RISC-V test flow runner
# Reads MANIFEST, runs each test via SIM_CMD, outputs CSV: test,actual,expected
#
#   SIM_NAME      - simulator name (used for output CSV filename)
#   SIM_CMD       - command template; __TEST__ is replaced with the test binary path
#   SH            - absolute path to shell (for sh -c invocations)
#   TIMEOUT       - per-test timeout in seconds
#   TEST_DIR      - directory containing test binaries and MANIFEST
#   OUT_DIR       - output directory for the CSV
set -e

: "${SH:=sh}"

CSV="$OUT_DIR/$SIM_NAME-results.csv"
echo "TEST,ACTUAL,EXPECTED" > "$CSV"

infer_expected() {
  case "$1" in
    *_negative*|*-negative*) echo "FAIL" ;;
    *)
      if [ -n "$2" ]; then echo "$2"; else echo "PASS"; fi
      ;;
  esac
}

run_test() {
  _name="$1"; _expected="$2"; _path="$3"
  _full_cmd="${SIM_CMD%%__TEST__*}${_path}${SIM_CMD#*__TEST__}"

  set +e
  timeout --kill-after=5 "$TIMEOUT" "$SH" -c "$_full_cmd" > /dev/null 2>&1
  _rc=$?
  set -e

  if [ "$_rc" -eq 124 ]; then
    echo "$_name,TIMEOUT,$_expected" >> "$CSV"
  elif [ "$_rc" -eq 0 ]; then
    echo "$_name,PASS,$_expected" >> "$CSV"
  else
    echo "$_name,FAIL,$_expected" >> "$CSV"
  fi
}

if [ ! -f "$TEST_DIR/MANIFEST" ]; then
  echo "ERROR: no MANIFEST in $TEST_DIR" >&2
  exit 1
fi

while IFS=: read -r _tname _texp || [ -n "$_tname" ]; do
  case "$_tname" in \#*|"") continue ;; esac
  _tname=$(echo "$_tname" | tr -d ' \t')
  _texp=$(echo "$_texp" | tr -d ' \t')
  _expected=$(infer_expected "$_tname" "$_texp")
  run_test "$_tname" "$_expected" "$TEST_DIR/$_tname"
done < "$TEST_DIR/MANIFEST"

echo "$SIM_NAME: $(wc -l < "$CSV") tests -> $CSV"
