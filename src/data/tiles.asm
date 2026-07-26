; =============================================================================
; Pixel Maze GB
; File:        src/data/tiles.asm
; Description: Binary assets inclusion for title screen and gameplay tiles.
;
; Copyright (C) 2026 Oasis Loop Labs
;
; This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the Free
; Software Foundation; version 2 of the License.
;
; SPDX-License-Identifier: GPL-2.0-only
; =============================================================================

SECTION "TitleGraphics", ROM0

TitleTiles::
    INCBIN "assets/generated/oasis_logo.2bpp"
TitleTilesEnd::

TitleTilemap::
    INCBIN "assets/generated/oasis_logo.tilemap"
TitleTilemapEnd::

SECTION "GameplayGraphics", ROM0

GameplayTiles::
    INCBIN "assets/generated/gameplay_tiles.2bpp"
GameplayTilesEnd::
