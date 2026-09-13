"""Convert the approved exploration design to runtime data; no engine or DB writes.

Run from the project root:
  python -B tools/build_exploration_crafting_v071.py
  python -B tools/build_exploration_crafting_v071.py --check

Only game/data/exploration_crafting_v071.json is written, and --check writes nothing.
Equipment.make determines values from the definition ID; the host assigns the new item ID.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from collections import Counter, defaultdict
from pathlib import Path
import exploration_crafting_progression_v071 as progression

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / "docs/design/exploration_crafting/catalog.json"
DATABASE = ROOT / "docs/database/stelrpg-database.json"
OUTPUT = ROOT / "game/data/exploration_crafting_v071.json"
KINDS = ("metal", "fiber", "catalyst", "sigil", "core", "curio")
ICON_KEYS = dict(zip(KINDS, ("ore", "seed", "essence", "coin", "essence", "satchel")))
REGIONS = (
    ("forest", "동굴숲"), ("crystal", "수정 광맥"), ("flood", "잠긴 회랑"),
    ("spore", "포자 정원"), ("lava", "잿불 용암굴"), ("ice", "빙하의 균열"),
    ("machine", "기계도시"), ("twilight", "황혼의 수림"), ("nebula", "성운의 공동"),
    ("core", "뒤틀린 마력핵"),
)
EVENTS = {"normal_kill", "elite_kill", "guardian_kill", "raid_clear", "gather", "cache_salvage", "secret_claim"}
STATS = {"power", "vitality", "fortitude", "swiftness", "precision", "specialization"}


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def encode(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False)+"\n").encode("utf-8")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unique(rows, key="id"):
    result = {r[key]: r for r in rows}
    assert len(result) == len(rows), f"duplicate {key}"
    return result


def sources():
    design = read(DESIGN)
    database = read(DATABASE)
    equipment = unique(database["equipment"])
    display = read(ROOT / "game/data/content_names.json")["equipment"]
    for row in equipment.values():
        owner = row["job_lock"] if row["slot"] == "weapon" else row["family"]
        row["base_name"] = display[f'{row["slot"]}:{owner}:{row["tier"]}']
    classes = unique(database["classes"])
    regions = read(ROOT / "game/assets/sprites/item_regions.json")
    equipment_code = (ROOT / "game/scripts/equipment_catalog.gd").read_text(encoding="utf-8")
    match = re.search(r"^const AFFIXES=(\{[^\n]+\})", equipment_code, re.M)
    assert match, "cannot read current affix contract"
    affixes = json.loads(match.group(1))
    for key, value in affixes.items():
        assert value["stat"] == "none" or value["stat"] in STATS, f"legacy stat in affix {key}"
    signature = 'static func make(type:String,tier:int,rarity:int,id:String,affix:String="none",job_id:String="warrior",special_options:bool=true)->Dictionary:'
    assert signature in equipment_code, "Equipment.make signature changed; review adapter"
    return design, database, equipment, classes, regions, affixes


def construct():
    design, database, equipment, classes, icon_regions, affixes = sources()
    loot = unique(design["loot"])
    authored_equipment = unique(design["equipment"])
    authored_recipes = unique(design["recipes"])
    unique(design["acquisition"])
    assert (len(loot), len(design["acquisition"]), len(authored_equipment), len(authored_recipes)) == (60,130,500,500)
    ingredients = defaultdict(dict)
    for row in design["ingredients"]:
        rid, lid, amount = row["recipe_id"], row["loot_id"], row["amount"]
        assert rid in authored_recipes and lid in loot and lid not in ingredients[rid]
        assert type(amount) is int and 0 < amount <= loot[lid]["max_stack"]
        ingredients[rid][lid] = amount

    biomes = {}
    for tier, (key, name) in enumerate(REGIONS):
        floor_ids = list(range(tier*10+1, tier*10+11))
        floors = [r for r in database["floors"] if int(r["id"]) in floor_ids]
        assert len(floors) == 10 and all(r["tier"] == tier for r in floors)
        biomes[key] = dict(id=key, name=name, tier=tier, chapter=tier,
                           floor_min=floor_ids[0], floor_max=floor_ids[-1],
                           terrains=sorted({r["terrain"] for r in floors}))

    source_rules = defaultdict(list)
    acquisition = []
    for r in sorted(design["acquisition"], key=lambda r:r["id"]):
        material = loot[r["loot_id"]]
        row = {k:r[k] for k in ("id", "event", "floor_min", "floor_max", "chance", "amount_min", "amount_max", "risk_bonus", "recipient")}
        row.update(material_id=r["loot_id"], biome=material["region"], tier=material["tier"],
                   roll_mode="independent_per_eligible_player", amount_distribution="uniform_integer_inclusive",
                   candidate_monster_ids_reference=r["candidate_monster_ids"],
                   source=dict(design_rule_id=r["id"], design_material_id=r["loot_id"]))
        source_rules[r["loot_id"]].append(r["id"])
        acquisition.append(row)

    materials = {}
    for lid, r in sorted(loot.items()):
        kind = lid.rsplit(":",1)[1]
        materials[lid] = dict(id=lid, name=r["name"], kind=kind,
            category="material", design_category=r["category"],
            icon=ICON_KEYS[kind], biome=r["region"], tier=r["tier"],
            stack=r["max_stack"], max_stack=r["max_stack"], rarity=r["rarity"], binding=r["binding"],
            sell_gold=r["sell_gold"], craft_ingredient=r["category"]=="craft_material",
            source=dict(design_material_id=lid, acquisition_rule_ids=source_rules[lid]))

    recipes = {}
    projections = []
    for rid, r in sorted(authored_recipes.items()):
        proposed = authored_equipment[r["output_id"]]
        eid = proposed["existing_equipment_id"]
        assert eid in equipment, f"missing existing equipment {eid}"
        live = equipment[eid]
        for field in ("slot", "family", "job_lock", "tier", "rarity", "required_level"):
            assert proposed[field] == live[field], f"design equipment identity changed: {eid}.{field}"
        assert live["rarity"] == 1 and r["required_level"] == live["required_level"]
        weapon = live["slot"] == "weapon"
        job = live["job_lock"] if weapon else live["family"]
        make_type = classes[job]["weapon"] if weapon else live["slot"]
        if weapon:
            assert make_type == live["weapon_type"]
        assert classes[job]["family"] == live["family"]
        affix = proposed["affix"]
        assert affix in affixes and affixes[affix]["stat"] in STATS
        row = dict(id=rid, name=live.get("base_name",live["name"]),
            existing_equipment_id=eid, type=make_type, job=job, family=live["family"],
            slot=live["slot"], job_lock=live["job_lock"], tier=live["tier"], rarity=1, upgrade=0,
            level=r["required_level"], gold=r["gold"], materials=ingredients[rid], affix=affix,
            amount=r["output_amount"], facility=r["facility"], binding=r["binding"],
            success_chance=r["success_chance"], craft_seconds=r["craft_seconds"],
            source=dict(design_recipe_id=rid, design_output_reference=r["output_id"]))
        recipes[rid] = row
        projections.append({k:row[k] for k in ("existing_equipment_id","name","type","job","family","slot","job_lock","tier","rarity","level","affix")})

    icon_blob = (ROOT / "game/assets/sprites/items-v04.png").read_bytes()
    assert icon_blob[:8] == b"\x89PNG\r\n\x1a\n"
    width,height = struct.unpack(">II",icon_blob[16:24])
    icons = {}
    for key in sorted(set(ICON_KEYS.values())):
        x,y,w,h = icon_regions[key]
        assert min(x,y)>=0 and min(w,h)>0 and x+w<=width and y+h<=height
        icons[key] = dict(provider="res://scripts/item_art.gd", key=key,
                          sheet="res://assets/sprites/items-v04.png", rect=icon_regions[key])

    base = dict(schema_version=1, version="V0.7.1", id="exploration_crafting_v071",
        metadata=dict(status="runtime_connected",
            design_source=DESIGN.relative_to(ROOT).as_posix(), design_sha256=digest(DESIGN),
            reference_database=DATABASE.relative_to(ROOT).as_posix(),
            equipment_reference_projection_sha256=hashlib.sha256(encode(projections)).hexdigest(),
            provenance_note="전체 운영DB 해시는 저장하지 않음: 이 파일을 운영DB에 편입할 때 해시 순환을 방지. 기존장비 식별·생성인자 투영만 검증.",
            counts=dict(materials=60, acquisition=130, recipes=500, ingredients=len(design["ingredients"]), biomes=10, new_equipment_definitions=0)),
        policies=dict(
            equipment_factory=dict(script="res://scripts/equipment_catalog.gd", method="make",
                argument_order=["type","tier","rarity","existing_equipment_id","affix","job","special_options"], special_options=False,
                instance_id="Equipment.make에는 기존 장비 정의ID(existing_equipment_id)를 전달. 생성 결과의 item.id만 호스트가 발급한 새 고유ID로 교체한 뒤 지급. 정의ID/recipe ID/crafted 설계ID를 인벤토리ID로 쓰지 않음.",
                identity_assignment=dict(factory_id_source="recipe.existing_equipment_id", delivered_item_id_source="host_new_unique_instance_id", replace_only="item.id", preserve_generated_resonance=True, then_generate="Equipment.Special.generate(item,item.id)", preview="unresolved_special_stats"),
                live_values="이름·bonus·착용제한·옵션·능력치는 현재 Equipment.make/normalize를 사용. 설계의 구스탯·bonus·affix_stat_value 복사 금지.",
                stat_schema_version=2, output_rarity=1, output_upgrade=0,
                equipment_special_stats="host_unique_id_once_active_pool_from_equipment_special_stats.gd", enhancement_policy="unchanged"),
            crafting=dict(mode="instant", production_queue=False, success_chance=1,
                craft_seconds=0, facility="smith", research_required=False,
                restriction="output_equippable_by_crafter", binding="personal",
                validation=["authoritative_recipe_id", "smith_access", "level", "equipment_restriction", "gold", "materials", "capacity_after_consumption"],
                transaction="validate_all_then_atomic_consume_and_make_one_equipment",
                failure="no_gold_or_material_cost_on_validation_or_capacity_failure",
                idempotency="same_player_request_id_returns_original_result_no_duplicate_charge_or_output",
                preserve_existing_recipes=True, batch="처리수량은 기본1. 복수제작은 매회 모든비용/용량을 검증하거나 일괄원자거래로 구현; 임의일부차감 금지."),
            acquisition=dict(authority="host_or_offline_authoritative_session",
                recipient="existing_authorized_eligible_player", binding="personal",
                selection="floor_range_and_exclusive_event", biome_mapping="chapter=(floor-1)//10; 지역 ID는 terrain ID와 다름",
                monster_candidates="source_reference_only_not_species_whitelist",
                event_precedence=["raid_clear","guardian_kill","elite_kill","normal_kill"],
                exclusive_kill_event=True, raid_excludes_guardian=True,
                excludes=["training_target","revived_enemy_reward","duplicate_spawn_or_site_claim"],
                key_fields=["map_instance_id","spawn_or_site_instance_id","player_id","rule_id"],
                success_rng="chance=1 always succeeds; otherwise host uniform roll in [0,1) < chance",
                amount_rng="uniform integer amount_min..amount_max inclusive after success",
                replay="persist_roll_and_claim_identity; retransmission_or_full_bag_must_not_reroll",
                capacity="use_existing_personal_loot_delivery; never_consume_or_overflow_a_stack_past_99",
                risk_bonus=False, preserve_existing_drops=True,
                stacking_with_species_rules="해당처치에 같은재료를 보상하는 신규종전용규칙이 연결되면 둘을 중복실행하지 말고 메인이 우선순위를 지정"),
            materials=dict(max_stack=99, sell_gold=0, tradable=False,
                id_usage="loot:*는 정의/재료키이며 기존 seed/ore/essence 지갑키로 변환하지 않음",
                icon_usage="재료 식별자는 그대로 유지하고 ItemArt.texture(material.icon)로 기존fallback 사용. icon키를 재료 저장키로 쓰지 않음.",
                collectible_policy="curio10종도 material카테고리 개인수집품. 제작재료 아님, 전투효과·판매/교환규칙 추가 없음")),
        biomes=biomes, icon_fallbacks=icons, materials=materials, acquisition=acquisition, recipes=recipes)
    return progression.extend(base, equipment, classes)


def validate(data):
    design, database, equipment, classes, _, affixes = sources()
    checks = 0
    def check(condition, message):
        nonlocal checks
        checks += 1
        assert condition, message
    mats, recipes, rules = data["materials"], data["recipes"], data["acquisition"]
    check((len(mats),len(rules),len(recipes),len(data["biomes"]))==(110,200,500,10),"catalog counts")
    check("equipment" not in data and data["metadata"]["counts"]["new_equipment_definitions"]==0,"no new equipment definitions")
    src_loot=unique(design["loot"]);src_rules=unique(design["acquisition"]);src_recipes=unique(design["recipes"])
    check(set(src_loot).issubset(mats) and set(recipes)==set(src_recipes),"source IDs preserved")
    check(len({r['id'] for r in rules})==200,"unique acquisition IDs")
    for key,m in mats.items():
        check(m['id']==key,"material identity")
        if key in src_loot:
            check(m['name']==progression.MATERIAL_NAMES[m['tier']][KINDS.index(m['kind'])],"revised material name")
        check(m['stack']==m['max_stack']==99 and m['sell_gold']==0 and m['binding']=='personal',"personal stack99")
        check(m['biome'] in data['biomes'] and m['tier']==data['biomes'][m['biome']]['tier'],"material biome")
        check(m['icon'] in data['icon_fallbacks'] and bool(m['source']['acquisition_rule_ids']),"icon/source references")
    for r in rules:
        if r['id'] not in src_rules: continue
        original=src_rules[r['id']];m=mats[r['material_id']]
        check(r['event'] in EVENTS and r['material_id']==original['loot_id'],"acquisition source")
        check(0<=r['chance']<=1 and r['chance']==original['chance'],"probability preserved")
        check(type(r['amount_min']) is int and type(r['amount_max']) is int and 1<=r['amount_min']<=r['amount_max']<=99,"acquisition amount")
        check((r['amount_min'],r['amount_max'])==(original['amount_min'],original['amount_max']),"original amounts")
        check((r['floor_min'],r['floor_max'])==(m['tier']*10+1,m['tier']*10+10),"floor scope")
        check(not r['risk_bonus'] and r['recipient']=='eligible_player',"personal original eligibility")
    totals=Counter();used=set();outputs=set();relation_count=0
    for rid,r in recipes.items():
        e=equipment[r['existing_equipment_id']];source=src_recipes[rid]
        check(r['id']==rid and r['existing_equipment_id'] not in outputs,"unique existing recipe output")
        outputs.add(r['existing_equipment_id'])
        check(r['rarity']==1 and r['upgrade']==0 and r['amount']==1,"rare unenhanced existing equipment")
        check(r['tier']==e['tier'] and r['level']==e['required_level']==source['required_level'],"equipment tier/level")
        check(type(r['gold']) is int and r['gold']>=0 and r['gold']==source['gold'],"source gold")
        check(r['job'] in classes and classes[r['job']]['family']==r['family']==e['family'],"factory owner")
        check(r['type']==(classes[r['job']]['weapon'] if r['slot']=='weapon' else r['slot']),"factory type")
        check(r['job_lock']==e['job_lock'] and r['slot']==e['slot'],"equipment restrictions")
        check(r['affix'] in affixes and affixes[r['affix']]['stat'] in STATS,"six-stat affix compatibility")
        check(r['success_chance']==1 and r['craft_seconds']==0 and r['facility']=='smith',"instant guaranteed craft")
        check(not set(r)&{'bonus','stats','affix_stat_value','resonance','enhance_success','enhance_cap'},"no copied effects or enhancement policy")
        for lid,amount in r['materials'].items():
            check(lid in mats and mats[lid]['craft_ingredient'] and mats[lid]['tier']==r['tier'],"same-biome ingredient")
            check(type(amount) is int and 1<=amount<=99,"valid recipe amount")
            used.add(lid);relation_count+=1
        totals[r['tier']]+=1
    check(outputs=={e['id'] for e in database['equipment'] if e['rarity']==1},"all existing rare equipment covered")
    check(dict(totals)==dict.fromkeys(range(10),50),"50 existing outputs per tier")
    check(relation_count==2410,"all original ingredient relations")
    check(used=={k for k,m in src_loot.items() if m['category']=='craft_material'},"original50 base crafting materials preserved")
    for rid in recipes:
        expected={r['loot_id']:r['amount'] for r in design['ingredients'] if r['recipe_id']==rid}
        check(recipes[rid]['materials']==expected,"exact source ingredient mapping")
    # Check eligibility precedence and floor edges independently of the serializer.
    def event(raid=False,guardian=False,elite=False):
        return 'raid_clear' if raid else 'guardian_kill' if guardian else 'elite_kill' if elite else 'normal_kill'
    for flags,want in [((True,True,True),'raid_clear'),((False,True,True),'guardian_kill'),((False,False,True),'elite_kill'),((False,False,False),'normal_kill')]:
        selected=[r for r in rules if r['floor_min']<=10<=r['floor_max'] and r['event']==event(*flags)]
        check(selected and {r['event'] for r in selected}=={want},"exclusive kill event")
    for floor in (0,1,10,11,90,91,100,101):
        found=[x for x in data['biomes'].values() if x['floor_min']<=floor<=x['floor_max']]
        check(len(found)==(1 if 1<=floor<=100 else 0),"biome boundary")
    return checks + progression.validate_extension(data, equipment)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true',help='validate exact generated bytes without writing')
    args=parser.parse_args()
    protected=[DESIGN,ROOT/'docs/design/exploration_crafting/catalog.sqlite',DATABASE,
               ROOT/'docs/database/stelrpg.sqlite',ROOT/'docs/database/manifest.json',
               ROOT/'game/data/codex-v053.bin',ROOT/'game/scripts/equipment_catalog.gd']
    before={p:digest(p) for p in protected}
    data=construct();checks=validate(data);blob=encode(data)
    if args.check:
        assert OUTPUT.is_file() and OUTPUT.read_bytes()==blob,"runtime catalog stale or missing; run generator"
    else:
        OUTPUT.write_bytes(blob)
    assert all(digest(p)==h for p,h in before.items()),"source/protected file changed during catalog validation"
    print(json.dumps(dict(status='PASS',mode='check' if args.check else 'generate',checks=checks,
        counts=data['metadata']['counts'],sha256=hashlib.sha256(blob).hexdigest(),
        engine_run=False,consumer_integration='connected_in_runtime_separately_verified',operational_database_written=False),ensure_ascii=False))


if __name__ == '__main__':
    main()
