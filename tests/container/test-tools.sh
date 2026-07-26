#!/bin/sh
# =============================================================================
# Pixel Maze GB
# File:        tests/container/test-tools.sh
# Description: Verifies that all expected development tools and library
#              dependencies are installed and working in the container.
#
# Copyright (C) 2026 Oasis Loop Labs
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

set -eu

echo "=== Verifying Container Toolchain and Emulator Environment ==="

# 1. Check RGBDS
echo -n "rgbasm: " && rgbasm --version
echo -n "rgblink: " && rgblink --version
echo -n "rgbfix: " && rgbfix --version
echo -n "rgbgfx: " && rgbgfx --version

# 2. Check head-less SameBoy tester
if command -v sameboy_tester >/dev/null 2>&1; then
    echo "sameboy_tester: Found"
else
    echo "Error: sameboy_tester not found" >&2
    exit 1
fi

# 3. Check head-less binjgb tester
if command -v binjgb-tester >/dev/null 2>&1; then
    echo "binjgb-tester: Found"
else
    echo "Error: binjgb-tester not found" >&2
    exit 1
fi

# 4. Check actionlint
echo -n "actionlint: " && actionlint --version | head -n 1

# 5. Check shellcheck
echo -n "shellcheck: " && shellcheck --version | grep "version:"

# 6. Check Python environment
echo -n "python3: " && python3 --version
echo -n "pytest: " && pytest --version | head -n 1

echo "Verifying Python packages PIL and numpy..."
python3 -c "import PIL; import numpy; print('PIL version:', PIL.__version__, 'numpy version:', numpy.__version__)"

echo "=== All checks passed successfully! ==="
