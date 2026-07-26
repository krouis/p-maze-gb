# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Pixel Maze GB is a Game Boy game (DMG + GBC dual-compatible) written entirely in RGBDS
assembly. It procedurally generates a maze each level, the player navigates it with the
D-pad, and reaching the exit advances to the next (larger) level. There is no cartridge
RAM/save — state resets to level 1 on every boot (see `docs/adr/0005-cartridge-layout.md`).

Design decisions are recorded as ADRs in `docs/adr/` — read these before making
architectural changes, they explain *why*, not just *what*:
- `0001-rgbds.md` — pinned RGBDS v0.7.0 toolchain, compiled in-container.
- `0002-dual-dmg-gbc-rom.md` — GBC detected at boot via register `A` ($11/$01), stored in `wIsGBC`; game must stay fully playable in monochrome.
- `0003-maze-representation.md` — maze coordinate system and per-cell bit layout (see below).
- `0004-test-emulator.md` — SameBoy (primary, via `libsameboy.so`/ctypes) and binjgb (secondary smoke test) as headless test emulators; `.sym` file is parsed to resolve WRAM symbol addresses from Python.
- `0005-cartridge-layout.md` — ROM ONLY, 32 KiB, no MBC, no cartridge RAM.

## Build, test, and run commands

All tooling (RGBDS, SameBoy, binjgb, Python) lives inside a pinned Docker image — the host
only needs Docker. Use the `./dev` wrapper rather than installing anything locally:

```bash
./dev build          # make all -> build/p-maze-gb.gb
./dev test           # make test (pytest, headless smoke test)
./dev gameplay       # make test-gameplay (pytest -s, verbose maze-solving integration test)
./dev check          # build + full test suite
./dev shell          # interactive bash inside the dev container
./dev versions       # print pinned vs. actual tool versions
./dev rebuild-image  # force-rebuild the Docker dev image
./dev release        # build + copy artifacts/checksum to release/
```

`./dev` auto-builds the image on first use and runs commands as your host UID/GID so
`build/` output stays owned by you. If you already have RGBDS/Python installed natively,
the underlying `make` targets work directly (`make all`, `make test`, `make check`, etc.)
— see the `Makefile`.

To run a single test file/test with the container's pytest:
```bash
./dev shell    # then inside the container:
python3 -m pytest tests/test_gameplay.py -k test_maze_gameplay -s
```

Tests read symbol addresses out of `build/p-maze-gb.sym`, so `./dev build` (or `make all`)
must be run first — there's no ROM to test otherwise.

`make reproducible` does two clean builds and diffs the SHA-256 of the ROM to confirm
determinism.

Full details on the container setup (mounts, offline verification, updating pinned tool
versions/checksums) are in `docs/container-development.md`.

## Architecture

### Main loop and state machine

`src/main.asm` holds the ROM header, `Init`, and `MainLoop`. Execution is a single
`wGameState`-driven dispatch, gated on VBlank via `halt` + a `wFrameCounter` tick (incremented
by the VBlank ISR in `src/hardware/interrupts.asm`):

```
STATE_BOOT -> STATE_TITLE -> STATE_LEVEL_PREPARE -> STATE_LEVEL_PLAY
                 ^                                        |
                 |                                        v
                 +------------------- STATE_LEVEL_COMPLETE
                                            |
                          STATE_PAUSED  <---+ (from STATE_LEVEL_PLAY, Start button)
```

Each state has one handler called once per frame from `MainLoop`: `Title_Update`,
`PrepareLevel`, `PlayLevel`, `CompleteLevel`, `PausedLevel` (the latter three live in
`main.asm` itself). `PrepareLevel` is the per-level setup pipeline: disable LCD -> clear
VRAM -> `Progression_GetSize` -> `Maze_Generate` -> copy tiles to VRAM -> `Maze_Render` ->
draw level-number HUD -> load DMG/GBC palettes (theme = `wCurrentLevel % 4`) -> position
player -> enable LCD -> transition to `STATE_LEVEL_PLAY`.

### Module layout

- `src/hardware/` — low-level hardware access: register constants (`constants.inc`,
  included by nearly everything), VBlank/interrupt setup, LCD on/off helpers, OAM DMA,
  joypad polling.
- `src/game/` — gameplay logic: title screen, level-size progression, maze generation,
  maze rendering, collision/movement validation, player sprite/animation, exit animation,
  pause overlay, PRNG.
- `src/memory/` — the *only* place WRAM (`wram.asm`) and HRAM (`hram.asm`) globals are
  declared. All persistent state is declared here with `ds` and exported with `::` so
  other files and the linker `.sym` map can reference it by name.
- `src/data/tiles.asm` — tile graphics data (`INCBIN`s the generated `.2bpp` files under
  `assets/generated/`).
- `assets/source/*.png` -> `scripts/generate_*.py` (Pillow) produce pixel-perfect source
  PNGs -> converted to `assets/generated/*.2bpp`/`.tilemap` for `INCBIN`. Regenerate source
  art by running the relevant `scripts/generate_*.py`, then reconvert to `.2bpp`.

Every `.asm` routine file uses a consistent header-comment convention per procedure:
`Inputs` / `Outputs` / `Preserves` / `Destroys` (register-level calling contract) — follow
this convention for any new routine.

### Maze representation (see ADR 0003 for the full spec)

- Grid-based path-and-wall tile model: cell $(c_x, c_y)$ maps to background tile
  $(2c_x+1, 2c_y+1)$; walls sit on the even tile coordinates between cells.
- `wMazeData` is a flat `width * height` byte array (max 9x8 = 72 bytes, capped by the
  20x18 tile screen). Per-cell bits: 0=North open, 1=East open, 2=South open, 3=West open,
  4=visited (used only during generation/pathfinding, see `DIR_*_BIT`/`CELL_VISITED` in
  `constants.inc`).
- Generation (`src/game/maze_generate.asm`) is iterative DFS backtracking using
  `wMazeStack`/`wMazeStackPtr`, seeded from `wRngSeed` (LCG PRNG in `src/game/rng.asm`).
  Exit placement uses BFS/Bellman-Ford distance propagation into `wMazeDistances` to pick
  the farthest reachable cell from the start `(0,0)`.
- Collision (`src/game/maze_collision.asm`) is an O(1) bitwise test of the current cell's
  direction bit via `Maze_CanMove` (inputs: `A`=direction, `B`=current X, `C`=current Y).

### Test instrumentation baked into the ROM

`wTestMagic` (4-byte magic "PMGB"), `wMoveCount`, `wCompletionCount`, and `wRngSeed` are
real WRAM globals declared in `wram.asm` specifically so the Python test harness can
force a deterministic seed and assert on gameplay progress — they are not debug-only/
stripped in release builds. When editing gameplay state, keep the symbol names in
`wram.asm` stable, since `tests/test_gameplay.py` and `tests/test_rom_boot.py` resolve
WRAM addresses by parsing `build/p-maze-gb.sym` for these exact names (e.g. `wGameState`,
`wPlayerX/Y`, `wExitX/Y`, `wMazeWidth/Height`, `wMazeData`).

### Testing approach

Both test files load `/opt/sameboy/lib/libsameboy.so` directly via `ctypes` (no PyBoy or
similar wrapper), run frames with `GB_run_frame`, and read/write memory with
`GB_safe_read_memory`/`GB_write_memory`. `test_gameplay.py` additionally BFS-solves the
maze in Python from the raw `wMazeData` bytes and drives the emulator through the solved
path, asserting `wPlayerX/Y` matches expected coordinates after each move and that the
game reaches `STATE_LEVEL_COMPLETE`.
