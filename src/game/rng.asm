; =============================================================================
; Pixel Maze GB
; File:        src/game/rng.asm
; Description: Deterministic Linear Congruential Generator (LCG) PRNG.
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

SECTION "RngEngine", ROM0

; -----------------------------------------------------------------------------
; RNG_Init
;
; Initializes the PRNG seed. If the seed is zero, it mixes in the divider
; register to provide entropy.
;
; Inputs:
;   HL = initial seed value (0 to use hardware timer)
;
; Outputs:
;   None
;
; Preserves:
;   BC, DE
;
; Destroys:
;   A, HL, F
; -----------------------------------------------------------------------------
RNG_Init::
    ld a, h
    or l
    jr nz, .setSeed
    
    ; Seed is zero, mix in rDIV
    ldh a, [rDIV]
    ld l, a
    ldh a, [rDIV]
    ld h, a
    ; Make sure it's not zero
    ld a, h
    or l
    jr nz, .setSeed
    ld hl, $1337 ; Fallback seed if everything is zero
.setSeed:
    ld a, l
    ld [wRngSeed], a
    ld a, h
    ld [wRngSeed + 1], a
    ret

; -----------------------------------------------------------------------------
; RNG_Next
;
; Generates the next 16-bit pseudo-random number using LCG: seed = (seed * 5) + 1.
; This has a guaranteed full period of 65536 steps.
;
; Inputs:
;   None (reads wRngSeed)
;
; Outputs:
;   HL = 16-bit random value
;
; Preserves:
;   BC, DE
;
; Destroys:
;   A, F
; -----------------------------------------------------------------------------
RNG_Next::
    ld a, [wRngSeed]
    ld l, a
    ld a, [wRngSeed + 1]
    ld h, a

    ; Multiply HL by 5: HL = (HL * 4) + HL
    ld d, h
    ld e, l     ; DE = HL
    add hl, hl  ; HL = HL * 2
    add hl, hl  ; HL = HL * 4
    add hl, de  ; HL = HL * 5

    ; Add 1
    inc hl

    ; Store seed back
    ld a, l
    ld [wRngSeed], a
    ld a, h
    ld [wRngSeed + 1], a
    ret

; -----------------------------------------------------------------------------
; RNG_Range
;
; Generates a random number in range [0, A - 1] (0 to A-1).
;
; Inputs:
;   A = upper bound limit (1 to 255)
;
; Outputs:
;   A = random number in range [0, A - 1]
;
; Preserves:
;   BC, DE, HL
;
; Destroys:
;   F
; -----------------------------------------------------------------------------
RNG_Range::
    push hl
    push bc
    ld c, a       ; C = limit (divisor)
    
    ; Get next random number
    call RNG_Next ; HL = 16-bit random
    
    ; Perform division/modulo: H modulo C
    ld a, h       ; A = dividend
.modLoop:
    cp c
    jr c, .done
    sub c
    jr .modLoop

.done:
    pop bc
    pop hl
    ret
