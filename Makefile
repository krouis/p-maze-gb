# =============================================================================
# Pixel Maze GB
# File:        Makefile
# Description: Standard build rules for compiling the ROM and running tests.
#
# Copyright (C) 2026 Oasis Loop Labs
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

ASM_SOURCES = \
    src/main.asm \
    src/hardware/interrupts.asm \
    src/hardware/lcd.asm \
    src/hardware/dma.asm \
    src/hardware/joypad.asm \
    src/game/title.asm \
    src/game/progression.asm \
    src/game/maze_generate.asm \
    src/game/maze_render.asm \
    src/game/maze_collision.asm \
    src/game/player.asm \
    src/game/exit.asm \
    src/game/pause.asm \
    src/game/rng.asm \
    src/data/tiles.asm \
    src/memory/wram.asm \
    src/memory/hram.asm

OBJECTS = $(patsubst %.asm,build/%.o,$(ASM_SOURCES))

.PHONY: all clean rebuild check test test-gameplay reproducible release

all: build/p-maze-gb.gb

build/%.o: %.asm
	@mkdir -p $(dir $@)
	rgbasm -Wall -o $@ $<

build/p-maze-gb.gb: $(OBJECTS)
	@mkdir -p build
	rgblink -n build/p-maze-gb.sym -m build/p-maze-gb.map -o $@ $(OBJECTS)
	rgbfix -v -p 0x00 -c -t "PIXELMAZE" -m 0x00 -r 0x00 $@

clean:
	rm -rf build/ test-results/

rebuild: clean all

check: all test

test:
	python3 -m pytest tests/

test-gameplay:
	python3 -m pytest -s tests/

reproducible:
	$(MAKE) clean
	$(MAKE) all
	@sha256sum build/p-maze-gb.gb | cut -d' ' -f1 > /tmp/p-maze-gb-hash1.txt
	$(MAKE) clean
	$(MAKE) all
	@sha256sum build/p-maze-gb.gb | cut -d' ' -f1 > /tmp/p-maze-gb-hash2.txt
	@diff /tmp/p-maze-gb-hash1.txt /tmp/p-maze-gb-hash2.txt && echo "ROM build is 100% reproducible!"
	@rm -f /tmp/p-maze-gb-hash1.txt /tmp/p-maze-gb-hash2.txt

release: all
	@mkdir -p release
	cp build/p-maze-gb.gb release/p-maze-gb.gb
	cp build/p-maze-gb.sym release/p-maze-gb.sym
	cp build/p-maze-gb.map release/p-maze-gb.map
	sha256sum release/p-maze-gb.gb > release/p-maze-gb.gb.sha256
