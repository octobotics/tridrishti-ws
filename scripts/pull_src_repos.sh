#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${WORKSPACE_DIR}/src"
REPO_LIST="${SCRIPT_DIR}/src_repos.sh"

source "${REPO_LIST}"

continue_on_error=0
selected_repos=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [REPO...]

Pulls repos listed in:
  ${REPO_LIST}

Options:
  -h, --help             Show this help.
  -k, --keep-going       Continue pulling remaining repos after a failure.
  --allow-dirty          Pull even when a repo has local changes.

Examples:
  ./scripts/pull_src_repos.sh
  ./scripts/pull_src_repos.sh -k
  ./scripts/pull_src_repos.sh i2w ouster-lidar-pub
EOF
}

allow_dirty=0

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

print_known_repos() {
  local repo name
  echo -n "known repos:" >&2
  for repo in "${SRC_REPOS[@]}"; do
    IFS='|' read -r name _url _build_mode _launch_name _binary_rel _config_rel <<<"${repo}"
    echo -n " ${name}" >&2
  done
  echo >&2
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

pull_repo() {
  local repo="$1"
  local repo_dir="${SRC_DIR}/${repo}"

  if [[ ! -d "${repo_dir}/.git" ]]; then
    echo "missing Git repo: ${repo_dir}" >&2
    return 1
  fi

  if [[ "${allow_dirty}" -eq 0 && -n "$(git -C "${repo_dir}" status --porcelain)" ]]; then
    echo "skipping ${repo}: local changes present; use --allow-dirty to pull anyway" >&2
    return 1
  fi

  echo
  echo "==> Pulling ${repo}"
  git -C "${repo_dir}" pull --ff-only
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
    --allow-dirty)
      allow_dirty=1
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
        print_known_repos
        exit 2
      fi
      selected_repos+=("$1")
      shift
      ;;
  esac
done

failures=()

for repo in "${SRC_REPOS[@]}"; do
  IFS='|' read -r name _url _build_mode _launch_name _binary_rel _config_rel <<<"${repo}"

  if ! has_selected_repo "${name}"; then
    continue
  fi

  if ! pull_repo "${name}"; then
    failures+=("${name}")
    if [[ "${continue_on_error}" -eq 0 ]]; then
      echo
      echo "Pull failed: ${name}" >&2
      exit 1
    fi
  fi
done

if [[ "${#failures[@]}" -gt 0 ]]; then
  echo
  echo "Pull failures: ${failures[*]}" >&2
  exit 1
fi

echo
echo "All requested repos pulled successfully."
