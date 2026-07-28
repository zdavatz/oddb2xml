#!/usr/bin/env bash
#
# setup_rust2xml.sh — install the Rust toolchain and build rust2xml, so the
# 03:00 cron job (rust2xml/scripts/run_artikelstamm.sh) can publish its
# Artikelstamm under https://mediupdatexml.oddb.org/artikelstamm/rust2xml/.
#
# Run as the build user (NOT root):  scripts/setup_rust2xml.sh
#
# Idempotent: re-running updates the toolchain and rebuilds if sources changed.
# rustup is used rather than Debian's rustc because run_artikelstamm.sh sources
# $HOME/.cargo/env to find cargo under cron's minimal PATH.
#
# Configurable via environment:
#   RUST2XML_DIR  rust2xml checkout  (default $HOME/software/rust2xml)
#
set -euo pipefail

RUST2XML_DIR="${RUST2XML_DIR:-$HOME/software/rust2xml}"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "Run this as the build user, not root (rustup installs into \$HOME)." >&2
  exit 1
fi
if [[ ! -d "$RUST2XML_DIR" ]]; then
  echo "rust2xml checkout not found at $RUST2XML_DIR" >&2
  echo "  git clone https://github.com/zdavatz/rust2xml $RUST2XML_DIR" >&2
  exit 1
fi

if [[ ! -x "$HOME/.cargo/bin/cargo" ]]; then
  step "Installing the Rust toolchain (rustup, stable)"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
else
  step "Updating the Rust toolchain"
  "$HOME/.cargo/bin/rustup" update stable
fi

# shellcheck disable=SC1091
source "$HOME/.cargo/env"
cargo --version

step "Building rust2xml (release)"
cd "$RUST2XML_DIR"
cargo build --release --bin rust2xml

step "Done"
echo "Binary: $RUST2XML_DIR/target/release/rust2xml"
echo "The 03:00 cron entry in /etc/cron.d/mediupdatexml picks it up from here."
