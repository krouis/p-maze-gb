# =============================================================================
# Pixel Maze GB
# File:        scripts/generate_gameplay_tiles.py
# Description: Generates a 200x8 pixel-perfect PNG containing gameplay tiles,
#              sprites, and alphanumeric characters (L, V, P, A, U, S, E, 0-9).
#
# Copyright (C) 2026 Oasis Loop Labs
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

import os
from PIL import Image, ImageDraw

# Create directories
os.makedirs("assets/source", exist_ok=True)

# Colors
COLOR_WHITE = (255, 255, 255)
COLOR_LIGHT = (170, 170, 170)
COLOR_DARK = (85, 85, 85)
COLOR_BLACK = (0, 0, 0)

# Total tiles:
# 0: Wall
# 1: Floor
# 2: Exit Frame 1
# 3: Exit Frame 2
# 4: Player Idle 1
# 5: Player Idle 2
# 6: Player Squash (wall collision)
# 7: Player Happy (win)
# 8-14: Letters 'L', 'V', 'P', 'A', 'U', 'S', 'E'
# 15-24: Digits '0'-'9'
# Total 25 tiles of 8x8 = 200x8 pixels
img = Image.new("RGB", (200, 8), COLOR_WHITE)
draw = ImageDraw.Draw(img)

# --- Tile 0: Wall (X: 0-7) ---
draw.rectangle([0, 0, 7, 7], fill=COLOR_DARK)
draw.line([(0, 0), (7, 0)], fill=COLOR_WHITE)
draw.line([(0, 0), (0, 7)], fill=COLOR_WHITE)
draw.line([(7, 0), (7, 7)], fill=COLOR_BLACK)
draw.line([(0, 7), (7, 7)], fill=COLOR_BLACK)

# --- Tile 1: Floor (X: 8-15) ---
draw.rectangle([8, 0, 15, 7], fill=COLOR_WHITE)

# --- Tile 2: Exit Frame 1 (X: 16-23) ---
star_points_1 = [
    (19, 1), (20, 3), (22, 3), (20, 4),
    (21, 6), (19, 5), (17, 6), (18, 4),
    (16, 3), (18, 3)
]
draw.polygon(star_points_1, fill=COLOR_BLACK, outline=COLOR_DARK)

# --- Tile 3: Exit Frame 2 (X: 24-31) ---
star_points_2 = [
    (27, 0), (28, 2), (30, 2), (28, 4),
    (29, 7), (27, 5), (25, 7), (26, 4),
    (24, 2), (26, 2)
]
draw.polygon(star_points_2, fill=COLOR_DARK, outline=COLOR_BLACK)

# --- Tile 4: Player Idle 1 (X: 32-39) ---
draw.ellipse([33, 1, 38, 7], fill=COLOR_LIGHT, outline=COLOR_BLACK)
draw.point((34, 3), fill=COLOR_BLACK)
draw.point((36, 3), fill=COLOR_BLACK)

# --- Tile 5: Player Idle 2 (X: 40-47) ---
draw.ellipse([41, 1, 46, 7], fill=COLOR_LIGHT, outline=COLOR_BLACK)
draw.line([(42, 3), (42, 3)], fill=COLOR_BLACK)
draw.line([(44, 3), (44, 3)], fill=COLOR_BLACK)

# --- Tile 6: Player Squash (X: 48-55) ---
draw.ellipse([49, 3, 54, 7], fill=COLOR_LIGHT, outline=COLOR_BLACK)
draw.point((50, 5), fill=COLOR_BLACK)
draw.point((52, 5), fill=COLOR_BLACK)

# --- Tile 7: Player Happy (X: 56-63) ---
draw.ellipse([57, 0, 62, 6], fill=COLOR_LIGHT, outline=COLOR_BLACK)
draw.point((58, 2), fill=COLOR_BLACK)
draw.point((60, 2), fill=COLOR_BLACK)
draw.point((59, 3), fill=COLOR_BLACK)

# --- Font Glyphs (5x7 mapped into 8x8 tiles) ---
FONT = {
    'L': ["█  ", "█  ", "█  ", "█  ", "█  ", "█  ", "███"],
    'V': ["█ █", "█ █", "█ █", "█ █", "█ █", " █ ", " █ "],
    'P': ["██ ", "█ █", "█ █", "██ ", "█  ", "█  ", "█  "],
    'A': [" █ ", "█ █", "█ █", "███", "█ █", "█ █", "█ █"],
    'U': ["█ █", "█ █", "█ █", "█ █", "█ █", "█ █", "███"],
    'S': [" ██", "█  ", "█  ", " ██", "   █", "   █", "██ "],
    'E': ["███", "█  ", "█  ", "██ ", "█  ", "█  ", "███"],
    '0': ["███", "█ █", "█ █", "█ █", "█ █", "█ █", "███"],
    '1': [" █ ", "██ ", " █ ", " █ ", " █ ", " █ ", "███"],
    '2': ["███", "  █", "  █", "███", "█  ", "█  ", "███"],
    '3': ["███", "  █", "  █", "███", "  █", "  █", "███"],
    '4': ["█ █", "█ █", "█ █", "███", "  █", "  █", "  █"],
    '5': ["███", "█  ", "█  ", "███", "  █", "  █", "███"],
    '6': ["███", "█  ", "█  ", "███", "█ █", "█ █", "███"],
    '7': ["███", "  █", "  █", "  █", "  █", "  █", "  █"],
    '8': ["███", "█ █", "█ █", "███", "█ █", "█ █", "███"],
    '9': ["███", "█ █", "█ █", "███", "  █", "  █", "███"]
}

# Write characters to tiles 8 to 24
chars = ['L', 'V', 'P', 'A', 'U', 'S', 'E', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
for idx, char in enumerate(chars):
    tile_x = (8 + idx) * 8
    # Draw character inside the 8x8 tile slot
    glyph = FONT[char]
    for row_idx, row_str in enumerate(glyph):
        for col_idx, pixel in enumerate(row_str):
            if pixel == '█':
                # Center character horizontally in 8x8 tile: add +1 padding
                draw.point((tile_x + col_idx + 2, row_idx), fill=COLOR_BLACK)

# Save image
img.save("assets/source/gameplay_tiles.png")
print("Generated assets/source/gameplay_tiles.png successfully.")
