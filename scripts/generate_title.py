# =============================================================================
# Pixel Maze GB
# File:        scripts/generate_title.py
# Description: Generates a pixel-perfect 160x144 PNG title screen using Pillow.
#
# Copyright (C) 2026 Oasis Loop Labs
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

import os
from PIL import Image, ImageDraw

# Create directories
os.makedirs("assets/source", exist_ok=True)

# 4 shades palette for DMG
# 00 = White (255, 255, 255)
# 01 = Light Grey (170, 170, 170)
# 10 = Dark Grey (85, 85, 85)
# 11 = Black (0, 0, 0)
COLOR_WHITE = (255, 255, 255)
COLOR_LIGHT = (170, 170, 170)
COLOR_DARK = (85, 85, 85)
COLOR_BLACK = (0, 0, 0)

# Create 160x144 image (L mode for grayscale, but we save as RGB/indexed)
img = Image.new("RGB", (160, 144), COLOR_WHITE)
draw = ImageDraw.Draw(img)

# --- Draw Oasis Loop Labs Emblem (centered at X=80, Y=36, radius=24) ---
cx, cy = 80, 36
r = 24

# Enclosing loop (circle)
draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=COLOR_BLACK, width=2)

# Small arrow at the right side of the loop (around X=104, Y=36)
# Arrow points down/clockwise
draw.polygon([(104, 33), (107, 36), (104, 39)], fill=COLOR_BLACK)

# Sun (top-right of emblem center)
draw.ellipse([cx + 4, cy - r + 6, cx + 14, cy - r + 16], fill=COLOR_LIGHT)

# Island (bottom of emblem)
draw.chord([cx - r + 4, cy + r - 12, cx + r - 4, cy + r - 2], start=0, end=180, fill=COLOR_DARK)

# Palm tree trunk
# Draw curved trunk from center of island
draw.line([(80, 48), (79, 44), (77, 36), (75, 30)], fill=COLOR_BLACK, width=2)

# Palm leaves
draw.line([(75, 30), (68, 28)], fill=COLOR_BLACK, width=1)
draw.line([(75, 30), (71, 23)], fill=COLOR_BLACK, width=1)
draw.line([(75, 30), (81, 24)], fill=COLOR_BLACK, width=1)
draw.line([(75, 30), (82, 31)], fill=COLOR_BLACK, width=1)

# Water reflections
draw.line([(cx - 16, cy + 14), (cx + 16, cy + 14)], fill=COLOR_LIGHT, width=1)
draw.line([(cx - 10, cy + 17), (cx + 10, cy + 17)], fill=COLOR_LIGHT, width=1)
draw.line([(cx - 6, cy + 20), (cx + 6, cy + 20)], fill=COLOR_LIGHT, width=1)

# --- 5x7 Pixel Font Representation ---
FONT = {
    'A': [
        " █ ",
        "█ █",
        "█ █",
        "███",
        "█ █",
        "█ █",
        "█ █"
    ],
    'B': [
        "██ ",
        "█ █",
        "█ █",
        "██ ",
        "█ █",
        "█ █",
        "██ "
    ],
    'E': [
        "███",
        "█  ",
        "█  ",
        "██ ",
        "█  ",
        "█  ",
        "███"
    ],
    'I': [
        "███",
        " █ ",
        " █ ",
        " █ ",
        " █ ",
        " █ ",
        "███"
    ],
    'L': [
        "█  ",
        "█  ",
        "█  ",
        "█  ",
        "█  ",
        "█  ",
        "███"
    ],
    'M': [
        "█ █",
        "███",
        "███",
        "█ █",
        "█ █",
        "█ █",
        "█ █"
    ],
    'O': [
        " █ ",
        "█ █",
        "█ █",
        "█ █",
        "█ █",
        "█ █",
        " █ "
    ],
    'P': [
        "██ ",
        "█ █",
        "█ █",
        "██ ",
        "█  ",
        "█  ",
        "█  "
    ],
    'R': [
        "██ ",
        "█ █",
        "█ █",
        "██ ",
        "█ █",
        "█ █",
        "█ █"
    ],
    'S': [
        " ██",
        "█  ",
        "█  ",
        " ██",
        "   █",
        "   █",
        "██ "
    ],
    'T': [
        "███",
        " █ ",
        " █ ",
        " █ ",
        " █ ",
        " █ ",
        " █ "
    ],
    'X': [
        "█ █",
        "█ █",
        " █ ",
        " █ ",
        " █ ",
        "█ █",
        "█ █"
    ],
    'Z': [
        "███",
        "  █",
        "  █",
        " █ ",
        "█  ",
        "█  ",
        "███"
    ],
    ' ': [
        "   ",
        "   ",
        "   ",
        "   ",
        "   ",
        "   ",
        "   "
    ]
}

def draw_text(text, start_x, start_y, color):
    cur_x = start_x
    for char in text:
        if char in FONT:
            glyph = FONT[char]
            for row_idx, row_str in enumerate(glyph):
                for col_idx, pixel in enumerate(row_str):
                    if pixel == '█':
                        draw.point((cur_x + col_idx, start_y + row_idx), fill=color)
            cur_x += 4  # 3 pixels char width + 1 pixel space
        else:
            cur_x += 4

# --- Draw text elements ---
# Center text calculations:
# Each char is 4 pixels wide. PIXEL MAZE = 10 chars -> 40 pixels wide. Let's adjust spacing.
# Actually, let's write draw_text to center the string.
def draw_centered_text(text, y, color):
    width = len(text) * 4 - 1
    start_x = (160 - width) // 2
    draw_text(text, start_x, y, color)

# 1. PIXEL MAZE
draw_centered_text("PIXEL MAZE", 84, COLOR_BLACK)

# 2. OASIS LOOP LABS
draw_centered_text("OASIS LOOP LABS", 104, COLOR_DARK)

# 3. PRESS START
draw_centered_text("PRESS START", 124, COLOR_BLACK)

# Save the generated image
img.save("assets/source/oasis-loop-labs-title.png")
print("Generated assets/source/oasis-loop-labs-title.png successfully.")
