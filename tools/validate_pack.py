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
# 州都の位置(capitalPos)と隣接(neighbors)。どちらも任意だが、1つでもあれば全地域に必要。
def _in_ring(x, y, ring):
    inside = False
    for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) / (y2 - y1) * (x2 - x1): inside = not inside
    return inside
_polys = {f["properties"]["id"]: [poly[0] for poly in f["geometry"]["coordinates"]] for f in geo.get("features", [])}
_regs = reg.get("regions", [])
_np = sum(1 for r in _regs if r.get("capitalPos") is not None); _nn = sum(1 for r in _regs if r.get("neighbors") is not None)
if _np not in (0, len(_regs)): err.append(f"capitalPos: 全地域に必要({len(_regs)}件中{_np}件)")
if _nn not in (0, len(_regs)): err.append(f"neighbors: 全地域に必要({len(_regs)}件中{_nn}件)")
_nb = {}
for r in _regs:
    rid = r["id"]; cp = r.get("capitalPos")
    if cp is not None:
        if not (isinstance(cp, dict) and isinstance(cp.get("x"), (int, float)) and isinstance(cp.get("y"), (int, float))): err.append(f"{rid}: capitalPos は {{x, y}}")
        elif not any(_in_ring(cp["x"], cp["y"], ring) for ring in _polys.get(rid, [])): err.append(f"{rid}: 州都の位置が州の形の外")
    n = r.get("neighbors")
    if n is not None:
        if len(set(n)) != len(n): err.append(f"{rid}: neighbors に重複")
        for o in n:
            if o == rid: err.append(f"{rid}: neighbors に自分自身")
            if o not in ids: err.append(f"{rid}: neighbors の未知の地域 {o}")
        _nb[rid] = set(n)
for a, st in _nb.items():
    for b in st:
        if b in _nb and a not in _nb[b]: err.append(f"隣接が非対称: {a}→{b} だけ")
caps = {r.get("capitalId") for r in reg.get("regions", []) if r.get("capitalId")}
for lang in pack.get("languages", []):
    try: s = json.loads((p/f"strings/{lang}.json").read_text())
    except Exception as e: err.append(f"strings/{lang}.json: {e}"); continue
    miss = set(ids) - set(s.get("regions", {}))
    if miss: err.append(f"{lang}: 地域名の欠落 {sorted(miss)}")
    miss = caps - set(s.get("capitals", {}))
    if miss: err.append(f"{lang}: 首都名の欠落 {len(miss)}件")
# 国の特性・戦い方(任意)。Dart版(PackValidator)と同じ規則。
prof_path = p/"profile.json"
if prof_path.exists():
    try: prof = json.loads(prof_path.read_text())
    except Exception as e: prof = None; err.append(f"profile.json: 読込失敗 {e}")
    if prof is not None:
        ENEMIES = {"normal", "speedy", "armored", "healer"}
        TERRAINS = {"sea", "mountain", "urban", "agriculture", "mixed"}
        if not prof.get("style"): err.append("profile.json: style が空")
        mix = prof.get("enemyMix") or {}
        if not mix: err.append("profile.json: enemyMix が空")
        for k, v in mix.items():
            if k not in ENEMIES: err.append(f"profile.json: enemyMix の未知の敵 {k}")
            if not isinstance(v, (int, float)) or v < 0: err.append(f"profile.json: enemyMix.{k} が負または数値でない")
        if mix and abs(sum(v for v in mix.values() if isinstance(v, (int, float))) - 1) > 0.01:
            err.append("profile.json: enemyMix の合計が1でない")
        eco = prof.get("economy") or {}
        for k in ("startCoins", "income", "facilityCost"):
            v = eco.get(k)
            if not isinstance(v, (int, float)) or not (0.5 <= v <= 2.0): err.append(f"profile.json: economy.{k} は0.5〜2.0")
        if prof.get("pathLength") not in ("short", "medium", "long"): err.append("profile.json: pathLength は short/medium/long")
        if not (prof.get("signature") or {}).get("id"): err.append("profile.json: signature.id が空")
        ABIL = {"none", "shield", "regen", "swarm", "flying", "disrupt"}
        EACT = {"none", "heal_aura", "ranged_disable", "sabotage"}
        FACS = {"farm", "fishery", "factory", "mine", "castle", "shrine"}
        FACT = {"single", "splash", "chain", "pierce", "slow", "burn"}
        for kind, t in (prof.get("enemies") or {}).items():
            if kind not in ENEMIES: err.append(f"profile.json: enemies の未知の敵 {kind}")
            for k in ("hp", "speed", "baseDamage"):
                v = t.get(k)
                if v is not None and (not isinstance(v, (int, float)) or not (0.5 <= v <= 2.0)): err.append(f"profile.json: enemies.{kind}.{k} は0.5〜2.0")
            a = t.get("armor")
            if a is not None and (not isinstance(a, int) or not (0 <= a <= 3)): err.append(f"profile.json: enemies.{kind}.armor は0〜3の整数")
            if t.get("ability") is not None and t["ability"] not in ABIL: err.append(f"profile.json: enemies.{kind}.ability が不正")
            if t.get("action") is not None and t["action"] not in EACT: err.append(f"profile.json: enemies.{kind}.action が不正")
        for fac, t in (prof.get("attackActions") or {}).items():
            if fac not in FACS: err.append(f"profile.json: attackActions の未知の施設 {fac}")
            if t.get("action") not in FACT: err.append(f"profile.json: attackActions.{fac}.action が不正")
            for k in ("damage", "range", "cooldown"):
                v = t.get(k)
                if v is not None and (not isinstance(v, (int, float)) or not (0.5 <= v <= 2.0)): err.append(f"profile.json: attackActions.{fac}.{k} は0.5〜2.0")
        import re
        WEATHER = {"hurricane", "tornado", "blizzard", "heatwave", "wildfire", "flood", "earthquake", "storm"}
        backdrops = set()
        for bid, b in ((prof.get("theme") or {}).get("backdrops") or {}).items():
            backdrops.add(bid)
            pal = (b or {}).get("palette")
            if not isinstance(pal, list) or len(pal) < 3 or any(not isinstance(c, str) or not re.fullmatch(r"#[0-9A-Fa-f]{6}", c) for c in pal):
                err.append(f"profile.json: theme.backdrops.{bid} の palette は#RRGGBBを3色以上")
        for key, allowed, label in (("facilities", FACS, "施設"), ("enemySkins", ENEMIES, "敵")):
            for k, t in (prof.get(key) or {}).items():
                if k not in allowed: err.append(f"profile.json: {key} の未知の{label} {k}")
                if not (t or {}).get("skin"): err.append(f"profile.json: {key}.{k} の skin が空")
                if not ((t or {}).get("name") or {}).get("en"): err.append(f"profile.json: {key}.{k} の name に英語がない")
        for rid, t in (prof.get("regions") or {}).items():
            if t.get("weatherEvent") is not None and t["weatherEvent"] not in WEATHER: err.append(f"profile.json: {rid} の weatherEvent が不正")
            if t.get("backdrop") is not None and t["backdrop"] not in backdrops: err.append(f"profile.json: {rid} の backdrop が theme.backdrops にない")
            if t.get("exclusiveFacility") is not None and not t["exclusiveFacility"]: err.append(f"profile.json: {rid} の exclusiveFacility が空")
            for k, v in (t.get("enemyBias") or {}).items():
                if k not in ENEMIES: err.append(f"profile.json: {rid} の enemyBias の未知の敵 {k}")
                if not isinstance(v, (int, float)) or not (0.5 <= v <= 2.0): err.append(f"profile.json: {rid} の enemyBias.{k} は0.5〜2.0")
            for k in (t.get("facilityBonus") or {}):
                if k not in FACS: err.append(f"profile.json: {rid} の facilityBonus の未知の施設 {k}")
            if rid not in set(ids): err.append(f"profile.json: 未知の地域 {rid}")
            if t.get("terrain") is not None and t["terrain"] not in TERRAINS: err.append(f"profile.json: {rid} の terrain が不正")
            for k, v in (t.get("facilityBonus") or {}).items():
                if not isinstance(v, (int, float)) or not (1.0 <= v <= 2.0): err.append(f"profile.json: {rid} の facilityBonus.{k} は1.0〜2.0")
print("\n".join(err) if err else f"OK {pack.get('packId')}: {len(ids)}地域")
sys.exit(1 if err else 0)
