; =============================================================================
; Pixel Maze GB
; File:        src/hardware/joypad.asm
; Description: Controller joypad polling utilities.
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

SECTION "JoypadEngine", ROM0
; -----------------------------------------------------------------------------
; Joypad_Update
;
; Polls the Game Boy joypad hardware, updates input state variables.
; Handles contact bounce by reading multiple times.
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
Joypad_Update::
    ; Read D-pad (bit 4 of rJOYP is cleared to select D-pad)
    ld a, $20
    ldh [rJOYP], a
    ldh a, [rJOYP]
    ldh a, [rJOYP] ; Wait a few cycles for lines to stabilize
    cpl            ; Complement bits so 1 = pressed, 0 = not pressed
    and $0F        ; We only care about lower nibble (Down, Up, Left, Right)
    ld d, a        ; Store temporarily in D (low nibble)

    ; Read buttons (bit 5 of rJOYP is cleared to select buttons)
    ld a, $10
    ldh [rJOYP], a
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    ldh a, [rJOYP]
    cpl
    and $0F        ; We only care about lower nibble (Start, Select, B, A)
    swap a         ; Put in high nibble of A
    or d           ; Combine D-pad (low nibble) and buttons (high nibble)
    ld d, a        ; D now has the complete current joypad state

    ; Reset joypad hardware lines
    ld a, $30
    ldh [rJOYP], a

    ; Update joypad variables in memory
    ld a, [wJoypadState]
    ld [wJoypadPrevState], a ; Save previous state
    ld a, d
    ld [wJoypadState], a     ; Save current state

    ; Compute just-pressed buttons: wJoypadDown = wJoypadState & ~wJoypadPrevState
    ld e, a                  ; E = current state
    ld a, [wJoypadPrevState]
    cpl                      ; A = ~previous state
    and e                    ; A = current & ~previous
    ld [wJoypadDown], a      ; Save just-pressed state
    ret
