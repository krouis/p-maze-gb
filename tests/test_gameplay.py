# =============================================================================
# Pixel Maze GB
# File:        tests/test_gameplay.py
# Description: Integration test that boots the ROM, reads the generated maze
#              from WRAM, solves it, inputs keys, and verifies level completion.
#
# Copyright (C) 2026 Oasis Loop Labs
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

import os
import ctypes
import pytest
from collections import deque

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

# SameBoy key indexes:
# RIGHT = 0, LEFT = 1, UP = 2, DOWN = 3, A = 4, B = 5, SELECT = 6, START = 7
KEY_RIGHT = 0
KEY_LEFT = 1
KEY_UP = 2
KEY_DOWN = 3
KEY_START = 7

DIR_KEYS = {
    0: KEY_UP,    # North
    1: KEY_RIGHT, # East
    2: KEY_DOWN,  # South
    3: KEY_LEFT   # West
}

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
        if (cell_val & 1) != 0: directions.append((0, -1, 0)) # North
        if (cell_val & 2) != 0: directions.append((1, 0, 1))  # East
        if (cell_val & 4) != 0: directions.append((0, 1, 2))  # South
        if (cell_val & 8) != 0: directions.append((-1, 0, 3)) # West
        
        for dx, dy, d_idx in directions:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height:
                if (nx, ny) not in visited:
                    visited.add((nx, ny))
                    queue.append(path + [(nx, ny, d_idx)])
                    
    return None

def test_maze_gameplay():
    # 1. Load symbols
    symbols = parse_symbols("build/p-maze-gb.sym")
    assert "wGameState" in symbols
    assert "wPlayerX" in symbols
    assert "wPlayerY" in symbols
    assert "wExitX" in symbols
    assert "wExitY" in symbols
    assert "wMazeWidth" in symbols
    assert "wMazeHeight" in symbols
    assert "wMazeData" in symbols
    assert "wTestMagic" in symbols
    assert "wRngSeed" in symbols

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
        
    # Configure signatures
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
    # incompatible with deterministic input injection, and indistinguishable
    # from a real collision/logic bug when a move doesn't register.
    lib.GB_set_emulate_joypad_bouncing(gb, False)

    # Load ROM
    ret = lib.GB_load_rom(gb, b"build/p-maze-gb.gb")
    assert ret == 0
    
    # Run a few frames to boot to title screen
    for _ in range(60):
        lib.GB_run_frame(gb)
        
    # Verify we are on title screen (state 1 = STATE_TITLE)
    state = lib.GB_safe_read_memory(gb, symbols["wGameState"])
    assert state == 1, "Should boot into title screen state"

    # Inject deterministic seed through wTestMagic and wRngSeed
    # wTestMagic = "PMGB" ($50, $4D, $47, $42)
    lib.GB_write_memory(gb, symbols["wTestMagic"], 0x50)
    lib.GB_write_memory(gb, symbols["wTestMagic"] + 1, 0x4D)
    lib.GB_write_memory(gb, symbols["wTestMagic"] + 2, 0x47)
    lib.GB_write_memory(gb, symbols["wTestMagic"] + 3, 0x42)
    
    # Injected seed: $1234
    lib.GB_write_memory(gb, symbols["wRngSeed"], 0x34)
    lib.GB_write_memory(gb, symbols["wRngSeed"] + 1, 0x12)
    
    # 4. Press Start to transition to gameplay
    lib.GB_set_key_state(gb, KEY_START, True)
    lib.GB_run_frame(gb)
    lib.GB_set_key_state(gb, KEY_START, False)
    
    # Run a few frames to allow level generation and transition to STATE_LEVEL_PLAY (state 3)
    for _ in range(30):
        lib.GB_run_frame(gb)
        
    state = lib.GB_safe_read_memory(gb, symbols["wGameState"])
    assert state == 3, f"Expected play state (3), got {state}"
    
    # 5. Read maze geometry and data from WRAM
    width = lib.GB_safe_read_memory(gb, symbols["wMazeWidth"])
    height = lib.GB_safe_read_memory(gb, symbols["wMazeHeight"])
    exit_x = lib.GB_safe_read_memory(gb, symbols["wExitX"])
    exit_y = lib.GB_safe_read_memory(gb, symbols["wExitY"])
    
    print(f"\n[DEBUG] wGameState address: {hex(symbols['wGameState'])}")
    print(f"[DEBUG] wExitX address: {hex(symbols['wExitX'])}")
    print(f"[DEBUG] wExitY address: {hex(symbols['wExitY'])}")
    print(f"[DEBUG] wTestMagic address: {hex(symbols['wTestMagic'])}")
    print(f"[DEBUG] wRngSeed address: {hex(symbols['wRngSeed'])}")
    
    print(f"Maze dimensions: {width}x{height}")
    print(f"Exit position: ({exit_x}, {exit_y})")
    
    maze_data = []
    for i in range(width * height):
        val = lib.GB_safe_read_memory(gb, symbols["wMazeData"] + i)
        maze_data.append(val)
        
    # 6. Solve the maze
    path = solve_maze(width, height, maze_data, (0, 0), (exit_x, exit_y))
    assert path is not None, "Maze must be solvable"
    print(f"Maze solved! Path length: {len(path)} steps.")
    
    # 7. Walk the path
    for step in path[1:]:
        nx, ny, d_idx = step
        key = DIR_KEYS[d_idx]
        
        # Press direction key
        lib.GB_set_key_state(gb, key, True)
        lib.GB_run_frame(gb)
        
        # Release key and let player move
        lib.GB_set_key_state(gb, key, False)
        # Run 10 frames to let input register and play move
        for _ in range(10):
            lib.GB_run_frame(gb)
            
        # Verify player position updated
        px = lib.GB_safe_read_memory(gb, symbols["wPlayerX"])
        py = lib.GB_safe_read_memory(gb, symbols["wPlayerY"])
        assert (px, py) == (nx, ny), f"Player coordinate mismatch: expected ({nx}, {ny}), got ({px}, {py})"
        
    # 8. Check that we reached the exit and transition to completion state
    state = lib.GB_safe_read_memory(gb, symbols["wGameState"])
    assert state == 4, f"Expected state 4 (LEVEL_COMPLETE), got {state}"
    print("SUCCESS: Player solved the maze and completed the level!")
    
    # 9. Clean up allocated memory
    libc.free(gb)
    libc.free(screen_buffer)
