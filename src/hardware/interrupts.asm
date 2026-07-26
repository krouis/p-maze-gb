; =============================================================================
; Pixel Maze GB
; File:        src/hardware/interrupts.asm
; Description: Interrupt vectors and service routines.
;
; Copyright (C) 2026 Oasis Loop Labs
;
; This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the Free
; Software Foundation; version 2 of the License.
;
; SPDX-License-Identifier: GPL-2.0-only
; =============================================================================

SECTION "Rst00_Vector", ROM0[$0000]
    jp Init

SECTION "VBlank_Vector", ROM0[$0040]
    jp VBlank_ISR

SECTION "LcdStat_Vector", ROM0[$0048]
    reti

SECTION "Timer_Vector", ROM0[$0050]
    reti

SECTION "Serial_Vector", ROM0[$0058]
    reti

SECTION "Joypad_Vector", ROM0[$0060]
    reti

SECTION "InterruptHandlers", ROM0

; -----------------------------------------------------------------------------
; VBlank_ISR
;
; Interrupt Service Routine for the VBlank interrupt. Increments the frame
; counter, performs OAM DMA transfer via HRAM, and handles background processes.
;
; Destroyed:
;   None (registers saved and restored)
; -----------------------------------------------------------------------------
VBlank_ISR:
    push af
    push bc
    push de
    push hl

    ; Increment frame counter
    ld hl, wFrameCounter
    inc [hl]

    ; Perform OAM DMA copy from shadow OAM to real OAM.
    ; This must run from HRAM, so we call hDmaCode.
    call hDmaCode

    pop hl
    pop de
    pop bc
    pop af
    reti
