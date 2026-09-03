#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${WORKSPACE_DIR}/src"
REPO_LIST="${SCRIPT_DIR}/src_repos.sh"

source "${REPO_LIST}"

mkdir -p "${SRC_DIR}"

for repo in "${SRC_REPOS[@]}"; do
  IFS='|' read -r name url _build_mode _launch_name _binary_rel _config_rel <<<"${repo}"
  target="${SRC_DIR}/${name}"

  if [[ -d "${target}/.git" ]]; then
    echo "Skipping ${name}: already cloned at ${target}"
    continue
  fi

  if [[ -e "${target}" ]]; then
    echo "Skipping ${name}: ${target} exists but is not a Git repo" >&2
    continue
  fi

  echo "Cloning ${name}..."
  git clone "${url}" "${target}"
done

echo "Done."
