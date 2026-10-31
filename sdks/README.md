# Dependencies for the robot stack

Workspace changes and commits require prior approval from **Hrithik
Dhongadi**. See the [maintenance policy](../README.md#maintenance-and-approval).

This page covers the packages in [`scripts/src_repos.sh`](../scripts/src_repos.sh)
on the Ubuntu/Jetson (`aarch64`) workspace. Run commands from the workspace
root (`~/tridrishti_ws`). The source repositories themselves are listed in
[`src/README.md`](../src/README.md).

## ARM64 SDK archive (quick setup)

A copy of the current SDK folders, including the ARM64 Ouster build and CMake
binary, is available in the [shared WorkDrive SDK archive](https://workdrive.zoho.in/file/xlryl18e2b7e83bb949c0bba8ec0a2879bdb3).
The local file is `~/tridrishti_ws/sdks.zip`; it is not part of this Git
workspace. Download it to the **workspace root**, then extract it there:

```bash
cd ~/tridrishti_ws
sudo apt install unzip
unzip -n sdks.zip
test -f sdks/ouster-sdk/build/OusterSDKConfig.cmake
test -x sdks/cmake-3.25.3-linux-aarch64/bin/cmake
```

The archive already contains a top-level `sdks/` directory, so do not extract
it from inside `sdks/`. `unzip -n` preserves existing files, including this
README. The archive includes the six additional SDK folders listed at the end
of this guide. Install the Ubuntu packages in step 1 even when using the
archive; the compiled SDKs still need their system libraries and headers.

The archived CMake build cache records the original workspace path
`/home/tridrishti/tridrishti_ws`. It is intended for an ARM64 Jetson with that
layout. If the workspace is at a different path, rebuild the Ouster SDK from
source using step 3 after removing its archived `build/` directory.

## 1. Install command-line tools and development packages

```bash
sudo apt update
sudo apt install \
  build-essential git wget ninja-build pkg-config doxygen \
  libeigen3-dev libtbb-dev libceres-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libcurl4-openssl-dev libtins-dev libpcap-dev libglfw3-dev \
  libpng-dev libflatbuffers-dev flatbuffers-compiler \
  libssl-dev libzip-dev libzstd-dev zlib1g-dev
```

These packages cover the Ouster C++ SDK's sensor/PCAP/OSF libraries, the
Ouster node's Eigen/TBB/Ceres/KISS build, DWE camera GStreamer headers, and
the mission planner's required Doxygen target. The Ouster SDK's own
[C++ build guide](ouster-sdk/docs/cpp/building.rst) has its full dependency
list. `libglfw3-dev` is kept here because the current Ouster CMake package
looks it up when another package consumes the static SDK.

The [`i2w` build script](../src/i2w/scripts/build.sh) requires **CMake 3.24
or newer** to build eCAL. This workspace contains CMake 3.25.3 for Jetson at
`sdks/cmake-3.25.3-linux-aarch64/`; put it first in `PATH` before building:

```bash
export PATH="$PWD/sdks/cmake-3.25.3-linux-aarch64/bin:$PATH"
cmake --version
```

If the extracted directory is missing, download the matching installer from
the [Kitware CMake 3.25.3 release](https://github.com/Kitware/CMake/releases/tag/v3.25.3)
when necessary, then extract it from the workspace root:

```bash
if [ ! -f sdks/cmake-3.25.3-linux-aarch64.sh ]; then
  wget -O sdks/cmake-3.25.3-linux-aarch64.sh \
    https://github.com/Kitware/CMake/releases/download/v3.25.3/cmake-3.25.3-linux-aarch64.sh
fi
mkdir -p sdks/cmake-3.25.3-linux-aarch64
sh sdks/cmake-3.25.3-linux-aarch64.sh \
  --skip-license --exclude-subdir \
  --prefix="$PWD/sdks/cmake-3.25.3-linux-aarch64"
```

On a different architecture, use a compatible CMake 3.24+ binary; the
`linux-aarch64` installer only runs on ARM64. The `PATH` export applies to the
current shell, including when it runs `./scripts/build_src_repos.sh`.

## 2. Check the SDK source folders

| Folder | Version verified in this workspace | Used by | Build separately? |
| --- | --- | --- | --- |
| `sdks/ouster-sdk` | 0.16.1, commit `409b452` (one commit after tag `v0.16.1`) | `ouster-lidar-pub` sensor, PCAP, and OSF libraries | **Yes**, create its `build/OusterSDKConfig.cmake` and static libraries |
| `sdks/mip_sdk` | 4.0.0, commit `212583c` (`v4.0.0`) | `mip-i2w` | No; added as a CMake subdirectory |
| `sdks/kiss-icp` | 1.3.0, commit `1ffa7d7` (one commit after tag `v1.3.0`) | Ouster LiDAR odometry | No; added as a CMake subdirectory by `ouster-lidar-pub` |
| `sdks/myactuator_rmd` | CMake project version 0.0.1, commit `c43980c` (no release tag at this checkout) | `TriDrishti-MyActuator-CPF` | No; added as a CMake subdirectory |
| `sdks/cmake-3.25.3-linux-aarch64` | 3.25.3 (`cmake --version`) | Build tool on Jetson | Prebuilt; extract the included installer if needed |

Versions above were checked against the local SDK version files/CMake projects,
Git checkout revisions, and the bundled CMake executable. The full Git commit
IDs used to reproduce those checkouts are in the commands below.

If any of the four source folders are missing, clone them **into these exact
paths**. Run only the clone/checkout pair for each missing folder; do not
overwrite an existing SDK checkout. The revisions below are the ones present
in this workspace:

```bash
git clone https://github.com/ouster-lidar/ouster-sdk.git sdks/ouster-sdk
git -C sdks/ouster-sdk checkout 409b4529fcf853f656840d627e991ad869febbfc
git clone https://github.com/HBK-MicroStrain/mip_sdk.git sdks/mip_sdk
git -C sdks/mip_sdk checkout 212583cf5dd12fd695d325dccb64b8c473334895
git clone https://github.com/PRBonn/kiss-icp.git sdks/kiss-icp
git -C sdks/kiss-icp checkout 1ffa7d7512f10bfc8b1185095011fa31184019e3
git clone https://github.com/2b-t/myactuator_rmd.git sdks/myactuator_rmd
git -C sdks/myactuator_rmd checkout c43980cac5948cfd4974a96b86fbac0a80749ed6
```

These are source dependencies, not Python packages. `pip install ouster-sdk`
or `pip install kiss-icp` does not provide the CMake targets used by this
workspace. The `ouster-sdk/thirdparty/sophus` directory must also be present;
it is supplied with the Ouster checkout and used by the KISS build.

## 3. Build the Ouster C++ SDK

The publisher expects the Ouster CMake package at
`sdks/ouster-sdk/build/OusterSDKConfig.cmake`. Build the required static
libraries before building `src/ouster-lidar-pub`:

```bash
cmake -S sdks/ouster-sdk -B sdks/ouster-sdk/build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SENSOR=ON -DBUILD_PCAP=ON -DBUILD_OSF=ON \
  -DBUILD_VIZ=OFF -DBUILD_MAPPING=OFF \
  -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF \
  -DBUILD_PYTHON_MODULE=OFF -DBUILD_SHARED_LIBRARY=OFF
cmake --build sdks/ouster-sdk/build -j2
test -f sdks/ouster-sdk/build/OusterSDKConfig.cmake
test -f sdks/ouster-sdk/build/ouster_client/libouster_client.a
test -f sdks/ouster-sdk/build/ouster_sensor/libouster_sensor.a
test -f sdks/ouster-sdk/build/ouster_pcap/libouster_pcap.a
test -f sdks/ouster-sdk/build/ouster_osf/libouster_osf.a
```

The reduced options build the libraries required by `ouster-lidar-pub` without
the SDK's visualizer or mapping application. Increase `-j2` if the machine
has enough memory. The Ouster node consumes this build tree directly; a
system-wide `sudo cmake --install` is unnecessary.

## 4. Other required source outside `sdks/`

The controller, MyActuator, and STM packages add `utils/logger` as a CMake
subdirectory. It is **not** in `scripts/src_repos.sh`, so ensure it exists
before building those packages:

```bash
git clone https://github.com/octopriyanshu123/logger.git utils/logger
git -C utils/logger checkout 1ae04fea12392422f3a7c9c4ad749aa4bb6a2f0f
```

Skip that command if `utils/logger/CMakeLists.txt` is already present.
The `i2w` build script separately clones and builds its pinned eCAL checkout
under `src/i2w/third_party/ecal` and downloads DataTamer through CMake. An
internet connection is therefore needed on a clean build even after the SDK
folders above have been cloned.

## 5. Build the source packages

After cloning the repositories in [`src/README.md`](../src/README.md), run:

```bash
./scripts/build_src_repos.sh
```

The script builds `i2w` first, then the nodes in the order declared in
[`scripts/src_repos.sh`](../scripts/src_repos.sh). Keep the CMake `PATH` export
from step 1 in this shell.

## Recommended SDK folders for additional workspace repositories

Keep the following source/vendor folders under `sdks/` when setting up a full
development workspace. Other repositories that may be cloned into `src/` will
use them, even though the **current** `scripts/src_repos.sh` build does not
consume them:

| Folder to keep in `sdks/` | Intended use |
| --- | --- |
| `aravis-0.8.35` | Aravis camera integration |
| `scanCONTROL-Linux-SDK-1-0-1` | scanCONTROL sensor integration |
| `imgui` | Dear ImGui user interfaces |
| `freetype-2.9` | Font rendering |
| `my-actuator-rs485-lib` | MyActuator RS-485 integration |
| `rmdcan-usbcan` | RMD CAN/USB-CAN integration |

Preserve these folder names and locations when copying or downloading the
SDKs. They are **recommended workspace dependencies**, not obsolete files.
Build or install each one according to the additional repository that needs
it; the current `build_src_repos.sh` does not build these six SDKs.
