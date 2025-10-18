set -e
set -x

# build and install
cd /root
mkdir xrt-git

# Use git cache if available
GIT_CLONE_OPTS=""
if [ -n "$GIT_CACHE_DIR" ] && [ -d "$GIT_CACHE_DIR" ]; then
    # Create a safe directory name from the URL (matches setup script naming)
    CACHE_NAME="github.com_Xilinx_XRT"
    CACHE_PATH="$GIT_CACHE_DIR/$CACHE_NAME"

    if [ -d "$CACHE_PATH" ]; then
        echo "Using git cache: $CACHE_PATH"
        GIT_CLONE_OPTS="--reference $CACHE_PATH"
    else
        echo "Git cache directory not found: $CACHE_PATH"
    fi
fi

git clone $GIT_CLONE_OPTS https://github.com/Xilinx/XRT xrt-git
cd xrt-git
git checkout -b temp tags/202210.2.13.466

# An incorrect format specifier causes a crash on armhf
sed -i 's:%ld bytes):%lld bytes):' src/runtime_src/tools/xclbinutil/XclBinClass.cxx

# Disable xbtop completely - it has CMake syntax errors and we don't need it
# Just replace the entire CMakeLists.txt with a minimal one
cat > src/runtime_src/core/tools/xbtop/CMakeLists.txt << 'EOF'
# xbtop disabled - not needed for embedded builds
message(STATUS "xbtop skipped for embedded build")
EOF

cd build
chmod 755 build.sh
XRT_NATIVE_BUILD=no ./build.sh -dbg -noctest
cd Debug
make install

# Build and install xclbinutil
cd ../../
mkdir xclbinutil_build
sed -i 's/xdp_hw_emu_device_offload_plugin xdp_core xrt_coreutil xrt_hwemu/xdp_core xrt_coreutil/g' ./src/runtime_src/xdp/CMakeLists.txt

cd xclbinutil_build/
cmake ../src/
make install -C runtime_src/tools/xclbinutil
mv /opt/xilinx/xrt/bin/unwrapped/xclbinutil /usr/local/bin/xclbinutil
rm -rf /opt/xilinx/xrt

# cleanup
cd /root
rm -rf xrt-git
