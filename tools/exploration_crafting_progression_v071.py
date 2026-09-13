"""Drop grades, practical crafting uses, and Korean names; data conversion only."""
from collections import Counter

GRADES = [("일반", "d5ddd8"), ("레어", "5aa8ed"), ("유니크", "c58ded"), ("에픽", "ecca61"), ("레전드리", "f18a47")]
MATERIAL_NAMES = [
    ["철광석", "질긴 뿌리", "나무 수액", "이끼 낀 문장", "수호목 심재", "숲의 기억석"],
    ["푸른 수정광석", "수정 거미줄", "수정 가루", "광부의 인장", "심장 수정", "수정 정동"],
    ["녹슨 합금 조각", "물에 젖은 가죽", "심해 점액", "침몰 왕가의 문장", "파수기사 휘장", "물에 잠긴 회중시계"],
    ["버섯 덮인 철광석", "질긴 균사", "발광 포자", "정원사의 인장", "군주 포자핵", "유리 포자병"],
    ["흑요철", "내열 가죽", "잿가루", "용광로 문장", "용암 핵", "꺼지지 않는 석탄"],
    ["서리 은광석", "설원 짐승 가죽", "얼음 결정 가루", "빙벽 탐사대 인장", "영구빙 결정", "얼어붙은 꽃"],
    ["기계 합금 조각", "절연천", "윤활유", "폐도시 통행증", "지휘 장치 동력핵", "멈춘 천문시계"],
    ["검은 철목", "밤거미 비단", "오래된 나무 수지", "황혼 순례자 문장", "고목왕 심재", "빛나는 잎"],
    ["운석 조각", "별빛 실", "성운 가루", "별길 관측대 인장", "별의 핵", "별자리판"],
    ["심연 합금", "공허 비단", "응축된 마력", "심연 왕가의 문장", "아스트라 핵 조각", "뒤틀린 왕관 조각"],
]
REFINED_NAMES = ["정제 철괴", "정제 수정괴", "정제 청동괴", "정제 균철괴", "정제 흑요철괴", "정제 은괴", "정제 기계 합금", "정제 철목", "정제 운철괴", "정제 심연 합금"]
LEGENDARY_NAMES = ["영겁수림 원핵", "만상수정 원핵", "심해왕권 원핵", "포자군림 원핵", "이그니스 원핵", "영겁빙결 원핵", "황동천구 원핵", "황혼윤회 원핵", "아이테르 원핵", "공허개벽 원핵"]
CORE_NAMES = ["숲", "수정", "심해", "포자", "용암", "빙하", "기계", "황혼", "성운", "심연"]
RAID_NAMES = ["숲 수호자의 증표", "수정 거인의 증표", "침수 성채의 인장", "포자 군주의 인장", "용암 거인의 증표", "빙하 군주의 인장", "기계도시 지휘관의 인장", "고목왕의 증표", "별먹는 거인의 인장", "아스트라의 인장"]
KINDS = ("metal", "fiber", "catalyst", "sigil", "core", "curio")
EXTRA = {
    "refined_metal": (1, "ore", [("normal_kill", .03), ("elite_kill", .20)]),
    "tempered_core": (2, "essence", [("elite_kill", .04), ("guardian_kill", .10)]),
    "epic_core": (3, "essence", [("raid_clear", .20)]),
    "legendary_core": (4, "essence", [("raid_clear", .02)]),
    "raid_seal": (2, "coin", [("raid_clear", 1.0)]),
}


def material_id(biome, kind):
    return f"loot:{biome}:{kind}"


def extend(data, equipment, classes):
    """Keep original recipe IDs and costs. Add explicit, independently consumable fields."""
    renames = {}
    advanced = {}
    alchemy = {}
    for biome, region in data["biomes"].items():
        tier = region["tier"]
        mid = lambda kind: material_id(biome, kind)
        for kind, name in zip(KINDS, MATERIAL_NAMES[tier]):
            row = data["materials"][mid(kind)]
            if row["name"] != name:
                renames[row["id"]] = {"previous": row["name"], "name": name}
            row["name"] = name
            # A collected memento is now an ingredient for refining and higher-grade gear.
            row["craft_ingredient"] = True
            row["uses"] = []
        for kind, (rarity, icon, drops) in EXTRA.items():
            lid = mid(kind)
            name = (REFINED_NAMES[tier] if kind=="refined_metal" else RAID_NAMES[tier] if kind=="raid_seal"
                    else LEGENDARY_NAMES[tier] if kind=="legendary_core" else CORE_NAMES[tier]+{"tempered_core":" 강화핵", "epic_core":" 정수", "legendary_core":" 원핵"}[kind])
            data["materials"][lid] = dict(id=lid, name=name, kind=kind, category="material",
                design_category="craft_material", icon=icon, biome=biome, tier=tier,
                stack=99, max_stack=99, rarity=rarity, binding="personal", sell_gold=0,
                craft_ingredient=True, uses=[], source={"extension":"drop_grade_crafting_20260914", "acquisition_rule_ids":[]})
            for event, chance in drops:
                rid = f"drop:{biome}:{event}:{kind}"
                data["acquisition"].append(dict(id=rid,event=event,floor_min=region["floor_min"],floor_max=region["floor_max"],
                    chance=chance,amount_min=1,amount_max=1,risk_bonus=False,recipient="eligible_player",
                    material_id=lid,biome=biome,tier=tier,roll_mode="independent_per_eligible_player",
                    amount_distribution="uniform_integer_inclusive",candidate_monster_ids_reference=[],
                    source={"extension":"drop_grade_crafting_20260914"}))
                data["materials"][lid]["source"]["acquisition_rule_ids"].append(rid)

        def formula(kind, name, inputs, outputs, gold, seconds, icon):
            rid = f"exploration_alchemy:{biome}:{kind}"
            alchemy[rid] = dict(id=rid,name=name,facility="alchemy",gold=gold,
                materials={mid(k):v for k,v in inputs.items()},outputs=outputs,
                seconds=seconds,icon=icon,research="",level=max(1,tier*10),
                success_chance=1.0,biome=biome,source={"extension":"drop_grade_crafting_20260914"})
        # Existing output item IDs and their current effects remain authoritative.
        formula("potion", "회복 물약 조제 · "+region["name"], {"catalyst":2,"fiber":2}, {"potion":2}, 6+2*tier,6,"potion")
        formula("mana_potion", "기력 물약 조제 · "+region["name"], {"catalyst":2,"core":1}, {"mana_potion":2},10+3*tier,6,"stamina")
        formula("power_potion", "공격 물약 조제 · "+region["name"], {"catalyst":3,"metal":2,"sigil":1}, {"power_potion":1},12+3*tier,8,"physical_attack")
        formula("fire_bottle", "화염병 조제 · "+region["name"], {"catalyst":2,"fiber":1,"metal":1}, {"fire_bottle":1},15+3*tier,8,"fire")
        formula("refined_metal",REFINED_NAMES[tier]+" 제련",{"metal":5,"catalyst":1},{mid("refined_metal"):1},10+5*tier,6,"ore")
        formula("tempered_core",CORE_NAMES[tier]+" 강화핵 정제",{"core":3,"sigil":2,"catalyst":3},{mid("tempered_core"):1},40+10*tier,8,"essence")
        formula("epic_core",CORE_NAMES[tier]+" 정수 정제",{"tempered_core":4,"curio":1,"catalyst":4,"raid_seal":1},{mid("epic_core"):1},100+20*tier,12,"essence")
        formula("legendary_core",LEGENDARY_NAMES[tier]+" 정제",{"epic_core":6,"curio":2,"sigil":6,"raid_seal":2},{mid("legendary_core"):1},300+40*tier,18,"essence")

    for recipe in data["recipes"].values():
        for rarity in (2,3,4):
            eid = recipe["existing_equipment_id"].rsplit(":",1)[0]+":"+str(rarity)
            assert eid in equipment, f"unregistered higher-grade equipment {eid}"
            live=equipment[eid]
            rid="recipe:"+eid
            row={**recipe,"id":rid,"existing_equipment_id":eid,"rarity":rarity,
                 "gold":recipe["gold"]*{2:3,3:7,4:15}[rarity],
                 "materials":{k:v*{2:2,3:3,4:4}[rarity] for k,v in recipe["materials"].items()},
                 "source":{"base_recipe_id":recipe["id"],"extension":"drop_grade_crafting_20260914"}}
            biome=next(k for k,b in data["biomes"].items() if b["tier"]==recipe["tier"])
            row["materials"][material_id(biome,"raid_seal")]={2:1,3:2,4:4}[rarity]
            row["materials"][material_id(biome,{2:"tempered_core",3:"epic_core",4:"legendary_core"}[rarity])]={2:2,3:2,4:2}[rarity]
            row["materials"][material_id(biome,"curio")]=rarity-1
            # Bulk metal at the highest tier may require more than one 99-count inventory stack.
            # Current inventory stores 99 per material ID: keep all single crafts reachable.
            for lid,amount in row["materials"].items():row["materials"][lid]=min(99,amount)
            row["requires_raid_material"]=True
            assert live["slot"]==row["slot"] and live["job_lock"]==row["job_lock"] and live["tier"]==row["tier"]
            advanced[rid]=row

    bands = [
        ("metal",1,1,.90), ("refined_metal",2,2,.80), ("core",3,6,.70),
        ("tempered_core",7,9,.30), ("epic_core",10,11,.10), ("legendary_core",12,12,.05),
    ]
    data["enhancement_materials"] = {
        "status":"material_selection_ready_full_probability_rework_pending",
        "tier_source":"equipment.tier -> biomes.tier; use that biome's material",
        "bands":[dict(target_min=lo,target_max=hi,kind=kind,user_confirmed_success_chance=chance,
                      material_by_tier={str(b["tier"]):material_id(k,kind) for k,b in data["biomes"].items()}) for kind,lo,hi,chance in bands],
        "current_runtime_material_adapter":{"target_min":1,"target_max":5,"quantity":"target_upgrade","gold":"target_upgrade * 50","scope":"기존 +5/100% 강화의 재료 선택만 교체. 기존 비용 보존, 확률 개편과 구분."},
        "confirmed_future_rules":{"caps":{"0":3,"1":None,"2":None,"3":None,"4":12},"failure_downgrade":1,"prevent_downgrade_at_current_upgrade":7,"allowed_downgrade_examples":[[9,8],[8,7]],"destroy_chance_given_failure":.03},
        "pending":["중간 장비등급 강화상한", "확률형 강화 실패 시 비용 처리", "6~12강 구간별 최종 재료수량·금화", "초과 강화된 구장비 이관"],
        "automatic_activation":False,
    }
    data["advanced_recipes"]=dict(sorted(advanced.items()))
    data["alchemy_recipes"]=dict(sorted(alchemy.items()))
    data["rarities"]={str(i):dict(id=i,name=name,color=color) for i,(name,color) in enumerate(GRADES)}
    for row in data["materials"].values():
        row["grade_name"]=GRADES[row["rarity"]][0]
        row["grade_color"]=GRADES[row["rarity"]][1]
    for table,usage in [(data["recipes"],"equipment_crafting"),(advanced,"advanced_equipment_crafting"),(alchemy,"alchemy")]:
        for recipe in table.values():
            for lid in recipe["materials"]:
                if usage not in data["materials"][lid]["uses"]:data["materials"][lid]["uses"].append(usage)
    for band in data["enhancement_materials"]["bands"]:
        for lid in band["material_by_tier"].values():data["materials"][lid]["uses"].append("enhancement_material")
    data["acquisition"].sort(key=lambda x:x["id"])
    data["metadata"]["counts"].update(materials=110,acquisition=200,advanced_recipes=1500,alchemy_recipes=80,total_equipment_recipes=2000,enhancement_bands=6)
    data["metadata"]["extension"]={"id":"drop_grade_crafting_20260914","numeric_status":"new_costs_drop_chances_and_amounts_are_initial_values","material_renames":renames}
    data["policies"]["materials"]["collectible_policy"]="기존 curio10종은 상위장비 및 정수·원핵 정제 재료로 사용. 판매가0/개인귀속 유지."
    data["policies"]["equipment_factory"]["output_rarity"]="recipe.rarity (base1 / advanced2,3,4)"
    data["policies"]["equipment_factory"]["live_values"]+=" 에픽·레전드리 resonance는 기존 장비 정의ID(existing_equipment_id)를 전달한 Equipment.make 결과로 고정. 미리보기와 실제 지급에 같은 정의ID를 사용하며, 생성 후 item.id만 새 고유ID로 교체한다. 지급ID로 공명을 다시 계산하거나 선택·재추첨하지 않음."
    data["policies"]["advanced_crafting"]={"merge":"base recipes + advanced_recipes; unique recipe IDs","success_chance":1.0,"craft_seconds":0,"production_queue":False,"raid_requirement":"all advanced recipes consume their biome's raid_seal; raid_seal drops only from raid_clear and has no crafting output"}
    data["policies"]["alchemy"]={"route":"merge alchemy_recipes into existing Production.recipes; retain all base/research definitions","success_chance":1.0,"queue":"existing personal production queue","effects":"existing output item effects; no stronger potion effect invented","level":"validate recipe.level at order start/reserve if used","mana_potion_note":"현재 stable ID mana_potion은 기력회복. MP도입완료나 마나회복으로 표시하지 않음."}
    return data


def validate_extension(data, equipment):
    checks=0
    def check(value,label):
        nonlocal checks
        checks+=1
        assert value,label
    mats=data["materials"];advanced=data["advanced_recipes"];alchemy=data["alchemy_recipes"]
    check((len(mats),len(data["acquisition"]),len(advanced),len(alchemy))==(110,200,1500,80),"extension counts")
    check(set(r["rarity"] for r in mats.values())==set(range(5)),"all five drop grades")
    check(not(set(data["recipes"])&set(advanced)),"stable base recipe IDs")
    check(not any(mid.endswith(":raid_seal") for r in alchemy.values() for mid in r["outputs"]),"raid source cannot be bypassed by refining")
    for lid,m in mats.items():
        check(m["stack"]==m["max_stack"]==99 and m["uses"],"all drops have real use and fit storage")
        check(m["grade_name"]==data["rarities"][str(m["rarity"])]["name"],"grade labels")
    for r in data["acquisition"]:
        check(r["material_id"] in mats and 0<r["chance"]<=1,"drop reference and chance")
        if r["material_id"].endswith(":raid_seal"):
            check(r["event"]=="raid_clear" and r["chance"]==1,"guaranteed raid-only seal")
    for r in advanced.values():
        check(r["existing_equipment_id"] in equipment,"existing higher-grade equipment")
        check(equipment[r["existing_equipment_id"]]["rarity"]==r["rarity"] and r["upgrade"]==0 and r["amount"]==1,"correct rarity/upgrade")
        check(r["success_chance"]==1 and r["craft_seconds"]==0,"instant guaranteed higher-grade crafting")
        check(any(lid.endswith(":raid_seal") and n>0 for lid,n in r["materials"].items()),"mandatory raid component")
        for lid,n in r["materials"].items():check(lid in mats and type(n) is int and 0<n<=99,"reachable higher-grade cost")
    for r in alchemy.values():
        check(r["facility"]=="alchemy" and r["seconds"]>0 and r["success_chance"]==1,"alchemy queue contract")
        for lid,n in r["materials"].items():check(lid in mats and 0<n<=99,"alchemy input")
        for lid,n in r["outputs"].items():check((lid in mats or lid in {"potion","mana_potion","power_potion","fire_bottle"}) and n>0,"existing valid output")
        check(not (set(r["materials"])&set(r["outputs"])),"no direct material self cycle")
    bands=data["enhancement_materials"]["bands"]
    check([n for b in bands for n in range(b["target_min"],b["target_max"]+1)]==list(range(1,13)),"six bands cover target1..12 once")
    check([b["user_confirmed_success_chance"] for b in bands]==[.9,.8,.7,.3,.1,.05],"confirmed chance thresholds preserved")
    for b in bands:
        check(len(b["material_by_tier"])==10 and all(lid in mats for lid in b["material_by_tier"].values()),"enhancement regional mapping")
    check(not data["enhancement_materials"]["automatic_activation"],"no invented activation of unfinished enhancement rules")
    # Every refinement edge must climb the declared processing order; no profitable cycles.
    order={"metal":0,"fiber":0,"catalyst":0,"sigil":0,"core":0,"curio":0,"raid_seal":0,"refined_metal":1,"tempered_core":1,"epic_core":2,"legendary_core":3}
    for r in alchemy.values():
        for output in r["outputs"]:
            if output in mats:check(all(order[mats[lid]["kind"]]<order[mats[output]["kind"]] for lid in r["materials"]),"acyclic refinement")
    check(Counter(r["rarity"] for r in advanced.values())=={2:500,3:500,4:500},"all500 bases get three higher grades")
    return checks
