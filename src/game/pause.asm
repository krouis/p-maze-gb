; =============================================================================
; Pixel Maze GB
; File:        src/game/pause.asm
; Description: Handles pause state rendering transitions.
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

SECTION "PauseEngine", ROM0

; --- Tile Index Constants (from generate_gameplay_tiles.py) ---
DEF TILE_P          EQU 10
DEF TILE_A          EQU 11
DEF TILE_U          EQU 12
DEF TILE_S          EQU 13
DEF TILE_E          EQU 14
DEF TILE_FLR        EQU 1

; -----------------------------------------------------------------------------
; Pause_DrawText
;
; Draws or clears the "PAUSE" text in the center of the top row (tile row 0).
; NOTE: Caller must ensure the LCD is disabled or we are in a safe VRAM period
; (e.g. VBlank).
;
; Inputs:
;   A = 1 to show PAUSE, 0 to clear/hide it
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
Pause_DrawText::
    or a
    jr z, .clearPause

    ; Draw "PAUSE" at (7, 0) to (11, 0)
    ld hl, $9807 ; Background map row 0, col 7
    ld [hl], TILE_P
    inc hl
    ld [hl], TILE_A
    inc hl
    ld [hl], TILE_U
    inc hl
    ld [hl], TILE_S
    inc hl
    ld [hl], TILE_E
    ret

.clearPause:
    ; Clear by writing TILE_FLR to (7, 0) to (11, 0)
    ld hl, $9807
    ld a, TILE_FLR
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hl], a
    ret
