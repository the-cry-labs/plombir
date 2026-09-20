#!/bin/sh
# Installs the plombir release binary (Linux x86_64).
#
#   sh install.sh                          # latest release -> ~/.local/bin
#   sh install.sh --prefix /usr/local/bin  # system-wide (needs sudo)
#   PLOMBIR_VERSION=v1.0.0 sh install.sh   # pin a release
#
# macOS / other platforms: build from source (see docs/installation.md).
# Env overrides (testing): PLOMBIR_RELEASE_BASE, PLOMBIR_VERSION.
set -eu

BASE="${PLOMBIR_RELEASE_BASE:-https://github.com/the-cry-labs/plombir/releases}"
VERSION="${PLOMBIR_VERSION:-latest}"
PREFIX="${1:-}"
if [ "${PREFIX:-}" = "--prefix" ]; then PREFIX="$2"; fi
PREFIX="${PREFIX:-$HOME/.local/bin}"

OS="$(uname -s)"; ARCH="$(uname -m)"
if [ "$OS" != "Linux" ] || [ "$ARCH" != "x86_64" ]; then
  echo "error: no prebuilt binary for $OS/$ARCH - build from source:" >&2
  echo "  git clone https://github.com/the-cry-labs/plombir && cd plombir && shards install && shards build --release" >&2
  exit 1
fi

if [ "$VERSION" = "latest" ]; then
  URL="$BASE/latest/download/plombir-linux-x86_64.tar.gz"
else
  URL="$BASE/download/$VERSION/plombir-linux-x86_64.tar.gz"
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT INT TERM
echo "downloading $URL"
curl -fsSL "$URL" -o "$TMP/plombir.tar.gz"
tar -xzf "$TMP/plombir.tar.gz" -C "$TMP"
mkdir -p "$PREFIX"
install -m 755 "$TMP/plombir" "$PREFIX/plombir"
echo "installed to $PREFIX/plombir"
"$PREFIX/plombir" --version
case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) echo "note: $PREFIX is not on PATH - add: export PATH=\"\$PATH:$PREFIX\"" ;;
esac
