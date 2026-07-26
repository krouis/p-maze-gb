# Pixel Maze GB Container Environment

This directory contains the configurations and metadata for the hermetic and reproducible Docker development environment used by **Pixel Maze GB**.

## Copyright and License

Copyright (C) 2026 Oasis Loop Labs

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; version 2 of the License.

SPDX-License-Identifier: GPL-2.0-only

## Structure

*   `Dockerfile`: Multi-stage build definition for compiling the pinned RGBDS compiler and the emulators headlessly.
*   `versions.env`: Central repository of tool and base image versions.
*   `checksums.txt`: SHA-256 hashes of all third-party release archives fetched during image builds.
*   `requirements.txt`: Pinned Python dependencies for the test suites and asset conversion scripts.

## Authoritative Tool Versions

*   **Base Image**: `debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818`
*   **RGBDS**: `v0.7.0` (assembly compiler toolchain)
*   **SameBoy**: `v1.0.3` (primary emulator and headless tester)
*   **binjgb**: `v0.1.11` (secondary compatibility emulator tester)
*   **actionlint**: `v1.7.12` (GitHub Actions workflow linter)
