# Robot stack repositories

The robot stack uses the repositories below under `src/`. The authoritative
list, including clone URLs, build order, binaries, and config paths, is
[`scripts/src_repos.sh`](../scripts/src_repos.sh).

| Repository | Used for |
| --- | --- |
| [i2w](https://github.com/octobotics/i2w.git) | Shared i2w runtime |
| [crawler-i2w-msgs](https://github.com/octobotics/crawler-i2w-msgs.git) | Shared message and service definitions |
| [ouster-lidar-pub](https://github.com/octobotics/ouster-lidar-pub.git) | Ouster LiDAR publisher |
| [mip-i2w](https://github.com/octobotics/mip-i2w.git) | MIP IMU publisher |
| [attitude-correction-i2w](https://github.com/octobotics/attitude-correction-i2w.git) | Attitude correction |
| [mission-planner-i2w](https://github.com/octobotics/mission-planner-i2w) | Mission planner |
| [dwe-cam-gst-i2w](https://github.com/octobotics/dwe-cam-gst-i2w.git) | DWE camera publisher |
| [robot-tf-static-i2w](https://github.com/octobotics/robot-tf-static-i2w.git) | Static robot transforms |
| [robot-ui-sync](https://github.com/octobotics/robot-ui-sync.git) | Robot data bridge to the UI |
| [local-ekf-i2w](https://github.com/octobotics/local-ekf-i2w.git) | Local flat-ground pose estimator |
| [tank-localization-i2w](https://github.com/octobotics/tank-localization-i2w.git) | Tank pose estimator |
| [TriDrishti-ControllerNode](https://github.com/octobotics/TriDrishti-ControllerNode.git) | Robot controller node |
| [TriDrishti-MyActuator-CPF](https://github.com/octobotics/TriDrishti-MyActuator-CPF.git) | Drive motor interface |
| [TriDrishti-STMHALNode](https://github.com/octobotics/TriDrishti-STMHALNode.git) | STM hardware interface |

## Install GitHub CLI and sign in

The clone script uses HTTPS GitHub URLs. On a new Ubuntu/Jetson setup, install
Git and the GitHub CLI (`gh`). If `gh --version` already works, skip its
installation. The commands below follow the [official GitHub CLI Linux
installation instructions](https://github.com/cli/cli/blob/trunk/docs/install_linux.md):

```bash
sudo apt update
sudo apt install git wget
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -nv -O /tmp/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg
sudo cp /tmp/githubcli-archive-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

Sign in **as the normal user who will clone the repositories**, without
`sudo`. Use a GitHub account with access to the `octobotics` repositories:

```bash
gh auth login --hostname github.com --git-protocol https
gh auth setup-git
gh auth status
```

Follow the login prompt to authenticate in a browser. On a headless robot,
open the displayed GitHub device-login URL on your PC and enter the code shown
in the robot terminal. `gh auth setup-git` configures Git to use the GitHub CLI
credentials for HTTPS clones; `gh auth status` verifies the login. The command
is **`gh auth login`**, not `git auth login`. See the [login](https://cli.github.com/manual/gh_auth_login)
and [Git credential setup](https://cli.github.com/manual/gh_auth_setup-git)
manual pages for details.

## Clone the repositories

From the workspace root (`~/tridrishti_ws`), run:

```bash
./scripts/clone_src_repos.sh
```

The script reads [`scripts/src_repos.sh`](../scripts/src_repos.sh) and clones
each missing repository into `src/`. It skips directories that already exist;
it does not update existing clones. To update existing repositories, use
[`scripts/pull_src_repos.sh`](../scripts/pull_src_repos.sh).

Before building or launching, review the configuration and startup steps in
[`scripts/README.md`](../scripts/README.md). Build the listed packages with
`./scripts/build_src_repos.sh` from the workspace root.
