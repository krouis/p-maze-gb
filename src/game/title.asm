; =============================================================================
; Pixel Maze GB
; File:        src/game/title.asm
; Description: Title screen initialization and input updates.
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

SECTION "TitleScreenEngine", ROM0
; --- GBC Color Palettes (15-bit color format) ---
; Background Palette 0: Green/Blue Theme
; Color 0: Pale warm background (RGB: 30, 31, 28) -> $73DE
; Color 1: Water light blue/green (RGB: 15, 24, 22) -> $5B0F
; Color 2: Deep forest green (RGB: 4, 16, 6) -> $1A04
; Color 3: Deep navy/black lettering (RGB: 2, 3, 5) -> $1462
Title_BG_Palettes:
    dw $73DE, $5B0F, $1A04, $1462

; Sprite Palette 0: Player Character Colors
; Color 0: Transparent (White)
; Color 1: Cute light body (RGB: 31, 26, 12) -> $335F
; Color 2: Dark body outline (RGB: 15, 8, 4) -> $110F
; Color 3: Black eyes (RGB: 0, 0, 0) -> $0000
Title_SP_Palettes::
    dw $7FFF, $335F, $110F, $0000

; -----------------------------------------------------------------------------
; Title_Init
;
; Disables the LCD, loads the title screen tiles and tilemap, initializes
; palettes for DMG/GBC, and resets screen scroll positions.
;
; Inputs:
;   None
;
; Outputs:
;   None
;
; Preserves:
;   None
;
; Destroys:
;   All
; -----------------------------------------------------------------------------
Title_Init::
    call LCD_Disable

    ; 1. Clear VRAM ($8000 - $9FFF)
    ld hl, $8000
    ld bc, $2000
.clearVramLoop:
    ld [hl], 0
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearVramLoop

    ; 2. Copy Title screen tiles to VRAM ($8000)
    ld hl, TitleTiles
    ld de, $8000
    ld bc, TitleTilesEnd - TitleTiles
.copyTilesLoop:
    ld a, [hli]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copyTilesLoop

    ; 3. Copy Title tilemap to Background Map ($9800) row-by-row
    ld hl, TitleTilemap
    ld de, $9800
    ld c, 18 ; 18 rows
.rowLoop:
    ld b, 20 ; 20 cols
.colLoop:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .colLoop
    ; Advance DE to next row in VRAM: add 12 (32 - 20)
    ld a, e
    add 12
    ld e, a
    ld a, d
    adc 0
    ld d, a
    dec c
    jr nz, .rowLoop

    ; 4. Reset scroll positions
    ld a, 0
    ldh [rSCX], a
    ldh [rSCY], a

    ; 5. Load Palettes
    ld a, [wIsGBC]
    or a
    jr z, .loadDMG

    ; GBC Palette Initialization
    ; Load BG Palette 0
    ld a, $80 ; Auto-increment, index 0
    ldh [rBCPS], a
    ld hl, Title_BG_Palettes
    ld c, 8 ; 4 colors * 2 bytes
.loadBGPalLoop:
    ld a, [hli]
    ldh [rBCPD], a
    dec c
    jr nz, .loadBGPalLoop

    ; Load Sprite Palette 0
    ld a, $80
    ldh [rOCPS], a
    ld hl, Title_SP_Palettes
    ld c, 8
.loadSPPalLoop:
    ld a, [hli]
    ldh [rOCPD], a
    dec c
    jr nz, .loadSPPalLoop
    jr .lcdOn

.loadDMG:
    ; DMG Palettes
    ld a, %11100100 ; Normal shading: Black, Dark Grey, Light Grey, White
    ldh [rBGP], a
    ldh [rOBP0], a

.lcdOn:
    ; 6. Turn LCD back on (Background + Sprites enabled)
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    call LCD_Enable
    
    ; Clear Shadow OAM to hide sprites during title
    ld hl, wShadowOAM
    ld bc, 160
.clearOamLoop:
    ld [hl], 0
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearOamLoop
    
    ret

; -----------------------------------------------------------------------------
; Title_Update
;
; Polls inputs. If Start, A, or a D-pad button is pressed, transitions the game
; state to prepare the first level.
;
; Inputs:
;   None
;
; Outputs:
;   None
;
; Preserves:
;   None
;
; Destroys:
;   All
; -----------------------------------------------------------------------------
Title_Update::
    ; Read inputs
    ld a, [wJoypadDown]
    or a
    ret z ; No buttons pressed

    ; Transition to LEVEL_PREPARE
    ld a, STATE_LEVEL_PREPARE
    ld [wGameState], a
    
    ; Initialize level counter
    ld a, 1
    ld [wCurrentLevel], a
    
    ; Check if wTestMagic is "PMGB" ($50, $4D, $47, $42)
    ld a, [wTestMagic]
    cp $50
    jr nz, .normalSeed
    ld a, [wTestMagic+1]
    cp $4D
    jr nz, .normalSeed
    ld a, [wTestMagic+2]
    cp $47
    jr nz, .normalSeed
    ld a, [wTestMagic+3]
    cp $42
    jr nz, .normalSeed
    jr .seedDone

.normalSeed:
    ; Seed the PRNG using the current divider register to ensure variability
    ldh a, [rDIV]
    ld l, a
    ld a, [wFrameCounter]
    ld h, a
    call RNG_Init
.seedDone:
    ret
