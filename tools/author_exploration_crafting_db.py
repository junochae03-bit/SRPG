"""Author proposal-only loot/crafting JSON and SQLite; never modify runtime DB."""
import hashlib
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/design/exploration_crafting'


def main():
    source = ROOT / 'docs/database/stelrpg-database.json'
    db = json.loads(source.read_text(encoding='utf-8'))
    protected = [source, ROOT / 'docs/database/stelrpg.sqlite', ROOT / 'game/data/codex-v053.bin']
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
    regions = [
        ('forest', '동굴숲', ['이슬철 조각', '질긴 뿌리섬유', '숲빛 수액', '이끼 낀 문장', '파수목 심재', '뿌리의 기억석']),
        ('crystal', '수정 광맥', ['청맥 원석', '수정 비단', '광맥 가루', '광부의 인장', '심장 수정', '노래하는 정동']),
        ('flood', '잠긴 회랑', ['녹청 합금', '침수 가죽', '심해 진액', '침몰 왕가의 문장', '파수기사 휘장', '물결 속 회중시계']),
        ('spore', '포자 정원', ['균철 덩이', '균사 직물', '발광 포자', '정원사의 인장', '군주 균핵', '유리 포자병']),
        ('lava', '잿불 용암굴', ['흑요 강철', '내열 가죽', '잿불 분말', '용광로 문장', '용암 심핵', '꺼지지 않는 석탄']),
        ('ice', '빙하의 균열', ['서리 은괴', '설수 모피', '빙정 가루', '빙벽 탐사 인장', '영구빙 결정', '얼어붙은 꽃']),
        ('machine', '기계도시', ['정밀 합금', '절연 직물', '태엽 윤활액', '폐도시 통행패', '지휘 동력핵', '멈춘 천문시계']),
        ('twilight', '황혼의 수림', ['황혼 목철', '밤안개 비단', '고목 수지', '황혼 순례 문장', '고목왕 심재', '빛을 품은 잎']),
        ('nebula', '성운의 공동', ['운철 파편', '별빛 직물', '성운 분진', '별길 관측 인장', '포식된 별핵', '작은 별자리판']),
        ('core', '뒤틀린 마력핵', ['심연 합금', '공허 직물', '응축 마력', '심연 왕가의 문장', '아스트라 핵편', '뒤틀린 왕관 조각']),
    ]
    loot, sources, gear, recipes, ingredients = [], [], [], [], []
    for tier, (region, label, names) in enumerate(regions):
        ids = [f'loot:{region}:{kind}' for kind in ('metal', 'fiber', 'catalyst', 'sigil', 'core', 'curio')]
        floors = [v for v in db['floors'] if v['tier'] == tier]
        monster_ids = sorted({x for f in floors for x in f['mobs']})
        for index, (lid, name) in enumerate(zip(ids, names)):
            loot.append(dict(id=lid, name=name, region=region, tier=tier,
                category='collectible' if index == 5 else 'craft_material', rarity=[0,0,1,1,2,2][index],
                max_stack=99, sell_gold=0, binding='personal', runtime_status='not_applied',
                purpose=['무기와 중갑 제작','방어구와 장신구 제작','모든 장비 제작 촉매','정밀 제작 보조 재료','정예·보스 제작 촉매','지역 수집품; 전투 능력치 없음'][index]))
        # New rolls supplement existing drops; amounts are conditional on a successful roll.
        for index, event, chance, lo, hi in [(0,'normal_kill',.18,1,2),(1,'normal_kill',.18,1,2),
                (2,'normal_kill',.08,1,1),(0,'gather',1,2,4),(1,'cache_salvage',1,2,4),
                (2,'elite_kill',1,1,2),(3,'elite_kill',.35,1,1),(3,'guardian_kill',1,1,2),
                (4,'elite_kill',.12,1,1),(4,'guardian_kill',.4,1,1),(4,'raid_clear',1,2,3),
                (5,'secret_claim',.2,1,1),(5,'raid_clear',.15,1,1)]:
            sources.append(dict(id=f'drop:{region}:{event}:{index}', loot_id=ids[index], event=event,
                floor_min=tier*10+1, floor_max=tier*10+10, chance=chance, amount_min=lo, amount_max=hi,
                candidate_monster_ids=monster_ids if event=='normal_kill' else [],
                rule='independent', recipient='eligible_player', risk_bonus=False,
                deduplication='one_roll_per_player_per_spawn_or_site; raid_clear_excludes_guardian_kill'))
        selected = [v for v in db['equipment'] if v['tier']==tier and v['rarity']==1]
        assert len(selected)==50
        for e in selected:
            weapon = e['slot']=='weapon'
            rid = 'recipe:'+e['id']
            gid = 'crafted:'+e['id']
            mage = e['family']=='mage'
            affix = 'fortune' if mage else 'focus' if weapon else 'vigor'
            gear.append(dict(id=gid, existing_equipment_id=e['id'], name=e['base_name'],
                slot=e['slot'], family=e['family'], job_lock=e['job_lock'], tier=tier,
                rarity=1, required_level=e['required_level'], bonus=e['bonus'], upgrade=0,
                affix=affix, affix_unlock_upgrade=2, affix_stat_value=3+2*tier,
                runtime_status='existing_base_new_recipe_not_applied',
                art_policy='reuse_existing_equipment_asset', effect_policy='existing_equipment_formula_no_new_stats'))
            recipes.append(dict(id=rid, output_id=gid, output_amount=1, facility='smith',
                gold=50+40*tier+(30 if weapon else 0), success_chance=1,
                required_level=e['required_level'], unlock='available_at_smith_at_required_level',
                craft_seconds=0, binding='personal', refund='no_cost_on_validation_or_capacity_failure',
                runtime_status='not_applied'))
            quantities={ids[0]:8+2*tier if weapon else 4+tier, ids[1]:3+tier if weapon else 7+2*tier,
                        ids[2]:2+tier, ids[3]:1}
            if weapon or tier>=3: quantities[ids[4]]=1
            for lid, amount in quantities.items():ingredients.append(dict(recipe_id=rid,loot_id=lid,amount=amount))
    data=dict(metadata=dict(status='proposal_not_runtime', stat_rework='option_2_selected_runtime_pending',
        stat_policy_reference='docs/design/character_stats_v2/catalog.json',
        source_database_sha256=hashes[str(source.relative_to(ROOT))],
        policy='기존 전리품 유지. 신규 재료·드롭·제작법은 미적용 설계. 기존 장비 ID를 제작 대상으로 참조.',
        acquisition='층과 사건 유형으로 제한; 부활·훈련 적 제외; 공유 처치도 개인 수령은 권위 판정 대상만',
        transaction='재료·금화·레벨·착용 제한·가방 용량 검증 후 일괄 차감 및 새 장비 인스턴스 생성',
        notes=['강화 옵션은 기존 +2 개방 규칙 유지','제작 장비는 기존 레어 성능; 고등급 드롭 가치 유지',
               '모든 확률·수량·가격은 초기 설계값이며 실측 밸런스 확정값이 아님',
               '수집품 판매·교환 기능은 미정; 판매가 0, 연구 선행 요구 없음',
               '새 재료는 저장 허용 목록·가방·한글명·획득 이벤트 연동이 필요']),
        loot=loot, acquisition=sources, equipment=gear, recipes=recipes, ingredients=ingredients)
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    path=OUT/'catalog.sqlite'
    con=sqlite3.connect(path)
    con.executescript('PRAGMA foreign_keys=ON; DROP TABLE IF EXISTS ingredients; DROP TABLE IF EXISTS recipes; DROP TABLE IF EXISTS equipment; DROP TABLE IF EXISTS acquisition; DROP TABLE IF EXISTS loot; DROP TABLE IF EXISTS metadata; CREATE TABLE metadata(id TEXT PRIMARY KEY,data TEXT NOT NULL); CREATE TABLE loot(id TEXT PRIMARY KEY,data TEXT NOT NULL); CREATE TABLE acquisition(id TEXT PRIMARY KEY,loot_id TEXT REFERENCES loot(id),data TEXT NOT NULL); CREATE TABLE equipment(id TEXT PRIMARY KEY,data TEXT NOT NULL); CREATE TABLE recipes(id TEXT PRIMARY KEY,output_id TEXT REFERENCES equipment(id),data TEXT NOT NULL); CREATE TABLE ingredients(recipe_id TEXT REFERENCES recipes(id),loot_id TEXT REFERENCES loot(id),amount INTEGER CHECK(amount>0),PRIMARY KEY(recipe_id,loot_id));')
    enc=lambda x:json.dumps(x,ensure_ascii=False,sort_keys=True)
    con.execute('INSERT INTO metadata VALUES (?,?)',('design',enc(data['metadata'])))
    for table in ('loot','equipment'):
        con.executemany(f'INSERT INTO {table} VALUES (?,?)',[(v['id'],enc(v)) for v in data[table]])
    for table,key in [('acquisition','loot_id'),('recipes','output_id')]:
        con.executemany(f'INSERT INTO {table} VALUES (?,?,?)',[(v['id'],v[key],enc(v)) for v in data[table]])
    con.executemany('INSERT INTO ingredients VALUES (?,?,?)',[(v['recipe_id'],v['loot_id'],v['amount']) for v in ingredients]);con.commit()
    assert con.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    assert not con.execute('PRAGMA foreign_key_check').fetchall()
    assert len(loot)==60 and len(gear)==len(recipes)==500
    assert all(0<=v['chance']<=1 and v['amount_min']<=v['amount_max'] for v in sources)
    assert {v['loot_id'] for v in ingredients}=={v['id'] for v in loot if v['category']=='craft_material'}
    assert all(hashes[str(p.relative_to(ROOT))]==hashlib.sha256(p.read_bytes()).hexdigest() for p in protected)
    con.close()
    report=dict(status='passed',runtime_modified=False,counts={k:len(data[k]) for k in ('loot','acquisition','equipment','recipes','ingredients')},checks=['SQLite 무결성','외래 키','고유 ID','기존 장비 참조','확률 범위','모든 제작 재료 사용','정본 DB 및 캐시 변경 없음'])
    (OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['# 탐사 전리품·장비 제작 DB','', '**미적용 설계 DB**입니다. 사용자가 후속으로 스탯 개편 2안을 선택했습니다. `docs/design/character_stats_v2/catalog.json`의 이관 정책을 적용하며, 이 DB의 기존 장비 참조와 구 옵션은 이관 전 스냅샷입니다.', '', '전리품 60종, 획득 규칙 130개, 기존 장비 기반 제작 대상 500종, 제작법 500개를 수록합니다. 제작 대상은 10단계마다 직업 무기 20종과 5계열 × 6부위 30종입니다.', '', '## 지역별 전리품', '', '|층|지역|금속|섬유|촉매|문장|핵 재료|수집품|','|---|---|---|---|---|---|---|---|']
    for t,(_,label,names) in enumerate(regions):lines.append('|'+ '|'.join([f'{t*10+1}–{t*10+10}',label]+names)+'|')
    lines += ['', '## 제작·획득 규칙', '', '- 일반 적: 금속·섬유 각각 18%, 촉매 8%. 기존 드롭과 별도 개인 판정입니다.', '- 채집/상자 해체: 해당 지역 금속/섬유 2~4개. 정예: 촉매 확정, 문장 35%, 핵 12%.', '- 일반 수문장: 문장 확정, 핵 40%. 레이드: 핵 2~3개 확정. 같은 처치에 일반 수문장 보상을 중복 적용하지 않습니다.', '- 비밀방 수집품 20%, 레이드 수집품 15%. 위험 단계의 추가 드롭 배율은 이 신규 표에는 우선 적용하지 않습니다.', '- 제작은 대장간에서 레벨 조건과 재료·금화 충족 시 즉시 100% 성공합니다. 생산 대기열을 새로 도입하지 않습니다.', '- 레어 등급 +0 장비를 제작합니다. 기존 장비 이름·성능·직업 제한을 보존하고, 옵션은 기존 +2 강화에서 개방합니다.', '- 연구 해금은 필수로 추가하지 않습니다. 기존 시설 연구와 제작법 6종을 덮어쓰지 않습니다.', '- 재료는 개인 귀속·최대 99개, 판매가 0입니다. 가방 부족 시 소모 없이 실패해야 합니다.', '', '## 파일과 반영 상태', '', '- `catalog.json`: 이름, 출처, 확률, 수량, 장비 참조, 비용, 제작 조건을 담은 원본.', '- `catalog.sqlite`: 전리품·획득·장비·제작법·재료 관계를 외래 키로 연결한 조회용 DB.', '- `validation.json`: 정적 검증 결과. 실제 게임·경제 시뮬레이션 검증은 미실행.', '- `tools/author_exploration_crafting_db.py`: 이 설계 자료만 생성하는 작성기.', '- 정본 `docs/database` 및 게임 캐시는 수정하지 않았습니다. 저장/드롭/제작 UI 연동 후 메인에서 실제 반영 DB를 재생성해야 합니다.']
    (OUT/'README.ko.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__':main()
