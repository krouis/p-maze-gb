; =============================================================================
; Pixel Maze GB
; File:        src/hardware/constants.inc
; Description: Game Boy hardware register and memory addresses.
;
; Copyright (C) 2026 Oasis Loop Labs
;
; This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the Free
; Software Foundation; version 2 of the License.
;
; SPDX-License-Identifier: GPL-2.0-only
; =============================================================================

    IF !DEF(HARDWARE_CONSTANTS_INC)
DEF HARDWARE_CONSTANTS_INC EQU 1

; --- Memory Regions ---
DEF VRAM_START      EQU $8000
DEF VRAM_END        EQU $9FFF
DEF OAM_START       EQU $FE00
DEF OAM_END         EQU $FE9F
DEF WRAM_START      EQU $C000
DEF WRAM_END        EQU $DFFF
DEF HRAM_START      EQU $FF80
DEF HRAM_END        EQU $FFFE

; --- Hardware Registers ---
DEF rJOYP           EQU $FF00 ; Joypad (R/W)
DEF rSB             EQU $FF01 ; Serial transfer data (R/W)
DEF rSC             EQU $FF02 ; Serial transfer control (R/W)
DEF rDIV            EQU $FF04 ; Divider register (R/W)
DEF rTIMA           EQU $FF05 ; Timer counter (R/W)
DEF rTMA            EQU $FF06 ; Timer modulo (R/W)
DEF rTAC            EQU $FF07 ; Timer control (R/W)
DEF rIF             EQU $FF0F ; Interrupt Flag (R/W)

; --- Sound Registers ---
DEF rNR10           EQU $FF10 ; Channel 1 Sweep register (R/W)
DEF rNR11           EQU $FF11 ; Channel 1 Sound Length/Wave Pattern Duty (R/W)
DEF rNR12           EQU $FF12 ; Channel 1 Volume Envelope (R/W)
DEF rNR13           EQU $FF13 ; Channel 1 Frequency low (W)
DEF rNR14           EQU $FF14 ; Channel 1 Frequency high (R/W)
DEF rNR21           EQU $FF16 ; Channel 2 Sound Length/Wave Pattern Duty (R/W)
DEF rNR22           EQU $FF17 ; Channel 2 Volume Envelope (R/W)
DEF rNR23           EQU $FF18 ; Channel 2 Frequency low (W)
DEF rNR24           EQU $FF19 ; Channel 2 Frequency high (R/W)
DEF rNR30           EQU $FF1A ; Channel 3 Sound on/off (R/W)
DEF rNR31           EQU $FF1B ; Channel 3 Sound Length (W)
DEF rNR32           EQU $FF1C ; Channel 3 Select output level (R/W)
DEF rNR33           EQU $FF1D ; Channel 3 Frequency low (W)
DEF rNR34           EQU $FF1E ; Channel 3 Frequency high (R/W)
DEF rNR41           EQU $FF20 ; Channel 4 Sound Length (W)
DEF rNR42           EQU $FF21 ; Channel 4 Volume Envelope (R/W)
DEF rNR43           EQU $FF22 ; Channel 4 Polynomial counter (R/W)
DEF rNR44           EQU $FF23 ; Channel 4 Counter/consecutive; Initial (R/W)
DEF rNR50           EQU $FF24 ; Channel control / ON-OFF / Volume (R/W)
DEF rNR51           EQU $FF25 ; Selection of Sound output terminal (R/W)
DEF rNR52           EQU $FF26 ; Sound on/off (R/W)

; --- LCD Registers ---
DEF rLCDC           EQU $FF40 ; LCD Control (R/W)
DEF rSTAT           EQU $FF41 ; LCDC Status (R/W)
DEF rSCY            EQU $FF42 ; Scroll Y (R/W)
DEF rSCX            EQU $FF43 ; Scroll X (R/W)
DEF rLY             EQU $FF44 ; LCDC Y-Coordinate (R)
DEF rLYC            EQU $FF45 ; LY Compare (R/W)
DEF rDMA            EQU $FF46 ; DMA Transfer and Start Address (W)
DEF rBGP            EQU $FF47 ; BG Palette Data (R/W) - DMG Only
DEF rOBP0           EQU $FF48 ; Object Palette 0 Data (R/W) - DMG Only
DEF rOBP1           EQU $FF49 ; Object Palette 1 Data (R/W) - DMG Only
DEF rWY             EQU $FF4A ; Window Y Position (R/W)
DEF rWX             EQU $FF4B ; Window X Position minus 7 (R/W)
DEF rBOOT           EQU $FF50 ; Boot ROM Disable register (W)

; --- GBC Color Registers ---
DEF rKEY1           EQU $FF4D ; GBC Speed Switch (R/W)
DEF rVBK            EQU $FF4F ; GBC VRAM Bank (R/W)
DEF rHDMA1          EQU $FF51 ; GBC New DMA Source High (W)
DEF rHDMA2          EQU $FF52 ; GBC New DMA Source Low (W)
DEF rHDMA3          EQU $FF53 ; GBC New DMA Destination High (W)
DEF rHDMA4          EQU $FF54 ; GBC New DMA Destination Low (W)
DEF rHDMA5          EQU $FF55 ; GBC New DMA Length/Mode/Start (R/W)
DEF rBCPS           EQU $FF68 ; GBC Background Color Palette Specification (R/W)
DEF rBCPD           EQU $FF69 ; GBC Background Color Palette Data (R/W)
DEF rOCPS           EQU $FF6A ; GBC Object Color Palette Specification (R/W)
DEF rOCPD           EQU $FF6B ; GBC Object Color Palette Data (R/W)
DEF rSVBK           EQU $FF70 ; GBC WRAM Bank (R/W)

DEF rIE             EQU $FFFF ; Interrupt Enable (R/W)

; --- Interrupt Flags ---
DEF IEF_VBLANK      EQU 1 << 0
DEF IEF_LCDC        EQU 1 << 1
DEF IEF_TIMER       EQU 1 << 2
DEF IEF_SERIAL      EQU 1 << 3
DEF IEF_JOYPAD      EQU 1 << 4

; --- LCDC Register Bits ---
DEF LCDCF_OFF       EQU 0
DEF LCDCF_ON        EQU 1 << 7
DEF LCDCF_WINON     EQU 1 << 5
DEF LCDCF_OBJ16     EQU 1 << 2
DEF LCDCF_OBJON     EQU 1 << 1
DEF LCDCF_BGON      EQU 1 << 0

; --- Stat Register Bits ---
DEF STATF_LYC       EQU 1 << 6
DEF STATF_MODE10    EQU 1 << 5
DEF STATF_MODE01    EQU 1 << 4
DEF STATF_MODE00    EQU 1 << 3
DEF STATF_BUSY      EQU 1 << 1

; --- Direction Bit Constants ---
DEF DIR_NORTH_BIT   EQU 0
DEF DIR_EAST_BIT    EQU 1
DEF DIR_SOUTH_BIT   EQU 2
DEF DIR_WEST_BIT    EQU 3
DEF VISITED_BIT     EQU 4

DEF DIR_NORTH       EQU 1 << DIR_NORTH_BIT
DEF DIR_EAST        EQU 1 << DIR_EAST_BIT
DEF DIR_SOUTH       EQU 1 << DIR_SOUTH_BIT
DEF DIR_WEST        EQU 1 << DIR_WEST_BIT
DEF CELL_VISITED    EQU 1 << VISITED_BIT

; --- Gameplay Tile Index Constants ---
DEF TILE_WALL       EQU $00
DEF TILE_FLOOR      EQU $01
DEF TILE_EXIT_A     EQU $02
DEF TILE_EXIT_B     EQU $03

; --- State Constants ---
DEF STATE_BOOT            EQU 0
DEF STATE_TITLE           EQU 1
DEF STATE_LEVEL_PREPARE   EQU 2
DEF STATE_LEVEL_PLAY      EQU 3
DEF STATE_LEVEL_COMPLETE  EQU 4
DEF STATE_PAUSED          EQU 5

; --- Joypad Button Masks ---
DEF PADF_RIGHT      EQU 1 << 0
DEF PADF_LEFT       EQU 1 << 1
DEF PADF_UP         EQU 1 << 2
DEF PADF_DOWN       EQU 1 << 3
DEF PADF_A          EQU 1 << 4
DEF PADF_B          EQU 1 << 5
DEF PADF_SELECT     EQU 1 << 6
DEF PADF_START      EQU 1 << 7

    ENDC ; HARDWARE_CONSTANTS_INC
