; =============================================================================
; Pixel Maze GB
; File:        src/main.asm
; Description: Main entry point, ROM header, initialization, and game loop.
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

; --- Header Entry Point ---
SECTION "HeaderEntry", ROM0[$0100]
    nop
    jp Init

; --- Cartridge Header ---
; Handled by rgbfix, but we declare space here to preserve alignment
SECTION "HeaderInfo", ROM0[$0104]
    ds $150 - $104

; --- Game Code Section ---
SECTION "MainEngine", ROM0

; GBC Palette Table (Background Palette 0)
; Index = (wCurrentLevel % 4) * 8
Gameplay_BG_Palettes:
    ; Theme 0: Green/Blue (Default)
    dw $73DE, $5B0F, $1A04, $1462
    ; Theme 1: Soft Cyan/Indigo
    dw $7BDE, $4B7F, $1A54, $0C2A
    ; Theme 2: Soft Orange/Warm Brown
    dw $77BE, $5AD7, $218A, $0C44
    ; Theme 3: Peaceful Lilac/Violet
    dw $7BDE, $525B, $2150, $0808

Init::
    di
    ld sp, $FFFE ; Set stack pointer

    ; Save the boot ROM's hardware-ID byte (in A) in E. wIsGBC lives inside
    ; WRAM_START..WRAM_START+$1000, which we're about to zero below, so the
    ; detection flag must be computed and stored *after* that clear, not
    ; before -- otherwise the clear loop immediately wipes it back to 0.
    ld e, a

    ; Disable boot ROM mapping to expose cartridge interrupt vectors
    ld a, 1
    ldh [rBOOT], a

    ; Clear WRAM variables ($C000 to $D000)
    ld hl, WRAM_START
    ld bc, $1000
.clearWram:
    ld [hl], 0
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearWram

    ; Clear HRAM variables ($FF80 to $FFFE)
    ld hl, HRAM_START
    ld c, $7E
.clearHram:
    ld [hl], 0
    inc hl
    dec c
    jr nz, .clearHram

    ; Store GBC detection flag now that WRAM has been cleared. The boot ROM
    ; leaves $11 in A on CGB/AGB hardware, $01 on DMG/SGB, and $FF on
    ; MGB/SGB2 -- only $11 means color hardware is present.
    ld a, e
    cp $11
    jr nz, .dmg
    ld a, 1
    jr .setMode
.dmg:
    ld a, 0
.setMode:
    ld [wIsGBC], a

    ; Initialize OAM DMA routine in HRAM
    call DMA_Init

    ; Set initial game state to BOOT
    ld a, STATE_BOOT
    ld [wGameState], a

    ; Go to Title Screen
    call Title_Init
    ld a, STATE_TITLE
    ld [wGameState], a

    ; Enable VBlank Interrupt
    ld a, IEF_VBLANK
    ldh [rIE], a
    ei

MainLoop:
    ; Wait for VBlank frame tick using halt
    ld a, [wFrameCounter]
    ld b, a
.waitVBlank:
    halt
    ld a, [wFrameCounter]
    cp b
    jr z, .waitVBlank

    ; Read joypad buttons
    call Joypad_Update

    ; Dispatch based on current game state
    ld a, [wGameState]
    
    cp STATE_TITLE
    jr nz, .notTitle
    call Title_Update
    jp .loopEnd

.notTitle:
    cp STATE_LEVEL_PREPARE
    jr nz, .notPrepare
    call PrepareLevel
    jp .loopEnd

.notPrepare:
    cp STATE_LEVEL_PLAY
    jr nz, .notPlay
    call PlayLevel
    jp .loopEnd

.notPlay:
    cp STATE_LEVEL_COMPLETE
    jr nz, .notComplete
    call CompleteLevel
    jp .loopEnd

.notComplete:
    cp STATE_PAUSED
    jr nz, .loopEnd
    call PausedLevel

.loopEnd:
    jp MainLoop

; -----------------------------------------------------------------------------
; PrepareLevel
;
; Disables the LCD, generates the maze based on difficulty, copies gameplay tiles
; to VRAM, renders the map, prints the level text, resets player position, and
; enables the screen.
; -----------------------------------------------------------------------------
PrepareLevel:
    call LCD_Disable

    ; 1. Clear VRAM
    ld hl, $8000
    ld bc, $2000
.clearLoop:
    ld [hl], 0
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearLoop

    ; 2. Determine maze size based on level progression
    call Progression_GetSize ; Returns B = width, C = height
    ld a, b
    ld [wMazeWidth], a
    ld a, c
    ld [wMazeHeight], a

    ; 3. Generate procedural maze
    call Maze_Generate

    ; 4. Copy gameplay tiles to VRAM ($8000)
    ld hl, GameplayTiles
    ld de, $8000
    ld bc, GameplayTilesEnd - GameplayTiles
.copyTilesLoop:
    ld a, [hli]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copyTilesLoop

    ; 5. Render maze layout to VRAM background
    call Maze_Render

    ; 6. Draw Level Number "LV XX" at (1, 0) to (5, 0)
    ; Letter L = 8, V = 9, Space = 1, d = 15+d
    ld hl, $9801
    ld [hl], 8   ; L
    inc hl
    ld [hl], 9   ; V
    inc hl
    ld [hl], 1   ; Space
    
    ; Convert wCurrentLevel to BCD (0-99) and write tiles
    ld a, [wCurrentLevel]
    ld c, 0      ; Tens digit
.tensLoop:
    cp 10
    jr c, .tensDone
    sub 10
    inc c
    jr .tensLoop
.tensDone:
    ; C = Tens digit, A = Units digit
    inc hl
    ld b, a      ; Save units in B
    ld a, 15     ; Tile index '0'
    add c
    ld [hli], a  ; Write tens digit
    ld a, 15
    add b
    ld [hl], a   ; Write units digit

    ; 7. Load Palettes for GBC or DMG
    ld a, [wIsGBC]
    or a
    jr z, .dmgPal

    ; Load BG Palette 0 depending on level theme (wCurrentLevel % 4)
    ld a, [wCurrentLevel]
    dec a ; Make 0-indexed
    and 3 ; Modulo 4
    ; Multiply by 8 (4 colors * 2 bytes = 8 bytes per palette)
    add a
    add a
    add a
    ld e, a
    ld d, 0
    ld hl, Gameplay_BG_Palettes
    add hl, de

    ld a, $80 ; Background palette 0, auto-increment
    ldh [rBCPS], a
    ld c, 8
.loadBGPalLoop:
    ld a, [hli]
    ldh [rBCPD], a
    dec c
    jr nz, .loadBGPalLoop

    ; Load Sprite Palette 0 (Player)
    ld a, $80 ; Sprite palette 0, auto-increment
    ldh [rOCPS], a
    ld hl, Title_SP_Palettes
    ld c, 8
.loadSPPalLoop:
    ld a, [hli]
    ldh [rOCPD], a
    dec c
    jr nz, .loadSPPalLoop
    jr .lcdOn

.dmgPal:
    ld a, %11100100
    ldh [rBGP], a
    ldh [rOBP0], a

.lcdOn:
    ; 8. Clear Shadow OAM and position player
    ld hl, wShadowOAM
    ld bc, 160
.clearOamLoop:
    ld [hl], 0
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearOamLoop

    call Player_Draw

    ; 9. Enable LCD
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    call LCD_Enable

    ; 10. Transition to Play state
    ld a, STATE_LEVEL_PLAY
    ld [wGameState], a
    ret

; -----------------------------------------------------------------------------
; PlayLevel
;
; Handles player animation, exit animation, movement input checks, wall collision
; checks, and pause button checks.
; -----------------------------------------------------------------------------
PlayLevel:
    call Player_Update
    call Exit_Animate

    ; 1. Check Pause command (Start button)
    ld a, [wJoypadDown]
    bit 7, a ; Start button
    jr z, .noPause
    
    ; Draw "PAUSE" text
    ld a, 1
    call Pause_DrawText
    ld a, STATE_PAUSED
    ld [wGameState], a
    ret

.noPause:
    ; 2. Check input repeat timings for press-and-hold movement
    call HandleMovementInput

    ; 3. Draw player sprite
    call Player_Draw
    ret

; -----------------------------------------------------------------------------
; CompleteLevel
;
; Animates player celebration state and advances to preparation state of next
; level when celebration timer finishes.
; -----------------------------------------------------------------------------
CompleteLevel:
    call Player_Update
    call Exit_Animate
    call Player_Draw

    ld a, [wCelebrationTimer]
    or a
    ret nz ; Wait for timer to finish

    ; Set state to preparation
    ld a, STATE_LEVEL_PREPARE
    ld [wGameState], a
    ret

; -----------------------------------------------------------------------------
; PausedLevel
;
; Checks if Start or A is pressed to resume the game.
; -----------------------------------------------------------------------------
PausedLevel:
    ld a, [wJoypadDown]
    and (PADF_START | PADF_A)
    ret z ; Neither pressed

    ; Clear "PAUSE" text
    ld a, 0
    call Pause_DrawText
    
    ; Resume
    ld a, STATE_LEVEL_PLAY
    ld [wGameState], a
    ret

; -----------------------------------------------------------------------------
; HandleMovementInput
;
; Reads D-pad taps and press-and-hold repeat states. If a valid direction is
; triggered, validates collision and updates coordinates.
; -----------------------------------------------------------------------------
HandleMovementInput:
    ld a, [wJoypadState]
    and $0F ; Check only D-pad buttons (Down, Up, Left, Right)
    jr nz, .dirHeld

    ; No direction buttons held, reset repeat variables
    ld a, 0
    ld [wInputRepeatTimer], a
    ld [wInputRepeatActive], a
    ld [wInputLastDir], a
    
    ; Read discrete taps from wJoypadDown
    ld a, [wJoypadDown]
    and $0F
    ret z ; No D-pad taps either

    ; Find which button was tapped
    ld b, a
    call GetDirectionFromMask
    ; B = direction index (0=N, 1=E, 2=S, 3=W)
    ld a, b
    ld [wInputLastDir], a
    jp TriggerMove

.dirHeld:
    ; A D-pad button is held down. Find its direction mask and index.
    ld b, a
    call GetDirectionFromMask ; B = direction index (0=N, 1=E, 2=S, 3=W)
    
    ; Check if this is a new direction or the same as the last held
    ld a, [wInputLastDir]
    cp b
    jr z, .sameDir
    
    ; New direction held, trigger immediately and initialize repeat timer
    ld a, b
    ld [wInputLastDir], a
    ld a, 0
    ld [wInputRepeatActive], a
    ld a, 20 ; 20 frames initial delay
    ld [wInputRepeatTimer], a
    jp TriggerMove

.sameDir:
    ; Same direction held, update timer
    ld a, [wInputRepeatTimer]
    or a
    jr z, .timerExpired
    dec a
    ld [wInputRepeatTimer], a
    ret

.timerExpired:
    ; Timer expired, trigger another move
    ld a, [wInputRepeatActive]
    or a
    jr nz, .intervalMode
    
    ; Transition from initial delay to repeat interval mode
    ld a, 1
    ld [wInputRepeatActive], a
.intervalMode:
    ld a, 6 ; Repeat every 6 frames
    ld [wInputRepeatTimer], a
    jp TriggerMove

; --- Helper: GetDirectionFromMask ---
; Translates button mask in B to direction index (0=N, 1=E, 2=S, 3=W) in B
GetDirectionFromMask:
    bit 2, b ; Up
    jr z, .notUp
    ld b, 0
    ret
.notUp:
    bit 0, b ; Right
    jr z, .notRight
    ld b, 1
    ret
.notRight:
    bit 3, b ; Down
    jr z, .notDown
    ld b, 2
    ret
.notDown:
    ld b, 3 ; Left (must be left)
    ret

; --- Helper: TriggerMove ---
; Processes move in direction B (0=N, 1=E, 2=S, 3=W)
TriggerMove:
    ; Get current coordinates
    ld a, [wPlayerX]
    ld d, a        ; D = X
    ld a, [wPlayerY]
    ld e, a        ; E = Y

    ; Calculate target coordinates
    ld a, b
    cp 0
    jr nz, .mNotNorth
    dec e          ; Target Y - 1
    jr .checkCollision
.mNotNorth:
    cp 1
    jr nz, .mNotEast
    inc d          ; Target X + 1
    jr .checkCollision
.mNotEast:
    cp 2
    jr nz, .mNotSouth
    inc e          ; Target Y + 1
    jr .checkCollision
.mNotSouth:
    dec d          ; Target X - 1

.checkCollision:
    ; Call collision check
    ld a, b        ; A = direction
    push bc
    push de
    ld b, d
    ld c, e        ; Wait, Maze_CanMove inputs are B=currentX, C=currentY
    pop de
    push de
    ld a, [wPlayerX]
    ld b, a
    ld a, [wPlayerY]
    ld c, a        ; B = currentX, C = currentY
    ld a, [wInputLastDir] ; Restore direction index into A
    call Maze_CanMove
    pop de
    pop bc

    or a
    jr z, .hitWall

    ; Movement allowed, update player coordinates
    ld a, d
    ld [wPlayerX], a
    ld a, e
    ld [wPlayerY], a
    
    ; Reset collision status
    ld a, 0
    ld [wLastCollisionResult], a
    
    ; Increment test move counter
    ld hl, wMoveCount
    inc [hl]

    ; Check if reached exit
    ld a, [wExitX]
    ld h, a
    ld a, [wPlayerX]
    cp h
    ret nz
    
    ld a, [wExitY]
    ld h, a
    ld a, [wPlayerY]
    cp h
    ret nz

    ; Reached exit!
    ld a, STATE_LEVEL_COMPLETE
    ld [wGameState], a
    
    ; Increment levels completed count
    ld hl, wCompletionCount
    inc [hl]
    
    ; Reset timers and level counter
    ld a, 90
    ld [wCelebrationTimer], a
    ld hl, wCurrentLevel
    inc [hl]
    ret

.hitWall:
    ; Blocked, set squash timer and last collision flag
    ld a, 10
    ld [wCollisionTimer], a
    ld a, 1
    ld [wLastCollisionResult], a
    ret
