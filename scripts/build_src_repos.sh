#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${WORKSPACE_DIR}/src"
REPO_LIST="${SCRIPT_DIR}/src_repos.sh"

source "${REPO_LIST}"

BUILD_TYPE="${BUILD_TYPE:-Debug}"
export BUILD_TYPE
export I2W_ECAL_INSTALL_DIR="${I2W_ECAL_INSTALL_DIR:-${SRC_DIR}/i2w/build/third_party/ecal-install}"

find_local_cmake_bin() {
  local sdk_root="$1"
  if [[ ! -d "${sdk_root}" ]]; then
    return 0
  fi

  local arch cmake_dir
  arch="$(uname -m)"
  cmake_dir="$(find "${sdk_root}" -maxdepth 1 -type d -name "cmake-*-linux-${arch}" 2>/dev/null | sort -V | tail -n 1)"
  if [[ -n "${cmake_dir}" ]]; then
    printf '%s/bin\n' "${cmake_dir}"
  fi
}

LOCAL_CMAKE_BIN="$(find_local_cmake_bin "${WORKSPACE_DIR}/sdks")"

if [[ -n "${LOCAL_CMAKE_BIN}" && -x "${LOCAL_CMAKE_BIN}/cmake" ]]; then
  export PATH="${LOCAL_CMAKE_BIN}:${PATH}"
fi

continue_on_error=0
selected_repos=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [REPO...]

Builds all buildable repos in ${SRC_DIR}.

Options:
  -h, --help             Show this help.
  -k, --keep-going       Continue building remaining repos after a failure.

Environment:
  BUILD_TYPE=Debug|Release
  I2W_ECAL_INSTALL_DIR=/path/to/ecal-install

This script automatically prefers a matching CMake from:
  ${WORKSPACE_DIR}/sdks/cmake-*-linux-\$(uname -m)/bin

Examples:
  ./scripts/build_src_repos.sh
  BUILD_TYPE=Release ./scripts/build_src_repos.sh
  ./scripts/build_src_repos.sh -k i2w ouster-lidar-pub local-ekf-i2w
EOF
}

has_selected_repo() {
  local repo="$1"
  local selected

  if [[ "${#selected_repos[@]}" -eq 0 ]]; then
    return 0
  fi

  for selected in "${selected_repos[@]}"; do
    if [[ "${selected}" == "${repo}" ]]; then
      return 0
    fi
  done

  return 1
}

is_known_repo() {
  local repo="$1"
  local entry known

  for entry in "${SRC_REPOS[@]}"; do
    IFS='|' read -r known _url _build_mode _launch_name _binary_rel _config_rel <<<"${entry}"
    if [[ "${known}" == "${repo}" ]]; then
      return 0
    fi
  done

  return 1
}

build_repo() {
  local repo="$1"
  local build_mode="$2"
  local repo_dir="${SRC_DIR}/${repo}"
  local build_script="${repo_dir}/scripts/build.sh"

  if [[ ! -d "${repo_dir}" ]]; then
    echo "missing repo: ${repo_dir}" >&2
    return 1
  fi

  if [[ "${build_mode}" == "skip" ]]; then
    echo "Skipping ${repo}: source/header-only package"
    return 0
  fi

  if [[ ! -x "${build_script}" ]]; then
    echo "missing executable build script: ${build_script}" >&2
    return 1
  fi

  echo
  echo "==> Building ${repo} (${BUILD_TYPE})"
  (
    cd "${repo_dir}"
    ./scripts/build.sh
  )
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -k|--keep-going)
      continue_on_error=1
      shift
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if ! is_known_repo "$1"; then
        echo "unknown repo: $1" >&2
        echo -n "known repos:" >&2
        for repo in "${SRC_REPOS[@]}"; do
          IFS='|' read -r name _url _build_mode _launch_name _binary_rel _config_rel <<<"${repo}"
          echo -n " ${name}" >&2
        done
        echo >&2
        exit 2
      fi
      selected_repos+=("$1")
      shift
      ;;
  esac
done

failures=()

for repo in "${SRC_REPOS[@]}"; do
  IFS='|' read -r name _url build_mode _launch_name _binary_rel _config_rel <<<"${repo}"

  if ! has_selected_repo "${name}"; then
    continue
  fi

  if ! build_repo "${name}" "${build_mode}"; then
    failures+=("${name}")
    if [[ "${continue_on_error}" -eq 0 ]]; then
      echo
      echo "Build failed: ${name}" >&2
      exit 1
    fi
  fi
done

if [[ "${#failures[@]}" -gt 0 ]]; then
  echo
  echo "Build failures: ${failures[*]}" >&2
  exit 1
fi

echo
echo "All requested repos built successfully."
