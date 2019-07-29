#!/usr/bin/env bash

set -euo pipefail

source tests/logging.sh

if dune build; then
  success "Built cleanly under Dune."
else
  error "Did not build cleanly under Dune."
  exit 1
fi

# TODO(jez) Require realpath?
if ! command -v realpath &> /dev/null; then
  attn "'realpath' not found. Some run-tests.sh behaviors may be different."
fi

ARGV=()
UPDATE=
VERBOSE=
while [[ $# -gt 0 ]]; do
  case $1 in
    --update)
      UPDATE=1
      shift
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    *)
      ARGV+=("$1")
      shift
      ;;
  esac
done

if [ ${#ARGV[@]} -eq 0 ]; then
  info "Discovering tests..."
  TESTS=()
  for folder in tests/cli/*; do
    if ! [ -d "$folder" ]; then
      error "Non-folder found in test/cli/: $folder"
      exit 1
    fi
    TESTS+=("$folder");
  done
else
  TESTS=("${ARGV[@]}")
fi

EXE="$PWD/_build/install/default/bin/multi-sub"

test_one() {
  local test_dir="$1"
  local test_dir_rel
  if command -v realpath &> /dev/null; then
    test_dir_rel="$(realpath --relative-to=. "$test_dir")"
  else
    test_dir_rel="$test_dir"
  fi
  info "Running test: $test_dir_rel"

  local actual
  actual="$(mktemp -d)"

  if [ "$VERBOSE" != "" ]; then
    info "├─ PWD:       $PWD"
    info "├─ test_dir:  $test_dir"
    info "├─ actual:    $actual"
  fi

  if ! [ -d "$test_dir/input" ]; then
    if [ "$UPDATE" = "" ]; then
      error "├─ each test must have an input/ dirctory: $test_dir_rel/input"
      info  "└─ (re-run with --update to create)"
      return 1
    else
      attn "├─ creating missing input/ directory: $test_dir_rel/input"
      mkdir -p "$test_dir/input"
    fi
  fi

  if ! [ -f "$test_dir/stdin.log" ]; then
    if [ "$UPDATE" = "" ]; then
      error "└─ each test must have a stdin.log file: $test_dir_rel/stdin.log"
      info  "└─ (re-run with --update to create)"
      return 1
    else
      attn "├─ creating missing stdin.log file: $test_dir_rel/stdin.log"
      touch "$test_dir/stdin.log"
    fi
  fi

  if ! [ -f "$test_dir/args.txt" ]; then
    if [ "$UPDATE" = "" ]; then
      error "└─ each test must have an args.txt file: $test_dir_rel/args.txt"
      info  "└─ (re-run with --update to create)"
      return 1
    else
      attn "├─ creating missing args.txt file: $test_dir_rel/args.txt"
      touch "$test_dir/args.txt"
    fi
  fi

  if ! [ -d "$test_dir/expected" ]; then
    if [ "$UPDATE" = "" ]; then
      error "└─ each test must have an expected/ dirctory: $test_dir_rel/expected"
      info  "└─ (re-run with --update to create)"
      return 1
    else
      attn "├─ creating missing expected/ directory: $test_dir_rel/expected"
      mkdir -p "$test_dir/expected"
    fi
  fi

  cp -r "$test_dir/input" "$actual"

  (
    # cd because the paths in in.log are relative, so `multi-sub` needs to be
    # run from a correct relative path.
    cd "$actual"
    # The fact that this splits on word boundaries powers arg forwarding.
    # shellcheck disable=SC2046
    if ! eval "'$EXE' $(< "$test_dir/args.txt")" \
        < "$test_dir/stdin.log" \
        1> "$actual/input/stdout.log" \
        2> "$actual/input/stderr.log"; then
      error "├─ $EXE exited non-zero."
      if [ "$VERBOSE" = "" ]; then
        error "├─ stdout: $actual/input/stdout.log"
        error "├─ stderr: $actual/input/stderr.log"
        error "└─ (or re-run with --verbose)"
      else
        error "├─ stdout ($actual/input/stdout.log):"
        cat "$actual/input/stdout.log"
        error "├─ stderr ($actual/input/stderr.log):"
        cat "$actual/input/stderr.log"
        error "└─ (end stderr)"
      fi
      return 1
    fi
  )

  if ! [ -f "$test_dir/expected/stdout.log" ] && \
     ! [ -s "$actual/input/stdout.log" ]; then
    rm "$actual/input/stdout.log"
  fi
  if ! [ -f "$test_dir/expected/stderr.log" ] && \
     ! [ -s "$actual/input/stderr.log" ]; then
    rm "$actual/input/stderr.log"
  fi

  if ! diff -ur "$test_dir/expected" "$actual/input"; then
    if [ "$UPDATE" = "" ]; then
      error "├─ expected expected/ did not match actual/ folder"
      error "└─ see output above. Run with --update to fix."
      return 1
    else
      attn "├─ overwriting expected/ with actual/"
      rm -rf "$test_dir/expected"
      mv "$actual/input" "$test_dir/expected"
    fi
  fi

  success "└─ test passed."
}

failing_tests=()
passing_tests=()
for test_dir in "${TESTS[@]}"; do
  if command -v realpath &> /dev/null; then
    test_case="$(realpath "$test_dir")"
  else
    test_case="$PWD/$test_dir"
  fi

  if test_one "$test_case"; then
    passing_tests+=("$test_dir")
  else
    failing_tests+=("$test_dir")
  fi
done

echo

if [ "${#passing_tests[@]}" -ne 0 ]; then
  echo
  echo "───── Passing tests ────────────────────────────────────────────────────"
  for passing_test in "${passing_tests[@]}"; do
    success "$passing_test"
  done
fi

if [ "${#failing_tests[@]}" -ne 0 ]; then
  echo
  echo "───── Failing tests ────────────────────────────────────────────────────"

  for failing_test in "${failing_tests[@]}"; do
    error "$failing_test"
  done

  echo
  echo "There were failing tests. To re-run all failing tests:"
  echo
  echo "    ./run-tests.sh ${failing_tests[*]}"
  echo

  exit 1
fi
