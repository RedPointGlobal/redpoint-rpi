#!/usr/bin/env bash
# ============================================================
# Package the RPI Helm CLI into a distributable zip
#
# Usage:
#   bash deploy/cli/package.sh
#
# Output:
#   dist/rpihelmcli.zip
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
PKG_DIR="${DIST_DIR}/rpihelmcli"

echo "Packaging RPI Helm CLI..."

rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}/lib"

cp "${SCRIPT_DIR}/rpihelmcli.sh" "${PKG_DIR}/"
cp "${SCRIPT_DIR}/lib/common.sh" "${PKG_DIR}/lib/"
cp "${SCRIPT_DIR}/lib/yaml_helpers.py" "${PKG_DIR}/lib/"

cat > "${PKG_DIR}/README.md" << 'EOF'
# RPI Helm CLI

Command-line tool for deploying and managing Redpoint Interaction (RPI) on Kubernetes.

## Prerequisites

- bash
- helm (v3+)
- kubectl (configured with cluster access)
- python3 with PyYAML (`pip3 install pyyaml`)

## Quick Start

1. Generate your overrides file using the Web UI at https://rpi-helm-assistant.redpointcdp.com
2. Generate secrets from your overrides:

       bash rpihelmcli.sh secrets -f overrides.yaml

3. Deploy to your cluster:

       bash rpihelmcli.sh deploy -f overrides.yaml

## Commands

    bash rpihelmcli.sh                              # Full interactive setup
    bash rpihelmcli.sh secrets -f overrides.yaml    # Generate secrets.yaml
    bash rpihelmcli.sh deploy -f overrides.yaml     # Deploy to cluster
    bash rpihelmcli.sh deploy -f overrides.yaml --dry-run  # Preview manifests
    bash rpihelmcli.sh status -n my-namespace       # Check deployment status
    bash rpihelmcli.sh troubleshoot -n my-namespace # Diagnose issues
    bash rpihelmcli.sh -a autoscaling               # Add a feature

## Workflow

    Web UI (generate overrides) -> CLI secrets -> CLI deploy

For full documentation, visit: https://rpi-helm-assistant.redpointcdp.com
EOF

chmod +x "${PKG_DIR}/rpihelmcli.sh"

# Create zip using Python (no zip dependency needed)
cd "${DIST_DIR}"
python3 -c "
import zipfile, os
with zipfile.ZipFile('rpihelmcli.zip', 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk('rpihelmcli'):
        for f in files:
            zf.write(os.path.join(root, f))
"

# Clean up
rm -rf "${PKG_DIR}"

echo "Created: ${DIST_DIR}/rpihelmcli.zip"
