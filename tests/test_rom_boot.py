# =============================================================================
# Pixel Maze GB
# File:        tests/test_rom_boot.py
# Description: Automated smoke test using headless SameBoy dynamic library.
#
# Copyright (C) 2026 Oasis Loop Labs
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

import os
import ctypes

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

def run_boot_smoke_test():
    print("=== SameBoy Headless Smoke Test ===")

    # 1. Load symbols
    sym_path = "build/p-maze-gb.sym"
    symbols = parse_symbols(sym_path)
    if not symbols:
        raise AssertionError(f"Symbol file '{sym_path}' not found or empty.")

    print(f"Loaded {len(symbols)} symbols.")
    wGameState_addr = symbols.get("wGameState")
    print(f"wGameState address: 0x{wGameState_addr:04X}")

    # 2. Load SameBoy DLL and glibc
    try:
        ctypes.CDLL("/usr/lib/x86_64-linux-gnu/libmvec.so.1", mode=ctypes.RTLD_GLOBAL)
        ctypes.CDLL("libm.so.6", mode=ctypes.RTLD_GLOBAL)
    except Exception as e:
        print(f"Warning: Could not pre-load libmvec/libm: {e}")

    lib = ctypes.CDLL("/opt/sameboy/lib/libsameboy.so")

    try:
        libc = ctypes.CDLL("libc.so.6")
    except Exception:
        libc = ctypes.CDLL(None)

    # Setup function prototypes
    lib.GB_allocation_size.argtypes = [ctypes.c_int]
    lib.GB_allocation_size.restype = ctypes.c_size_t

    lib.GB_init.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.GB_init.restype = None

    lib.GB_load_rom.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lib.GB_load_rom.restype = ctypes.c_int

    lib.GB_run_frame.argtypes = [ctypes.c_void_p]
    lib.GB_run_frame.restype = None

    lib.GB_safe_read_memory.argtypes = [ctypes.c_void_p, ctypes.c_uint16]
    lib.GB_safe_read_memory.restype = ctypes.c_uint8

    lib.GB_set_pixels_output.argtypes = [ctypes.c_void_p, ctypes.c_void_p]

    libc.malloc.argtypes = [ctypes.c_size_t]
    libc.malloc.restype = ctypes.c_void_p
    libc.free.argtypes = [ctypes.c_void_p]

    # 3. Get allocation size and allocate the Game Boy instance and screen buffer
    # via libc.malloc (not ctypes.create_string_buffer/byref) so SameBoy has a
    # real, stable heap pointer to render into across repeated GB_run_frame calls.
    model_cgb = 12  # CGB_E
    size = lib.GB_allocation_size(model_cgb)
    print(f"Required allocation size for model {model_cgb}: {size} bytes")

    gb = libc.malloc(size)
    assert gb is not None, "Failed to allocate memory for Game Boy instance"

    screen_buffer = libc.malloc(160 * 144 * 4)
    assert screen_buffer is not None, "Failed to allocate screen buffer"

    try:
        # 4. Initialize Game Boy
        lib.GB_init(gb, model_cgb)
        print("Game Boy initialized.")

        # SameBoy renders into this buffer during GB_run_frame; without it,
        # rendering writes through an unset pointer and crashes.
        lib.GB_set_pixels_output(gb, screen_buffer)

        # 5. Load ROM
        rom_path = b"build/p-maze-gb.gb"
        ret = lib.GB_load_rom(gb, rom_path)
        assert ret == 0, "Failed to load ROM."
        print("ROM loaded successfully.")

        # 6. Run for 60 frames and check state
        for frame in range(60):
            lib.GB_run_frame(gb)

        state = lib.GB_safe_read_memory(gb, wGameState_addr)
        print(f"Game State after 60 frames: {state} (Expected 1 for STATE_TITLE)")
        assert state == 1, f"Expected STATE_TITLE (1), got {state}"
        print("SUCCESS: ROM booted to title screen successfully!")
    finally:
        libc.free(gb)
        libc.free(screen_buffer)


def test_rom_boot_smoke():
    run_boot_smoke_test()


if __name__ == "__main__":
    import sys
    try:
        run_boot_smoke_test()
        sys.exit(0)
    except AssertionError as e:
        print(f"FAILURE: {e}")
        sys.exit(1)
