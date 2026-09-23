# Installation

## From a release binary (Linux x86_64/ARM64, macOS ARM64)

```bash
sh install.sh                  # latest release -> ~/.local/bin
sh install.sh --prefix /usr/local/bin   # system-wide (needs sudo)
PLOMBIR_VERSION=v1.0.0 sh install.sh    # pin a release
```

Or download `plombir-linux-x86_64.tar.gz` (`-aarch64` on ARM64
Linux, `plombir-macos-arm64.tar.gz` on Apple Silicon) from the
[releases page](https://github.com/the-cry-labs/plombir/releases)
yourself, extract `plombir`, and put it on your `PATH`. The binary
is statically linked: zero runtime dependencies, any output of
`plombir --version` names its commit (`plombir 1.0.0 (336e3d4)`).

## From source

macOS (Intel), other platforms, or hacking on Plombir itself.

Prerequisites: Crystal `>= 1.21.0` and Shards (`>= 0.20.0`).

```bash
git clone https://github.com/the-cry-labs/plombir
cd plombir
shards install
shards build --release  # binary -> bin/plombir
./bin/plombir --version
```

Put `bin/plombir` on your `PATH`, or copy it anywhere you like —
the core is a single native binary with zero runtime dependencies.

## Development setup

```bash
shards install
shards build          # debug binary -> bin/plombir
crystal spec          # full test suite, must stay green
crystal tool format   # format sources before every commit
```

## Troubleshooting installs

- `shards install --frozen` fails: your checkout is behind —
  `git pull` and retry (CI pins exact versions via `shard.lock`).
- `crystal` not found: install Crystal `>= 1.21.0` from
  <https://crystal-lang.org/install/> (or check `plombir doctor`
  once built — it reports the toolchain version it sees).
- Prebuilt binaries live on the releases page; a static build
  from any checkout is `shards build --release --static`
  (needs a musl toolchain — e.g. Alpine; plain glibc hosts
  usually lack static libc).
