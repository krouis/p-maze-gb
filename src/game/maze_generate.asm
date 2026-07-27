; =============================================================================
; Pixel Maze GB
; File:        src/game/maze_generate.asm
; Description: Generates deterministic, connected mazes using an iterative
;              depth-first backtracking algorithm and places the exit.
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

SECTION "MazeGeneratorEngine", ROM0
; -----------------------------------------------------------------------------
; Maze_Generate
;
; Generates a solvable maze of size wMazeWidth x wMazeHeight using the current seed.
; Places the player at (0, 0) and the exit at the farthest reachable cell.
;
; Inputs:
;   None (reads wMazeWidth, wMazeHeight, wRngSeed)
;
; Outputs:
;   None (writes to wMazeData, wPlayerX, wPlayerY, wExitX, wExitY)
;
; Preserves:
;   None
;
; Destroys:
;   All
; -----------------------------------------------------------------------------
Maze_Generate::
    ; 1. Clear maze grid data
    ld hl, wMazeData
    ld bc, 72
.clearLoop:
    ld [hl], 0
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearLoop

    ; 2. Initialize generation state
    ld a, 0
    ld [wMazeStackPtr], a ; Stack is empty
    ld [wDebugPathPtr], a ; Reset debug pointer

    ; Total cells to visit
    ld a, [wMazeWidth]
    ld b, a
    ld a, [wMazeHeight]
    ld c, a
    call Math_Multiply8   ; A = total cells
    ld d, a               ; D = total cells count
    ld e, 1               ; E = visited cells count (start cell visited)
    push de

    ; Start cell is (0, 0)
    ld b, 0               ; B = current X
    ld c, 0               ; C = current Y
    
    ; Mark (0, 0) as visited
    call GetCellAddress   ; HL = wMazeData offset for (0, 0)
    ld [hl], CELL_VISITED

.dfsLoop:
    ; Debug trace: store current coordinates (B, C) to wDebugPath
    push hl
    push af
    ld a, [wDebugPathPtr]
    cp 64
    jr z, .debugDone ; Prevent overflow
    ld hl, wDebugPath
    add l
    ld l, a
    ld a, h
    adc 0
    ld h, a
    ld a, [wMazeWidth]
    swap a
    or b ; A = wMazeWidth<<4 | B
    ld [hl], a
    ld a, [wDebugPathPtr]
    inc a
    ld [wDebugPathPtr], a
.debugDone:
    pop af
    pop hl
    ; Check if we have visited all cells
    pop de
    push de
    ld a, e
    cp d
    jp z, .generationDone

    ; Let's clear the neighbor count
    xor a
    ldh [$FFB0], a

    ; Check North neighbor (B, C-1)
    ld a, c
    or a
    jr z, .checkEast
    dec c
    call IsCellVisited ; A = 0 if unvisited, nonzero if visited/OOB
    inc c              ; restores C, but inc/dec clobber Z -- doesn't touch A
    or a               ; re-derive Z from A (unaffected by the restore above)
    jr nz, .checkEast ; Visited
    ; Add North neighbor
    ld a, c
    dec a
    swap a
    or b           ; A = (Y-1)<<4 | X
    ld d, 0        ; D = direction (North)
    call AddNeighbor

.checkEast:
    ; Check East neighbor (B+1, C)
    ld a, [wMazeWidth]
    dec a
    cp b
    jr z, .checkSouth
    inc b
    call IsCellVisited ; A = 0 if unvisited, nonzero if visited/OOB
    dec b              ; restores B, but inc/dec clobber Z -- doesn't touch A
    or a               ; re-derive Z from A (unaffected by the restore above)
    jr nz, .checkSouth ; Visited
    ; Add East neighbor
    ld a, c
    swap a
    inc b
    or b           ; A = Y<<4 | (X+1)
    dec b
    ld d, 1        ; D = direction (East)
    call AddNeighbor

.checkSouth:
    ; Check South neighbor (B, C+1)
    ld a, [wMazeHeight]
    dec a
    cp c
    jr z, .checkWest
    inc c
    call IsCellVisited ; A = 0 if unvisited, nonzero if visited/OOB
    dec c              ; restores C, but inc/dec clobber Z -- doesn't touch A
    or a               ; re-derive Z from A (unaffected by the restore above)
    jr nz, .checkWest ; Visited
    ; Add South neighbor
    ld a, c
    inc a
    swap a
    or b           ; A = (Y+1)<<4 | X
    ld d, 2        ; D = direction (South)
    call AddNeighbor

.checkWest:
    ; Check West neighbor (B-1, C)
    ld a, b
    or a
    jr z, .neighborsCheckDone
    dec b
    call IsCellVisited ; A = 0 if unvisited, nonzero if visited/OOB
    inc b              ; restores B, but inc/dec clobber Z -- doesn't touch A
    or a               ; re-derive Z from A (unaffected by the restore above)
    jr nz, .neighborsCheckDone ; Visited
    ; Add West neighbor
    ld a, c
    swap a
    dec b
    or b           ; A = Y<<4 | (X-1)
    inc b
    ld d, 3        ; D = direction (West)
    call AddNeighbor

.neighborsCheckDone:
    ; Check count
    ldh a, [$FFB0]
    or a
    jp z, .backtrack

    ; We have unvisited neighbors!
    ; Choose one randomly. Current cell (B, C) must survive this section
    ; untouched, so the chosen index is stashed on the stack (via AF) between
    ; the two lookups instead of a register -- BC holds current X/Y and is
    ; read again right after this block to push the current cell.
    call RNG_Range ; A = chosen index (0 to count-1)
    push af        ; Save chosen index

    ; Retrieve chosen neighbor coord: $FFB1 + index
    ld hl, $FFB1
    add l
    ld l, a
    ld a, [hl]
    ld e, a        ; E = chosen neighbor coord (Y<<4 | X)

    ; Retrieve chosen direction: $FFB5 + index
    pop af         ; Restore chosen index
    ld hl, $FFB5
    add l
    ld l, a
    ld a, [hl]     ; A = chosen direction (0=N, 1=E, 2=S, 3=W)
    ld d, a        ; D = chosen direction

    ; Current X and Y are still in B, C untouched.
    
    ; 1. Push current cell onto generator stack: wMazeStack[wMazeStackPtr] = Y<<4|X.
    ; Must not touch D/E (chosen neighbor coord/direction, needed below) or B/C
    ; (current X/Y, needed below) -- only A and HL.
    ld a, [wMazeStackPtr]
    ld hl, wMazeStack
    add l
    ld l, a
    ld a, h
    adc 0
    ld h, a
    ld a, c
    swap a
    or b           ; A = Y<<4 | X (current cell)
    ld [hl], a
    ; Increment stack pointer
    ld hl, wMazeStackPtr
    inc [hl]

    ; 2. Remove walls between current cell (B, C) and neighbor cell E (NY<<4 | NX)
    ; D = direction taken (0=N, 1=E, 2=S, 3=W)
    ; Update current cell (B, C) walls
    call GetCellAddress ; HL = current cell address
    ld a, d
    cp 0
    jr nz, .notNorth
    ; Direction is North
    ld a, [hl]
    or DIR_NORTH
    ld [hl], a
    jr .updateNeighbor
.notNorth:
    cp 1
    jr nz, .notEast
    ; Direction is East
    ld a, [hl]
    or DIR_EAST
    ld [hl], a
    jr .updateNeighbor
.notEast:
    cp 2
    jr nz, .notSouth
    ; Direction is South
    ld a, [hl]
    or DIR_SOUTH
    ld [hl], a
    jr .updateNeighbor
.notSouth:
    ; Direction is West
    ld a, [hl]
    or DIR_WEST
    ld [hl], a

.updateNeighbor:
    ; Update neighbor cell (E) walls
    ; E = neighbor cell coord (NY<<4 | NX)
    push bc
    ld a, e
    and $0F
    ld b, a        ; B = neighbor X
    ld a, e
    swap a
    and $0F
    ld c, a        ; C = neighbor Y
    call GetCellAddress ; HL = neighbor cell address
    
    ; If we went North, neighbor opens South
    ; If we went East, neighbor opens West
    ; If we went South, neighbor opens North
    ; If we went West, neighbor opens East
    ld a, d
    cp 0
    jr nz, .nNotNorth
    ld a, [hl]
    or DIR_SOUTH
    ld [hl], a
    jr .neighborDone
.nNotNorth:
    cp 1
    jr nz, .nNotEast
    ld a, [hl]
    or DIR_WEST
    ld [hl], a
    jr .neighborDone
.nNotEast:
    cp 2
    jr nz, .nNotSouth
    ld a, [hl]
    or DIR_NORTH
    ld [hl], a
    jr .neighborDone
.nNotSouth:
    ld a, [hl]
    or DIR_EAST
    ld [hl], a

.neighborDone:
    ; Mark neighbor cell as visited
    ld a, [hl]
    or CELL_VISITED
    ld [hl], a
    
    pop bc         ; Restore current cell (B, C) to correspond to neighbor
    ; Make neighbor cell the new current cell
    ld a, e
    and $0F
    ld b, a        ; B = new X
    ld a, e
    swap a
    and $0F
    ld c, a        ; C = new Y

    ; Increment visited count
    pop de         ; Restore visited count E, total count D
    inc e          ; Increment visited count
    push de        ; Save back
    
    jp .dfsLoop

.backtrack:
    ; Stack empty?
    ld a, [wMazeStackPtr]
    or a
    jr z, .generationDoneStackEmpty
    
    ; Pop from stack
    dec a
    ld [wMazeStackPtr], a
    ld hl, wMazeStack
    add l
    ld l, a
    ld a, h
    adc 0
    ld h, a
    ld a, [hl]     ; A = popped coord (Y<<4 | X)
    
    ; Set popped as current
    and $0F
    ld b, a        ; B = popped X
    ld a, [hl]
    swap a
    and $0F
    ld c, a        ; C = popped Y
    
    jp .dfsLoop

.generationDoneStackEmpty:
.generationDone:
    ; Clean up stack variables
    pop de ; Restore stack-pushed DE

    ; 3. Setup player start coordinate at (0, 0)
    ld a, 0
    ld [wPlayerX], a
    ld [wPlayerY], a

    ; 4. Run Distance Propagation to find farthest cell for exit
    call Maze_PropagateDistances
    ret

; --- Helper: AddNeighbor ---
; Adds neighbor coordinate in A and direction in D to lists in HRAM
AddNeighbor:
    push hl
    push bc
    ld b, a        ; B = coord
    
    ; Coords at $FFB1 + count
    ldh a, [$FFB0] ; A = count
    ld hl, $FFB1
    add l
    ld l, a
    ld a, h
    adc 0
    ld h, a
    ld [hl], b
    
    ; Dirs at $FFB5 + count
    ldh a, [$FFB0] ; A = count
    ld hl, $FFB5
    add l
    ld l, a
    ld a, h
    adc 0
    ld h, a
    ld [hl], d
    
    ; Count++
    ldh a, [$FFB0]
    inc a
    ldh [$FFB0], a
    
    pop bc
    pop hl
    ret

; --- Helper: IsCellVisited ---
; Checks if cell at (B, C) is visited (or out of bounds).
; Returns: Z flag set if visited (or invalid), NZ if unvisited.
; Destroys: A, HL, F
IsCellVisited:
    ; Bounds check
    ld a, [wMazeWidth]
    cp b
    jr z, .visited ; Out of bounds X
    jr c, .visited
    ld a, [wMazeHeight]
    cp c
    jr z, .visited ; Out of bounds Y
    jr c, .visited

    call GetCellAddress ; HL = cell address
    ld a, [hl]
    bit VISITED_BIT, a
    ret nz ; NZ = visited (return with Z=0)
    
    ; Z=1 means unvisited! Wait, Z flag set usually means zero, i.e. NOT visited!
    ; Let's return:
    ;   Z flag set (zero) if cell is visited or out of bounds.
    ;   NZ flag set (non-zero) if cell is unvisited.
    ; If bit VISITED_BIT is set, a is non-zero, so NZ. We want to invert it:
    ; We can do:
    ;   bit VISITED_BIT, a
    ;   ret z ; if zero, it is NOT visited, return with Z=1? Wait!
    ; Let's make it simple:
    ; Return:
    ;   A = 1 if visited, A = 0 if unvisited.
    ;   Then caller does "or a" to set flags: Z if unvisited, NZ if visited.
    ; Let's write it that way, it is much less confusing!
    
    ld a, [hl]
    and CELL_VISITED
    ret

.visited:
    ld a, CELL_VISITED
    ret

; --- Helper: Math_Multiply8 ---
; Computes A = B * C
; Destroys: F
Math_Multiply8::
    push bc
    ld a, b
    or a
    jr z, .zero
    
    ld a, 0
    ld h, b
    ld l, c
.loop:
    add l
    dec h
    jr nz, .loop
    pop bc
    ret
.zero:
    xor a
    pop bc
    ret

; --- Helper: GetCellAddress ---
; Given cell coordinates (B=X, C=Y), returns its address in HL.
; Preserves: BC, DE
; Destroys: A, F, HL
GetCellAddress::
    push bc
    ld a, c
    ld b, a
    ld a, [wMazeWidth]
    ld c, a
    call Math_Multiply8 ; A = Y * wMazeWidth
    pop bc
    add b               ; A = Y * wMazeWidth + X
    ld hl, wMazeData
    add l
    ld l, a
    ld a, h
    adc 0
    ld h, a
    ret

; --- Helper: GetDistanceAddress ---
; Given cell coordinates (B=X, C=Y), returns its distance address in HL.
; Preserves: BC, DE
; Destroys: A, F, HL
GetDistanceAddress::
    push bc
    ld a, c
    ld b, a
    ld a, [wMazeWidth]
    ld c, a
    call Math_Multiply8
    pop bc
    add b
    ld hl, wMazeDistances
    add l
    ld l, a
    ld a, h
    adc 0
    ld h, a
    ret

; -----------------------------------------------------------------------------
; Maze_PropagateDistances
;
; Computes shortest path distances from (0, 0) to all cells in the maze using
; an iterative propagation algorithm. Selects the cell with the maximum distance
; as the exit (wExitX, wExitY).
;
; Destroys:
;   All
; -----------------------------------------------------------------------------
Maze_PropagateDistances:
    ; 1. Initialize distance array to 255
    ld hl, wMazeDistances
    ld bc, 72
.initLoop:
    ld [hl], 255
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .initLoop

    ; Set start cell distance to 0
    ld a, 0
    ld [wMazeDistances], a

.propagateLoop:
    ld d, 0 ; D = changed flag (0 = no changes, 1 = changes)

    ; Loop over all cells
    ld c, 0 ; C = Y (0 to wMazeHeight-1)
.yLoop:
    ld a, [wMazeHeight]
    cp c
    jr z, .yLoopEnd

    ld b, 0 ; B = X (0 to wMazeWidth-1)
.xLoop:
    ld a, [wMazeWidth]
    cp b
    jr z, .xLoopEnd

    ; Get cell address
    call GetCellAddress ; HL = wMazeData address for (B, C)
    ld a, [hl]          ; A = cell connectivity bits
    ld e, a             ; E = connectivity bits
    
    ; Get current cell distance
    call GetDistanceAddress ; HL = wMazeDistances address for (B, C)
    ld a, [hl]          ; A = distance of cell (B, C)
    ld h, a             ; H = distance of cell (B, C)
    
    ld a, h
    cp 255
    jr z, .nextCell ; If cell is unreachable/unvisited yet, skip it

    ; Propagate to North if open
    bit DIR_NORTH_BIT, e
    jr z, .checkEast
    ; Neighbor is (B, C-1)
    dec c
    ld a, h
    inc a ; A = target distance (d + 1)
    call TryUpdateDistance
    inc c

.checkEast:
    ; Propagate to East if open
    bit DIR_EAST_BIT, e
    jr z, .checkSouth
    ; Neighbor is (B+1, C)
    inc b
    ld a, h
    inc a
    call TryUpdateDistance
    dec b

.checkSouth:
    ; Propagate to South if open
    bit DIR_SOUTH_BIT, e
    jr z, .checkWest
    ; Neighbor is (B, C+1)
    inc c
    ld a, h
    inc a
    call TryUpdateDistance
    dec c

.checkWest:
    ; Propagate to West if open
    bit DIR_WEST_BIT, e
    jr z, .nextCell
    ; Neighbor is (B-1, C)
    dec b
    ld a, h
    inc a
    call TryUpdateDistance
    inc b

.nextCell:
    inc b
    jp .xLoop
.xLoopEnd:
    inc c
    jp .yLoop
.yLoopEnd:

    ; If any distance changed, repeat propagation pass
    ld a, d
    or a
    jp nz, .propagateLoop

    ; 2. Scan for maximum distance to place exit
    ld hl, wMazeDistances
    ld b, 0 ; B = current max distance
    ld d, 0 ; D = X of max
    ld e, 0 ; E = Y of max

    ld c, 0 ; Y counter
.yFind:
    ld a, [wMazeHeight]
    cp c
    jr z, .yFindEnd

    ld h, 0 ; X counter
.xFind:
    ld a, [wMazeWidth]
    cp h
    jr z, .xFindEnd

    ; Get distance of (H, C)
    push hl
    push bc
    ld b, h ; B = X
    ; C = Y
    call GetDistanceAddress
    ld a, [hl]          ; A = distance
    pop bc
    pop hl

    cp 255
    jr z, .skipFind     ; Skip unvisited/invalid

    cp b
    jr c, .skipFind     ; If dist < max, skip
    jr z, .skipFind     ; If dist == max, skip (prefer earlier ones to keep deterministic, or update. Let's keep it deterministic)
    
    ; Found new max distance
    ld b, a             ; B = new max
    ld d, h             ; D = new max X
    ld e, c             ; E = new max Y

.skipFind:
    inc h
    jr .xFind
.xFindEnd:
    inc c
    jr .yFind
.yFindEnd:

    ; Set exit position
    ld a, d
    ld [wExitX], a
    ld a, e
    ld [wExitY], a
    ret

; ; --- Helper: TryUpdateDistance ---
; Tries to update distance of cell (B, C) with value in A.
; If wMazeDistances[B, C] > A, updates it and sets changed flag D = 1.
; Preserves: A, BC, H
TryUpdateDistance:
    push hl
    push bc
    
    push af                 ; Save target distance (A) on stack
    call GetDistanceAddress ; HL = wMazeDistances address (destroys A)
    pop af                  ; A = target distance
    
    ld b, a                 ; B = target distance (BC will be restored at the end)
    ld a, [hl]              ; A = current distance
    cp b                    ; Compare current and target
    jr c, .noUpdate         ; If current < target, skip
    jr z, .noUpdate         ; If current == target, skip
    
    ; Update distance
    ld [hl], b
    ld d, 1                 ; Set changed flag to 1
    
.noUpdate:
    pop bc
    pop hl
    ret
