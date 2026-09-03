#!/usr/bin/env bash

# Format: repo-name|clone-url|build-mode|launch-name|binary-relpath|config-relpath
# build-mode is "build" for repos with scripts/build.sh, or "skip" for
# source/header-only repos consumed by other packages.
# Leave launch-name, binary-relpath, and config-relpath empty for repos that
# should not be launched by launch_robot_stack.sh.
SRC_REPOS=(
  "i2w|https://github.com/octobotics/i2w.git|build|||"
  "crawler-i2w-msgs|https://github.com/octobotics/crawler-i2w-msgs.git|skip|||"
  "ouster-lidar-pub|https://github.com/octobotics/ouster-lidar-pub.git|build|ouster|build/ouster_lidar_i2w_pub|config/config.json"
  "mip-i2w|https://github.com/octobotics/mip-i2w.git|build|mip|build/mip_i2w_node|config/config.json"
  "dwe-cam-gst-i2w|https://github.com/octobotics/dwe-cam-gst-i2w.git|build|dwe|build/dwe_cam_gst_i2w_node|config/config.json"
  "robot-tf-static-i2w|https://github.com/octobotics/robot-tf-static-i2w.git|build|robot_tf_static|build/robot_tf_static_i2w_node|config/config.json"
  "robot-ui-sync|https://github.com/octobotics/robot-ui-sync.git|build|robot_ui_sync|build/robot_ui_sync_node|config/config.json"
  "myactuator-cpf-i2w|https://github.com/octobotics/myactuator-cpf-i2w.git|build|myactuator|build/myactuator_cpf_i2w_diff_drive|"
  "local-ekf-i2w|https://github.com/octobotics/local-ekf-i2w.git|build|local_ekf|build/local_ekf_i2w_node|config/config.json"
  "tank-localization-i2w|https://github.com/octobotics/tank-localization-i2w.git|build|tank_localization|build/tank_localization_i2w_node|config/config.json"
)
