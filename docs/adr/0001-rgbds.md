# ADR 0001: Choice and Pinning of RGBDS

## Context

We require a Game Boy assembly compiler and linker toolchain that is stable, widely supported, well-documented, and behaves deterministically.

## Decision

We select **RGBDS** (Rednex Game Boy Development System) as the compiler toolchain, specifically version **v0.7.0**. 

Reasons:
1. It is the de-facto standard assembler for native Game Boy projects.
2. Version `v0.7.0` is a stable release with robust support for both DMG and GBC architectures.
3. We compile `v0.7.0` from its official release source package inside a container, ensuring build reproducibility and avoiding dependency on host-installed tools.

## Status

Accepted.

## Consequences

* All assembly source files must conform to RGBDS syntax.
* We must include `rgbasm`, `rgblink`, `rgbfix`, and `rgbgfx` in the container.
* The local build wrapper (`./dev`) and CI/CD pipelines will use this pinned version exclusively.

---
*Copyright (C) 2026 Oasis Loop Labs. Licensed under GPL-2.0-only.*
