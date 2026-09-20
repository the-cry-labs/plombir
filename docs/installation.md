# Installation

## From source

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
- Prebuilt release binaries will ship with v1.0; until then,
  build from source as above.
