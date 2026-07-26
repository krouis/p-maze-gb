; =============================================================================
; Pixel Maze GB
; File:        src/game/maze_render.asm
; Description: Renders the maze grid to the VRAM background tile map.
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

SECTION "MazeRendererEngine", ROM0
; -----------------------------------------------------------------------------
; Maze_Render
;
; Renders the current maze (wMazeWidth, wMazeHeight, wMazeData) to the background
; tile map.
; NOTE: Caller must ensure the LCD is disabled or we are in a safe VRAM period.
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
Maze_Render::
    ; 1. Clear background tile map (first 20x18 area) to floor tiles
    ld c, 0 ; Y = 0 to 17
.clearY:
    ld a, 18
    cp c
    jr z, .clearDone
    ld b, 0 ; X = 0 to 19
.clearX:
    ld a, 20
    cp b
    jr z, .clearNextY

    ; Write Floor tile to (B, C)
    ld d, b
    ld e, c
    call GetVramAddress
    ld a, TILE_FLOOR
    ld [hl], a

    inc b
    jr .clearX
.clearNextY:
    inc c
    jr .clearY
.clearDone:

    ; 2. Render outer border walls
    ; Top wall: Y = 0, X from 0 to 2*wMazeWidth
    ; Left wall: X = 0, Y from 0 to 2*wMazeHeight
    ; Bottom wall: Y = 2*wMazeHeight, X from 0 to 2*wMazeWidth
    ; Right wall: X = 2*wMazeWidth, Y from 0 to 2*wMazeHeight
    
    ld a, [wMazeWidth]
    add a
    ld d, a ; D = right border X
    
    ld a, [wMazeHeight]
    add a
    ld e, a ; E = bottom border Y

    ; Draw top and bottom borders
    ld b, 0 ; X index
.borderHorizLoop:
    ld a, d
    cp b
    jr c, .borderHorizDone
    
    ; Top tile (B, 0)
    push de
    ld d, b
    ld e, 0
    call GetVramAddress
    ld a, TILE_WALL
    ld [hl], a
    pop de

    ; Bottom tile (B, E)
    push de
    ld d, b
    ; E has bottom border Y
    call GetVramAddress
    ld a, TILE_WALL
    ld [hl], a
    pop de

    inc b
    jr .borderHorizLoop
.borderHorizDone:

    ; Draw left and right borders
    ld c, 0 ; Y index
.borderVertLoop:
    ld a, e
    cp c
    jr c, .borderVertDone

    ; Left tile (0, C)
    push de
    ld d, 0
    ld e, c
    call GetVramAddress
    ld a, TILE_WALL
    ld [hl], a
    pop de

    ; Right tile (D, C)
    push de
    ; D has right border X
    ld e, c
    call GetVramAddress
    ld a, TILE_WALL
    ld [hl], a
    pop de

    inc c
    jr .borderVertLoop
.borderVertDone:

    ; 3. Render interior cell walls and corners
    ld c, 0 ; Cell Y = 0 to wMazeHeight-1
.yLoop:
    ld a, [wMazeHeight]
    cp c
    jr z, .renderDone

    ld b, 0 ; Cell X = 0 to wMazeWidth-1
.xLoop:
    ld a, [wMazeWidth]
    cp b
    jr z, .nextY

    ; Render cell borders and corner intersections
    ; Tile coord: tx = 2*b + 1, ty = 2*c + 1
    ld a, b
    add a
    inc a
    ld d, a ; D = tx
    
    ld a, c
    add a
    inc a
    ld e, a ; E = ty

    ; Get cell connectivity
    push de
    call GetCellAddress ; HL = cell data address
    ld a, [hl]
    ld l, a ; L = cell data bits
    pop de

    ; North Wall: if bit 0 is closed (0), draw wall at (tx, ty - 1)
    bit DIR_NORTH_BIT, l
    jr nz, .checkEast
    push de
    dec e
    call GetVramAddress
    ld a, TILE_WALL
    ld [hl], a
    pop de

.checkEast:
    ; East Wall: if bit 1 is closed (0), draw wall at (tx + 1, ty)
    bit DIR_EAST_BIT, l
    jr nz, .checkSouth
    push de
    inc d
    call GetVramAddress
    ld a, TILE_WALL
    ld [hl], a
    pop de

.checkSouth:
    ; South Wall: if bit 2 is closed (0), draw wall at (tx, ty + 1)
    bit DIR_SOUTH_BIT, l
    jr nz, .checkWest
    push de
    inc e
    call GetVramAddress
    ld a, TILE_WALL
    ld [hl], a
    pop de

.checkWest:
    ; West Wall: if bit 3 is closed (0), draw wall at (tx - 1, ty)
    bit DIR_WEST_BIT, l
    jr nz, .drawCorners
    push de
    dec d
    call GetVramAddress
    ld a, TILE_WALL
    ld [hl], a
    pop de

.drawCorners:
    ; Corner intersections are always solid walls
    ; Corner (tx+1, ty+1)
    push de
    inc d
    inc e
    call GetVramAddress
    ld a, TILE_WALL
    ld [hl], a
    pop de

    inc b
    jp .xLoop
.nextY:
    inc c
    jp .yLoop
.renderDone:

    ; 4. Render Exit portal tile at exit coordinates
    ; Exit cell (wExitX, wExitY) -> tile (2*wExitX + 1, 2*wExitY + 1)
    ld a, [wExitX]
    add a
    inc a
    ld d, a
    
    ld a, [wExitY]
    add a
    inc a
    ld e, a
    
    call GetVramAddress
    ld a, TILE_EXIT_A
    ld [hl], a
    ret

; -----------------------------------------------------------------------------
; GetVramAddress
;
; Calculates background tile map VRAM address for screen coordinates (D=X, E=Y).
; Background map starts at $9800 and is 32 tiles wide.
;
; Inputs:
;   D = X tile coordinate (0 to 31)
;   E = Y tile coordinate (0 to 31)
;
; Outputs:
;   HL = VRAM tile address ($9800 + Y * 32 + X)
;
; Preserves:
;   BC, DE
;
; Destroys:
;   A, F, HL
; -----------------------------------------------------------------------------
GetVramAddress::
    ld h, 0
    ld l, e
    
    ; Multiply by 32 (shift left 5 times)
    add hl, hl ; *2
    add hl, hl ; *4
    add hl, hl ; *8
    add hl, hl ; *16
    add hl, hl ; *32
    
    ld a, d
    add l
    ld l, a
    ld a, h
    adc $98 ; $9800 base
    ld h, a
    ret
