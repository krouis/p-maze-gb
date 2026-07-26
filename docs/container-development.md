# Hermetic Container Development Guide

This guide describes how to build, test, and manage the reproducible container environment for **Pixel Maze GB**.

## Overview

We use a self-contained Docker container to ensure every contributor, coding agent, and CI/CD runner works under the exact same environment. This eliminates the "works on my machine" problem and prevents the need to install specific Game Boy compilers and emulators directly on your host system.

## Prerequisites

Your host system needs only:
1. **Git**
2. **Docker** (with BuildKit enabled)
3. **Docker Compose** (optional, for compose commands)

No Python, RGBDS, sameboy, SDL, or compiler libraries are needed on the host.

## Canonical Command Wrapper

We provide a POSIX-compliant `./dev` script at the root of the repository. It automatically builds the container image if it does not exist, and runs build targets while maintaining host file ownership.

### Commands

*   **Build the ROM**:
    ```bash
    ./dev build
    ```
    This invokes `make all` inside the container and compiles `build/p-maze-gb.gb`.

*   **Run Automated Tests**:
    ```bash
    ./dev test
    ```
    Runs all host-side tests and emulator execution scripts (`make test`).

*   **Run Entire Verification Suite**:
    ```bash
    ./dev check
    ```
    Performs formatting, linting, ROM headers validation, unit tests, and emulator integration scenarios.

*   **Rebuild Image**:
    ```bash
    ./dev rebuild-image
    ```
    Forces Docker to rebuild the development container image from scratch, downloading and verifying all tools.

*   **Print Pinned Tool Versions**:
    ```bash
    ./dev versions
    ```
    Prints the pinned versions from `versions.env` and query tool output inside the active image.

*   **Run Interactive Shell**:
    ```bash
    ./dev shell
    ```
    Opens a `/bin/bash` interactive session inside the development container.

## Folder Mounts and File Permissions

*   The repository is bind-mounted to `/workspace` inside the container.
*   By default, the container runs commands using the host's active User ID (UID) and Group ID (GID) passed via the command wrapper. This ensures that any files created by the compilers or tests (e.g. inside `build/` or `test-results/`) are owned by your host user and can be modified or deleted without requiring root permissions.

## Offline/Network-Isolated Verification

Once the image is built, all compilation, testing, and asset conversion operations run locally without network access. You can verify this by running:

```bash
docker run --rm \
    --network none \
    --volume "$PWD:/workspace" \
    --workdir /workspace \
    p-maze-gb-dev:latest \
    make check
```

## Adding or Updating Dependencies

To update tool versions:
1. Edit `tools/container/versions.env` to change the version number.
2. If changing release tarballs, download the new archive on the host, compute its SHA-256 (`sha256sum archive.tar.gz`), and update the corresponding line in `tools/container/checksums.txt`.
3. Rebuild the image: `./dev rebuild-image`.

---
*Copyright (C) 2026 Oasis Loop Labs. Licensed under GPL-2.0-only.*
