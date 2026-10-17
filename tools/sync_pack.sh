#!/usr/bin/env bash
# terrimap_core の packs/us を取り込む(コアが正本)。使い方: tools/sync_pack.sh [コアのパス]
set -euo pipefail
core="${1:-../terrimap_core}"
rm -rf packs/us && cp -r "$core/packs/us" packs/us
python3 -I "$core/tools/validate_pack.py" packs/us
