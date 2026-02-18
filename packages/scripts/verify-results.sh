#!/bin/sh
# Verify all simulator flows match the reference model # (sail-riscv,spike)
# Usage: verify-results <reference.csv> <sim1.csv> [sim2.csv] ...
# Step 1: self-check reference — actual (col2) must match expected (col3)
# Step 2: cross-compare — each flow's CSV must match reference's CSV exactly
set -e

REFERENCE="$1"
shift

if [ "$#" -eq 0 ]; then
  echo "FAIL: no simulator CSVs provided"
  exit 1
fi

# Sanity: reference CSV must exist and be non-empty
if [ ! -s "$REFERENCE" ]; then
  echo "FAIL: reference model CSV missing or empty: $REFERENCE"
  exit 1
fi

# Step 1: self-check reference model (actual == expected for every test)
if ! tail -n +2 "$REFERENCE" | cut -d, -f2 | cmp -s - \
     <(tail -n +2 "$REFERENCE" | cut -d, -f3); then
  echo "FAIL: reference model actual != expected"
  diff <(tail -n +2 "$REFERENCE" | cut -d, -f1,2) \
       <(tail -n +2 "$REFERENCE" | cut -d, -f1,3) || true
  exit 1
fi
echo "OK: reference model self-check passed"

# Step 2: cross-compare each flow against reference (whole-file cmp)
_fail=0
for csv in "$@"; do
  _name=$(basename "$csv" -results.csv)
  if [ ! -s "$csv" ]; then
    echo "FAIL: $_name CSV missing or empty: $csv"
    _fail=1
    continue
  fi
  if ! cmp -s "$REFERENCE" "$csv"; then
    echo "FAIL: $_name differs from reference model"
    diff "$REFERENCE" "$csv" || true
    _fail=1
  else
    echo "OK: $_name"
  fi
done

if [ "$_fail" -ne 0 ]; then
  exit 1
fi
echo "ALL FLOWS VERIFIED"
