#!/usr/bin/env python3
"""PackValidator(Python版)。使い方: validate_pack.py <packdir>。エラーがあれば終了コード1。"""
import json, sys, pathlib
p = pathlib.Path(sys.argv[1]); err = []
def load(n):
    try: return json.loads((p/n).read_text())
    except Exception as e: err.append(f"{n}: 読込失敗 {e}"); return {}
pack, reg, geo = load('pack.json'), load('regions.json'), load('geo.geojson')
for k in ("packId","version","country","regionKind","languages","projection","attribution","license"):
    if not pack.get(k): err.append(f"pack.json: {k} が空")
if not (pack.get("license") or {}).get("name"): err.append("license.name が空")
ids = [r["id"] for r in reg.get("regions", [])]
if len(ids) != len(set(ids)): err.append("regions: id重複")
gids = [f["properties"].get("id") for f in geo.get("features", [])]
if set(ids) != set(gids): err.append(f"id不一致 regionsのみ={set(ids)-set(gids)} geoのみ={set(gids)-set(ids)}")
if len(gids) != len(set(gids)): err.append("geo: id重複")
MAXV = 20000
planar = (pack.get('projection') or {}).get('type') == 'planar'
for f in geo.get("features", []):
    n = 0
    for poly in f["geometry"]["coordinates"]:
        for ring in poly:
            n += len(ring)
            if len(ring) < 4 or ring[0] != ring[-1]: err.append(f"{f['properties']['id']}: リング不正")
            for x, y in ring:
                if not planar and not (-180 <= x <= 180 and -90 <= y <= 90): err.append(f"{f['properties']['id']}: 座標範囲外"); break
    if n > MAXV: err.append(f"{f['properties']['id']}: 頂点数超過 {n}")
caps = {r.get("capitalId") for r in reg.get("regions", []) if r.get("capitalId")}
for lang in pack.get("languages", []):
    try: s = json.loads((p/f"strings/{lang}.json").read_text())
    except Exception as e: err.append(f"strings/{lang}.json: {e}"); continue
    miss = set(ids) - set(s.get("regions", {}))
    if miss: err.append(f"{lang}: 地域名の欠落 {sorted(miss)}")
    miss = caps - set(s.get("capitals", {}))
    if miss: err.append(f"{lang}: 首都名の欠落 {len(miss)}件")
print("\n".join(err) if err else f"OK {pack.get('packId')}: {len(ids)}地域")
sys.exit(1 if err else 0)
