#!/usr/bin/env bash

# Format: repo-name|clone-url|build-mode|launch-name|binary-relpath|config-relpath|shutdown-grace-sec
# build-mode is "build" for repos with scripts/build.sh, or "skip" for
# source/header-only repos consumed by other packages.
# Leave launch-name, binary-relpath, and config-relpath empty for repos that
# should not be launched by launch_robot_stack.sh.
# shutdown-grace-sec is used by launch_robot_stack.sh after SIGTERM is sent to
# that node, before moving to the next node in list order.
SRC_REPOS=(
  "i2w|https://github.com/octobotics/i2w.git|build||||0"
  "crawler-i2w-msgs|https://github.com/octobotics/crawler-i2w-msgs.git|skip||||0"
  "ouster-lidar-pub|https://github.com/octobotics/ouster-lidar-pub.git|build|ouster|build/ouster_lidar_i2w_pub|config/config.json|1"
  "mip-i2w|https://github.com/octobotics/mip-i2w.git|build|mip|build/mip_i2w_node|config/config.json|0"
  "attitude-correction-i2w|https://github.com/octobotics/attitude-correction-i2w.git|build|attitude_correction|build/attitude_correction_i2w_node|config/config.json|1"
  "dwe-cam-gst-i2w|https://github.com/octobotics/dwe-cam-gst-i2w.git|build|dwe|build/dwe_cam_gst_i2w_node|config/config.json|0"
  "robot-tf-static-i2w|https://github.com/octobotics/robot-tf-static-i2w.git|build|robot_tf_static|build/robot_tf_static_i2w_node|config/config.json|0"
  "robot-ui-sync|https://github.com/octobotics/robot-ui-sync.git|build|robot_ui_sync|build/robot_ui_sync_node|config/config.json|0"
  "local-ekf-i2w|https://github.com/octobotics/local-ekf-i2w.git|build|local_ekf|build/local_ekf_i2w_node|config/config.json|0"
  "tank-localization-i2w|https://github.com/octobotics/tank-localization-i2w.git|build|tank_localization|build/tank_localization_i2w_node|config/config.json|1"
  "TriDrishti-ControllerNode|https://github.com/octobotics/TriDrishti-ControllerNode.git|build|mcu|build/robot_mcu_node||1"
  "TriDrishti-MyActuator-CPF|https://github.com/octobotics/TriDrishti-MyActuator-CPF.git|build|myactuator|build/myactuator_cpf_i2w_diff_drive||0"
)
