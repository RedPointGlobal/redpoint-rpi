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

cp "${SCRIPT_DIR}/setup.sh" "${PKG_DIR}/"
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

    unzip rpihelmcli.zip
    rpihelmcli/setup.sh secrets -f overrides.yaml
    rpihelmcli/setup.sh deploy -f overrides.yaml

## Commands

    rpihelmcli/setup.sh secrets -f overrides.yaml           # Generate secrets.yaml
    rpihelmcli/setup.sh deploy -f overrides.yaml            # Deploy to cluster
    rpihelmcli/setup.sh deploy -f overrides.yaml --dry-run  # Preview manifests
    rpihelmcli/setup.sh status -n my-namespace              # Check deployment status
    rpihelmcli/setup.sh troubleshoot -n my-namespace        # Diagnose issues

Generate your overrides at: https://rpi-helm-assistant.redpointcdp.com
EOF

chmod +x "${PKG_DIR}/setup.sh"

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
