; =============================================================================
; Pixel Maze GB
; File:        src/memory/hram.asm
; Description: High RAM (HRAM) memory variables allocation.
;
; Copyright (C) 2026 Oasis Loop Labs
;
; This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the Free
; Software Foundation; version 2 of the License.
;
; SPDX-License-Identifier: GPL-2.0-only
; =============================================================================

SECTION "HRAMVariables", HRAM

hDmaCode::            ds 16 ; Room for OAM DMA routine (copied at boot)
