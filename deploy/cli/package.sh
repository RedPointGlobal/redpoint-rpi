#!/usr/bin/env bash
# ============================================================
# Package the Interaction CLI into a distributable zip
#
# Usage:
#   bash deploy/cli/package.sh
#
# Output:
#   dist/interactioncli.zip
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
PKG_DIR="${DIST_DIR}/interactioncli"

echo "Packaging Interaction CLI..."

rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}/lib"

cp "${SCRIPT_DIR}/interactioncli.sh" "${PKG_DIR}/"
cp "${SCRIPT_DIR}/deploy.sh" "${PKG_DIR}/"
cp "${SCRIPT_DIR}/lib/common.sh" "${PKG_DIR}/lib/"
cp "${SCRIPT_DIR}/lib/yaml_helpers.py" "${PKG_DIR}/lib/"

cat > "${PKG_DIR}/README.md" << 'EOF'
# Interaction CLI

Command-line tool for deploying and managing Redpoint Interaction (RPI) on Kubernetes.

## Prerequisites

- bash
- helm (v3+)
- kubectl (configured with cluster access)
- python3 with PyYAML (`pip3 install pyyaml`)

## Quick Start

1. Generate your overrides file using the Web UI at https://rpi-helm-assistant.redpointcdp.com
2. Generate secrets from your overrides:

       bash interactioncli.sh secrets -f overrides.yaml

3. Deploy to your cluster:

       bash interactioncli.sh deploy -f overrides.yaml -c /path/to/chart

## Commands

    bash interactioncli.sh                              # Full interactive setup
    bash interactioncli.sh secrets -f overrides.yaml    # Generate secrets.yaml
    bash interactioncli.sh deploy -f overrides.yaml     # Deploy to cluster
    bash interactioncli.sh deploy -f overrides.yaml --dry-run  # Preview manifests
    bash interactioncli.sh status -n my-namespace       # Check deployment status
    bash interactioncli.sh troubleshoot -n my-namespace # Diagnose issues
    bash interactioncli.sh -a autoscaling               # Add a feature

## Workflow

    Web UI (generate overrides) -> CLI secrets -> CLI deploy

For full documentation, visit: https://rpi-helm-assistant.redpointcdp.com
EOF

chmod +x "${PKG_DIR}/interactioncli.sh"
chmod +x "${PKG_DIR}/deploy.sh"

# Create zip using Python (no zip dependency needed)
cd "${DIST_DIR}"
python3 -c "
import zipfile, os
with zipfile.ZipFile('interactioncli.zip', 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk('interactioncli'):
        for f in files:
            zf.write(os.path.join(root, f))
"

# Clean up
rm -rf "${PKG_DIR}"

echo "Created: ${DIST_DIR}/interactioncli.zip"
