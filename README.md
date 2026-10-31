# Tridrishti Robot Workspace

This workspace builds and runs the TriDrishti robot stack on the Ubuntu/Jetson
host. Run the commands below from the workspace root (`~/tridrishti_ws`). The
current package list and launch order are defined in
[`scripts/src_repos.sh`](scripts/src_repos.sh).

## Working in this workspace

**Hrithik Dhongadi** maintains this workspace. Please get his approval before
changing files or making commits, including changes to source repositories,
SDKs, scripts, configuration, and documentation.

| Directory | What it contains |
| --- | --- |
| [`src/`](src/README.md) | Robot node repositories and shared message/runtime packages |
| [`sdks/`](sdks/README.md) | C++ SDK source, a Jetson CMake binary, and dependency instructions |
| [`scripts/`](scripts/README.md) | Clone, build, launch, service, network, and troubleshooting scripts |
| `utils/logger/` | Logger source required by the controller, motor, and STM nodes |
| `logs/robot/` | Per-run node logs created by the launcher |

## Set up a new workspace

### 1. Install GitHub CLI and authenticate

The source clone script uses HTTPS GitHub URLs. Install `git` and GitHub CLI
(`gh`) using the instructions in [src/README.md](src/README.md#install-github-cli-and-sign-in),
then sign in **as the normal user who will clone the repositories**:

```bash
gh auth login --hostname github.com --git-protocol https
gh auth setup-git
gh auth status
```

Use an account with access to the `octobotics` repositories. On a headless
Jetson, complete the device-code login in a browser on your PC. The command is
`gh auth login` (not `git auth login`); do not run it with `sudo`.

### 2. Install build dependencies and SDKs

Follow [sdks/README.md](sdks/README.md) to install the Ubuntu development
packages and check the SDK revisions. For the standard ARM64 Jetson layout,
you can download the [prebuilt SDK archive from WorkDrive](https://workdrive.zoho.in/file/xlryl18e2b7e83bb949c0bba8ec0a2879bdb3),
save it as `sdks.zip` in the workspace root, and follow the
[archive extraction steps](sdks/README.md#arm64-sdk-archive-quick-setup).
The archive is not committed to this workspace. Otherwise, follow the SDK
source clone and Ouster build steps in `sdks/README.md`. The main SDK
versions verified in this workspace are:

| Dependency | Version / local revision | Required by |
| --- | --- | --- |
| Ouster C++ SDK | 0.16.1 / `409b452` | Ouster LiDAR publisher |
| MIP SDK | 4.0.0 / `212583c` | MIP IMU node |
| KISS-ICP | 1.3.0 / `1ffa7d7` | LiDAR odometry |
| myactuator_rmd | CMake project 0.0.1 / `c43980c` | Drive motor node |
| CMake for Jetson | 3.25.3 | `i2w`/eCAL build |

Keep these source folders at their documented paths under `sdks/`. The
Ouster SDK must be built first so
`sdks/ouster-sdk/build/OusterSDKConfig.cmake` and its static libraries exist.
MIP SDK, KISS-ICP, and myactuator_rmd are built within their consuming node
builds. Also ensure `utils/logger/CMakeLists.txt` exists; its clone command is
in [sdks/README.md](sdks/README.md#4-other-required-source-outside-sdks).
For a full development workspace, also keep the recommended Aravis,
scanCONTROL, ImGui, FreeType, RS-485, and USB-CAN folders under `sdks/` for
additional repositories that may be cloned later. Their exact folder names
are in [sdks/README.md](sdks/README.md#recommended-sdk-folders-for-additional-workspace-repositories).

### 3. Clone the robot packages

The stack uses these repositories under `src/`:

| Area | Repositories |
| --- | --- |
| Shared foundations | `i2w`, `crawler-i2w-msgs` |
| Sensors and transforms | `ouster-lidar-pub`, `mip-i2w`, `dwe-cam-gst-i2w`, `robot-tf-static-i2w` |
| Localization | `attitude-correction-i2w`, `local-ekf-i2w`, `tank-localization-i2w` |
| Mission and UI | `mission-planner-i2w`, `robot-ui-sync` |
| Hardware control | `TriDrishti-ControllerNode`, `TriDrishti-MyActuator-CPF`, `TriDrishti-STMHALNode` |

```bash
./scripts/clone_src_repos.sh
```

The clone script skips existing repositories; it does not update them. Use
[`scripts/pull_src_repos.sh`](scripts/pull_src_repos.sh) for existing checkouts.
See [src/README.md](src/README.md) for the complete repository list.

### 4. Check the robot configuration

Before starting the stack or enabling boot startup:

1. Review the node `config/config.json` files referenced by
   [`scripts/src_repos.sh`](scripts/src_repos.sh). Check sensor addresses,
   device ports, mission settings, and the real Ouster address if the config
   was previously changed for replay or mock testing.
2. Check the robot's Ethernet mode with
   `./scripts/toggle_network_interface.sh status`.
3. In the controller's
   [`isConnected()` function](src/TriDrishti-ControllerNode/src/i2wControllerNode.cpp),
   set `host` to the **controlling PC's IP**: `10.0.0.2` for a direct cable, or
   the PC's actual address on the router/Wi-Fi network. Rebuild the controller
   after changing this source value.

The detailed [pre-start checklist and network recovery steps](scripts/README.md#robot-startup)
are in `scripts/README.md`.

### 5. Build the robot packages

```bash
./scripts/build_src_repos.sh
```

The build script uses the order in `scripts/src_repos.sh` and automatically
prefers the matching CMake binary under `sdks/`. On a clean build, `i2w` also
downloads its pinned eCAL checkout and DataTamer source, so network access is
needed.

## Start and monitor the robot

For automatic startup at boot, install the service once after building and
checking the configuration:

```bash
sudo ./scripts/install_robot_stack_service.sh
systemctl status tridrishti-robot-stack.service
journalctl -u tridrishti-robot-stack.service -b -f
```

The installer enables the service for the next boot. Add `--start` to the
install command to start it immediately. The service runs
[`launch_robot_stack.sh`](scripts/launch_robot_stack.sh) as root, including its
CAN setup. See [robot_stack_service.md](scripts/robot_stack_service.md) for
service control, preview, and uninstall commands.

For a manual run, stop the boot service first so two stacks do not run at
once:

```bash
sudo systemctl stop tridrishti-robot-stack.service
sudo ./scripts/launch_robot_stack.sh --show-log all
```

Press Ctrl-C to stop a manual run. The launcher writes each node's output to
`logs/robot/<YYYYMMDD_HHMMSS>/<node>.log` and its selected paths to
`session.env`. A running service only confirms that the launcher is active;
check the node logs and sensor/motor telemetry to confirm the robot is ready.

## Robot-to-PC network modes

| Mode | Robot IP | Controlling PC IP |
| --- | --- | --- |
| Direct cable (`inter-device`) | `10.0.0.1` | `10.0.0.2` |
| Router (`normal`) | `192.168.0.10` | The PC's assigned address on that network |

If the robot is on the other address range, follow the
[Ethernet recovery procedure](scripts/README.md#troubleshooting-robot-ethernet-access)
to reach it, switch modes, and update the PC's IPv4 settings. That guide also
includes screenshots. The controller's `isConnected()` ping target must match
the PC's address in the active mode.

## View package changes in VS Code

This workspace has a root `.git` directory, while packages such as
`src/mip-i2w` and `src/ouster-lidar-pub` each have their **own** `.git`
directory. The root repository tracks those packages as Git links, so its
Source Control entry can show only a package-level change instead of the
individual files changed inside that package.

In VS Code, open **Source Control → Repositories** and select the package
repository whose changes you want to inspect. VS Code can display multiple
repositories in one workspace; see its [Repositories view guide](https://code.visualstudio.com/docs/sourcecontrol/repos-remotes#_working-with-repositories).

If the root repository still gets in the way, you can **rename the workspace
root's `.git` directory** from the workspace root and reload the VS Code
window:

```bash
cd ~/tridrishti_ws
mv .git .git-root-backup
```

VS Code can then detect the separate repositories under `src/`. This does not
rename or remove any package's own `.git`. To restore the root repository:

```bash
cd ~/tridrishti_ws
mv .git-root-backup .git
```

Check that the backup name does not already exist before renaming. Deleting
the root `.git` directory is also possible, but it discards the root
repository's local history and configuration; use the reversible rename when
you only want to change the VS Code view. Follow the maintenance approval rule
above before changing workspace Git metadata or committing in any repository.

## Detailed guides

- [Source repositories and GitHub login](src/README.md)
- [SDK and Ubuntu build dependencies](sdks/README.md)
- [Script index, startup, and network troubleshooting](scripts/README.md)
- [Boot service installation and removal](scripts/robot_stack_service.md)
