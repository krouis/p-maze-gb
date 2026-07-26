; =============================================================================
; Pixel Maze GB
; File:        src/memory/wram.asm
; Description: Work RAM (WRAM) memory variables allocation.
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

SECTION "EngineVariables", WRAM0

wGameState::          ds 1 ; Current state of game flow
wIsGBC::              ds 1 ; GBC hardware detected boolean (0=DMG, 1=GBC)
wFrameCounter::       ds 1 ; General frame tick counter incremented in VBlank
wRngSeed::            ds 2 ; 16-bit PRNG seed state

; --- Input System ---
wJoypadState::        ds 1 ; Current buttons held down
wJoypadPrevState::    ds 1 ; Previous frame buttons held down
wJoypadDown::         ds 1 ; Buttons pressed this frame (just went down)
wInputRepeatTimer::   ds 1 ; Counts down to next repeat move when D-pad held
wInputRepeatActive::  ds 1 ; Flag: 0 = initial delay, 1 = repeat rate interval
wInputLastDir::       ds 1 ; Last direction button pressed for repeat

; --- Gameplay state ---
wCurrentLevel::       ds 1 ; Current level index (starts at 1)
wMazeWidth::          ds 1 ; Current maze width (in cells)
wMazeHeight::         ds 1 ; Current maze height (in cells)
wPlayerX::            ds 1 ; Logical player X coordinate (0 to wMazeWidth-1)
wPlayerY::            ds 1 ; Logical player Y coordinate (0 to wMazeHeight-1)
wExitX::              ds 1 ; Logical exit X coordinate (0 to wMazeWidth-1)
wExitY::              ds 1 ; Logical exit Y coordinate (0 to wMazeHeight-1)

; --- Gameplay Animation/Control ---
wLastCollisionResult::ds 1 ; 0 = normal move, 1 = hit a wall
wCollisionTimer::     ds 1 ; Non-zero activates wall bump squash animation
wCelebrationTimer::   ds 1 ; Non-zero blocks input and animates level transition
wTitleAnimationTimer::ds 1 ; Title screen logo shimmer animation timer

; --- Test Instrumentation ---
; Exposing a test block at a fixed WRAM address is done via separate test sections,
; but we declare these variables for compatibility.
wTestMagic::          ds 4 ; Test harness magic sequence
wMoveCount::          ds 1 ; Movement counter for test validation
wCompletionCount::    ds 1 ; Completed levels count for test validation

; --- Maze Connectivity Grid ---
; Maze cells are 9 columns x 8 rows maximum = 72 bytes.
; Each cell byte stores open directions (Bits 0-3: N, E, S, W) and Visited state.
wMazeData::           ds 72 
wMazeDataEnd::

; Stack for iterative DFS maze generation
wMazeStack::          ds 72
wMazeStackPtr::       ds 1

; Distance array for exit placement (BFS/Bellman-Ford propagation)
wMazeDistances::      ds 72

; Debug trace variables
wDebugPath::          ds 64
wDebugPathPtr::       ds 1

SECTION "ShadowOAM", WRAM0, ALIGN[8]
wShadowOAM::          ds 160 ; Shadow OAM copied to hardware OAM in DMA
wShadowOAMEnd::
