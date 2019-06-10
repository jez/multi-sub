#!/usr/bin/env bash

set -euo pipefail

opam_release() {
  local version="$1"
  local arch_os="$2"

  echo "https://github.com/ocaml/opam/releases/download/$version/opam-$version-$arch_os"
}

echo "--- Setting up OPAM environment ----------------------------------------"

opam_version="2.0.4"
opam_release_url=
case "$TRAVIS_OS_NAME" in
  osx)   opam_release_url="$(opam_release "$opam_version" "x86_64-macos")" ;;
  linux) opam_release_url="$(opam_release "$opam_version" "x86_64-linux")" ;;
  *)
    echo "Unknown TRAVIS_OS_NAME: $TRAVIS_OS_NAME"
    exit 1
    ;;
esac

curl -L "$opam_release_url" > opam
sudo mv -v opam /usr/local/bin/opam
sudo chmod +x /usr/local/bin/opam

opam init --yes
eval "$(opam config env)"

abs_pwd="$(pwd -P)"
if [ "$(opam switch show)" != "$abs_pwd" ]; then
  rm -rf _opam
  opam switch create . ocaml-base-compiler.4.07.1
fi
eval "$(opam config env)"

opam install dune

echo "--- Building project ---------------------------------------------------"

dune build

echo "--- Creating release tarfile -------------------------------------------"

mkdir -p "$HOME/.local"
dune install --prefix="$HOME/.local"
pushd "$HOME/.local"

if [ "$TRAVIS_TAG" != "" ]; then
  tar czf "multi-sub-$TRAVIS_TAG-$TRAVIS_OS_NAME.tar.gz" \
    bin/multi-sub \
    doc/multi-sub/README.md \
    doc/multi-sub/LICENSE
fi
