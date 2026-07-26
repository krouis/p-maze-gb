# =============================================================================
# Pixel Maze GB
# File:        scripts/convert_screenshot.py
# Description: Converts PPM screenshots to PNG format for presentation.
#
# Copyright (C) 2026 Oasis Loop Labs
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

import os
from PIL import Image

def main():
    ppm_path = "build/title_screenshot.ppm"
    png_path = "build/title_screenshot.png"
    if not os.path.exists(ppm_path):
        print(f"Error: PPM screenshot '{ppm_path}' not found.")
        return 1
    
    img = Image.open(ppm_path)
    img.save(png_path)
    print(f"Converted '{ppm_path}' to '{png_path}' successfully.")
    return 0

if __name__ == "__main__":
    import sys
    sys.exit(main())
