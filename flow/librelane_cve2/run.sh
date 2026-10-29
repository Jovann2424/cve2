#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PDK_ROOT="${PDK_ROOT:-/usr/local/share/OpenPDKs}"
export PDK="${PDK:-ihp-sg13g2}"
export STD_CELL_LIBRARY="${STD_CELL_LIBRARY:-sg13g2_stdcell}"

exec librelane --manual-pdk "$repo_root/flow/librelane_cve2/config.yaml" "$@"
