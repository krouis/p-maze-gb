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

# SameBoy GB_model_t values (Core/model.h at the pinned SameBoy v1.0.3 tag).
# GB_MODEL_FAMILY_MASK is 0xF00; the low byte selects the specific hardware
# revision within a family (DMG/MGB/CGB).
GB_MODEL_DMG_B = 0x0002  # Game Boy (DMG), revision B
GB_MODEL_CGB_E = 0x0205  # Game Boy Color, revision E

# SameBoy's own clean-room reimplementations of the Nintendo boot ROMs (built
# from BootROMs/*.asm in the SameBoy source, not extracted from real
# hardware/firmware) -- copied into the dev image by tools/container/Dockerfile.
CGB_BOOT_ROM_PATH = b"/opt/sameboy/bin/cgb_boot.bin"

# SameBoy requires an RGB-encode callback to be registered before running any
# frames on CGB hardware: CGB background-palette writes call it unconditionally
# (unlike the DMG palette path, which guards against it being unset), so
# without one the very first BCPD write during gameplay segfaults.
_RGB_ENCODE_CB_T = ctypes.CFUNCTYPE(
    ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint8, ctypes.c_uint8, ctypes.c_uint8
)


def _encode_rgb(_gb, r, g, b):
    return (0xFF << 24) | (r << 16) | (g << 8) | b


# Kept alive at module scope: a ctypes callback object must not be garbage
# collected while SameBoy still holds the underlying function pointer.
_RGB_ENCODE_CALLBACK = _RGB_ENCODE_CB_T(_encode_rgb)


def _load_sameboy():
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
    lib.GB_set_rgb_encode_callback.argtypes = [ctypes.c_void_p, _RGB_ENCODE_CB_T]

    lib.GB_load_boot_rom.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lib.GB_load_boot_rom.restype = ctypes.c_int

    libc.malloc.argtypes = [ctypes.c_size_t]
    libc.malloc.restype = ctypes.c_void_p
    libc.free.argtypes = [ctypes.c_void_p]

    return lib, libc


def run_boot_smoke_test(
    model=12,
    model_label="model 12 (legacy default)",
    check_gbc_flag=None,
    boot_rom_path=None,
    frames=60,
):
    print("=== SameBoy Headless Smoke Test ===")

    # 1. Load symbols
    sym_path = "build/p-maze-gb.sym"
    symbols = parse_symbols(sym_path)
    if not symbols:
        raise AssertionError(f"Symbol file '{sym_path}' not found or empty.")

    print(f"Loaded {len(symbols)} symbols.")
    wGameState_addr = symbols.get("wGameState")
    wIsGBC_addr = symbols.get("wIsGBC")
    print(f"wGameState address: 0x{wGameState_addr:04X}")

    # 2. Load SameBoy DLL and glibc
    lib, libc = _load_sameboy()

    # 3. Get allocation size and allocate the Game Boy instance and screen buffer
    # via libc.malloc (not ctypes.create_string_buffer/byref) so SameBoy has a
    # real, stable heap pointer to render into across repeated GB_run_frame calls.
    size = lib.GB_allocation_size(model)
    print(f"Required allocation size for {model_label}: {size} bytes")

    gb = libc.malloc(size)
    assert gb is not None, "Failed to allocate memory for Game Boy instance"

    screen_buffer = libc.malloc(160 * 144 * 4)
    assert screen_buffer is not None, "Failed to allocate screen buffer"

    try:
        # 4. Initialize Game Boy
        lib.GB_init(gb, model)
        print("Game Boy initialized.")

        if boot_rom_path is not None:
            # Run the real (SameBoy-reimplemented, non-proprietary) boot ROM
            # so the boot-time hardware-ID register is set exactly as it
            # would be on real hardware, instead of GB_init's direct-entry
            # fake-boot defaults.
            boot_ret = lib.GB_load_boot_rom(gb, boot_rom_path)
            assert boot_ret == 0, f"Failed to load boot ROM '{boot_rom_path}'."
            print(f"Boot ROM loaded: {boot_rom_path}")

        # SameBoy renders into this buffer during GB_run_frame; without it,
        # rendering writes through an unset pointer and crashes.
        lib.GB_set_pixels_output(gb, screen_buffer)
        lib.GB_set_rgb_encode_callback(gb, _RGB_ENCODE_CALLBACK)

        # 5. Load ROM
        rom_path = b"build/p-maze-gb.gb"
        ret = lib.GB_load_rom(gb, rom_path)
        assert ret == 0, "Failed to load ROM."
        print("ROM loaded successfully.")

        # 6. Run for the given number of frames and check state. A real boot
        # ROM run (Nintendo logo scroll, checksum, palette fade-in) takes
        # ~190 frames before handing off to our own code, versus ~1 frame
        # for GB_init's direct-entry fast path -- callers must budget for it.
        for frame in range(frames):
            lib.GB_run_frame(gb)

        state = lib.GB_safe_read_memory(gb, wGameState_addr)
        print(f"Game State after {frames} frames: {state} (Expected 1 for STATE_TITLE)")
        assert state == 1, f"Expected STATE_TITLE (1), got {state}"

        if check_gbc_flag is not None:
            is_gbc = lib.GB_safe_read_memory(gb, wIsGBC_addr)
            print(f"wIsGBC: {is_gbc} (Expected {int(check_gbc_flag)})")
            assert is_gbc == int(check_gbc_flag), (
                f"Expected wIsGBC == {int(check_gbc_flag)} for {model_label}, got {is_gbc}"
            )

        print("SUCCESS: ROM booted to title screen successfully!")
    finally:
        libc.free(gb)
        libc.free(screen_buffer)


def test_rom_boot_smoke():
    run_boot_smoke_test()


def test_rom_boot_smoke_dmg():
    # Verifies the ROM actually boots on real DMG hardware (not just CGB),
    # per ADR 0002's dual-compatibility requirement: the boot-time GBC
    # detection (main.asm's check of register A) must land on the DMG path
    # and reach STATE_TITLE without any GBC-only setup.
    run_boot_smoke_test(
        model=GB_MODEL_DMG_B,
        model_label="GB_MODEL_DMG_B",
        check_gbc_flag=False,
    )


def test_rom_boot_smoke_gbc():
    # Verifies the ROM boots on real CGB hardware and actually detects it.
    # Runs SameBoy's own CGB boot ROM (not GB_init's fast-entry defaults) so
    # the boot-time hardware-ID register is set the way real hardware sets
    # it, then asserts wIsGBC == 1 -- the outcome ADR 0002's whole
    # dual-compatibility design depends on.
    run_boot_smoke_test(
        model=GB_MODEL_CGB_E,
        model_label="GB_MODEL_CGB_E",
        check_gbc_flag=True,
        boot_rom_path=CGB_BOOT_ROM_PATH,
        frames=240,
    )


if __name__ == "__main__":
    import sys
    try:
        run_boot_smoke_test()
        run_boot_smoke_test(
            model=GB_MODEL_DMG_B, model_label="GB_MODEL_DMG_B", check_gbc_flag=False
        )
        run_boot_smoke_test(
            model=GB_MODEL_CGB_E,
            model_label="GB_MODEL_CGB_E",
            check_gbc_flag=True,
            boot_rom_path=CGB_BOOT_ROM_PATH,
            frames=240,
        )
        sys.exit(0)
    except AssertionError as e:
        print(f"FAILURE: {e}")
        sys.exit(1)
