; =============================================================================
; Pixel Maze GB
; File:        src/hardware/lcd.asm
; Description: LCD control utility functions.
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

SECTION "LCDEngine", ROM0
; -----------------------------------------------------------------------------
; LCD_Disable
;
; Disables the LCD display safely by waiting for VBlank first to avoid hardware
; damage.
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
LCD_Disable::
    ; Check if LCD is already off
    ldh a, [rLCDC]
    bit 7, a
    ret z ; If LCDC bit 7 is 0, it's already off

.waitVBlank:
    ldh a, [rLY]
    cp 144
    jr c, .waitVBlank

    ; Turn off LCD
    ld a, 0
    ldh [rLCDC], a
    ret

; -----------------------------------------------------------------------------
; LCD_Enable
;
; Enables the LCD with sprites and background enabled.
;
; Inputs:
;   A = LCDC bits configuration
;
; Outputs:
;   None
;
; Preserves:
;   BC, DE, HL
;
; Destroys:
;   F
; -----------------------------------------------------------------------------
LCD_Enable::
    ldh [rLCDC], a
    ret
