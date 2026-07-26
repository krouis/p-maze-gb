# ADR 0005: Cartridge Specification and Memory Layout

## Context

We need to specify the hardware mapping of the Game Boy cartridge, including memory bank controllers (MBC) and ROM/RAM capacities, to keep hardware implementation simple, stable, and highly compatible.

## Decision

We select a **ROM ONLY (no MBC)** cartridge layout with the following parameters:
1. **ROM size**: 32 KiB (occupying addresses `$0000` to `$7FFF`).
2. **RAM size**: 0 KiB (no cartridge RAM, no battery-backed save). All volatile state will be stored inside the Game Boy's 8 KiB Work RAM (WRAM).
3. **Cartridge type**: Type `$00` (ROM ONLY).
4. **Header Validation**: We use `rgbfix` during compilation to validate and write standard Nintendo header attributes (e.g. padding, global checksums, GBC support byte).

## Status

Accepted.

## Consequences

* The code size and graphic assets must fit within the 32 KiB ROM limit.
* No save progress persists after boot (the game restarts at level 1 on boot, which fits our simple peaceful design).
* It eliminates hardware banking complexity, making development straightforward and compilation fast.

---
*Copyright (C) 2026 Oasis Loop Labs. Licensed under GPL-2.0-only.*
