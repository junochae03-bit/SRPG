"""직업별 명칭 원고를 이름 전용 카탈로그로 편집한다. 실행 수치는 수정하지 않는다."""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIVE = {'tank': '수호의 도약|은빛 가호|방패 돌진|수호 서약|철벽 방진|성벽 전개|충격 흡수|불락성채|방패 강타|진군 분쇄|수호자의 포효|대지 균열',
 'swordsman': '검심 점화|일섬|결투의 낙인|종명참|쾌검 호흡|삼연참|검풍 추격|난화검무|심안|검심불퇴|급소 찌르기|무아지경',
 'runesword': '가속 각인|룬 인챈트|룬 해방|아르카나|폭렬 각인|빙결 문장|칠성검진|각인 붕괴|허공 전이|룬 결계|정화 각인|인력 문장',
 'summoner': '검령 소환|마탄 정령 소환|수호 정령 소환|거수 소환|맹공의 계약|질풍의 계약|생명 공유|계약 해방|집중 공격|계약자 귀환|정령 공명|생명 공물',
 'elementalist': '이그니스|화염 장막|홍련낙성|잔화 폭발|빙화개벽|빙벽|백야폭설|빙화 파쇄|연쇄 전격|도너카일|술식 가속|삼원겁화',
 'healer': '치유의 손길|생명의 기도|치유의 물결|룩스 아에테르나|용맹의 축복|질풍의 축복|혜안의 축복|승전 성가|정화의 종|여명의 가호|구원의 기도|빛의 심판',
 'sniper': '관통 사격|집중 연사|침묵의 시위|산개 사격|심장 조준|파갑 사격|족쇄 화살|종결 사격|이탈 사격|저격 진지|순간 장전|접근 금지선',
 'hunter': '톱날 볼트|추격 연사|갈고리 상흔|혈흔 추살|혈화 덫|발목 올가미|사냥감 유인|가시 사냥터|송곳니 돌격|몰이의 호각|야성의 호각|회수의 호각',
 'explorer': '덩굴 채찍|회전 채찍|강타 채찍|갈고리 견인|포박 투척|발목 걸기|그물 포박|진동 채찍|절벽 도약|선회 채찍|후방 도약|낙하 채찍',
 'thief': '섬영 각인|순영 습격|그림자 귀환|연속 잠영|오금 베기|갑옷 틈새|약점 각인|무장 교란|혈영 절개|암막|장물 분배|은밀한 거래',
 'reaper': '명부의 사슬|쇄혼 추격|사슬 견인|철쇄 감옥|단혼참|흑월참|낙혼 집행|절명참|흑월보|사슬 장막|사형 선고|타나토스',
 'gambler': '히트|히든 카드|패 바꾸기|스탠드|승부수|카드 부채|헤비 베팅|포르투나|운명의 주사위|리롤|페이크 딜|행운의 판세',
 'infighter': '연환권|파고들기|승천권|백련난타|위빙 잽|정면 돌파|일보 반격|사각 연타|몰아침|가드 브레이크|투혼|무휴연격',
 'breaker': '붕산장|진각|회천각|파천일격|유수 패링|낮은 팔꿈치|철문 무릎|역린|철산고|금강불괴|운기조식|파천지세',
 'martialist': '쇄도각|추풍각|질풍이단각|비상각|쌍룡회축|천개각|선풍회축|낙성각|반보후축|부동심|용권종식|무극연무',
 'rogue': '그림자 베기|측면 회피|붉은 절개|연막 기습',
 'fighter': '정권|진입권|올려치기|맞받아치기'}
BASE_ACTIVE = {'blade_wave': '검기 파동',
 'rush': '돌격참',
 'whirlwind': '선풍참',
 'warrior_barrier': '강철의 맹세',
 'warrior_burst': '지평참',
 'warrior_chain': '연환참',
 'warrior_fan': '삼방 검기',
 'warrior_field': '검기진',
 'warrior_haste': '진군의 함성',
 'warrior_heal': '재기의 맹세',
 'warrior_nova_ring': '회전 검기',
 'warrior_pull': '흡인검진',
 'arrow_rain': '화살비',
 'piercing_shot': '관통 화살',
 'retreat_shot': '후퇴 사격',
 'ranger_barrier': '숲의 엄호',
 'ranger_burst': '폭발 화살',
 'ranger_chain': '도탄 사격',
 'ranger_fan': '산개 화살',
 'ranger_field': '가시 울타리',
 'ranger_haste': '추풍의 집중',
 'ranger_heal': '응급처치',
 'ranger_nova_ring': '원형 사격',
 'ranger_pull': '바람 올가미',
 'blink': '공간 도약',
 'frost_nova': '빙결 파동',
 'thunder': '낙뢰',
 'mage_barrier': '수정 결계',
 'mage_burst': '운석 낙하',
 'mage_chain': '연쇄 번개',
 'mage_fan': '삼중 마탄',
 'mage_field': '눈보라',
 'mage_haste': '시간 가속',
 'mage_heal': '생명 회복',
 'mage_nova_ring': '마력 고리',
 'mage_pull': '중력 소용돌이'}
SIGNATURES = dict(zip(
"warrior ranger mage rogue fighter tank swordsman runesword summoner elementalist healer sniper hunter explorer thief reaper gambler infighter breaker martialist".split(),
"검로 녹음 별빛 그림자 정권 은벽 검심 각인 계약 삼원 여명 일점 사냥 매듭 섬표 철쇄 승부 몰아침 축기 연무".split()))
CLUSTERS = {'warrior': '잔영검|일점집중|축지검|검기 방출|수호 반격',
 'tank': '방패 잔향|일점 수호|선봉 돌파|방패 충격파|수호의 응수',
 'swordsman': '잔광검|일검집중|찰나검|검선 확장|검심 반격',
 'runesword': '이중 각인|룬 응축|전이 가속|룬 파동|방호 공명',
 'ranger': '메아리 화살|일점 조준|이탈 반격|연쇄 화살|지연 폭발',
 'sniper': '잔향 사격|집중 조준|이탈 조준|연쇄 사격|지연 화살촉',
 'hunter': '추격의 메아리|집중 추적|이탈의 호각|연쇄 추격|잠복 폭발',
 'explorer': '채찍 잔향|일점 포박|선회 반격|연쇄 채찍|시간차 덫',
 'mage': '마력 잔향|마력 응축|전이 탄력|이그니스 잔화|술식 폭발',
 'summoner': '계약의 잔향|집중 계약|귀환 가속|잔화의 계약|계약 문장',
 'elementalist': '원소 잔향|술식 응축|원소 전이|홍련잔화|삼원 마법진',
 'healer': '기도의 잔향|집중 기도|구원의 발걸음|정화의 잔화|성역 문장',
 'rogue': '잔영격|급소 집중|회피 반격|교차 상흔|맹독 회수',
 'thief': '섬영 잔흔|급소 포착|잠영 가속|교차 각인|맹독 장물',
 'reaper': '철쇄 잔향|단독 집행|흑월 반격|교차 선고|독혈 추심',
 'gambler': '메아리 패|단독 승부|회피 배당|교차 승부패|독 묻은 판돈',
 'fighter': '권격 잔향|일점 타격|회피 반격권|연환 타격|축기 강타',
 'infighter': '잔상권|일점 압박|위빙 반격|추격 난타|응축 강타',
 'breaker': '장타 잔향|일점 축기|유수 반격|추격 삼련격|압축 진각',
 'martialist': '잔영각|일점 중심|반보 가속|추풍 연무|절초'}
EFFECT_WORDS = {'skill_damage': '위력',
 'skill_range': '사거리',
 'skill_radius': '범위',
 'skill_haste': '재사용',
 'skill_discount': '절약',
 'skill_duration': '지속',
 'move_speed': '이동',
 'attack_speed': '속공',
 'stagger_power': '무력화',
 'support_power': '가호',
 'followup_damage': '추격',
 'stagger_followup': '붕괴',
 'execute_damage': '처형',
 'efficiency_followup': '효율',
 'mobility_refund': '회수',
 'slow_on_followup': '감속',
 'support_followup': '지원 타격',
 'guard_on_followup': '방호',
 'control_damage': '제압',
 'heal_on_followup': '회복'}
WEAPON_TYPES = {'warrior': '장검',
 'tank': '수호검',
 'swordsman': '검',
 'runesword': '룬검',
 'ranger': '사냥활',
 'sniper': '저격궁',
 'hunter': '석궁',
 'explorer': '채찍',
 'mage': '지팡이',
 'summoner': '소환의 홀',
 'elementalist': '원소의 홀',
 'healer': '성물',
 'rogue': '단검',
 'thief': '쌍단검',
 'reaper': '사슬낫',
 'gambler': '카드덱',
 'fighter': '너클',
 'infighter': '권투갑',
 'breaker': '파쇄권갑',
 'martialist': '무투권갑'}
TIER_WORDS = ['숲지기', '수정', '침수 성채', '포자 정원', '흑요철', '영구빙', '황동', '황혼', '성운', '심연']
WEAPON_TITLES = {'warrior': ['네메시스 장검', '천단검'],
 'tank': ['아이기스 수호검', '불락성채의 검'],
 'swordsman': ['월영검', '공명절천검'],
 'runesword': ['아르카나 룬검', '허공각인검'],
 'ranger': ['아르테미스 사냥활', '천궁 아스테르'],
 'sniper': ['아폴론 저격궁', '도너카일 저격궁'],
 'hunter': ['흑랑 석궁', '혈월추살 석궁'],
 'explorer': ['미궁의 채찍', '공간쇄박 채찍'],
 'mage': ['아이테르 지팡이', '무극천성의 지팡이'],
 'summoner': ['계약의 홀 에코', '만령계약의 홀'],
 'elementalist': ['이그니스 원소홀', '삼원개벽의 홀'],
 'healer': ['룩스 아에테르나 성물', '여명불멸 성물'],
 'rogue': ['닉스 단검', '무영절명 단검'],
 'thief': ['움브라 쌍단검', '천영무흔 쌍단검'],
 'reaper': ['타나토스 사슬낫', '명부단죄의 낫'],
 'gambler': ['포르투나 카드덱', '운명찬탈의 패'],
 'fighter': ['슈투름 너클', '천붕권갑'],
 'infighter': ['블리츠 글러브', '백련무극 권투갑'],
 'breaker': ['도너카일 권갑', '절천붕산 권갑'],
 'martialist': ['무극 권갑', '진천무신 권갑']}
ARMOR = {'warrior': ['투구', '흉갑', '철장갑', '각반', '철장화', '호신 부적'],
 'ranger': ['깃모자', '사냥 조끼', '궁수 장갑', '사냥 바지', '추적 장화', '매깃 브로치'],
 'mage': ['마법관', '예복', '마법사 장갑', '마법사 바지', '룬 구두', '수정 목걸이'],
 'rogue': ['두건', '잠행복', '도적 장갑', '잠행 바지', '잠행화', '그늘 반지'],
 'fighter': ['머리띠', '수련복', '손등 보호대', '수련 바지', '수련화', '수련 옥패']}

def main():
    db=json.loads((ROOT/'docs/database/stelrpg-database.json').read_text('utf-8'))
    names=dict(BASE_ACTIVE)
    for cls,text in ACTIVE.items():
        for i,name in enumerate(text.split('|'),1):names[f'{cls}_a{i:02}']=name
    for skill in db['skills']:
        if skill['effect']=='active':assert skill['id'] in names,skill['id']
        elif skill['effect']=='upgrade':names[skill['id']]=names[skill['target']]+' · 숙련'
        else:
            prefix=SIGNATURES[skill['class_id']]+' · '
            names[skill['id']]=prefix+skill['name'].split(' · ')[-1]
    clusters={cls:text.split('|') for cls,text in CLUSTERS.items()}
    for node in db['constellations']:
        theme=clusters[node['class_id']][node['cluster']]
        names[node['id']]=theme if node['type']=='keystone' else theme+' · '+EFFECT_WORDS[next(iter(node['effects']))]
    equipment={}
    for cls,kind in WEAPON_TYPES.items():
        for tier in range(10):equipment[f'weapon:{cls}:{tier}']=TIER_WORDS[tier]+' '+kind if tier<8 else WEAPON_TITLES[cls][tier-8]
    for family,types in ARMOR.items():
        for slot,kind in zip(['head','chest','hands','legs','feet','accessory'],types):
            for tier in range(10):equipment[f'{slot}:{family}:{tier}']=TIER_WORDS[tier]+' '+kind
    result={'version':2,'monsters':{'lava_ash_hopper': '잿빛 메뚜기', 'machine_copper_crow': '구리깃 까마귀', 'core_bound_grimoire': '봉인파쇄 마도서', 'flood_rustclaw_crab': '녹갑 집게게', 'spore_compost_slug': '부식토 민달팽이', 'machine_mortar_tripod': '삼각포대 감시기'},'note':'표시명 전용. 기존 ID·효과·수치·조건을 유지합니다.','skills':names,'clusters':clusters,'equipment':equipment}
    assert len(names)==1510 and len(equipment)==500
    for collection in [names,equipment]:
        assert all(0<len(v)<=28 for v in collection.values())
        duplicates=[name for name,count in Counter(collection.values()).items() if count>1]
        assert not duplicates, "Duplicate display names: "+repr(duplicates)
    out=ROOT/'game/data/content_names.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n','utf-8')
    report=['# 직업별 스킬·장비 명칭표','', '원기술610개·별자리900개·장비 기본500조합의 이름입니다. 등급별2500개 장비는 기본 이름과 등급 표시를 함께 사용합니다.','']
    for cls in db['classes']:
        report += ['## '+cls['name']+' ('+cls['id']+')','','| ID | 이전 이름 | 새 이름 |','|---|---|---|']
        for s in db['skills']+db['constellations']:
            if s['class_id']==cls['id']:report.append('| '+s['id']+' | '+s['name']+' | '+names[s['id']]+' |')
        report+=['','무기: '+', '.join(equipment[f"weapon:{cls['id']}:{t}"] for t in range(10)),'']
    report+=['## 방어구·장신구','','| 기본 조합 | 새 이름 |','|---|---|']
    report += ['| '+k+' | '+v+' |' for k,v in equipment.items() if not k.startswith('weapon:')]
    report+=['','## 몬스터 표시명','','| ID | 이름 |','|---|---|']
    report += ['| '+k+' | '+v+' |' for k,v in result['monsters'].items()]
    report+=['','## 참고','', '[메이플스토리 직업 안내](https://gi.maplestory.nexon.com/Guide/Character/Intro) · [로스트아크 클래스 안내](https://lostark.game.onstove.com/Class). 직업별 어휘를 구분하는 방향만 참고했습니다.','']
    (ROOT/'docs/CONTENT_NAMES.ko.md').write_text('\n'.join(report),'utf-8')
    print('NAMES_AUTHORED',len(names),len(equipment))

if __name__=='__main__':main()
