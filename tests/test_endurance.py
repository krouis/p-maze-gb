# =============================================================================
# Pixel Maze GB
# File:        tests/test_endurance.py
# Description: Endurance test that boots the ROM and automatically solves and
#              completes many successive mazes in a row, verifying that
#              procedural generation, progression, and completion all keep
#              working correctly as maze size ramps up level over level.
#
# Copyright (C) 2026 Oasis Loop Labs
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

import os
import ctypes
from collections import deque

# Spec requirement: complete at least 20 successive mazes in ordinary CI.
NUM_LEVELS = 20

# Bounded timeouts so a real regression fails fast instead of hanging forever.
TITLE_BOOT_FRAMES = 60
LEVEL_GENERATE_TIMEOUT_FRAMES = 120
LEVEL_COMPLETE_TIMEOUT_FRAMES = 60
FRAMES_PER_MOVE = 10


def parse_symbols(sym_path):
    symbols = {}
    if not os.path.exists(sym_path):
        return symbols
    with open(sym_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or ";" in line:
                continue
            parts = line.split()
            if len(parts) == 2:
                addr_str, name = parts
                if ":" in addr_str:
                    addr = int(addr_str.split(":")[1], 16)
                else:
                    addr = int(addr_str, 16)
                symbols[name] = addr
    return symbols


# SameBoy key indexes: RIGHT=0, LEFT=1, UP=2, DOWN=3, A=4, B=5, SELECT=6, START=7
KEY_RIGHT = 0
KEY_LEFT = 1
KEY_UP = 2
KEY_DOWN = 3
KEY_START = 7

DIR_KEYS = {
    0: KEY_UP,     # North
    1: KEY_RIGHT,  # East
    2: KEY_DOWN,   # South
    3: KEY_LEFT,   # West
}

STATE_LEVEL_PREPARE = 2
STATE_LEVEL_PLAY = 3
STATE_LEVEL_COMPLETE = 4


def solve_maze(width, height, maze_data, start, target):
    queue = deque([[start]])
    visited = {start}

    while queue:
        path = queue.popleft()
        x, y = path[-1][0], path[-1][1]

        if (x, y) == target:
            return path

        cell_val = maze_data[y * width + x]
        directions = []
        if (cell_val & 1) != 0: directions.append((0, -1, 0))  # North
        if (cell_val & 2) != 0: directions.append((1, 0, 1))   # East
        if (cell_val & 4) != 0: directions.append((0, 1, 2))   # South
        if (cell_val & 8) != 0: directions.append((-1, 0, 3))  # West

        for dx, dy, d_idx in directions:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height:
                if (nx, ny) not in visited:
                    visited.add((nx, ny))
                    queue.append(path + [(nx, ny, d_idx)])

    return None


def run_until_state(lib, gb, wGameState_addr, target_state, max_frames, description):
    for _ in range(max_frames):
        lib.GB_run_frame(gb)
        if lib.GB_safe_read_memory(gb, wGameState_addr) == target_state:
            return
    current = lib.GB_safe_read_memory(gb, wGameState_addr)
    raise AssertionError(
        f"Timed out after {max_frames} frames waiting for {description} "
        f"(wGameState={target_state}); last observed wGameState={current}"
    )


def test_endurance_twenty_levels():
    # 1. Load symbols
    symbols = parse_symbols("build/p-maze-gb.sym")
    for name in (
        "wGameState", "wPlayerX", "wPlayerY", "wExitX", "wExitY",
        "wMazeWidth", "wMazeHeight", "wMazeData", "wTestMagic", "wRngSeed",
        "wCurrentLevel", "wCompletionCount",
    ):
        assert name in symbols, f"Missing expected symbol: {name}"

    # 2. Load SameBoy dynamic library and glibc
    try:
        ctypes.CDLL("/usr/lib/x86_64-linux-gnu/libmvec.so.1", mode=ctypes.RTLD_GLOBAL)
        ctypes.CDLL("libm.so.6", mode=ctypes.RTLD_GLOBAL)
    except Exception as e:
        print(f"Warning pre-loading libs: {e}")

    lib = ctypes.CDLL("/opt/sameboy/lib/libsameboy.so")

    try:
        libc = ctypes.CDLL("libc.so.6")
    except Exception:
        libc = ctypes.CDLL(None)

    lib.GB_allocation_size.argtypes = [ctypes.c_int]
    lib.GB_allocation_size.restype = ctypes.c_size_t
    lib.GB_init.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.GB_load_rom.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lib.GB_load_rom.restype = ctypes.c_int
    lib.GB_run_frame.argtypes = [ctypes.c_void_p]
    lib.GB_safe_read_memory.argtypes = [ctypes.c_void_p, ctypes.c_uint16]
    lib.GB_safe_read_memory.restype = ctypes.c_uint8
    lib.GB_write_memory.argtypes = [ctypes.c_void_p, ctypes.c_uint16, ctypes.c_uint8]
    lib.GB_set_key_state.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_bool]
    lib.GB_set_pixels_output.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    lib.GB_set_emulate_joypad_bouncing.argtypes = [ctypes.c_void_p, ctypes.c_bool]

    libc.malloc.argtypes = [ctypes.c_size_t]
    libc.malloc.restype = ctypes.c_void_p
    libc.free.argtypes = [ctypes.c_void_p]

    # 3. Initialize and allocate Game Boy instance and screen buffer
    model_cgb = 12
    size = lib.GB_allocation_size(model_cgb)
    gb = libc.malloc(size)
    assert gb is not None, "Failed to allocate memory for Game Boy instance"

    screen_buffer = libc.malloc(160 * 144 * 4)
    assert screen_buffer is not None, "Failed to allocate screen buffer"

    lib.GB_init(gb, model_cgb)
    lib.GB_set_pixels_output(gb, screen_buffer)
    # SameBoy's mechanical-contact-bounce simulation is on by default and can
    # drop a single-frame button press depending on exact frame alignment --
    # incompatible with the "100% deterministic" input injection ADR 0004
    # promises, and this test presses many buttons across many levels, so any
    # one of them landing in a bounce window would make the run flaky.
    lib.GB_set_emulate_joypad_bouncing(gb, False)

    try:
        ret = lib.GB_load_rom(gb, b"build/p-maze-gb.gb")
        assert ret == 0, "Failed to load ROM"

        wGameState = symbols["wGameState"]

        # Run a few frames to boot to title screen
        for _ in range(TITLE_BOOT_FRAMES):
            lib.GB_run_frame(gb)
        state = lib.GB_safe_read_memory(gb, wGameState)
        assert state == 1, f"Should boot into title screen state, got {state}"

        # Inject a deterministic seed via the test-instrumentation block, same
        # as test_gameplay.py, so this run is reproducible across CI runs.
        # wTestMagic = "PMGB" ($50, $4D, $47, $42); seed = $1234.
        lib.GB_write_memory(gb, symbols["wTestMagic"], 0x50)
        lib.GB_write_memory(gb, symbols["wTestMagic"] + 1, 0x4D)
        lib.GB_write_memory(gb, symbols["wTestMagic"] + 2, 0x47)
        lib.GB_write_memory(gb, symbols["wTestMagic"] + 3, 0x42)
        lib.GB_write_memory(gb, symbols["wRngSeed"], 0x34)
        lib.GB_write_memory(gb, symbols["wRngSeed"] + 1, 0x12)

        # Press Start to begin level 1
        lib.GB_set_key_state(gb, KEY_START, True)
        lib.GB_run_frame(gb)
        lib.GB_set_key_state(gb, KEY_START, False)

        for level in range(1, NUM_LEVELS + 1):
            run_until_state(
                lib, gb, wGameState, STATE_LEVEL_PLAY,
                LEVEL_GENERATE_TIMEOUT_FRAMES, f"level {level} generation",
            )

            current_level = lib.GB_safe_read_memory(gb, symbols["wCurrentLevel"])
            assert current_level == level, (
                f"wCurrentLevel drifted: expected {level}, got {current_level}"
            )

            width = lib.GB_safe_read_memory(gb, symbols["wMazeWidth"])
            height = lib.GB_safe_read_memory(gb, symbols["wMazeHeight"])
            exit_x = lib.GB_safe_read_memory(gb, symbols["wExitX"])
            exit_y = lib.GB_safe_read_memory(gb, symbols["wExitY"])
            assert 1 <= width <= 9 and 1 <= height <= 8, (
                f"Level {level}: implausible maze dimensions {width}x{height}"
            )

            maze_data = [
                lib.GB_safe_read_memory(gb, symbols["wMazeData"] + i)
                for i in range(width * height)
            ]

            path = solve_maze(width, height, maze_data, (0, 0), (exit_x, exit_y))
            assert path is not None, (
                f"Level {level}: unsolvable maze ({width}x{height}, "
                f"exit=({exit_x},{exit_y}))"
            )

            for step in path[1:]:
                nx, ny, d_idx = step
                key = DIR_KEYS[d_idx]

                lib.GB_set_key_state(gb, key, True)
                lib.GB_run_frame(gb)
                lib.GB_set_key_state(gb, key, False)
                for _ in range(FRAMES_PER_MOVE):
                    lib.GB_run_frame(gb)

                px = lib.GB_safe_read_memory(gb, symbols["wPlayerX"])
                py = lib.GB_safe_read_memory(gb, symbols["wPlayerY"])
                assert (px, py) == (nx, ny), (
                    f"Level {level}: player coordinate mismatch after move "
                    f"toward {step}: expected ({nx}, {ny}), got ({px}, {py})"
                )

            run_until_state(
                lib, gb, wGameState, STATE_LEVEL_COMPLETE,
                LEVEL_COMPLETE_TIMEOUT_FRAMES, f"level {level} completion",
            )

            completion_count = lib.GB_safe_read_memory(gb, symbols["wCompletionCount"])
            assert completion_count == level, (
                f"wCompletionCount mismatch after level {level}: expected "
                f"{level}, got {completion_count}"
            )

            print(f"Level {level}: {width}x{height} maze solved in {len(path) - 1} moves.")

        print(f"SUCCESS: completed {NUM_LEVELS} successive mazes.")
    finally:
        libc.free(gb)
        libc.free(screen_buffer)
