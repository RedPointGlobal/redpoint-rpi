#!/usr/bin/env bash
# Shared colors and helpers for RPI CLI scripts.
# Source this file: source "$(dirname "$0")/lib/common.sh"

if [ -t 1 ] && command -v tput &>/dev/null && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  BOLD=$(tput bold)
  CYAN=$(tput setaf 6)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  RED=$(tput setaf 1)
  DIM=$(tput dim)
  RESET=$(tput sgr0)
else
  BOLD="" CYAN="" GREEN="" YELLOW="" RED="" DIM="" RESET=""
fi

die() {
  echo "${RED}Error: $1${RESET}" >&2
  exit "${2:-1}"
}
