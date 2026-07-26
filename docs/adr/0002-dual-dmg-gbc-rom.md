# ADR 0002: Dual DMG and GBC Compatibility

## Context

We need the game to run on monochrome Game Boy (DMG) hardware as well as Game Boy Color (GBC) hardware, leveraging the unique features of the GBC (color palettes) without making GBC a requirement for gameplay.

## Decision

We will build a **dual-compatible ROM** (CGB-compatible but DMG-runnable). 

Implementation details:
1. The ROM header flag for CGB compatibility will be set to `$80` (dual compatibility: supports CGB features but runs on DMG).
2. During the boot/initialization sequence, we will read the CPU registers (specifically the value of the `A` register at boot time) to detect GBC hardware.
3. If GBC hardware is detected, we will store a boolean flag `wIsGBC` in memory and initialize CGB color palettes. If DMG is detected, we will default to standard DMG shading registers (`rBGP`, `rOBP0`, `rOBP1`).

## Status

Accepted.

## Consequences

* The game must remain completely playable in monochrome (DMG). Color must not be required to solve any level.
* Graphic assets and layout will be designed for 8x8 background tiles and 8x16 sprites compatible with both DMG and GBC.

---
*Copyright (C) 2026 Oasis Loop Labs. Licensed under GPL-2.0-only.*
