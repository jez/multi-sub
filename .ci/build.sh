#!/usr/bin/env bash

set -euo pipefail

fold_start() {
  echo -e "travis_fold:start:$1\\033[33;1m$2\\033[0m"
}

fold_end() {
  echo -e "\\ntravis_fold:end:$1\\r"
}

# -----------------------------------------------------------------------------
fold_start opam "Setting up OPAM environment"

opam init --yes
eval "$(opam config env)"

opam switch multi-sub --alias-of 4.07.0
eval "$(opam config env)"

# TODO(jez) pin dependencies?
opam install dune

fold_end opam
# -----------------------------------------------------------------------------
fold_start dune.build "Building project"

dune build

fold_end dune.build
# -----------------------------------------------------------------------------
fold_start dune.install "Creating release tarfile"

mkdir -p "$HOME/.local"
dune install --prefix="$HOME/.local"
pushd "$HOME/.local"

if [ "$TRAVIS_TAG" != "" ]; then
  tar czf "multi-sub-$TRAVIS_TAG-$TRAVIS_OS_NAME.tar.gz" \
    bin/multi-sub \
    doc/multi-sub/README.md \
    doc/multi-sub/LICENSE
fi

fold_end dune.install
# -----------------------------------------------------------------------------
