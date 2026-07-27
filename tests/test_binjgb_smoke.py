# =============================================================================
# Pixel Maze GB
# File:        tests/test_binjgb_smoke.py
# Description: Secondary-emulator smoke test using headless binjgb-tester.
#              Boots the ROM, captures a real screenshot, and checks both the
#              parsed cartridge header and that something actually rendered.
#
# Copyright (C) 2026 Oasis Loop Labs
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

import subprocess
import tempfile
from collections import Counter
from pathlib import Path

ROM_PATH = "build/p-maze-gb.gb"
BOOT_FRAMES = 100  # per ADR 0004: "runs for 100 frames, and dumps a correct visual screen"


def _run_binjgb_tester(frames, extra_args=()):
    with tempfile.TemporaryDirectory() as tmp_dir:
        ppm_path = Path(tmp_dir) / "screenshot.ppm"
        result = subprocess.run(
            [
                "binjgb-tester",
                "-f", str(frames),
                "-o", str(ppm_path),
                *extra_args,
                ROM_PATH,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0, (
            f"binjgb-tester exited {result.returncode}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
        assert ppm_path.exists(), "binjgb-tester did not produce a screenshot"
        return result.stdout, _read_ppm(ppm_path)


def _read_ppm(path):
    with open(path) as f:
        magic = f.readline().strip()
        assert magic == "P3", f"Expected ASCII PPM (P3), got {magic!r}"
        width, height = (int(x) for x in f.readline().split())
        maxval = int(f.readline())
        values = [int(v) for v in f.read().split()]
    assert len(values) == width * height * 3, (
        f"Expected {width * height * 3} color values for a {width}x{height} "
        f"image, got {len(values)}"
    )
    pixels = [tuple(values[i:i + 3]) for i in range(0, len(values), 3)]
    return width, height, maxval, pixels


def test_binjgb_boots_and_renders_title_screen():
    # 1. Boot for BOOT_FRAMES and capture a screenshot.
    stdout, (width, height, maxval, pixels) = _run_binjgb_tester(BOOT_FRAMES)
    print(stdout)

    # 2. Cross-check the cartridge header binjgb independently parsed against
    # what rgbfix wrote -- this doubles as a second, independent confirmation
    # of the ROM_ONLY/32K/dual-compatible ($80) header from a different
    # emulator's header parser.
    assert '"PIXELMAZE"' in stdout, f"Unexpected ROM title in output:\n{stdout}"
    assert "cgb flag: CGB_FLAG_SUPPORTED" in stdout, (
        f"Expected a dual-compatible (not CGB-only, not unsupported) CGB flag:\n{stdout}"
    )
    assert "header checksum:" in stdout and "[OK]" in stdout, (
        f"Header checksum did not validate:\n{stdout}"
    )

    # 3. Screen must be the real Game Boy resolution.
    assert (width, height) == (160, 144), f"Unexpected screen size: {width}x{height}"

    # 4. The screen must show actual rendered content, not a blank/uniform
    # frame. This is the check that would have caught the LCDC bit-4
    # (BG tile data select) bug: with that bug, every background tile
    # resolved to whichever byte sat at $9000+index*16 instead of the real
    # tile graphic at $8000+index*16, and the whole screen rendered as a
    # single flat color.
    distinct_colors = Counter(pixels)
    assert len(distinct_colors) >= 3, (
        f"Title screen rendered as only {len(distinct_colors)} distinct "
        f"color(s) ({distinct_colors.most_common(5)}) -- expected real "
        f"multi-color title art, not a blank/uniform screen."
    )


def test_binjgb_boots_in_forced_dmg_mode():
    # Sanity-check the secondary emulator's independent DMG code path too
    # (SameBoy's DMG boot test lives in test_rom_boot.py; this is binjgb's).
    stdout, (width, height, maxval, pixels) = _run_binjgb_tester(
        BOOT_FRAMES, extra_args=["--force-dmg"]
    )
    print(stdout)
    assert (width, height) == (160, 144)
    distinct_colors = Counter(pixels)
    assert len(distinct_colors) >= 3, (
        f"Forced-DMG title screen rendered as only {len(distinct_colors)} "
        f"distinct color(s) -- expected real title art."
    )
