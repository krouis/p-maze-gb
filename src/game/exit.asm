; =============================================================================
; Pixel Maze GB
; File:        src/game/exit.asm
; Description: Handles exit portal drawing and animation.
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

SECTION "ExitEngine", ROM0
; -----------------------------------------------------------------------------
; Exit_Animate
;
; Animates the exit portal by toggling between two frames of the star animation
; based on the global frame counter.
; NOTE: Must be called during a safe VRAM period (e.g., VBlank).
;
; Inputs:
;   None
;
; Outputs:
;   None
;
; Preserves:
;   BC, DE, HL
;
; Destroys:
;   A, F, HL
; -----------------------------------------------------------------------------
Exit_Animate::
    ; Calculate exit tile coordinate: (2*wExitX + 1, 2*wExitY + 1)
    ld a, [wExitX]
    add a
    inc a
    ld d, a
    
    ld a, [wExitY]
    add a
    inc a
    ld e, a
    
    call GetVramAddress ; HL = VRAM address of exit

    ; Select frame index based on frame counter bit 4 (changes every 16 frames)
    ld a, [wFrameCounter]
    bit 4, a
    jr z, .frame2
    ld a, TILE_EXIT_B
    jr .write
.frame2:
    ld a, TILE_EXIT_A
.write:
    ld [hl], a
    ret
