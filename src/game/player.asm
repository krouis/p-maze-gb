; =============================================================================
; Pixel Maze GB
; File:        src/game/player.asm
; Description: Player sprite position calculations and animations.
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

SECTION "PlayerEngine", ROM0

; --- Sprite Tile Indices ---
DEF SPRITE_PLAYER_IDLE1   EQU $04
DEF SPRITE_PLAYER_IDLE2   EQU $05
DEF SPRITE_PLAYER_SQUASH  EQU $06
DEF SPRITE_PLAYER_HAPPY   EQU $07

; -----------------------------------------------------------------------------
; Player_Update
;
; Updates player animations (bump timer, win/celebration timer).
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
;   A, F
; -----------------------------------------------------------------------------
Player_Update::
    ; Handle collision/bump squash timer
    ld a, [wCollisionTimer]
    or a
    jr z, .checkCelebration
    dec a
    ld [wCollisionTimer], a

.checkCelebration:
    ; Handle celebration/win timer
    ld a, [wCelebrationTimer]
    or a
    ret z
    dec a
    ld [wCelebrationTimer], a
    ret

; -----------------------------------------------------------------------------
; Player_Draw
;
; Computes the player's pixel position and updates sprite 0 in wShadowOAM.
; Cleans up and hides all other sprite slots.
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
;   A, F
; -----------------------------------------------------------------------------
Player_Draw::
    ; 1. Calculate X and Y coordinates in OAM
    ; OAM X = 16 * wPlayerX + 16
    ld a, [wPlayerX]
    swap a              ; Multiply by 16 (since X < 16, swap shifts left 4 bits)
    and $F0
    add 16
    ld [wShadowOAM + 1], a ; Set Sprite 0 X

    ; OAM Y = 16 * wPlayerY + 24
    ld a, [wPlayerY]
    swap a
    and $F0
    add 24
    ld [wShadowOAM + 0], a ; Set Sprite 0 Y

    ; 2. Determine which tile to draw based on animation state
    ld a, [wCelebrationTimer]
    or a
    jr z, .noCelebration
    
    ; Drawing happy frame
    ld a, SPRITE_PLAYER_HAPPY
    jr .setTile

.noCelebration:
    ld a, [wCollisionTimer]
    or a
    jr z, .noCollision
    
    ; Drawing squash frame
    ld a, SPRITE_PLAYER_SQUASH
    jr .setTile

.noCollision:
    ; Idle animation: alternate between Idle1 and Idle2 based on wFrameCounter bit 5
    ld a, [wFrameCounter]
    bit 5, a ; Changes state every 32 frames (~0.5s)
    jr z, .idle2
    ld a, SPRITE_PLAYER_IDLE1
    jr .setTile
.idle2:
    ld a, SPRITE_PLAYER_IDLE2

.setTile:
    ld [wShadowOAM + 2], a ; Set Sprite 0 Tile
    
    ; Set attributes (palette 0, low priority, no flip)
    ld a, 0
    ld [wShadowOAM + 3], a ; Set Sprite 0 Attributes

    ; 3. Hide all other sprites (Sprites 1 to 39)
    ; Write Y = 0 to entries wShadowOAM + 4, 8, 12, ..., 156
    ld hl, wShadowOAM + 4
    ld c, 39 ; 39 sprites to hide
.hideLoop:
    ld [hl], 0 ; Set Y = 0 (hides the sprite)
    
    ; Advance by 4 bytes (next sprite entry)
    ld a, l
    add 4
    ld l, a
    ld a, h
    adc 0
    ld h, a
    
    dec c
    jr nz, .hideLoop
    ret
