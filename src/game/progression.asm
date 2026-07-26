; =============================================================================
; Pixel Maze GB
; File:        src/game/progression.asm
; Description: Handles level-to-difficulty/size progression.
;
; Copyright (C) 2026 Oasis Loop Labs
;
; This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the Free
; Software Foundation; version 2 of the License.
;
; SPDX-License-Identifier: GPL-2.0-only
; =============================================================================

SECTION "ProgressionEngine", ROM0

; -----------------------------------------------------------------------------
; Progression_GetSize
;
; Given the current level number, determines the grid size of the maze.
;
; Inputs:
;   None (reads wCurrentLevel)
;
; Outputs:
;   B = width in cells (3 to 9)
;   C = height in cells (3 to 8)
;
; Preserves:
;   DE, HL
;
; Destroys:
;   A, F
; -----------------------------------------------------------------------------
Progression_GetSize::
    ld a, [wCurrentLevel]
    
    ; Level 1: 3x3 cells
    cp 1
    jr nz, .notL1
    ld b, 3
    ld c, 3
    ret

.notL1:
    ; Level 2: 4x4 cells
    cp 2
    jr nz, .notL2
    ld b, 4
    ld c, 4
    ret

.notL2:
    ; Level 3: 5x4 cells
    cp 3
    jr nz, .notL3
    ld b, 5
    ld c, 4
    ret

.notL3:
    ; Level 4: 6x5 cells
    cp 4
    jr nz, .notL4
    ld b, 6
    ld c, 5
    ret

.notL4:
    ; Level 5: 7x6 cells
    cp 5
    jr nz, .notL5
    ld b, 7
    ld c, 6
    ret

.notL5:
    ; Level 6: 8x7 cells
    cp 6
    jr nz, .notL6
    ld b, 8
    ld c, 7
    ret

.notL6:
    ; Level 7+: 9x8 cells (Maximum size for single-screen view)
    ld b, 9
    ld c, 8
    ret
