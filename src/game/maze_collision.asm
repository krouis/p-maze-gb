; =============================================================================
; Pixel Maze GB
; File:        src/game/maze_collision.asm
; Description: Handles player movement validation and collision checks.
;
; Copyright (C) 2026 Oasis Loop Labs
;
; This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the Free
; Software Foundation; version 2 of the License.
;
; SPDX-License-Identifier: GPL-2.0-only
; =============================================================================
INCLUDE "src/hardware/constants.inc"

SECTION "MazeCollisionEngine", ROM0
; -----------------------------------------------------------------------------
; Maze_CanMove
;
; Determines whether movement is allowed from the current cell in the
; requested direction.
;
; Inputs:
;   A = direction enum (0 = North, 1 = East, 2 = South, 3 = West)
;   B = current X cell coordinate
;   C = current Y cell coordinate
;
; Outputs:
;   A = 1 if movement is allowed, 0 if blocked
;
; Preserves:
;   BC, DE, HL
;
; Destroys:
;   F
;
; Notes:
;   Caller must ensure B and C are inside the current maze dimensions.
; -----------------------------------------------------------------------------
Maze_CanMove::
    push hl
    push bc
    
    ld d, a             ; D = direction
    ; Get address of cell (B, C)
    call GetCellAddress ; HL = cell address
    ld a, [hl]          ; A = cell bits
    ld e, a             ; E = cell bits
    
    ld a, d
    cp 0
    jr nz, .notNorth
    ; Check North (Bit 0)
    bit DIR_NORTH_BIT, e
    jr nz, .allowed
    jr .blocked

.notNorth:
    cp 1
    jr nz, .notEast
    ; Check East (Bit 1)
    bit DIR_EAST_BIT, e
    jr nz, .allowed
    jr .blocked

.notEast:
    cp 2
    jr nz, .notSouth
    ; Check South (Bit 2)
    bit DIR_SOUTH_BIT, e
    jr nz, .allowed
    jr .blocked

.notSouth:
    ; Check West (Bit 3)
    bit DIR_WEST_BIT, e
    jr nz, .allowed
    jr .blocked

.blocked:
    ld a, 0
    jr .done

.allowed:
    ld a, 1

.done:
    pop bc
    pop hl
    ret
