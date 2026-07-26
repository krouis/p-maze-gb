# =============================================================================
# Pixel Maze GB
# File:        tools/container/Dockerfile
# Description: Multi-stage Dockerfile for a hermetic Game Boy dev environment.
#
# Copyright (C) 2026 Oasis Loop Labs
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; version 2 of the License.
#
# SPDX-License-Identifier: GPL-2.0-only
# =============================================================================

# syntax=docker/dockerfile:1

ARG BASE_IMAGE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

# --- Stage 1: Toolchain Builder (RGBDS) ---
FROM ${BASE_IMAGE} AS toolchain-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    pkg-config \
    libpng-dev \
    bison \
    && rm -rf /var/lib/apt/lists/*

COPY tools/container/checksums.txt /tmp/checksums.txt

RUN curl -L -f -o /tmp/rgbds-0.7.0.tar.gz https://github.com/gbdev/rgbds/releases/download/v0.7.0/rgbds-0.7.0.tar.gz \
    && (cd /tmp && grep "rgbds-0.7.0.tar.gz" /tmp/checksums.txt | sha256sum --check -) \
    && mkdir -p /tmp/rgbds \
    && tar -xzf /tmp/rgbds-0.7.0.tar.gz -C /tmp/rgbds --strip-components=1 \
    && cd /tmp/rgbds \
    && make -j$(nproc) \
    && make install PREFIX=/opt/rgbds

# --- Stage 2: Emulator Builder (SameBoy & binjgb) ---
FROM ${BASE_IMAGE} AS emulator-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    pkg-config \
    cmake \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=toolchain-builder /opt/rgbds /opt/rgbds
ENV PATH="/opt/rgbds/bin:${PATH}"

COPY tools/container/checksums.txt /tmp/checksums.txt

# Build SameBoy tester and lib
RUN curl -L -f -o /tmp/sameboy-1.0.3.tar.gz https://github.com/LIJI32/SameBoy/archive/refs/tags/v1.0.3.tar.gz \
    && (cd /tmp && grep "sameboy-1.0.3.tar.gz" /tmp/checksums.txt | sha256sum --check -) \
    && mkdir -p /tmp/sameboy \
    && tar -xzf /tmp/sameboy-1.0.3.tar.gz -C /tmp/sameboy --strip-components=1 \
    && cd /tmp/sameboy \
    && make -j$(nproc) tester lib CONF=release \
    && mkdir -p /opt/sameboy/bin /opt/sameboy/lib /opt/sameboy/include/sameboy \
    && cp build/bin/tester/sameboy_tester /opt/sameboy/bin/ \
    && cp build/bin/tester/*.bin /opt/sameboy/bin/ \
    && cp build/lib/libsameboy.a /opt/sameboy/lib/ \
    && cp build/lib/libsameboy.so /opt/sameboy/lib/ \
    && cp -r build/include/sameboy/* /opt/sameboy/include/sameboy/

# Build binjgb-tester
RUN curl -L -f -o /tmp/binjgb-0.1.11.tar.gz https://github.com/binji/binjgb/archive/refs/tags/v0.1.11.tar.gz \
    && (cd /tmp && grep "binjgb-0.1.11.tar.gz" /tmp/checksums.txt | sha256sum --check -) \
    && mkdir -p /tmp/binjgb \
    && tar -xzf /tmp/binjgb-0.1.11.tar.gz -C /tmp/binjgb --strip-components=1 \
    && cd /tmp/binjgb \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc) binjgb-tester \
    && mkdir -p /opt/binjgb/bin \
    && cp binjgb-tester /opt/binjgb/bin/

# --- Stage 3: Dev Environment (Final) ---
FROM ${BASE_IMAGE} AS dev

# Install system runtime tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    libpng16-16 \
    python3 \
    python3-dev \
    python3-venv \
    python3-pip \
    shellcheck \
    && rm -rf /var/lib/apt/lists/*

COPY tools/container/checksums.txt /tmp/checksums.txt

# Install actionlint
RUN curl -L -f -o /tmp/actionlint_1.7.12_linux_amd64.tar.gz https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz \
    && (cd /tmp && grep "actionlint_1.7.12_linux_amd64.tar.gz" /tmp/checksums.txt | sha256sum --check -) \
    && tar -xzf /tmp/actionlint_1.7.12_linux_amd64.tar.gz -C /usr/local/bin/ actionlint

# Copy toolchain and emulators
COPY --from=toolchain-builder /opt/rgbds /opt/rgbds
COPY --from=emulator-builder /opt/sameboy /opt/sameboy
COPY --from=emulator-builder /opt/binjgb /opt/binjgb

# Set up Python virtual environment and pre-install dependencies
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:/opt/rgbds/bin:/opt/sameboy/bin:/opt/binjgb/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/sameboy/lib:${LD_LIBRARY_PATH}"

# Install pinned Python packages
COPY tools/container/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Metadata Labels
LABEL org.opencontainers.image.title="Pixel Maze GB Dev Environment" \
      org.opencontainers.image.description="Hermetic Game Boy development and testing environment" \
      org.opencontainers.image.source="https://github.com/krouis/p-maze-gb" \
      org.opencontainers.image.licenses="GPL-2.0-only"

WORKDIR /workspace
