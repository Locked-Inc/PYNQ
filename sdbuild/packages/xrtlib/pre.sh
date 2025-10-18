#!/bin/bash

set -e
set -x

target=$1

# Install build dependencies needed for XRT
sudo chroot $target apt-get install -y \
    pkg-config \
    libdrm-dev \
    libboost-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    ocl-icd-opencl-dev \
    ocl-icd-dev \
    opencl-headers \
    protobuf-compiler \
    libprotoc-dev \
    uuid-dev \
    libssl-dev \
    libudev-dev \
    libncurses5-dev \
    rapidjson-dev \
    libffi-dev
