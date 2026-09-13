"""Author proposal-only monster records; never modify runtime/generated management DB."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/design/monster_ecology'
DB = ROOT / 'docs/database/stelrpg-database.json'

# id | ecology | relationship | element | resistant | weak | trophy | attack1 | counter1 | attack2 | counter2
ROWS = '''shade|낙엽과 마력 찌꺼기를 분해해 숲에 돌려주는 청소 생물. 침입자가 몸속 씨앗을 밟으면 공격한다.|독침 벌이 떨어뜨린 꽃가루를 먹고 들쥐에게 몸속 씨앗을 빼앗긴다.|physical|poison|fire|응축된 초록 점액|점액 내려찍기|몸이 납작해진 뒤 옆으로 한 걸음|씨앗 튀기기|표시된 착탄 원에서 이탈
imp|버려진 야영지에서 도구를 주워 생활하는 숲 부족의 수색병.|고블린 궁수에게 먹이를 공급하고 대장의 북소리에 모인다.|physical|none|none|고블린 사냥 매듭|녹슨 칼 휘두르기|칼 든 팔 반대편으로 이동|돌멩이 견제|팔을 뒤로 젖히면 측면 이동
fairy|균사에 오염된 꽃가루를 옮기는 벌. 벌집 주변 마력에 과민하다.|슬라임과 공생하고 동굴 거미에게 포식당한다.|poison|poison|ice|검푸른 독침|독침 사격|날개 진동 후 고정된 사선을 벗어나기|꽃가루 낙하|작은 독 장판 바깥으로 이동
rat|지상에서 유입된 곡식과 씨앗으로 번식하는 소형 잡식동물.|황토 늑대의 먹이이며 슬라임의 씨앗을 훔친다.|physical|none|none|들쥐의 저장 주머니|두 번 물기|첫 타격을 피한 뒤 두 번째 타격까지 거리 유지|먹이 쟁탈 돌진|짧은 직선 예고의 측면으로 이동
fox|황토를 털에 문질러 냄새를 숨기는 매복 포식자.|들쥐와 약해진 멧돼지를 사냥하며 고블린 야영지와 먹이를 두고 경쟁한다.|physical|ice|fire|황토빛 송곳니|낮은 도약|몸을 낮춘 순간 고정된 도약점에서 이탈|측면 물어뜯기|우회 이동 후 턱을 벌리는 예고를 보고 회피
bat|광물성 이끼를 먹어 엄니가 돌처럼 굳은 멧돼지.|딱정벌레가 부순 광물을 섭취하고 늑대의 영역에 무리 지어 진입한다.|physical|physical|lightning|암석질 엄니|엄니 돌진|고정된 직선에서 옆으로 이동|지면 파헤치기|전방 부채꼴 대신 후방으로 이동
beetle|광맥을 갉아먹으며 버려진 광석을 흙으로 바꾸는 분해자.|멧돼지에게 광물 가루를 공급하지만 오크에게 껍질을 채집당한다.|physical|physical|lightning|광맥 갑각|갑각 내려찍기|주변 원형 예고에서 이탈|방어 자세|정면 피해 감소 동안 후방 공격
cave_bat|수정 동굴의 진동으로 먹이를 찾는 야행성 박쥐.|동굴 거미를 먹지만 거미줄에 걸린 개체는 역으로 포식당한다.|physical|dark|light|공명 날개막|초음파 부채|부채꼴 바깥 또는 뒤로 이동|저공 선회|고정된 착지 원을 벗어나기
spider|통로를 가로질러 거미줄을 설치하는 매복 포식자.|독침 벌과 박쥐를 포식하고 오크 폐기물 주변에 둥지를 튼다.|poison|poison|fire|마력 거미실|거미줄 투척|착탄점을 피해서 통로 확보|독니 급습|거미가 다리를 모으면 뒤로 이동
mole|옛 광부의 동굴을 점거한 오크 채굴꾼.|딱정벌레의 갑각을 연장으로 쓰고 도끼병에게 광석을 상납한다.|physical|physical|ice|거친 채굴 쇄기|곡괭이 찍기|좁은 전방 원을 피한 뒤 반격|광석 흩뿌리기|부채꼴 범위 바깥으로 이동
goblin_archer|약탈보다 매복을 선호하는 부족 사냥꾼.|수색병 뒤에서 사격하고 주술사의 보호를 받는다.|physical|none|none|뒤틀린 화살촉|조준 사격|흰 조준선이 고정되면 횡이동|후퇴 사격|후퇴 경로를 쫓기보다 화살을 먼저 회피
goblin_shaman|균사와 광물을 섞어 부족의 상처를 치료하는 의식 담당.|슬라임 분비물을 약으로 쓰며 대장을 우선 치료한다.|dark|dark|light|균사 의식 부적|치유 의식|빛나는 연결 대상보다 시전자를 우선 제압|저주 탄환|고정된 사선에서 이탈
goblin_captain|지하 부족의 식량과 통행세를 통제하는 대장.|수색병·궁수·주술사와 계층을 이루며 오크와 통로를 두고 싸운다.|physical|physical|ice|부족장의 뿔피리|연속 내려치기|두 번의 원형 예고를 모두 회피|집결 호령|호령 시전 중 경직으로 저지
orc_axeman|광맥을 지키는 오크 부족의 전투원.|채굴꾼을 보호하고 투사의 명령에 따라 통로를 봉쇄한다.|physical|physical|ice|이 빠진 전투 도끼날|도끼 횡베기|후방으로 이동|돌진 쪼개기|직선 예고 옆으로 이동 후 회복 틈 공격
orc_champion|싸움의 승자로 뽑힌 광산 부족의 투사.|도끼병의 우두머리이며 고블린 대장과 적대한다.|physical|physical|lightning|투사의 균열 완갑|회전 분쇄|고리 안쪽 안전지대 또는 바깥으로 이동|양손 처형|넓은 전방 부채꼴의 뒤로 이동
ember_slime|균사 발효열과 용암 마력으로 살아가는 열 분해자.|서리 슬라임과 경계에서 충돌하며 버려진 유기물을 태운다.|fire|fire|ice|미지근한 잿불핵|잿불 분출|첫 원형 예고를 회피|남은 불씨|반복 점멸 장판에 다시 들어가지 않기
frost_slime|물과 잔류 마력을 몸 안에서 얼리는 냉각 생물.|잿불 슬라임과 서식 경계가 나뉘며 동굴 박쥐의 식수원이 된다.|ice|ice|fire|녹지 않는 서리핵|얼음 파편|부채꼴 사선의 틈으로 이동|냉기 고리|고리 안쪽 또는 바깥으로 이탈
skeleton|침수 성채의 경비 명령이 뼈에 남아 움직이는 병사.|파수기사의 명령을 따르며 거미와 박쥐에는 반응하지 않는다.|physical|poison|light|낡은 수비대 인장|창 찌르기|직선 옆으로 이동|회수 찌르기|첫 공격 직후 전방으로 재진입하지 않기
clockwork|작업장을 지키던 태엽 장치가 오래된 출입 명령을 반복한다.|정찰 드론의 신호를 받고 백인대장의 지휘에 반응한다.|physical|poison|lightning|마모된 태엽축|기계 찌르기|직선 회피|반동 타격|첫 공격 뒤 근접 원형 공격까지 기다리기
spellbook|빛과 소리로 침입자를 기록하는 공중 정찰 장치.|태엽 경비병에 표적을 전달하지만 실제 추가 증원은 생성하지 않는다.|lightning|poison|ice|정찰용 수정 렌즈|삼중 광선|세 사선 사이로 이동|표적 점등|표식 후 고정되는 착탄 원에서 이동
centurion|지하 자동 방어망의 현장 지휘 장치.|드론·경비병을 조율하고 레이드 지휘관의 오래된 암호를 따른다.|lightning|physical|ice|백인대장의 제어판|십자 제압|대각선 안전지대로 이동|지휘 핵 폭발|십자 직후 나타나는 원형 예고에서 이탈
warden|뿌리와 균사의 흐름을 제어하는 고대 수호목의 기본형.|벌·슬라임의 서식지를 유지하지만 오염이 깊어지면 숙주를 흡수한다.|poison|poison|fire|수호목의 생장환|뿌리 내려찍기|전방 원형 예고에서 이탈|뿌리 파동|순차적으로 솟는 선 사이로 이동
golem|광물에 축적된 마력이 응집해 깨어난 지질 수호자의 기본형.|딱정벌레의 광물 순환과 연결되며 채굴을 침입으로 인식한다.|physical|physical|lightning|수호 골렘의 핵편|암석 주먹|전방 원형 예고 회피|공명 충격파|고리 안쪽 안전지대 활용
sentinel|성채·공장·심연의 명령을 수행하는 갑주 수호자의 기본형.|해골 병사와 자동 장치를 지휘하나 레이드 전장에 잡몹을 소환하지 않는다.|light|light|dark|빛바랜 지휘 인장|심판 직선베기|검의 직선 예고 옆으로 이동|수호의 고리|고리 중심 또는 범위 바깥으로 이동'''

# Floor | story | signature | counter | elemental damage | resist | weak
RAIDS = '''10|지상 생태를 지키려다 침입자와 주민을 구분하지 못하는 수호목.|뿌리 감옥|닫히는 뿌리선 사이 열린 통로로 이동|poison|poison|fire
20|끝없는 채굴에 깨어난 광산 자체의 심장.|광맥 공명|순서대로 점등하는 원형 균열을 차례로 회피|physical|physical|lightning
30|물에 잠긴 성채에서 마지막 경계 명령을 반복하는 기사.|침수 십자검|십자 사선 사이 대각선 구역으로 이동|ice|ice|lightning
40|지하 생물을 하나의 균사로 묶으려는 군체 의식.|포자 개화|개화 전 빈 원을 찾아 이동하고 독 구역 재진입 금지|poison|poison|fire
50|용광로를 지키며 주변 생물의 열을 흡수하는 거인.|용암 분출|연속 세 착탄 예고를 바깥쪽으로 유도|fire|fire|ice
60|침수층에서 스며든 물을 얼려 통로를 봉인한 수호자.|빙결 왕관|고리와 직선 공격의 예고 순서대로 이동|ice|ice|fire
70|멈춘 공장의 마지막 생산 명령을 전투 명령으로 바꾼 지휘관.|철의 포위망|점등하지 않은 사분면으로 이동|lightning|physical|ice
80|빛을 잃은 뿌리가 꿈과 기억을 먹고 자란 고목.|황혼의 그림자|진짜 공격은 밝은 테두리로 표시되며 흐린 잔상은 무판정|dark|dark|light
90|떨어진 별의 파편을 흡수해 중력이 뒤틀린 거상.|낙성 의식|표식 착탄을 가장자리로 유도한 뒤 중심 안전구역으로 복귀|dark|dark|light
100|생태 순환과 방어망을 자신의 의지로 묶으려는 심연의 왕.|왕의 종언|세 구역 중 순서대로 빛나는 안전구역을 따라 이동|light|light|dark'''

REGION_ECOLOGY = [
    '뿌리층: 점액이 낙엽을 분해하고 벌이 꽃가루를 운반한다. 들쥐의 씨앗 약탈에 고블린의 식량 수집이 겹친다.',
    '광맥층: 딱정벌레의 분해로 광석이 드러나고 오크가 채굴한다. 박쥐와 거미가 좁은 천장 생태를 나눠 갖는다.',
    '침수층: 물에 잠긴 성채의 시체와 폐기물이 작은 생물의 먹이가 된다. 해골과 기계는 생태와 무관하게 경계 명령을 반복한다.',
    '균사층: 포자가 생물을 감염시키며 분해 순환을 과도하게 가속한다. 잿불 생물은 균사를 태워 확산을 억제한다.',
    '용암층: 광물성 먹이와 열이 주 에너지원이다. 멧돼지와 딱정벌레의 내열 변종은 외형 변주이며 신규 종 ID를 만들지 않는다.',
    '빙결층: 서리 슬라임이 물을 저장하고 박쥐는 해빙 틈을 따라 움직인다. 적 수보다 통로와 안전지대 배치로 긴장감을 만든다.',
    '기계층: 태엽병·드론·백인대장이 폐쇄된 지휘망을 이룬다. 유기체가 드문 대신 오작동 장치와 마력 누출이 환경 역할을 한다.',
    '황혼층: 고목이 빛 대신 기억을 흡수한다. 기계의 감지광과 거미줄이 어둠 속에서 서로 다른 예고 신호가 된다.',
    '성운층: 별의 잔해가 기계와 광물 생물을 변화시킨다. 이동하는 천체 연출은 실제 공격 범위를 가리지 않는다.',
    '핵심층: 뿌리·광물·자동 방어망이 한 동력원에 연결된다. 마지막 보스의 단독 전장과 일반층의 혼합 생태를 구분한다.',
]


def main():
    raw = DB.read_bytes()
    db = json.loads(raw)
    source_hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                     for name in ['game/data/monsters-v05.json', 'game/data/drop_tables.json',
                                  'game/scripts/monster_attacks.gd', 'game/scripts/abyss_catalog.gd']}
    result = {
        'status': 'design_proposal_not_applied', 'version': 1,
        'baseline': {'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                     'database_sha256': hashlib.sha256(raw).hexdigest(), 'source_sha256': source_hashes},
        'rules': {
            'scope': '24 existing species and 10 existing raid encounters; no new spawns or runtime edits',
            'ecology_status': 'lore and encounter-design proposal; predator/prey simulation not implemented',
            'level_health_xp_gold': 'preserve actual appearances/raids values; base monster level=0 is not an encounter level',
            'damage': 'pattern multiplier times current encounter attack before existing defenses; a hit affects each target once',
            'elements': ['physical', 'fire', 'ice', 'lightning', 'poison', 'light', 'dark'],
            'resistance': 'proposal only: damage multiplied by 1-resistance; unspecified=0; not an additional defense layer yet',
            'normal_resistance': .20, 'normal_weakness': -.15, 'boss_resistance': .15, 'boss_weakness': -.10,
            'normal_cc': 'slow25%2s; no repeated hard stun; no mana drain substitution for stamina',
            'attack_tracking': 'lock target position at telegraph start; no homing during windup',
            'scheduling': 'one attack per enemy; cooldown starts after recovery; same pack max2 simultaneous damaging windups',
            'coop': 'retain host authority, private rewards and current party_rules scaling; no player-count damage increase',
            'boss_stagger': {'success_down_s': 6, 'immunity_after_down_s': 60, 'failed_check_recovery_s': 6,
                             'wall_collision': 'may call existing guarded break_boss; never bypass immune/down'},
            'drops': 'retain all current independent rolls and raid extra-equipment rolls; trophies are separately proposed',
            'trophy': 'one bound research/cosmetic material per eligible personal kill roll; no sale or power recipe in v1',
            'new_statuses': 'poison/bleed/debuff interactions need implementation; pattern names alone do not apply a status',
        }, 'monsters': [], 'raids': [], 'items': [], 'regions': []}
    by_id = {m['id']: m for m in db['monsters']}
    for line in ROWS.splitlines():
        mid, ecology, relation, element, resist, weak, trophy, p1, c1, p2, c2 = line.split('|')
        live = by_id[mid]
        role = live['role']; boss = role == 'boss'; elite = role == 'elite'
        a = [x for x in db['appearances'] if x['monster_id'] == mid]
        patterns = []
        for i, (name, counter) in enumerate([(p1, c1), (p2, c2)]):
            patterns.append({'id': f'{mid}:design:{i+1}', 'name': name,
                'trigger': 'target in existing attack range' if i == 0 else 'after two primary attacks',
                'telegraph_s': (1.2 if boss else .95 if elite else .65) + .15*i,
                'telegraph': 'high-contrast ground outline plus distinct body windup; outline must match hit shape',
                'shape': 'circle' if i == 0 else 'cone', 'radius_units': (3.0 if boss else 2.4 if elite else 1.5)+.5*i,
                'damage_multiplier_total': (1.4 if boss else 1.15 if elite else 1.0) if i == 0 else (.9 if not elite else 1.3),
                'hit_count': 1, 'recovery_s': 1.0 if boss or elite else .65,
                'cooldown_s': (7 if boss or elite else 4) + i*3, 'counter': counter,
                'interrupt': 'boss_rules_only' if boss else 'ordinary_stagger',
                'shape_note': 'Generic envelope; species overrides below are authoritative.'})
        # Match the authored tells and counterplay instead of generic envelopes.
        for pt in patterns:
            name = pt['name']
            if any(w in name for w in ['사격', '찌르기', '광선', '돌진', '직선', '파동']):
                pt.update(shape='line', length_units=6 if boss else 4, half_width_units=.45)
            elif any(w in name for w in ['고리', '회전']):
                pt.update(shape='ring', inner_radius_units=.9)
            elif any(w in name for w in ['부채', '흩뿌리기', '횡베기', '처형']):
                pt.update(shape='cone', angle_degrees=90)
            else: pt['shape']='circle'
            if name in ['방어 자세','치유 의식','집결 호령']:
                pt.update(shape='support',damage_multiplier_total=0,hit_count=0)
                pt['support_effect']={'방어 자세':'front damage -30% for 3s; rear unchanged',
                    '치유 의식':'heal one wounded same-pack ally 8% maxHP; exclude bosses; cooldown12s',
                    '집결 호령':'existing same-pack allies speed+15% for 4s; no reinforcements'}[name]
                if name=='치유 의식':pt['cooldown_s']=12
            if name in ['두 번 물기','연속 내려치기','삼중 광선']:
                pt['hit_count']=3 if name=='삼중 광선' else 2
                pt['hit_interval_s']=.35
                pt['damage_distribution']='total multiplier divided equally; overlapping rays hit target only once'
            if name=='남은 불씨':pt.update(shape='circle',hit_count=3,hit_interval_s=.5,damage_multiplier_total=.6)
            if name=='회전 분쇄':pt.update(radius_units=2.6,inner_radius_units=.85)
            if name=='십자 제압':pt.update(shape='cross',length_units=4,half_width_units=.3)
            if name in ['초음파 부채','얼음 파편']:pt.update(shape='cone',angle_degrees=70)
            if name in ['씨앗 튀기기','꽃가루 낙하','거미줄 투척','표적 점등','저주 탄환']:
                pt['placement']='target position captured at telegraph start'
            if name in ['꽃가루 낙하','거미줄 투척','냉기 고리']:
                pt['on_hit']='slow25% for2s; refresh duration only; no stacking'
            if name=='남은 불씨':pt['placement']='same location as preceding primary; no fresh target tracking'
            pt.pop('shape_note',None)
        item_id='trophy_'+mid
        resistance = {resist:(.15 if boss else .20)} if resist!='none' else {}
        if weak!='none':resistance[weak]=-.10 if boss else -.15
        result['items'].append({'id':item_id,'name':trophy,'status':'proposed_new_item', 'stack_max':99,
                               'bound':True,'sell_gold':0,'uses':['regional research collection','cosmetic crafting'],
                               'recipe_status':'not implemented; no combat power conversion in this proposal'})
        result['monsters'].append({'id':mid,'name':live['name'], 'status':'proposal',
            'applied_snapshot':{'base':live,'appearances':a,'drops':[x for x in db['drops'] if x['monster_id']==mid]},
            'proposed':{'ecology':ecology,'relationship':relation,'habitat_floors':live['floors'],
                'level_policy':'keep each applied appearance level','damage_element':element,'resistances':resistance,
                'behavior':'territorial; does not chase beyond current home limit; no new ambient combat rewards',
                'patterns':patterns,'sequence':[patterns[0]['id'],patterns[0]['id'],patterns[1]['id']],
                'trophy_drop':{'item_id':item_id,'chance':1 if boss or elite else .20,'amount':1,
                               'eligible':'non-training, credited kill; same reward eligibility as current loot'},
                'research_goal':{'kills':10 if boss else 15 if elite else 30,'reward':'reveal ecology and pattern hints; no stat bonus'},
                'implementation_notes':['existing runtime patterns remain until integrated','element resistance and trophies require explicit runtime/storage/catalog support']}})
    for line in RAIDS.splitlines():
        floor, story, name, counter, element, resist, weak = line.split('|'); floor=int(floor)
        live=next(x for x in db['raids'] if x['floor']==floor)
        result['raids'].append({'id':live['id'],'name':live['name'],'status':'proposal',
            'applied_snapshot':{'encounter':live,'drops':[x for x in db['raid_drops'] if x['raid_id']==live['id']]},
            'proposed':{'story':story,'level':live['level'],'adds':0,'damage_element':element,
                'resistances':{resist:.15,weak:-.10},'signature':{'name':name,'counter':counter,
                    'telegraph_s':1.6,'damage_multiplier_total':1.8,'hit_count':3 if floor in [20,50,100] else 1,
                    'recovery_s':2.0,'cooldown_s':18,'interrupt':'taunt_cancel_once_per30s_except_stagger_immune'},
                'phase_rules':[{'hp_above':.70,'sequence':['primary','secondary','primary','wall_charge']},
                               {'hp_above':.30,'sequence':['primary','signature','secondary','wall_charge']},
                               {'hp_above':0,'sequence':['signature','secondary','primary','wall_charge']}],
                'phase_transition':'queue at end of current action; never overlap or shorten telegraph; one action at a time',
                'wall_charge':{'telegraph_s':1.5,'damage_multiplier_total':1.2,'aim':'lock at telegraph start',
                               'wall_result':'existing stagger guard applies; during immune only visual impact and1s recovery'},
                'primary_secondary':'use the matching species proposal, with no new adds',
                'trophy_drop':'use species trophy once per personal boss kill; do not roll twice for raid and species',
                'unique_equipment':'retain current guaranteed extra equipment and grade/slot rules',
                'taunt_policy':'primary/secondary cancellable once per30s outside down/immune; wall_charge cannot be taunt-cancelled; cancellation adds no stun and never resets stagger immunity'}})
        signature=result['raids'][-1]['proposed']['signature']
        signature['geometry']={
            10:{'shape':'radial_lines','rays':5,'missing_sector_degrees':72,'length':8,'half_width':.45},
            20:{'shape':'circles','radius':2,'interval_s':.8,'placement':'three fixed target samples; separate telegraph for each'},
            30:{'shape':'cross','length':9,'half_width':.7},
            40:{'shape':'circles','count':5,'radius':1.8,'placement':'fixed arena marks; keep at least one3-unit safe lane'},
            50:{'shape':'circles','radius':2,'interval_s':1,'placement':'sample target once at each1.6s telegraph; never chase afterwards'},
            60:{'shape':'ring','outer_radius':6,'inner_radius':2,'followup':'visual line only in v1; no unbudgeted extra hit'},
            70:{'shape':'three_quadrants','radius':8,'safe_quadrants':1},
            80:{'shape':'cone','radius':7,'angle_degrees':100,'decoys':'zero damage; dashed muted outline'},
            90:{'shape':'circle','radius':3,'placement':'locked target point; center safe after impact; no forced movement'},
            100:{'shape':'arena_sectors','sectors':3,'safe_sectors_each_hit':1,'interval_s':1.8},
        }[floor]
        signature['damage_distribution']='total1.8 divided by hit_count; each target at most once per pulse even if shapes overlap'
        if floor==60:signature['counter']='고리 안쪽 또는 바깥으로 이동; 뒤따르는 선은 v1에서는 무판정 연출'
        signature['scheduler']='if cooldown not ready, use primary instead; phase change never resets cooldown'
    for idx, region in enumerate(db['metadata']['dungeon_region_rules']['regions']):
        floors=list(range(idx*10+1,idx*10+11))
        species=sorted({a['monster_id'] for a in db['appearances'] if a['floor_id'] in floors})
        result['regions'].append({'id':region['id'],'floors':floors,'existing_species':species,
            'ecology':REGION_ECOLOGY[idx],
            'rule':'biome variants share species ID; preserve actual appearances; raid floor contains boss only',
            'encounter_budget':'one support and one controller maximum per existing pack; rearrange roles without adding enemies',
            'rare_trophy_collection':{'required_each':5,'species':species,'reward':'regional codex seal cosmetic; proposal only'}})
    validate(result,db)
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'catalog.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    write_doc(result)
    evidence={'status':'PASS','scope':'design data validation only; no engine/playtest/runtime integration',
              'monsters':len(result['monsters']),'raids':len(result['raids']),'items':len(result['items']),
              'regions':len(result['regions']),'checks':['exact existing IDs','drop bounds','pattern timing','item references',
              'actual encounter snapshots','runtime source hashes unchanged'],
              'catalog_sha256':hashlib.sha256((OUT/'catalog.json').read_bytes()).hexdigest()}
    assert hashlib.sha256(DB.read_bytes()).hexdigest()==result['baseline']['database_sha256']
    assert all(hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==h for n,h in source_hashes.items())
    (OUT/'validation.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(evidence,ensure_ascii=True))


def validate(r,db):
    assert {x['id'] for x in r['monsters']}=={x['id'] for x in db['monsters']}
    assert len(r['monsters'])==24 and len(r['raids'])==10 and len(r['regions'])==10
    assert {x['id'] for x in r['raids']}=={x['id'] for x in db['raids']}
    item_ids={x['id'] for x in r['items']};assert len(item_ids)==24
    for x in r['monsters']:
        p=x['proposed'];drop=p['trophy_drop'];assert drop['item_id'] in item_ids and 0<=drop['chance']<=1
        assert all(-.5<=v<=.5 for v in p['resistances'].values())
        assert all(t['telegraph_s']>=.6 and t['cooldown_s']>0 and t['damage_multiplier_total']>=0 for t in p['patterns'])
        assert {a['floor_id'] for a in x['applied_snapshot']['appearances']}==set(p['habitat_floors'])


def write_doc(r):
    lines=['# 몬스터 생태·공격·드롭 설정안', '',
           '**상태: 작성된 설계안. 게임 적용·밸런스 실측 전.** 기존 24종과 레이드10개를 모두 다룬다.',
           '기존 내부 ID·출현 층·레벨·체력·경험치·금화·드롭은 catalog.json의 applied_snapshot에 보관했다. 새 규칙은 proposed에만 있다.',
           '기본형 level=0은 실제 적 레벨이 아니다. 출현별 appearances 또는 raid 레벨을 사용한다. 내부 bat는 멧돼지, fox는 늑대, fairy는 벌, spellbook은 드론이다.', '',
           '## 공통 규칙', '',
           '- 생태 관계는 세계관과 조우 설계이며 자동 포식·번식 시뮬레이션은 아직 없다.',
           '- 일반 약점은 받는 피해 +15%, 저항은 -20%; 보스는 약점 +10%, 저항 -15%. 미지정 속성은 0. 신규 속성 판정은 미구현 제안이다.',
           '- 피해 배율은 해당 층의 현재 공격력 기준이며 다단히트는 총합이다. 예고 시작에 조준을 고정하고 표시와 실제 판정을 일치시킨다.',
           '- 일반 공격 예고는 최소0.65초, 강한 기술은 더 길다. 한 무리에서 동시 피해 예고는 최대2개를 제안한다.',
           '- 6인 보정·개인 전리품은 현재 규칙을 유지한다. 보스는 성공 무력화6초 뒤60초 잠금, 실패 검사 회복6초를 유지한다.',
           '- 기존 장비·재료·물약 드롭은 유지한다. 고유재료24종은 신규 제안으로 일반20%, 정예/보스100%, 개인당1개. 훈련용 적은 제외한다.',
           '- 고유재료는 귀속·판매0G·중첩99, 연구/외형 수집용이다. 전투 능력치나 기존 재료 환전으로 경제를 증가시키지 않는다.',
           '- 지역 도감 인장은 해당 지역 종별 재료5개 수집을 조건으로 제안한다. 제작·수집 UI 및 저장 지원 전에는 획득시키지 않는다.', '',
           '## 24종 상세', '']
    for x in r['monsters']:
        p=x['proposed'];a=x['applied_snapshot']['appearances'];levels=sorted({z['level'] for z in a})
        lines += [f"### {x['name']} · `{x['id']}`",'',p['ecology'],p['relationship'],
                  f"- 현재 출현 층: {', '.join(map(str,p['habitat_floors'])) or '던전 출현 없음'}. 실제 레벨: {min(levels) if levels else '없음'}~{max(levels) if levels else '없음'}.",
                  f"- 제안 공격 속성: {p['damage_element']}. 제안 저항: {json.dumps(p['resistances'],ensure_ascii=False)}."]
        for t in p['patterns']:
            lines.append(f"- **{t['name']}**: {t['shape']}, 예고{t['telegraph_s']:.2f}초 / 총피해×{t['damage_multiplier_total']} / {t['hit_count']}타 / 후딜{t['recovery_s']}초 / 쿨타임{t['cooldown_s']}초. 대응: {t['counter']}.")
            if 'support_effect' in t:lines.append('  - 지원 효과 제안: '+t['support_effect'])
        item=next(i for i in r['items'] if i['id']==p['trophy_drop']['item_id'])
        lines += [f"- 신규 고유 드롭: **{item['name']}** 1개, 확률{p['trophy_drop']['chance']*100:g}%.",
                  '- 현재 드롭: '+ ' / '.join(f"{z['name']} {z['amount']}개 {z['chance']*100:g}%" for z in x['applied_snapshot']['drops']), '']
    lines += ['## 레이드별 설정','', '레이드층 잡몹0을 유지한다. 단계는 HP70%/30%에서 현재 행동 종료 후 전환하며 예고를 줄이지 않는다. 기본/보조는 종별 기술을 쓰고 네 번째 행동은 벽 충돌 유도 돌진이다.',
              '도발 취소는 기본·보조·고유기의 취소 가능한 시전에 한해30초당1회 제안. 무력화 down/immune에서는 불가. 돌진은 취소 불가이며 벽 충돌도60초 잠금을 우회하지 않는다.', '']
    for x in r['raids']:
        p=x['proposed'];t=p['signature'];lines += [f"### {x['name']} · {x['id']}",'',p['story'],
            f"- LV.{p['level']}. 고유기 **{t['name']}**: 예고1.6초, 총피해×1.8, {t['hit_count']}타, 후딜2초, 쿨타임18초.",
            '- 대응: '+t['counter'],f"- 속성 {p['damage_element']}, 저항 {json.dumps(p['resistances'],ensure_ascii=False)}.",
            '- 기존 확정 추가 장비 유지. 종별 고유재료는 보스 처치당1회만 지급하고 중복 추첨하지 않는다.','']
    lines += ['## 10개 지역의 생태 연결','']
    for region in r['regions']:
        lines += [f"### B{region['floors'][0]}~B{region['floors'][-1]} · {region['id']}",'',region['ecology'],
                  '- 실제 출현 종: '+', '.join(next(x['name'] for x in r['monsters'] if x['id']==mid) for mid in region['existing_species']),
                  '- 같은 무리에 지원형·제어형은 각각 최대1종을 제안한다. 기존 출현 수를 늘리지 않고 배치만 조정한다.','']
    lines += ['## 적용 전 필요한 작업','',
              '1. 공격 예고와 실제 도형·판정 구현. 모든 기술은 이동만으로 피할 수 있어야 하며 짧은 일반 예고를 대시 보유만으로 해결하지 않는다.',
              '2. 속성 피해·저항을 실제 전투 계산과 UI에 연결. 종별 감면을 현재 방어력에 중복 적용할지 확정하고 한 곳에서 계산한다.',
              '3. 고유재료24종의 item_definitions·개인 보상·저장·가방·연구 수집 지원. 기존 드롭을 수동 덮어쓰지 않는다.',
              '4. 같은 레벨/장비의1인·6인, 근접·원거리 조합으로 생존/처치시간/경험치·재료 수입을 비교. 현재 데이터 검증은 실전 밸런스 통과가 아니다.',
              '5. 구현 후 tools/build_database.py 단일 경로로 정본·SQLite·캐시 재생성. 현재 파일은 docs/design 설계자료이며 실행 DB로 로딩하지 않는다.', '',
              '기계 판독 원본: catalog.json. 작성기: tools/author_monster_ecology_design.py. 검증 기록: validation.json.']
    (OUT/'README.ko.md').write_text('\n'.join(lines)+'\n',encoding='utf8')


if __name__=='__main__':main()
