#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 {shutdown|startup} [--confirm] [extra-ansible-args...]"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

ACTION="$1"; shift || true
CONFIRM="false"

if [[ "${1:-}" == "--confirm" ]]; then
  CONFIRM="true"
  shift || true
fi

case "$ACTION" in
  shutdown|startup)
    ;;
  *)
    usage
    exit 1
    ;;
esac

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

ANSIBLE_CMD=(ansible-playbook "${ROOT_DIR}/playbooks/k3s_cluster_control.yml" -t "${ACTION}" -e "confirm=${CONFIRM}")
if [[ $# -gt 0 ]]; then
  ANSIBLE_CMD+=("$@")
fi

echo "Running: ${ANSIBLE_CMD[*]}"
"${ANSIBLE_CMD[@]}"
