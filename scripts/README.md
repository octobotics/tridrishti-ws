# Robot workspace scripts

Workspace changes and commits require prior approval from **Hrithik
Dhongadi**. See the [maintenance policy](../README.md#maintenance-and-approval).

Run these commands from the workspace root (`~/tridrishti_ws`). The robot
packages live in `src/`; [src_repos.sh](src_repos.sh) lists which packages the
scripts build and launch, their order, binary paths, configs, and shutdown
grace periods.

## Robot startup

### Before you start: check the configuration

Check the settings for **this robot and this network** before installing the
boot service or launching the stack:

1. Review the `src/<package>/config/config.json` files for nodes that have
   one. The packages and config files used by the launcher are listed in
   [src_repos.sh](src_repos.sh). In particular, check sensor addresses, device
   ports, and mission settings.
2. Check the robot's Ethernet mode with
   `./scripts/toggle_network_interface.sh status`. Use the network access
   instructions below if the robot and controlling PC are on different
   address ranges.
3. Set the controller's hard-coded `isConnected()` host address to the
   **controlling PC's IP**: `10.0.0.2` for the direct cable, or the PC's actual
   IP on the router/Wi-Fi network. See [Set the controller's host PC
   address](#set-the-controllers-host-pc-address). Rebuild the controller if
   you change this source value.

Then follow **Start automatically at boot** or **Start manually** below.

### Start automatically at boot

The installed `tridrishti-robot-stack.service` runs
[launch_robot_stack.sh](launch_robot_stack.sh) as root. Check it after boot:

```bash
systemctl status tridrishti-robot-stack.service
journalctl -u tridrishti-robot-stack.service -b -f
```

Install and enable the service once with
`sudo ./scripts/install_robot_stack_service.sh`. Add `--start` to start it
immediately. To stop or restart the installed service:

```bash
sudo systemctl stop tridrishti-robot-stack.service
sudo systemctl restart tridrishti-robot-stack.service
```

See [robot_stack_service.md](robot_stack_service.md) for the unit preview,
optional environment file, and uninstall command. Because the service runs as
root, its run logs are owned by root.

### Start manually

Stop the boot service first so two stacks do not run at once. Build missing
binaries before launching:

```bash
sudo systemctl stop tridrishti-robot-stack.service
./scripts/build_src_repos.sh
sudo ./scripts/launch_robot_stack.sh --show-log ouster
```

Press Ctrl-C in the launch terminal to stop the stack. Omit `--show-log` for
quieter output, or use `--show-log mip,dwe` or `--show-log all`. The launcher
accepts `--help` for all options, including `--no-can-up` and
`--no-health-monitor` for focused tests.

### What the launcher does

1. Creates `logs/robot/<YYYYMMDD_HHMMSS>/` and records the selected binaries
   and configs in `session.env`.
2. Stops previously running robot nodes, configures `can1` at 1 Mbit/s, and
   starts host health logging.
3. Starts each node listed in `src_repos.sh` in order. Each node gets its own
   `<name>.log`; Ouster also gets its effective config copied to the run folder.
4. On Ctrl-C or service stop, signals its nodes and waits their configured
   shutdown grace periods.

The service being `active` means the launcher is running; inspect the node
logs to confirm sensors and motors are healthy. For CAN, run
`ip -details -statistics link show can1`. An administratively UP interface
does not establish that the motors are powered and acknowledging frames.

## Script index

| Script | Purpose | Example |
| --- | --- | --- |
| [launch_robot_stack.sh](launch_robot_stack.sh) | Start and supervise the full robot stack | `sudo ./scripts/launch_robot_stack.sh --show-log ouster` |
| [stop_robot_nodes.sh](stop_robot_nodes.sh) | Stop named nodes by verified executable path | `./scripts/stop_robot_nodes.sh --dry-run all` |
| [can_interface.sh](can_interface.sh) | Configure or inspect SocketCAN | `./scripts/can_interface.sh status` |
| [monitor_robot_health.sh](monitor_robot_health.sh) | Record thermal, power, tegrastats, and kernel logs | `./scripts/monitor_robot_health.sh --interval 1` |
| [install_robot_stack_service.sh](install_robot_stack_service.sh) | Generate, install, and enable the boot service | `sudo ./scripts/install_robot_stack_service.sh --start` |
| [generate_robot_stack_service.sh](generate_robot_stack_service.sh) | Print the systemd unit without installing it | `./scripts/generate_robot_stack_service.sh` |
| [uninstall_robot_stack_service.sh](uninstall_robot_stack_service.sh) | Stop, disable, and remove the boot service | `sudo ./scripts/uninstall_robot_stack_service.sh` |
| [setup_persistent_journal.sh](setup_persistent_journal.sh) | Keep system journal entries across reboots | `sudo ./scripts/setup_persistent_journal.sh` |
| [clone_src_repos.sh](clone_src_repos.sh) | Clone missing repositories from `src_repos.sh` | `./scripts/clone_src_repos.sh` |
| [pull_src_repos.sh](pull_src_repos.sh) | Fast-forward selected repositories | `./scripts/pull_src_repos.sh mip-i2w` |
| [build_src_repos.sh](build_src_repos.sh) | Build all or selected repositories | `./scripts/build_src_repos.sh mip-i2w` |
| [ecal_map.py](ecal_map.py) | Export a live eCAL node/topic/service graph to `ecal_topology/` | `python3 scripts/ecal_map.py` |
| [toggle_network_interface.sh](toggle_network_interface.sh) | Switch the robot Ethernet port between inter-device and normal network modes | `./scripts/toggle_network_interface.sh status` |
| [launch_local_fusion.sh](launch_local_fusion.sh) | Older three-node fusion test launcher | See note below |

`launch_local_fusion.sh` defaults to `src/mip-lidar-aiding-i2w`, which is not
present in this checkout. Use the full stack launcher for current runs, or
override that test launcher's paths if you have the older package. Changing
network mode can disconnect an SSH session on that interface.

## Troubleshooting robot Ethernet access

[toggle_network_interface.sh](toggle_network_interface.sh) configures the
robot's `enP1p1s0` port. Its two modes are:

| Robot mode | Robot IP | Directly connected PC IP | PC netmask | PC gateway |
| --- | --- | --- | --- | --- |
| `normal` (router) | `192.168.0.10` | `192.168.0.1` temporarily, with the router disconnected | `255.255.255.0` | Leave blank for the temporary direct connection |
| `inter-device` (direct cable) | `10.0.0.1` | `10.0.0.2` | `255.255.255.0` | `10.0.0.1` |

### Set the controller's host PC address

The controller's [`isConnected()` check](../src/TriDrishti-ControllerNode/src/i2wControllerNode.cpp) 
pings a **hard-coded host PC address** to decide whether the UI connection is
live. Set `host` in that function to the address of the PC controlling the robot whenever its network address changes:

| Connection | Set controller `host` to |
| --- | --- |
| Direct cable, robot at `10.0.0.1` | `10.0.0.2` |
| Router or Wi-Fi, robot at `192.168.0.10` | The controlling PC's actual IP on that network (for example, `192.168.0.195` only if that is its current address) |

Use the **PC's IP**, not the robot's IP or the router gateway. After editing
the source, rebuild `TriDrishti-ControllerNode` and restart the robot stack so
the running controller uses the new address. The check requires the PC to
answer ping; a firewall blocking ICMP can make it appear disconnected even
when SSH or the UI works.

On an Ubuntu PC, open **Settings → Network → Wired connection → gear icon →
IPv4**, choose **Manual**, enter the address, netmask and gateway shown above,
then **Apply**.

### If the robot is at `192.168.0.10`, but you want a direct PC connection

![Temporary PC IPv4 settings: 192.168.0.1](<assets/Screenshot from 2026-10-30 15-49-43.png>)

1. Keep the router disconnected from this link. Connect the PC directly to
   the robot and temporarily set the **PC Ethernet IPv4 address** to
   `192.168.0.1`, netmask `255.255.255.0`, gateway blank.
2. SSH into the robot and switch it to the direct-link mode:

   ```bash
   ssh tridrishti@192.168.0.10
   cd ~/tridrishti_ws
   sudo ./scripts/toggle_network_interface.sh inter-device
   ```

3. The SSH session will disconnect when the robot changes IP. Set the PC
   Ethernet address to `10.0.0.2`, netmask `255.255.255.0`, gateway
   `10.0.0.1`, and reconnect:

   ```bash
   ssh tridrishti@10.0.0.1
   cd ~/tridrishti_ws
   ./scripts/toggle_network_interface.sh status
   ```

The robot is now in direct-link mode for normal operation with the PC.

### If the robot is at `10.0.0.1`, but you want it on the router

![PC IPv4 settings for the direct link: 10.0.0.2](<assets/Screenshot from 2026-10-30 15-49-06.png>)

1. With the PC still directly connected at `10.0.0.2/24`, SSH into the robot
   and switch to router mode:

   ```bash
   ssh tridrishti@10.0.0.1
   cd ~/tridrishti_ws
   sudo ./scripts/toggle_network_interface.sh normal
   ```

2. The SSH session will disconnect. Connect the robot's Ethernet port to the
   router. Restore the PC's router connection (usually **Automatic/DHCP**),
   then connect to the robot at `192.168.0.10`:

   ```bash
   ssh tridrishti@192.168.0.10
   cd ~/tridrishti_ws
   ./scripts/toggle_network_interface.sh status
   ```

The `normal` mode assumes the router uses `192.168.0.1` and the robot can use
`192.168.0.10`. Do not leave the PC set to `192.168.0.1` when connecting it to
that router; it would duplicate the router's address. If the robot is not
reachable, check the active address and link on the robot with
`./scripts/toggle_network_interface.sh status` from a local console.
