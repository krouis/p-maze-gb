# ADR 0003: Maze Representation and Tile Mapping

## Context

We need a compact, efficient memory representation for the maze to perform procedural generation, pathfinding/solvability validation, and collision detection within the Game Boy's limited WRAM. We also need a clear layout translation to hardware tile coordinates.

## Decision

We select a **grid-based path-and-wall tile model** where:
1. Each logical maze cell is represented by odd tile coordinates, and the boundaries/walls between cells are represented by even tile coordinates.
2. The coordinate mapping is:
   * Cell $(c_x, c_y)$ maps to Background Tile $(2c_x + 1, 2c_y + 1)$.
   * The wall between cell $(c_x, c_y)$ and $(c_x + 1, c_y)$ is at $(2c_x + 2, 2c_y + 1)$.
   * The wall between cell $(c_x, c_y)$ and $(c_x, c_y + 1)$ is at $(2c_x + 1, 2c_y + 2)$.
3. This creates a natural wall-corridor grid where pathways are 8x8 pixels (1 tile) and walls are 8x8 pixels (1 tile).
4. The maximum maze dimensions that fit on the 20x18 tile screen are 9x8 cells (which maps to 19x17 tiles).

### WRAM Data Representation
We represent the maze state in WRAM as a flat byte array of size $9 \times 8 = 72$ bytes.
Each cell has the following bit layout:
* Bit 0: North opening (0 if wall, 1 if path/open)
* Bit 1: East opening (0 if wall, 1 if path/open)
* Bit 2: South opening (0 if wall, 1 if path/open)
* Bit 3: West opening (0 if wall, 1 if path/open)
* Bit 4: Visited flag (used during generation and pathfinding)

## Status

Accepted.

## Consequences

* Checking collisions is a simple O(1) bitwise test of the adjacent cell's opening bits or checking the target tile coordinate directly.
* Rendering is straightforward: we write either wall tiles or floor tiles to VRAM according to the cell openings.

---
*Copyright (C) 2026 Oasis Loop Labs. Licensed under GPL-2.0-only.*
