#!/usr/bin/env bash

join_posix_path() {
  local segment
  local -a parts=()

  for segment in "$@"; do
    [[ -n "$segment" ]] || continue
    segment="${segment#/}"
    segment="${segment%/}"
    [[ -n "$segment" ]] || continue
    parts+=("$segment")
  done

  if [[ ${#parts[@]} -eq 0 ]]; then
    printf '/\n'
    return 0
  fi

  local IFS='/'
  printf '/%s\n' "${parts[*]}"
}

podman_broad_host_mount_sources_json() {
  local users_path
  local private_path
  local folders_path

  users_path="$(join_posix_path "${PODMAN_MACOS_USERS_ROOT_NAME:-Users}")"
  private_path="$(join_posix_path "${PODMAN_MACOS_PRIVATE_ROOT_NAME:-private}")"
  folders_path="$(join_posix_path "${PODMAN_MACOS_VAR_ROOT_NAME:-var}" "${PODMAN_MACOS_FOLDERS_LEAF_NAME:-folders}")"

  jq -nc \
    --arg users_path "$users_path" \
    --arg private_path "$private_path" \
    --arg folders_path "$folders_path" \
    '[$users_path, $private_path, $folders_path]'
}

podman_rootful_socket_path() {
  printf '%s\n' "${PODMAN_ROOTFUL_SOCKET_PATH:-$(join_posix_path run podman podman.sock)}"
}
