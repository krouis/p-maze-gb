# Pixel Maze GB

[![CI](https://github.com/krouis/p-maze-gb/actions/workflows/ci.yml/badge.svg)](https://github.com/krouis/p-maze-gb/actions/workflows/ci.yml)

A peaceful maze game for the original Game Boy (DMG) and Game Boy Color (GBC),
by **Oasis Loop Labs**.

A small pixel character walks through a procedurally generated maze toward an
exit. There is no score, no timer, no lives, and no game-over state — walking
into a wall just gently bumps the character in place, and reaching the exit
opens the next, slightly larger maze. It's designed to be understandable
without reading, for players roughly 3–8 years old.

## AI-assistance disclosure

This project is an explicit AI-assisted development and review experiment.
The source code, tests, documentation, initial artwork, and any audio in this
repository were produced with substantial assistance from AI coding agents.
None of it should be assumed correct, secure, or production-ready without
human review. If you find a mistake an agent introduced or missed, please
open an issue.

## License

GNU General Public License v2.0 only (`GPL-2.0-only`). See [`LICENSE`](LICENSE)
for the full text. Source files carry per-file GPL-2.0-only headers.

## Quick start

The only host prerequisites are `git` and `docker` — no RGBDS, Python,
SameBoy, or graphics tools need to be installed locally. Everything else runs
inside a pinned, hermetic container.

```bash
git clone git@github.com:krouis/p-maze-gb.git
cd p-maze-gb
./dev check
```

`./dev` builds its own Docker image on first use, then runs the requested
target inside the container as your host user (so `build/` output stays
owned by you, not root).

| Command | Description |
|---|---|
| `./dev build` | Compile `build/p-maze-gb.gb` |
| `./dev test` | Run the full pytest suite (boot smokes, gameplay solve, binjgb visual smoke, endurance) |
| `./dev gameplay` | Same as `test`, but verbose (`pytest -s`) |
| `./dev check` | Build + run the test suite |
| `./dev shell` | Interactive shell inside the dev container |
| `./dev versions` | Print pinned vs. actual tool versions |
| `./dev clean` | Remove build output |
| `./dev release` | Build and package release artifacts + checksum |
| `./dev rebuild-image` | Force-rebuild the dev Docker image |

See [`docs/container-development.md`](docs/container-development.md) for
details on the container setup, file ownership, and offline verification.

## CI/CD

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) builds the ROM inside
the same dev container described above (no separate CI-only toolchain), on
every push to `main` and every pull request:

- container toolchain check, `actionlint`/`shellcheck` linting
- ROM build
- unit tests (ROM boot smoke, DMG/GBC hardware detection, gameplay solve,
  binjgb secondary-emulator visual smoke)
- non-regression tests (20-level endurance run)
- reproducible-build verification (`make reproducible`)
- ROM/`.sym`/`.map` uploaded as a workflow artifact

On pushes to `main` only, a second job publishes the dev container image to
`ghcr.io/krouis/p-maze-gb-dev` (tagged `latest` and by commit SHA), gated on
the first job passing.

## Hardware targets

One ROM (`build/p-maze-gb.gb`), 32 KiB, no MBC, no cartridge RAM/save —
progress resets to level 1 on boot. It boots on both:

- **Game Boy / DMG** (monochrome, mandatory — gameplay never depends on color)
- **Game Boy Color / GBC** (enhanced per-level background/sprite palettes)

via a dual-compatible cartridge header, not a CGB-only one. See
[`docs/adr/0002-dual-dmg-gbc-rom.md`](docs/adr/0002-dual-dmg-gbc-rom.md) and
[`docs/adr/0005-cartridge-layout.md`](docs/adr/0005-cartridge-layout.md).

Designed for DMG/GBC hardware and verified in the SameBoy and binjgb
emulators used by the automated test suite; it has not been verified on real
hardware or a flash cartridge.

## Architecture

The gameplay runtime is written entirely in LR35902 assembly (RGBDS). Host
tooling (asset generation, ROM/testing automation) is Python and POSIX shell.
Design decisions and the reasoning behind them are recorded as ADRs in
[`docs/adr/`](docs/adr/); [`CLAUDE.md`](CLAUDE.md) has a fuller architecture
map (module layout, state machine, maze bit representation) for anyone
working in the codebase.

## Current status / limitations

- Gameplay (title screen, procedural maze generation, movement, collision,
  pause, level progression) is implemented and covered by emulator-driven
  tests (SameBoy and binjgb) that solve real generated mazes and drive them
  via simulated D-pad input, including a 20-level endurance run.
- Audio is not implemented yet.
- Test coverage still uses a single fixed seed; broader property-based maze
  tests (connectivity/solvability across many random seeds) and
  screenshot-based visual regression tests don't exist yet.
