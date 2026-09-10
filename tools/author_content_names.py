"""직업별 명칭 원고를 이름 전용 카탈로그로 편집한다. 실행 수치는 수정하지 않는다."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIVE = {
"tank":"서약의 도약|은벽의 손길|방패 선봉|전우의 서약|닫히지 않는 성문|은벽 전개|충격 저금|마지막 성채|방패 울림|진군 저지|수호자의 호령|성문 앞 균열",
"swordsman":"검심 점화|일선 가르기|결투의 낙인|마지막 검선|쾌검 호흡|세 겹의 검흔|검끝 추격|일점 검무|틈을 읽는 눈|검심의 결의|심장 겨누기|찰나의 몰입",
"runesword":"속행 각인|새김의 칼날|각인 해방|공명의 검문|폭렬 각인|서릿결 문양|일곱 칼날 진|겹새김 파열|틈새 전이|방호 각인|맑힘의 각인|끌림의 문장",
"summoner":"칼날벗 부르기|별탄벗 부르기|방패벗 부르기|거수의 응답|맹공의 약속|추풍의 약속|숨결 나누기|계약의 새벽|한마음 표적|곁으로 부름|울림의 합주|생명의 담보",
"elementalist":"불씨 유탄|잿불 휘장|낙성 화우|잔불 터뜨리기|서리 만개|겨울의 벽|백야 눈보라|얼음꽃 파쇄|번개 징검다리|하늘의 벼락|술식 가속|삼원 대폭풍",
"healer":"새벽의 손길|이어지는 기도|온기의 물결|숨결의 성역|용기의 축복|날갯짓 축복|혜안의 축복|승전의 합창|맑은 종소리|여명의 인장|꺼지지 않는 기도|빛내림 심판",
"sniper":"일선 관통시|한점 연속시|고요를 깨는 시위|갈래깃 화살|심장 조준점|갑옷 너머 시선|발묶음 화살|끝맺음 화살|뒷걸음 견제|고요한 사격대|찰나의 장전|다가오지 못할 선",
"hunter":"톱니깃 볼트|연발 추격|갈고리 상흔|핏자국 결산|피꽃 덫|발목 올가미|사냥감의 미끼|가시 사냥터|송곳니 돌격|몰이의 호각|야성의 호각|곁으로 호각",
"explorer":"덩굴 채찍|원무 채찍|내리꽂는 매듭|끌어오는 갈고리|묶음줄 투척|발걸림 매듭|그물 매듭|채찍의 굉음|절벽 건너기|매듭 선회|벼랑 뒤도약|매달린 낙하격",
"thief":"섬표 새기기|찰나의 침입|돌아갈 그림자|그림자 징검다리|발목 훔치기|갑옷 이음새|약점의 서명|빈손의 굴욕|붉은 절개|시야 훔치기|장물 나눔|흔적 없는 거래",
"reaper":"거두는 사슬|매달린 추격|되감는 거리|철쇄 그물|단두의 낫|검은 반월|낙하 집행|끝자락 집행|흑월 걸음|철쇄 장막|마지막 예고장|집행자의 시간",
"gambler":"한 장 더|비장의 보관|두 장의 갈림길|승부 잠그기|첫 패의 일격|갈래패 투척|판돈의 무게|스물하나의 종막|운명의 눈금|운명 다시 굴리기|가짜 배분|승부판의 법칙",
"infighter":"쏟아지는 주먹|품속 돌파|턱끝 올려치기|몰아침 난타|비껴치는 잽|끝까지 직진|한 걸음 반격|사각의 두 주먹|몰아침 유지|가드 찢기|권투가의 호흡|쉴 틈 없는 공세",
"breaker":"산울림 장타|대지 진각|회천 뒤꿈치|하늘깨기 일격|흘림의 손|낮은 팔꿈치|철문 무릎|역린의 예비|산등성이 돌진|금강의 숨|기맥 고르기|파천의 예비",
"martialist":"쇄도 옆차기|바람쫓는 발|질풍 이단각|비상 돌파각|쌍룡 돌려차기|하늘여는 발|회축의 춤|별떨굼 뒤꿈치|반보 뒤차기|철벽의 중심|용권 끝맺음|무극의 흐름",
"rogue":"그림자 첫칼|비껴선 그림자|붉은 칼자국|연막 속 첫수",
"fighter":"정권 내지르기|파고드는 주먹|턱끝 띄우기|맞선 두 주먹",
}
BASE_ACTIVE = {
"blade_wave":"여명 검파","rush":"돌파의 검로","whirlwind":"회오리 검륜",
"warrior_barrier":"강철의 맹세","warrior_burst":"지평 가르기","warrior_chain":"이어베는 검흔","warrior_fan":"갈래 검광","warrior_field":"머무는 검진","warrior_haste":"진군의 함성","warrior_heal":"다시 서는 맹세","warrior_nova_ring":"겹치는 검륜","warrior_pull":"끌림의 검진",
"arrow_rain":"녹음의 화살비","piercing_shot":"바람뚫는 화살","retreat_shot":"물러서는 깃털",
"ranger_barrier":"잎새의 엄호","ranger_burst":"터지는 화살촉","ranger_chain":"튕기는 깃살","ranger_fan":"부챗살 시위","ranger_field":"가시 울타리","ranger_haste":"추풍의 집중","ranger_heal":"숲길 응급처치","ranger_nova_ring":"둘레깃 사격","ranger_pull":"바람 매듭",
"blink":"별틈 걸음","frost_nova":"서릿별 개화","thunder":"벼락별 낙하",
"mage_barrier":"수정빛 결계","mage_burst":"별돌 낙하","mage_chain":"번개별 연결","mage_fan":"세 갈래 별탄","mage_field":"눈꽃의 소용돌이","mage_haste":"시계별 가속","mage_heal":"달빛 한 모금","mage_nova_ring":"별고리 공명","mage_pull":"별무게 소용돌이",
}
SIGNATURES = dict(zip(
"warrior ranger mage rogue fighter tank swordsman runesword summoner elementalist healer sniper hunter explorer thief reaper gambler infighter breaker martialist".split(),
"검로 녹음 별빛 그림자 정권 은벽 검심 각인 계약 삼원 여명 일점 사냥 매듭 섬표 철쇄 승부 몰아침 축기 연무".split()))
CLUSTERS = {
"warrior":"잔검의 울림|한줄기 검심|잔영 돌파|전방 검파|수호 검륜",
"tank":"방패의 잔향|수호의 일점|은벽 도약|성문 파동|맹세의 반향",
"swordsman":"겹치는 검흔|한점 결투|찰나 검로|검선의 확장|검심의 응수",
"runesword":"겹울림 각인|단일 검문|전이 가속|칼날 파문|방호 공명",
"ranger":"깃살의 잔향|한점 조준|뒷걸음 반격|갈래 사냥길|늦게 피는 덫",
"sniper":"뒤따르는 화살|고요한 일점|이탈 뒤 조준|갈래깃 연쇄|지연 화살촉",
"hunter":"사냥의 메아리|한마리 추적|이탈의 호각|몰이 연쇄|잠복 폭발",
"explorer":"채찍의 잔향|한곳의 매듭|선회 반격|갈래 탐사로|시간차 올가미",
"mage":"별빛 메아리|별의 초점|별틈 탄력|잔열의 별|문장의 별길",
"summoner":"계약의 잔향|한뜻의 초점|귀환의 탄력|잔열의 약속|계약의 문장",
"elementalist":"원소의 잔향|응축된 술식|전이의 탄력|꺼지지 않는 잔열|삼원의 중계",
"healer":"기도의 잔향|한뜻의 기도|구원의 발걸음|남겨진 온기|성역의 문장",
"rogue":"그림자 잔격|급소의 초점|비껴선 반격|교차 칼자국|회수하는 독",
"thief":"섬표의 잔흔|한점의 범행|도약의 탄력|서로 다른 서명|독 묻은 장물",
"reaper":"철쇄의 잔향|단독 집행|흑월 반격|교차 예고장|독의 추심",
"gambler":"뒷패의 메아리|한패의 승부|옆걸음 배당|교차 서약패|독 묻은 판돈",
"fighter":"권격의 잔향|한점의 주먹|회피의 반격|따라붙는 연타|모아치는 주먹",
"infighter":"주먹의 잔상|한점 압박|위빙 반격|끝까지 난타|응축된 강타",
"breaker":"장타의 잔향|일점 축기|흘림 뒤 반격|따라붙는 삼격|압축된 진각",
"martialist":"발끝의 잔향|한점의 중심|반보의 탄력|추적하는 연무|응축된 끝맺음",
}
EFFECT_WORDS={"skill_damage":"위력","skill_range":"뻗음","skill_radius":"둘레","skill_haste":"순환","skill_discount":"절제","skill_duration":"여운","move_speed":"보법","attack_speed":"박자","stagger_power":"균열","support_power":"가호","followup_damage":"이음격","stagger_followup":"연쇄 붕괴","execute_damage":"끝맺음","efficiency_followup":"고른 호흡","mobility_refund":"되찾는 숨","slow_on_followup":"붙드는 잔흔","support_followup":"응답의 일격","guard_on_followup":"맞이하는 방호","control_damage":"묶인 약점","heal_on_followup":"되살리는 박자"}
WEAPON_TYPES={"warrior":"장검","tank":"수호검","swordsman":"결투검","runesword":"각인검","ranger":"사냥활","sniper":"저격궁","hunter":"석궁","explorer":"탐사 채찍","mage":"지팡이","summoner":"계약의 홀","elementalist":"원소의 홀","healer":"치유 성물","rogue":"단검","thief":"쌍단검","reaper":"사슬낫","gambler":"카드덱","fighter":"너클","infighter":"권투갑","breaker":"파쇄권갑","martialist":"연무권갑"}
TIER_WORDS=["이슬벼림","수정맥","푸른잔해","포자안개","잿불벼림","서리심장","황동톱니","황혼서약","은하잔광","심핵봉인"]
WEAPON_TITLES={"warrior":["별길 개척자","심핵을 가르는 검"],"tank":["별을 지킨 맹세","무너지지 않는 성문"],"swordsman":["은하의 한 획","결투의 마지막 선"],"runesword":["별새김 검문","태초의 각인검"],"ranger":["별깃 추적자","심핵을 꿰는 시위"],"sniper":["은하의 조준점","침묵을 끝내는 활"],"hunter":["별자국 사냥꾼","끝없는 추적석궁"],"explorer":["별길 탐사채찍","미답지의 표식"],"mage":["별무리 지팡이","첫별의 지팡이"],"summoner":["은하의 약속","태초의 계약홀"],"elementalist":["삼원 별지팡이","원소의 첫 울림"],"healer":["별빛 기도서","꺼지지 않는 새벽"],"rogue":["별그늘 단검","끝자락의 칼날"],"thief":["별빛 훔친 쌍칼","이름 없는 범행"],"reaper":["은하의 사슬낫","마지막 밤의 집행"],"gambler":["별무늬 승부패","운명을 접는 손"],"fighter":["별바위 너클","태초를 두드린 주먹"],"infighter":["별똥 권투갑","끝나지 않는 공세"],"breaker":["별깨기 권갑","하늘을 여는 장타"],"martialist":["별궤도 권갑","무극의 끝자락"]}
ARMOR={"warrior":["투구","흉갑","철장갑","각반","철장화","호신 부적"],"ranger":["깃모자","사냥 조끼","시위 장갑","추적 바지","숲길 장화","깃살 브로치"],"mage":["마도관","예복","술식 장갑","마도 하의","룬 구두","별눈 목걸이"],"rogue":["두건","잠행복","암수 장갑","잠행 바지","소리없는 신발","그늘 반지"],"fighter":["머리띠","수련복","손등 보호대","수련 바지","보법 신발","호흡 옥패"]}

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
            names[skill['id']]=prefix+skill['name'].removeprefix(prefix)
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
    result={'version':1,'note':'표시명 전용. 기존 ID·효과·수치·조건을 유지합니다.','skills':names,'clusters':clusters,'equipment':equipment}
    assert len(names)==1510 and len(equipment)==500
    for collection in [names,equipment]:
        assert all(0<len(v)<=28 for v in collection.values())
    out=ROOT/'game/data/content_names.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n','utf-8')
    report=['# 직업별 스킬·장비 명칭표','', '원기술610개·별자리900개·장비 기본500조합의 이름입니다. 등급별2500개 장비는 기본 이름과 등급 표시를 함께 사용합니다.','']
    for cls in db['classes']:
        report += ['## '+cls['name']+' ('+cls['id']+')','','| ID | 이전 이름 | 새 이름 |','|---|---|---|']
        for s in db['skills']+db['constellations']:
            if s['class_id']==cls['id']:report.append('| '+s['id']+' | '+s['name']+' | '+names[s['id']]+' |')
        report+=['','무기: '+', '.join(equipment[f"weapon:{cls['id']}:{t}"] for t in range(10)),'']
    report+=['## 방어구·장신구','','| 기본 조합 | 새 이름 |','|---|---|']
    report += ['| '+k+' | '+v+' |' for k,v in equipment.items() if not k.startswith('weapon:')]
    report+=['','## 참고','', '[메이플스토리 직업 안내](https://gi.maplestory.nexon.com/Guide/Character/Intro) · [로스트아크 클래스 안내](https://lostark.game.onstove.com/Class). 직업별 어휘를 구분하는 방향만 참고했습니다.','']
    (ROOT/'docs/CONTENT_NAMES.ko.md').write_text('\n'.join(report),'utf-8')
    print('NAMES_AUTHORED',len(names),len(equipment))

if __name__=='__main__':main()
