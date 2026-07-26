; =============================================================================
; Pixel Maze GB
; File:        src/hardware/dma.asm
; Description: OAM DMA copy and transfer handling.
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

SECTION "DMAEngine", ROM0
; -----------------------------------------------------------------------------
; DMA_Init
;
; Copies the DMA transfer routine from ROM into HRAM.
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
;   A, BC, HL, F
; -----------------------------------------------------------------------------
DMA_Init::
    ld de, hDmaCode
    ld hl, DMA_CodeSource
    ld c, DMA_CodeEnd - DMA_CodeSource
.loop:
    ld a, [hli]
    ld [de], a
    inc de
    dec c
    jr nz, .loop
    ret

; This is the code template that must run in HRAM during OAM DMA.
; When rDMA is written, the CPU starts copying from WRAM to OAM, taking
; 160 microseconds (40 machine cycles). Only HRAM is readable by the CPU.
DMA_CodeSource:
    ld a, HIGH(wShadowOAM)
    ldh [rDMA], a
    ld a, 40
.waitLoop:
    dec a
    jr nz, .waitLoop
    ret
DMA_CodeEnd:
