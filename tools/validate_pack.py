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
        NEW_ENEMIES = {"flyer", "saboteur", "swarmer", "splitter"}
        HARD_ENEMIES = {"brute", "jammer"}
        ENEMIES = {"normal", "speedy", "armored", "healer"} | NEW_ENEMIES | HARD_ENEMIES
        TERRAINS = {"sea", "mountain", "urban", "agriculture", "mixed"}
        if not prof.get("style"): err.append("profile.json: style が空")
        mix = prof.get("enemyMix") or {}
        if not mix: err.append("profile.json: enemyMix が空")
        for k, v in mix.items():
            if k not in ENEMIES or k in NEW_ENEMIES or k in HARD_ENEMIES: err.append(f"profile.json: enemyMix の未知の敵 {k}（新しい種類は enemyMixV3・enemyMixHard に書く）")
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
        for k, x in (prof.get("enemyMixHard") or {}).items():
            if k not in HARD_ENEMIES: err.append(f"profile.json: enemyMixHard の未知の敵 {k}")
            if not isinstance(x, (int, float)) or x < 0: err.append(f"profile.json: enemyMixHard.{k} が負または数値でない")
        _skins = {t.get("skin") for t in (prof.get("enemySkins") or {}).values() if isinstance(t, dict)}
        for g, mb in (prof.get("miniBosses") or {}).items():
            if g not in (prof.get("groups") or {}): err.append(f"profile.json: miniBosses の未知の地方 {g}")
            if not mb.get("skin"): err.append(f"profile.json: miniBosses.{g} の skin が空")
            elif mb["skin"] in _skins: err.append(f"profile.json: miniBosses の skin {mb['skin']} が重複")
            else: _skins.add(mb["skin"])
            if not (mb.get("name") or {}).get("en"): err.append(f"profile.json: miniBosses.{g} の name に英語がない")
            if mb.get("skill") not in {"speedBurst", "hpRegen", "summon", "stunFacility"}: err.append(f"profile.json: miniBosses.{g}.skill が不正")
        for kind, lst in (prof.get("enemyVariants") or {}).items():
            for v in lst:
                t = v.get("trait")
                if not t: continue
                lb = f"enemyVariants.{kind}.{v.get('skin')}.trait"
                for k in ("hp", "speed", "baseDamage"):
                    x = t.get(k)
                    if x is not None and (not isinstance(x, (int, float)) or not (0.5 <= x <= 2.0)): err.append(f"profile.json: {lb}.{k} は0.5〜2.0")
                a = t.get("armor")
                if a is not None and (not isinstance(a, int) or not (0 <= a <= 3)): err.append(f"profile.json: {lb}.armor は0〜3の整数")
                if t.get("ability") is not None and t["ability"] not in ABIL: err.append(f"profile.json: {lb}.ability が不正")
                if t.get("action") is not None and t["action"] not in EACT: err.append(f"profile.json: {lb}.action が不正")
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
        used = {t.get("skin") for t in (prof.get("enemySkins") or {}).values() if isinstance(t, dict)}
        grp_ids = set((prof.get("groups") or {}).keys())
        for kind, lst in (prof.get("enemyVariants") or {}).items():
            if kind not in ENEMIES: err.append(f"profile.json: enemyVariants の未知の敵 {kind}")
            if not isinstance(lst, list): err.append(f"profile.json: enemyVariants.{kind} が配列でない"); continue
            for v in lst:
                if not isinstance(v, dict): err.append(f"profile.json: enemyVariants.{kind} に、オブジェクトでない要素がある"); continue
                sk = v.get("skin") or ""
                if not sk: err.append(f"profile.json: enemyVariants.{kind} の skin が空")
                elif sk in used: err.append(f"profile.json: enemyVariants の skin {sk} が重複")
                used.add(sk)
                if not (v.get("name") or {}).get("en"): err.append(f"profile.json: enemyVariants.{kind}.{sk} の name に英語がない")
                w = v.get("when") or {}
                for r in w.get("regions") or []:
                    if r not in set(ids): err.append(f"profile.json: enemyVariants.{kind}.{sk} の未知の州 {r}")
                for g in w.get("groups") or []:
                    if g not in grp_ids: err.append(f"profile.json: enemyVariants.{kind}.{sk} の未知の地方 {g}")
        xseen = set()
        for e in (prof.get("extras") or []):
            xid = e.get("id")
            if xid in xseen: err.append(f"profile.json: extras の id が重複 {xid}")
            xseen.add(xid)
            if e.get("basis") not in ("legend", "biography", "history"): err.append(f"profile.json: extras.{xid} の basis は legend/biography/history")
            regs = e.get("regions")
            if not isinstance(regs, list) or not regs: err.append(f"profile.json: extras.{xid} の regions が空")
            else:
                for r in regs:
                    if r not in set(ids): err.append(f"profile.json: extras.{xid} の未知の地域 {r}")
                if e.get("center") not in regs: err.append(f"profile.json: extras.{xid} の center が regions にない")
            ss = e.get("seasons")
            if not isinstance(ss, list) or not ss or any(x not in ("spring", "summer", "autumn", "winter") for x in ss): err.append(f"profile.json: extras.{xid} の seasons が不正")
            if e.get("weatherEvent") not in WEATHER: err.append(f"profile.json: extras.{xid} の weatherEvent が不正")
            if e.get("bossSkill") not in ("speedBurst", "hpRegen", "summon", "stunFacility"): err.append(f"profile.json: extras.{xid} の bossSkill が不正")
            w = e.get("waves")
            if not isinstance(w, int) or not (8 <= w <= 10): err.append(f"profile.json: extras.{xid} の waves は8〜10")
            for k in ("title", "summary", "fact", "bossName"):
                if not (e.get(k) or {}).get("en"): err.append(f"profile.json: extras.{xid} の {k} に英語がない")
            if e.get("backdrop") is not None and e["backdrop"] not in backdrops: err.append(f"profile.json: extras.{xid} の backdrop が theme.backdrops にない")
        seen = {}
        for gid, g in (prof.get("groups") or {}).items():
            members = (g or {}).get("regions")
            if not isinstance(members, list) or len(members) < 2:
                err.append(f"profile.json: groups.{gid} の regions は2つ以上"); continue
            for r in members:
                if r not in set(ids): err.append(f"profile.json: groups.{gid} の未知の地域 {r}")
                if r in seen: err.append(f"profile.json: {r} が groups.{seen[r]} と groups.{gid} の両方にある")
                seen[r] = gid
            if g.get("center") not in members: err.append(f"profile.json: groups.{gid} の center が regions にない")
            if not (g.get("name") or {}).get("en"): err.append(f"profile.json: groups.{gid} の name に英語がない")
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
            if "blurb" in t and not (t["blurb"] or {}).get("en"): err.append(f"profile.json: {rid} の blurb に英語がない")
            if t.get("terrain") is not None and t["terrain"] not in TERRAINS: err.append(f"profile.json: {rid} の terrain が不正")
            for k, v in (t.get("facilityBonus") or {}).items():
                if not isinstance(v, (int, float)) or not (1.0 <= v <= 2.0): err.append(f"profile.json: {rid} の facilityBonus.{k} は1.0〜2.0")
# facts.json（任意）: 名所の地域が実在し、id が重複せず、英語の名前があること
if (p/'facts.json').exists():
    try: facts = json.loads((p/'facts.json').read_text())
    except Exception as e: facts = {}; err.append(f"facts.json: 読込失敗 {e}")
    if facts and facts.get("v") != 1: err.append("facts.json: v は 1")
    seen = set()
    for l in (facts.get("landmarks") or []):
        lid = l.get("id")
        if lid in seen: err.append(f"facts.json: 名所 id の重複 {lid}")
        seen.add(lid)
        if l.get("region") not in set(ids): err.append(f"facts.json: {lid} の未知の地域 {l.get('region')}")
        if not (l.get("name") or {}).get("en"): err.append(f"facts.json: {lid} に英語の名前がない")
        if l.get("check", "unchecked") not in ("unchecked", "checked"): err.append(f"facts.json: {lid} の check が不正")
    seen_k = set()
    for k in (facts.get("knowledge") or []):
        kid = k.get("id")
        if kid in seen_k: err.append(f"facts.json: 知識 id の重複 {kid}")
        seen_k.add(kid)
        if k.get("region") not in set(ids): err.append(f"facts.json: {kid} の未知の地域 {k.get('region')}")
        if not (k.get("name") or {}).get("en"): err.append(f"facts.json: {kid} に英語の名前がない")
        if k.get("kind") not in ("food", "product", "culture", "nature"): err.append(f"facts.json: {kid} の kind が不正 {k.get('kind')}")
        if k.get("check", "unchecked") not in ("unchecked", "checked"): err.append(f"facts.json: {kid} の check が不正")
# story.json（任意）: 章の id・ステージの参照・前提の章の順番・英語の文・伝説の章の注記（Dart の Story.validate と同じ規則）
if (p/'story.json').exists():
    try: story = json.loads((p/'story.json').read_text())
    except Exception as e: story = {}; err.append(f"story.json: 読込失敗 {e}")
    prof = {}
    if (p/'profile.json').exists():
        try: prof = json.loads((p/'profile.json').read_text())
        except Exception: prof = {}
    extras = {e.get("id"): e for e in (prof.get("extras") or [])}
    groups = set((prof.get("groups") or {}).keys())
    SPEAKERS = ("narrator", "boss", "note", "hero")
    hero = story.get("hero")
    if hero is not None and not (hero.get("name") or {}).get("en"): err.append("story.json: hero の名前の英語がない")
    seen_ch = set(); seen_all = set()
    for c in (story.get("chapters") or []):
        cid = c.get("id")
        if cid in seen_all: err.append(f"story.json: 章の id が重複 {cid}")
        seen_all.add(cid)
        if not (c.get("title") or {}).get("en"): err.append(f"story.json: {cid} の題名の英語がない")
        lines = [l for k in ("intro", "beforeBoss", "outro") for l in (c.get(k) or [])]
        for l in lines:
            if l.get("speaker") not in SPEAKERS: err.append(f"story.json: {cid} の語り手が不正 {l.get('speaker')}")
            if not (l.get("text") or {}).get("en"): err.append(f"story.json: {cid} に英語のない文がある")
            if l.get("speaker") == "hero" and not hero: err.append(f"story.json: {cid} に主人公の文があるが、hero が定義されていない")
        kind, sid = c.get("kind"), c.get("stageId")
        if kind == "normal":
            if sid not in set(ids): err.append(f"story.json: {cid} の未知の州 {sid}")
        elif kind == "regional":
            if sid not in groups: err.append(f"story.json: {cid} の未知の地方 {sid}")
        elif kind == "extra":
            e = extras.get(sid)
            if e is None: err.append(f"story.json: {cid} の未知のエクストラ {sid}")
            elif e.get("basis") == "legend" and not any(l.get("speaker") == "note" for l in (c.get("outro") or [])):
                err.append(f"story.json: {cid} は伝説の章なので、実在と伝説を分ける注記（note）が要る")
        else: err.append(f"story.json: {cid} の kind が不正 {kind}")
        r = c.get("requires")
        if r is not None and r not in seen_ch: err.append(f"story.json: {cid} の前提の章 {r} が先にない")
        seen_ch.add(cid)
    for e in (story.get("endless") or []):
        eid = e.get("id")
        if eid in seen_all: err.append(f"story.json: id が重複 {eid}")
        seen_all.add(eid)
        if not isinstance(e.get("waves"), int) or e["waves"] <= 0: err.append(f"story.json: {eid} の waves は1以上の整数")
        if not (e.get("title") or {}).get("en"): err.append(f"story.json: {eid} の題名の英語がない")
        for l in (e.get("lines") or []):
            if l.get("speaker") not in SPEAKERS: err.append(f"story.json: {eid} の語り手が不正 {l.get('speaker')}")
            if not (l.get("text") or {}).get("en"): err.append(f"story.json: {eid} に英語のない文がある")
            if l.get("speaker") == "hero" and not hero: err.append(f"story.json: {eid} に主人公の文があるが、hero が定義されていない")
print("\n".join(err) if err else f"OK {pack.get('packId')}: {len(ids)}地域")
sys.exit(1 if err else 0)
