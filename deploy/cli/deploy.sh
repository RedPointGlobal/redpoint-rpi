#!/usr/bin/env bash
# ============================================================
# RPI Deploy — Helm install/upgrade with live rollout progress
#
# Usage:
#   bash deploy/cli/rpi-deploy.sh [options]
#
# Modes:
#   (default)    Run helm install/upgrade, then watch rollout
#   --watch      Watch-only mode (skip helm, just monitor pods)
#
# Options:
#   -f FILE      Overrides file (default: overrides.yaml)
#   -n NS        Namespace (default: redpoint-rpi)
#   -r NAME      Release name (default: rpi)
#   -c PATH      Chart path (default: ./chart)
#   --install    Force helm install (default: auto-detect)
#   --upgrade    Force helm upgrade (default: auto-detect)
#   --watch      Watch-only — monitor existing deployment
#   --timeout N  Timeout in seconds (default: 600)
#   -h           Show this help
# ============================================================
set -euo pipefail

# --- Defaults ---
OVERRIDES="overrides.yaml"
NAMESPACE="redpoint-rpi"
RELEASE="rpi"
CHART="./chart"
MODE=""          # install | upgrade | auto
WATCH_ONLY=false
TIMEOUT=600
EXTRA_ARGS=()

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)         OVERRIDES="$2"; shift 2 ;;
    -n)         NAMESPACE="$2"; shift 2 ;;
    -r)         RELEASE="$2"; shift 2 ;;
    -c)         CHART="$2"; shift 2 ;;
    --install)  MODE="install"; shift ;;
    --upgrade)  MODE="upgrade"; shift ;;
    --watch)    WATCH_ONLY=true; shift ;;
    --timeout)  TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# //; s/^#//; p }' "$0"
      exit 0 ;;
    *)          EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# --- Colors ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

OK="${GREEN}✔${RESET}"
FAIL="${RED}✘${RESET}"
WARN="${YELLOW}●${RESET}"
SPIN="${CYAN}◌${RESET}"

header() {
  echo ""
  echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo "${BOLD}  $1${RESET}"
  echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# --- Helm install/upgrade ---
if [ "$WATCH_ONLY" = false ]; then
  # Auto-detect install vs upgrade
  if [ -z "$MODE" ]; then
    if helm status "$RELEASE" -n "$NAMESPACE" &>/dev/null; then
      MODE="upgrade"
    else
      MODE="install"
    fi
  fi

  header "Helm ${MODE}: ${RELEASE}"
  echo ""
  echo "  ${DIM}Release:   ${RELEASE}${RESET}"
  echo "  ${DIM}Namespace: ${NAMESPACE}${RESET}"
  echo "  ${DIM}Chart:     ${CHART}${RESET}"
  echo "  ${DIM}Values:    ${OVERRIDES}${RESET}"
  echo ""

  HELM_LOG=$(mktemp)
  trap "rm -f $HELM_LOG" EXIT

  echo "  ${SPIN} Running helm ${MODE}..."
  if helm "${MODE}" "$RELEASE" "$CHART" \
    -f "$OVERRIDES" \
    -n "$NAMESPACE" \
    "${EXTRA_ARGS[@]}" \
    > "$HELM_LOG" 2>&1; then
    echo "  ${OK} Helm ${MODE} submitted"
  else
    echo "  ${FAIL} Helm ${MODE} failed"
    echo ""
    cat "$HELM_LOG"
    exit 1
  fi
fi

# --- Watch rollout ---
header "Monitoring rollout — ${NAMESPACE}"
echo ""
echo "  ${DIM}Watching pods until all are Ready (timeout: ${TIMEOUT}s)${RESET}"
echo "  ${DIM}Press Ctrl+C to stop watching (deployment continues)${RESET}"
echo ""

# Collect expected deployments
get_deployments() {
  kubectl get deployments -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.replicas}{"\t"}{.status.readyReplicas}{"\t"}{.status.unavailableReplicas}{"\n"}{end}' 2>/dev/null
}

# Collect pod statuses
get_pods() {
  kubectl get pods -n "$NAMESPACE" --no-headers \
    -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount' \
    2>/dev/null
}

# Format a single deployment line
fmt_deploy() {
  local name=$1 desired=$2 ready=$3 unavail=$4
  ready=${ready:-0}
  unavail=${unavail:-0}

  local icon
  if [ "$ready" = "$desired" ] && [ "$desired" != "0" ]; then
    icon="$OK"
  elif [ "$unavail" != "0" ] || [ "$ready" = "0" ]; then
    icon="$SPIN"
  else
    icon="$WARN"
  fi

  printf "  %s %-38s %s/%s ready\n" "$icon" "$name" "$ready" "$desired"
}

START=$SECONDS
PREV_OUTPUT=""

while true; do
  ELAPSED=$(( SECONDS - START ))
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo ""
    echo "  ${YELLOW}${BOLD}Timeout reached (${TIMEOUT}s). Some pods may still be starting.${RESET}"
    echo "  ${DIM}Run 'kubectl get pods -n ${NAMESPACE}' to check status.${RESET}"
    exit 1
  fi

  # Build output
  OUTPUT=""
  ALL_READY=true
  TOTAL=0
  READY_COUNT=0

  while IFS=$'\t' read -r name desired ready unavail; do
    [ -z "$name" ] && continue
    TOTAL=$((TOTAL + 1))
    ready_n=${ready:-0}
    if [ "$ready_n" = "$desired" ] && [ "$desired" != "0" ]; then
      READY_COUNT=$((READY_COUNT + 1))
    else
      ALL_READY=false
    fi
    OUTPUT="${OUTPUT}$(fmt_deploy "$name" "$desired" "$ready_n" "$unavail")
"
  done <<< "$(get_deployments)"

  # Also check for jobs (upgrade, postinstall)
  JOBS=$(kubectl get jobs -n "$NAMESPACE" --no-headers \
    -o custom-columns='NAME:.metadata.name,COMPLETE:.status.succeeded,FAILED:.status.failed' 2>/dev/null || true)
  while IFS=' ' read -r jname jcomplete jfailed; do
    [ -z "$jname" ] && continue
    jcomplete=${jcomplete:-0}
    jfailed=${jfailed:-0}
    if [ "$jcomplete" = "1" ]; then
      OUTPUT="${OUTPUT}  ${OK} ${jname}  (job complete)
"
    elif [ "$jfailed" != "0" ] && [ "$jfailed" != "<none>" ]; then
      OUTPUT="${OUTPUT}  ${FAIL} ${jname}  (job failed)
"
    else
      OUTPUT="${OUTPUT}  ${SPIN} ${jname}  (job running)
"
      ALL_READY=false
    fi
  done <<< "$JOBS"

  # Only redraw if output changed
  if [ "$OUTPUT" != "$PREV_OUTPUT" ]; then
    # Clear previous output
    if [ -n "$PREV_OUTPUT" ]; then
      LINE_COUNT=$(echo "$PREV_OUTPUT" | wc -l)
      for ((i=0; i<LINE_COUNT+1; i++)); do
        printf "\033[A\033[2K"
      done
    fi

    echo "$OUTPUT"
    MINS=$(( ELAPSED / 60 ))
    SECS=$(( ELAPSED % 60 ))
    printf "  ${DIM}%d/%d ready  (%dm%02ds elapsed)${RESET}\n" "$READY_COUNT" "$TOTAL" "$MINS" "$SECS"
    PREV_OUTPUT="$OUTPUT"
  else
    # Update timer line in place
    if [ -n "$PREV_OUTPUT" ]; then
      printf "\033[A\033[2K"
    fi
    MINS=$(( ELAPSED / 60 ))
    SECS=$(( ELAPSED % 60 ))
    printf "  ${DIM}%d/%d ready  (%dm%02ds elapsed)${RESET}\n" "$READY_COUNT" "$TOTAL" "$MINS" "$SECS"
  fi

  if [ "$ALL_READY" = true ] && [ "$TOTAL" -gt 0 ]; then
    echo ""
    echo "  ${GREEN}${BOLD}All ${TOTAL} deployments ready.${RESET}"
    echo ""

    # Show ingress endpoints if available
    INGRESS=$(kubectl get ingress -n "$NAMESPACE" --no-headers \
      -o custom-columns='NAME:.metadata.name,HOSTS:.spec.rules[*].host' 2>/dev/null || true)
    if [ -n "$INGRESS" ]; then
      echo "  ${BOLD}Endpoints:${RESET}"
      while read -r iname ihosts; do
        [ -z "$iname" ] && continue
        echo "  ${DIM}  ${ihosts}${RESET}"
      done <<< "$INGRESS"
      echo ""
    fi

    # Print NOTES if helm was run
    if [ "$WATCH_ONLY" = false ] && [ -f "$HELM_LOG" ]; then
      # Extract NOTES section from helm output
      if grep -q "NOTES:" "$HELM_LOG"; then
        echo "${DIM}$(sed -n '/^NOTES:/,$ p' "$HELM_LOG" | tail -n +2)${RESET}"
      fi
    fi
    exit 0
  fi

  sleep 3
done
