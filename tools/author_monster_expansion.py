"""Author normal-monster ecology and a sprite-team handoff, without runtime edits."""
import hashlib
import json
import sqlite3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/design/normal_monster_expansion'
ART=Path('D:/SSRPG/RPG2/art/MONSTER_DB_HANDOFF_20260913.json')


def main():
    source=ROOT/'docs/database/stelrpg-database.json'
    db=json.loads(source.read_text(encoding='utf-8'))
    art={v['asset_id']:v for v in json.loads(ART.read_text(encoding='utf-8'))['monsters']}
    loot=json.loads((ROOT/'docs/design/exploration_crafting/catalog.json').read_text(encoding='utf-8'))
    loot_ids={v['id'] for v in loot['loot']}
    protected=[source,ROOT/'docs/database/stelrpg.sqlite',ROOT/'game/data/codex-v053.bin']
    hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
    # id, name, trophic role, diet, microhabitat, attack, element, silhouette
    groups=[
      ('forest','동굴숲','천장 마력석의 빛으로 자라는 이끼·버섯·뿌리',[
        ('thorn_maw','가시턱 포식초','매복 포식자','씨앗을 먹으러 온 소동물','밝은 뿌리 가장자리','턱을 벌려 전방을 물고 뿌리를 거둠','physical','잎턱과 낮은 뿌리'),
        ('briar_stag','가시넝쿨 사슴','초식동물','연한 잎과 이끼','넓은 숲길','앞발로 땅을 긁은 뒤 짧은 직선 돌진','physical','가지뿔과 긴 다리'),
        ('forest_spore_millipede','낙엽등 노래기','분해자','썩은 잎과 버섯','쓰러진 나무 아래','몸을 둥글게 말았다가 옆으로 꼬리치기','physical','납작한 다절 몸과 낙엽 지붕'),
        ('forest_root_shrew','뿌리코 땃쥐','소형 포식자','노래기 유충과 뿌리 해충','뿌리 틈의 마른 흙','코를 들고 두 번 짧게 물기','physical','긴 주둥이와 둥근 귀')]),
      ('crystal','수정 광맥','광맥 주변의 광물 세균막과 미량 마력',[
        ('geode_pangolin','정동석 천산갑','광물 초식동물','세균막과 약한 광석','광맥 아래 완만한 길','비늘을 세운 뒤 몸통 밀치기','physical','정동석 비늘과 굵은 꼬리'),
        ('bone_serpent','백골 뱀','포식자','광맥 소동물의 잔류 마력','건조한 뼈무덤','몸을 S자로 접은 뒤 정면 물기','dark','분리된 뼈 마디가 이어진 뱀'),
        ('crystal_salt_mite','소금수정 진드기','광물 섭식자','벽면 염류와 세균막','흰 광석의 바닥 균열','수정 다리를 모은 뒤 짧게 뛰어찍기','physical','흰 결정 여섯 다리와 넓은 등'),
        ('crystal_echo_gecko','반향 도마뱀','소형 포식자','진드기와 작은 곤충','낮은 바위 선반','목주머니를 부풀린 뒤 좁은 음파 부채꼴','physical','큰 목주머니와 납작한 발')]),
      ('flood','잠긴 회랑','물에 잠긴 목재의 조류·균막·유기 퇴적물',[
        ('flood_rustclaw_crab','녹갑옷 집게게','청소동물','죽은 물고기와 침수 목재 생물','물가 보행 가능한 가장자리','큰 집게를 뒤로 당겨 전방 내려찍기','physical','녹슨 갑각과 비대칭 집게'),
        ('flood_bell_nautilus','종껍질 앵무조개','여과 섭식자','부유 유기물','수위가 낮은 회랑','촉수를 모았다가 전방 물줄기 발사','water','종 모양 껍질과 촉수'),
        ('flood_silt_skater','진흙발 소금쟁이','소형 포식자','물가 벌레','바닥에 얕게 고인 물','긴 앞다리를 든 뒤 일직선 찌르기','physical','가느다란 여섯 다리와 긴 몸'),
        ('flood_reed_eel','갈대수염 뱀장어','매복 포식자','소금쟁이와 작은 갑각류','갈대와 무너진 배수구','수염을 떨고 몸을 내밀어 한 번 물기','water','넓은 지느러미와 갈대 같은 수염')]),
      ('spore','포자 정원','따뜻한 습기와 사체를 분해하는 거대 균사',[
        ('spore_blade_cricket','칼턱 동굴귀뚜라미','균식동물','굳은 버섯과 균사','두꺼운 버섯 가장자리','뒷다리를 접고 짧은 도약 베기','physical','칼 같은 턱과 긴 뒷다리'),
        ('spore_lantern_moth','포자등 나방','수분 매개자','버섯 진액','발광 버섯 주변','배의 포자등을 밝힌 뒤 작은 포자탄','poison','둥근 날개와 빛나는 배'),
        ('spore_compost_slug','퇴비등 민달팽이','분해자','썩은 균사와 배설물','낮은 퇴비 더미','몸을 부풀린 뒤 느린 점액 한 덩이 발사','poison','버섯 찌꺼기를 얹은 둥근 연체'),
        ('spore_hook_mantis','갈고리 균사마귀','매복 포식자','나방과 귀뚜라미','키 큰 버섯 줄기 아래','갈고리 앞다리를 벌리고 한 번 교차 베기','physical','버섯 위장 등판과 긴 갈고리')]),
      ('lava','잿불 용암굴','열수 미생물과 식은 용암의 광물층',[
        ('lava_coal_salamander','석탄등 도롱뇽','포식자','열수 벌레','용암 밖 식은 돌길','목의 열빛을 켠 뒤 짧은 불숨','fire','석탄 등판과 붉은 목'),
        ('lava_vent_snail','분화구 달팽이','광물 섭식자','유황 세균막','식은 분기공 주변','껍질 분기공을 열고 앞쪽 증기 분사','fire','분화구 껍질과 낮은 발'),
        ('lava_ash_hopper','재도약 메뚜기','광물 섭식자','재에 묻힌 미생물막','검은 재 언덕','붉은 뒷다리를 접었다가 착지 찍기','physical','검은 껍질과 주황 관절'),
        ('lava_slag_mole','광재발 두더지','소형 포식자','메뚜기 유충과 작은 달팽이','채광 찌꺼기 바닥','앞발을 크게 들어 부채꼴 흙치기','physical','삽 같은 앞발과 짧은 주둥이')]),
      ('ice','빙하의 균열','얼음 밑 조류와 따뜻한 지열 틈의 이끼',[
        ('frost_penguin','서리 투척 펭귄','잡식동물','빙조류와 작은 벌레','미끄럽지 않은 얼음 가장자리','양 날개로 눈덩이를 모아 던지기','ice','짧은 날개와 둥근 흰 배'),
        ('rime_lynx','서리송곳니 스라소니','포식자','눈토끼와 약한 펭귄','낮은 얼음 언덕','귀를 눕히고 짧게 뛰어 발톱긋기','physical','귀끝 털과 넓은 발'),
        ('ice_moss_hare','빙이끼 눈토끼','초식동물','빙조류와 이끼','지열 틈 근처','귀를 세우고 뒷발로 한 번 차기','physical','푸른 귀끝과 이끼 꼬리'),
        ('ice_frost_louse','서리껍질 쥐며느리','분해자','동사한 작은 생물과 이끼 찌꺼기','눈 밑 바위틈','얼음 등판을 접고 짧은 구르기','ice','타원 얼음 마디와 짧은 다리')]),
      ('machine','버려진 기계도시','누출 동력·폐유·폐금속을 순환시키는 정비계',[
        ('machine_saw_wheel','톱니바퀴 추격자','폐품 절단기','폐금속을 잘라 재처리장에 공급','폐공장 넓은 길','톱날을 회전시키고 짧은 직선 돌진','physical','한 개 큰 톱니바퀴와 낮은 축'),
        ('machine_mortar_tripod','삼각포대 감시기','시설 방위체','잔존 동력망으로 충전','교차로 바깥쪽','포신을 세우고 지면 표식에 탄 한 발','fire','삼각 다리와 굵은 박격포'),
        ('machine_oil_tick','폐유 진드기','정비 분해기','바닥 폐유와 작은 쇳가루','파이프 누출부','흡입관을 빼고 짧은 전방 분사','physical','기름통 배와 집게 다리'),
        ('machine_copper_crow','동선까마귀','수거 운반기','진드기의 응축 금속과 전선 조각','낮은 잔해 위','날개를 접고 짧게 활강 찌르기','lightning','구리 날개와 집게 부리')]),
      ('twilight','황혼의 수림','희미한 마력광에 자라는 야행성 균류·수액',[
        ('moss_owlbear','이끼깃 올빼미곰','잡식 포식자','과실과 작은 숲 동물','굵은 고목 아래','상체를 들고 앞발 한 번 내려찍기','physical','이끼 깃털과 넓은 어깨'),
        ('grave_lantern','묘지 등불령','잔류 마력 포식자','수목이 흘린 잔류 마력','고목 뿌리의 오래된 묘지','등불이 작아졌다가 전방 마력 구체 방출','dark','떠 있는 등불과 찢어진 천'),
        ('twilight_sap_bat','밤수액 과일박쥐','수분 매개자','밤꽃 수액과 과실','낮은 가지 사이','날개를 접어 짧은 급강하 긁기','physical','넓은 귀와 자주빛 과즙 턱'),
        ('twilight_bark_isopod','고목껍질 공벌레','분해자','죽은 수피와 낙엽','썩은 나무 속','나무 등판을 웅크린 뒤 옆으로 밀치기','physical','거친 수피 공 모양 등판')]),
      ('nebula','성운의 공동','떠다니는 광물 먼지와 마력 결정을 먹는 생물막',[
        ('nebula_quartz_scorpion','석영꼬리 전갈','포식자','별가루 여과 생물','넓은 수정 바닥','석영 꼬리를 들고 전방 한 점 찌르기','physical','굽은 수정 꼬리와 넓은 집게'),
        ('nebula_comet_cuttlefish','혜성 갑오징어','포식자','작은 여과 생물','낮은 부유층','촉수를 모으고 직선 마력탄 발사','magic','혜성 꼬리막과 짧은 촉수'),
        ('nebula_dust_ray','별가루 가오리','여과 섭식자','마력 먼지와 결정 미생물','지면 가까운 부유층','날개를 말고 전방 먼지 부채꼴','magic','얇은 마름모 지느러미와 짧은 꼬리'),
        ('nebula_prism_worm','프리즘 관벌레','정착 분해자','가라앉은 광물성 유기물','갈라진 수정 바닥','관에서 몸을 내밀어 반짝이는 침 한 발','magic','작은 수정 관과 방사형 촉수')]),
      ('core','뒤틀린 마력핵','새는 마력·폐주문·수복 장치가 이루는 인공 생태계',[
        ('core_rune_leech','룬갑 거머리','마력 기생자','손상된 룬의 누출 마력','금이 간 룬 바닥','몸통 룬을 밝히고 짧은 전방 물기','magic','등에 룬갑이 붙은 굵은 연체'),
        ('core_bound_grimoire','봉인 파쇄마도서','폐주문 포식체','떠도는 주문 조각','무너진 서가 근처','책을 펼친 뒤 종이 칼날 한 발','magic','쇠사슬 책등과 날개 같은 책장'),
        ('core_seal_beetle','봉랍 딱정벌레','수복 분해체','거머리 잔해와 폐주문을 봉랍으로 전환','깨진 봉인 가장자리','봉랍 뿔을 낮추고 짧은 몸통 박치기','physical','붉은 봉랍 등과 납작한 뿔'),
        ('core_ink_hound','먹물 사냥개','방위 포식체','봉인을 갉는 마력 기생체','서가와 핵실 연결길','몸의 글자가 모인 뒤 짧은 도약 물기','dark','흐르는 먹물 몸과 흰 글자 갈비')]),
    ]
    monsters=[];appearances=[];drops=[];regions=[]
    predator_pairs={
        'forest':[(0,3),(3,2)],'crystal':[(1,3),(3,2)],'flood':[(3,2)],
        'spore':[(3,0),(3,1)],'lava':[(3,2),(3,1)],'ice':[(1,2),(1,0)],
        'machine':[],'twilight':[(0,2)],'nebula':[(0,2),(1,2)],'core':[(3,0)]}
    for tier,(region,label,energy,rows) in enumerate(groups):
        ids=[x[0] for x in rows];regions.append(dict(id=region,name=label,tier=tier,energy_source=energy,
            species=ids,spawn_policy='기존 일반 조우 수를 늘리지 않고 조우 후보를 대체; 한 무리 최대2종·원거리 최대1마리',
            population='지역 신규4종 합산 출현 가중치40%, 기존 일반종60%; 초기에는 신규종당10%',
            encounter_policy='포식자와 먹이종을 같은 무리에 동시에 배치하지 않음; 배경 생태 행동은 전투/보상 없음'))
        for index,(mid,name,role,diet,habitat,attack,element,silhouette) in enumerate(rows):
            existing=art.get(mid)
            assert mid not in {v['id'] for v in db['monsters']}
            small=index>=2; hp=.80 if small else 1.10; dmg=.80 if small else 1.0
            height=(64 if small else 100); collider=.28 if small else .4
            if existing:height=int(existing['recommended_display_height'])
            windup=.9 if index%2==0 else 1.1
            pattern=dict(id=mid+':primary',description=attack,shape='cone' if index%2==0 else 'circle',
                windup_seconds=windup,damage_multiplier=1.0,cooldown_seconds=3.5 if small else 4.5,
                recovery_seconds=.65,range_tiles=1.5 if index%2==0 else 3.0,tracking='windup_start_lock',
                dodge='예고 방향 옆으로 이동; 후딜 동안 반격',hit_rule='1회 시전당 대상별 1회, 지형 시선 검사',
                status=None,animation_authority='스프라이트 프레임 수가 피해·시전 시간을 결정하지 않음')
            # Keep explicit visual attack shape aligned to its prose.
            if any(v in attack for v in ['발사','한 발','던지기','포자탄']):pattern.update(shape='projectile',range_tiles=5.0,projectile_speed_tiles=4.0)
            elif any(v in attack for v in ['돌진','구르기','활강','도약','급강하']):pattern.update(shape='short_dash',range_tiles=2.5)
            elif '두 번' in attack:pattern.update(shape='two_bites',damage_multiplier=.5,hit_rule='시전당 최대2타, 타격 간격0.25초, 총계수1.0')
            weaknesses={'fire':'ice','ice':'fire','water':'lightning','lightning':'physical','poison':'fire','dark':'magic','magic':'physical','physical':'magic'}
            resist={element:10} if element!='physical' else {}
            mon=dict(id=mid,name=name,classification='normal',boss=False,tier=tier,region=region,
                runtime_status='not_registered_proposal',ecology=dict(role=role,diet=diet,microhabitat=habitat,
                    behavior='평상시 섭식·수거 행동, 접근 또는 유효 소음 감지 시 전투; 추적은 기존 귀환 규칙',
                    prey_ids=[ids[b] for a,b in predator_pairs[region] if a==index],
                    predator_ids=[ids[a] for a,b in predator_pairs[region] if b==index]),
                size=dict(display_height_px=height,world_height_m_proposal=round(height/80,2),
                    collision_radius_tiles=collider,hit_radius_tiles=collider+.1,
                    definition='표시 높이는 기존 카메라 기준; 미터는 설정용이며 충돌/실제 투영과 별개'),
                combat=dict(hp_factor=hp,damage_factor=dmg,speed_factor=1.05 if small else .9,
                    xp_factor=hp,gold_factor=hp,damage_element=element,resistance_percent=resist,
                    weakness_percent={weaknesses[element]:10},resistance_status='proposal_requires_element_pipeline',
                    stagger='일반 적 기준; 보스 무력화·페이즈 없음',pattern=pattern),
                sprite=dict(status='reuse_existing_art_review' if existing else 'new_requested',
                    existing_asset_id=mid if existing else None,existing_catalog=existing['catalog_path'] if existing else None,
                    existing_sheet=existing['sheet'] if existing else None,silhouette=silhouette,
                    phases=['idle','windup','impact','recover'],new_unique_poses=0 if existing else 4,
                    motion_brief=attack,foot_anchor='모든 포즈의 발 기준점 고정, 좌우 반전 시 기준점 유지',
                    facing='기존 팩과 동일한 화면 왼쪽 공격; 좌우 반전 가능',
                    format='원본 RGBA PNG·투명 배경·원본 SHA256·셀 영역·foot/body bounds·권장 높이·포즈 이름·manifest',
                    reuse_policy='기존4포즈가 패턴과 맞으면 재사용; 불일치 포즈만 별도 목록으로 보고'),
                spawn=dict(group_size=[1,2] if index<2 else [2,3],floor_min=tier*10+1,floor_max=tier*10+9,
                    raid=False,weight_within_new_species=.25,first_chapter_rule='초반3층 투사체/독 피해형을 같은 조우에 섞지 않음'))
            monsters.append(mon)
            for floor in range(tier*10+1,tier*10+10):
                baselines=[v for v in db['appearances'] if int(v['floor_id'])==floor and v['role']=='normal']
                assert baselines
                base=sorted(baselines,key=lambda v:(v['health'],v['id']))[len(baselines)//2]
                appearances.append(dict(id=f'appearance:{floor:03}:{mid}:normal',monster_id=mid,floor=floor,
                    baseline_appearance_id=base['id'],level=base['level'],health=max(1,round(base['health']*hp)),
                    damage=max(1,round(base['damage']*dmg)),speed=round(base['speed']*mon['combat']['speed_factor'],3),
                    xp=max(1,round(base['xp']*hp)),gold=max(1,round(base['gold']*hp)),status='proposed_scaled_snapshot'))
            for item,chance,amount in [(f'loot:{region}:fiber' if index%2==0 else f'loot:{region}:metal',.22,1),
                    (f'loot:{region}:catalyst',.08,1),('seed' if index%2==0 else 'ore',.12,1)]:
                assert item in loot_ids or item in {'seed','ore'}
                drops.append(dict(id=f'drop:{mid}:{item}',monster_id=mid,item_id=item,chance=chance,amount=amount,
                    mode='independent',scope='eligible_personal',risk_bonus=False,
                    note='종 전용 완전 목록; 범용 신규 재료 표와 중복 판정 금지'))
    meta=dict(status='design_and_sprite_request_not_runtime',source_hashes=hashes,
        roster=dict(existing_runtime_species=len(db['monsters']),additional_normals=40,reuse_art=20,new_art=20,new_unique_poses=80),
        baseline='같은 층 일반 출현 행의 HP 중앙값에 해당하는 실제 행을 기준으로 수치 산출',
        drop_policy='위3개 재료 표와 명시 gold/xp만 적용 제안; 장비 드롭은 기존 별도 정책 유지 대상으로 메인 결정 필요',
        boundaries='기존24종·보스 모션 추가 팩·스탯/강화 설계를 변경하지 않음; 신규 개체 수를 기존 밀도 위에 추가하지 않음',
        element_policy='저항·약점은 세계관 및 설계 수치; 런타임 속성 파이프라인 검증 전 적용 표시 금지')
    size_path=OUT/'size_assignments.json'
    if size_path.exists():
        assignments={v['monster_id']:v for v in json.loads(size_path.read_text(encoding='utf-8'))['assignments']}
        for v in monsters:
            a=assignments[v['id']]
            v['size'].update(size_class=a['size_class'],display_ratio=a['ratio'],display_height_status='legacy_reference_only',world_height_status='legacy_lore_reference_only')
            v['sprite']['size_policy']='size_class/display_ratio 우선; 이전 display_height_px는 참고값'
        meta['size_policy_reference']='docs/design/normal_monster_expansion/size_assignments.json'
    data=dict(metadata=meta,regions=regions,monsters=monsters,appearances=appearances,drops=drops)
    OUT.mkdir(parents=True,exist_ok=True);enc=lambda v:json.dumps(v,ensure_ascii=False,indent=2)
    (OUT/'catalog.json').write_text(enc(data)+'\n',encoding='utf-8')
    con=sqlite3.connect(OUT/'catalog.sqlite');con.executescript('PRAGMA foreign_keys=ON; DROP TABLE IF EXISTS drops; DROP TABLE IF EXISTS appearances; DROP TABLE IF EXISTS monsters; CREATE TABLE monsters(id TEXT PRIMARY KEY,data TEXT NOT NULL); CREATE TABLE appearances(id TEXT PRIMARY KEY,monster_id TEXT REFERENCES monsters(id),data TEXT NOT NULL); CREATE TABLE drops(id TEXT PRIMARY KEY,monster_id TEXT REFERENCES monsters(id),data TEXT NOT NULL);')
    con.executemany('INSERT INTO monsters VALUES (?,?)',[(v['id'],enc(v)) for v in monsters])
    for t in ['appearances','drops']:con.executemany(f'INSERT INTO {t} VALUES (?,?,?)',[(v['id'],v['monster_id'],enc(v)) for v in data[t]])
    con.commit();assert con.execute('PRAGMA integrity_check').fetchone()[0]=='ok';assert not con.execute('PRAGMA foreign_key_check').fetchall();con.close()
    assert len(monsters)==40 and len(appearances)==360 and len(drops)==120
    assert sum(v['sprite']['new_unique_poses'] for v in monsters)==80
    assert all(not art[v['id']]['boss'] for v in monsters if v['id'] in art)
    assert all(hashes[str(p.relative_to(ROOT))]==hashlib.sha256(p.read_bytes()).hexdigest() for p in protected)
    report=dict(status='passed',monsters=40,new_art_species=20,reuse_art_species=20,appearances=360,drop_rows=120,
        checks=['고유ID','기존종 ID 충돌 없음','층별 실제 기준행','일반종만 포함','재료 참조','SQLite 무결성·외래 키','정본 미변경'],runtime_tested=False)
    (OUT/'validation.json').write_text(enc(report)+'\n',encoding='utf-8')
    handoff=dict(status='request_ready',scope='일반 몬스터 20종 신규 제작·20종 기존 포즈 적합성 검토',
        priority='동굴숲·수정광맥 신규4종 먼저, 나머지 지역 순서',
        delivery='게임 폴더 직접 덮어쓰기 금지; 별도 팩과 catalog/manifest/SHA256로 DB 관리·메인에 전달',
        excludes='보스 모션 기존 요청과 합치지 않음; 신규종20종80포즈만 기본 제작량',
        monsters=[dict(id=v['id'],name=v['name'],ecology=v['ecology'],size=v['size'],sprite=v['sprite'],pattern=v['combat']['pattern']) for v in monsters])
    (OUT/'SPRITE_HANDOFF.json').write_text(enc(handoff)+'\n',encoding='utf-8')
    lines=['# 일반 몬스터 생태계 확장', '', '**설계·제작 요청 DB이며 실제 게임 미반영입니다.** 기존 일반/보스 24종은 유지하고, 일반 몬스터 후보40종(기존 아트20·신규20)을 추가합니다.', '', '10지역의 먹이 공급→섭식/분해→포식 관계를 구성합니다. 기계도시는 동력·폐유·금속을 순환하는 정비계, 마력핵은 폐주문·봉인 수복을 순환하는 인공 생태계입니다.', '', '|지역|생산 기반|추가 일반 몬스터|','|---|---|---|']
    for region in regions:lines.append('|'+region['name']+'|'+region['energy_source']+'|'+', '.join(v['name'] for v in monsters if v['region']==region['id'])+'|')
    lines+=['','## 개체별 명세','']
    for v in monsters:
        first=next(x for x in appearances if x['monster_id']==v['id']);drop=[x for x in drops if x['monster_id']==v['id']]
        lines += [f"### {v['name']} · {v['id']}",'',f"- {v['ecology']['role']}. 먹이: {v['ecology']['diet']}. 서식: {v['ecology']['microhabitat']}.",f"- 출현 {v['spawn']['floor_min']}~{v['spawn']['floor_max']}층(레이드 제외). 첫 층 LV{first['level']} / HP {first['health']} / 피해 {first['damage']} / 속도 {first['speed']} / 경험치 {first['xp']} / 금화 {first['gold']}. 나머지 층은 appearances에 개별 수록.",f"- 크기: 표시 높이 {v['size']['display_height_px']}px, 충돌 반경 {v['size']['collision_radius_tiles']}칸. 외형: {v['sprite']['silhouette']}.",f"- 공격: {v['combat']['pattern']['description']}. 예고 {v['combat']['pattern']['windup_seconds']}초 / 후딜0.65초. 피해 속성 {v['combat']['damage_element']}; 저항 {v['combat']['resistance_percent']}, 약점 {v['combat']['weakness_percent']} (미적용 제안).",'- 드롭: '+', '.join(f"{x['item_id']} {x['chance']*100:g}% ×{x['amount']}" for x in drop)+'.',f"- 제작: {'기존4포즈 적합성 검토' if v['sprite']['existing_asset_id'] else '신규4포즈 요청'}.",'']
    lines+=['## 제작과 적용 경계','','- 최신 크기 배정은 SIZE_ASSIGNMENTS.ko.md 및 size_assignments.json을 따릅니다. 위 개체별 px/미터는 이전 참고값입니다.','- 신규20종×대기/예고/타격/회복4포즈=80포즈. 기존20종은 접수한 아트와 프레임 적합성을 먼저 확인합니다.','- 크기는 표시 높이와 충돌 반경을 별도로 관리하며 실루엣 때문에 충돌을 확대하지 않습니다.','- 생성 수·밀도는 유지하고 후보를 교체합니다. 포식자와 먹이종은 같은 전투 무리로 묶지 않습니다.','- 독/냉기 등 지속 피해나 강제 제어는 이번 일반 공격에 추가하지 않았습니다. 속성 수치는 파이프라인 적용 전 설계값입니다.','- 새 전리품은 exploration_crafting의 미적용 설계 ID를 참조합니다. 저장/가방/드롭/제작 연동은 메인 구현이 필요합니다.','- 확률은 개인별 독립 판정이며 동일 범용 재료 표와 중복 적용하지 않습니다. 이번 수치는 플레이 실측 이전 초기안입니다.']
    (OUT/'README.ko.md').write_text('\n'.join(lines)+'\n',encoding='utf-8');print(enc(report))


if __name__=='__main__':main()
