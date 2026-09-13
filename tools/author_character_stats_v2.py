"""Write the approved stat direction and proposed tuning to a design-only DB."""
import hashlib
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/design/character_stats_v2'


def main():
    protected = [ROOT/'docs/database/stelrpg-database.json', ROOT/'docs/database/stelrpg.sqlite', ROOT/'game/data/codex-v053.bin']
    before = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
    primary = [
        ('power','위력','물리·마법 공격력', '각각 +2 × 투자값'),
        ('vitality','활력','최대 생명력·받는 회복량', '최대 HP +8 × 투자값; 받는 회복 +0.15×x/(x+60)'),
        ('fortitude','견고','물리·마법 방어력·경직 저항', '양방어 각각 +2 × 투자값; 일반 경직 지속 감소 0.20×x/(x+60)'),
        ('swiftness','신속','공격속도·시전속도·이동속도', '속도 증가 각각 0.40/0.25/0.20 × x/(x+60); 시전 시간은 속도 배율로 나눔'),
        ('precision','정밀','치명타 확률·치명타 피해', '확률 +0.15×x/(x+60); 치명타 피해 배율 +0.30×x/(x+60)'),
        ('specialization','특화','직업 고유 효과', '직업별 아래 지정 계수 × x/(x+60); 동일 피해에 중복 곱 적용 금지'),
    ]
    primary = [dict(id=i,name=n,effects=e,formula=f,source='investment_and_equipment',runtime_status='not_applied') for i,n,e,f in primary]
    # Rates use fractions, chance_add means percentage-point addition; explicit units avoid ambiguity.
    specs = [
        ('dexterity','손재주','제작', [('craft_great_success','chance_add',.002),('upgrade_success','chance_add',.001)],'신규 확률형 강화에 가산 적용 제안; 목표 단계 기본 확률과 보정 후 확률을 별도 표시'),
        ('exploration','탐색','탐사',[('sight_radius','tiles',.05),('normal_drop_chance','relative',.0025)],'시야는 벽을 관통하지 않음; 일반 몬스터 재료 드롭만'),
        ('intelligence','지능','제작',[('alchemy_great_success','chance_add',.0025)],'물약 조합에만 적용; 기본 마력이나 MP와 무관'),
        ('recovery','회수','제작',[('salvage_extra_material','chance_add',.0025)],'장비 분해 시 광석 1개 추가; 고급 핵·정수 복제 제외'),
        ('frugality','절약','제작',[('craft_gold_discount','relative',.0025)],'제작 금화에만 적용, 연구 예약과 취소 환급에는 미적용'),
        ('bargaining','흥정','상점',[('shop_gold_discount','relative',.002)],'NPC 구매 금화 할인; 판매가 증가 없음'),
        ('gathering','채집','탐사',[('gather_extra_material','chance_add',.003)],'개인 채집 보상에 기본 재료 1개 추가, 희귀 재료 제외'),
        ('quiet_step','은밀','탐사',[('noise_radius_reduction','tiles',.05)],'본인 이동·공격 소음만; 유인 돌·사건 소음 제외; 반경 최소 1칸'),
        ('medicine','약학','회복',[('potion_recovery','relative',.003)],'본인 회복 물약의 HP 회복량; 강화 물약 공격 버프 제외'),
        ('breathing','호흡','자원',[('stamina_cost_reduction','relative',.002)],'기력 비용만; MP 도입 시 별도 검토'),
        ('concentration','집중','전투',[('active_cooldown_reduction','relative',.0015)],'일반 액티브만; 궁극기·대시·물약·도구 제외'),
        ('tenacity','끈기','방어',[('slow_duration_reduction','relative',.004)],'본인이 받는 둔화 지속시간만'),
        ('antidote','해독','방어',[('poison_damage_reduction','relative',.004)],'독 지속 피해만; 즉발 독 속성 공격은 제외'),
        ('hemostasis','지혈','방어',[('bleed_damage_reduction','relative',.004)],'출혈 지속 피해만'),
        ('barrier_craft','보호','지원',[('outgoing_shield','relative',.0025)],'본인이 부여하는 보호막 흡수량; 무적 지속시간 제외'),
        ('first_aid','응급','지원',[('outgoing_heal','relative',.0025)],'본인 기술 회복량; 물약에는 약학만 적용'),
        ('staggering','파쇄','전투',[('stagger_damage','relative',.0025)],'무력화 피해만; HP 피해·도발 취소 가능 여부 변경 없음'),
        ('composure','평정','방어',[('normal_hitstun_duration_reduction','relative',.003)],'일반 경직만; 다운·잡기·보스 강제 연출 제외'),
    ]
    secondary=[]
    for sid,name,group,effects,note in specs:
        secondary.append(dict(id=sid,name=name,group=group,source='equipped_gear_only',points_per_line=[1,3],
            max_total_points=12,effects=[dict(id=k,unit=u,per_point=v,total_cap=round(v*12,6)) for k,u,v in effects],
            restrictions=note,runtime_status='not_applied'))
    jobs=[
        ('tank','무력화 피해',.25,'피해 흡수량',.15),('runesword','룬 소비 스킬 피해',.25,'룬 충전 확률',0),
        ('swordsman','자기 공격 버프 효과',.15,'버프 지속시간',0),('summoner','소환수 피해',.20,'소환수 최대 HP',.15),
        ('elementalist','시전 준비가 있는 원소 액티브 피해',.25,'모든 즉발 피해',0),('healer','기술 회복·보호막',.20,'공격 지원 버프 효과',.10),
        ('sniper','차지 사격·관통 액티브 피해',.25,'사거리',0),('hunter','출혈 피해',.20,'출혈 대상 처형 피해',.15),
        ('explorer','이동·공격속도 지원 버프 효과',.15,'일반 적 제어 지속시간',.10),('thief','독 지속 피해',.20,'방어 감소·취약 효과',.10),
        ('reaper','강화 강공격 피해',.25,'일반 낫 공격 피해',0),('gambler','족보 공격 피해',.20,'족보 확률',0),
        ('infighter','몰아침 스택당 피해 보너스',.20,'몰아침 최대 스택',0),('breaker','차지·패링 반격 피해',.25,'패링 판정 시간',0),
        ('martialist','콤보 마무리 피해',.25,'일반 발차기 피해',0),
    ]
    specialization=[dict(class_id=j,effect=a,max_bonus=x,secondary_effect=b,secondary_max_bonus=y,
        application='검증 가능한 현재 기술만 연결; 미구현 직업 기믹은 보류 상태로 표시') for j,a,x,b,y in jobs]
    specialization += [dict(class_id=j,effect='직업 기본 액티브 위력·회복·보호막',max_bonus=.15,secondary_max_bonus=0,
        application='기본직 공통. 전직 시 전직 효과로 교체하며 중복 적용하지 않음') for j in ['warrior','mage','ranger','rogue','fighter']]
    metadata=dict(direction='approved_option_2',tuning='proposed_initial_values',runtime_status='not_applied',
        source_hashes=before,primary_points_per_level=3,secondary_investment_allowed=False,
        enhancement=dict(status='user_confirmed_rates_partial_policy',runtime_status='not_applied',
            probability_basis='target_upgrade_level',
            success_chance_by_target={str(i+1):v/100 for i,v in enumerate([90,80,70,70,70,70,30,30,30,10,10,5])},
            caps_by_rarity={'0':3,'1':None,'2':None,'3':None,'4':12},
            proposed_middle_caps={'1':6,'2':8,'3':10},
            failure_policy=dict(downgrade_levels=1,protected_current_levels=[7],
                minimum_level=0,destruction_chance_given_failure=.03,
                order='성공 판정 → 실패 시 파괴 3% 판정 → 생존 시 단계 하락/현재 +7 유지',
                downgrade_rule='현재 +9 실패 시 +8; 현재 +8 실패 시 +7; 현재 +7에서 +8 시도 실패 시 +7 유지',
                protection_scope='현재 +7의 단계 하락만 방지하며 장비 파괴는 방지하지 않음',
                cost_on_failure=None),
            enhancement_material_bands=[dict(target_min=a,target_max=b,material_rank=t,
                material_name_proposal=n) for a,b,t,n in [(1,1,1,'강화석 조각'),(2,2,2,'정제 강화석'),
                (3,6,3,'응축 강화석'),(7,9,4,'빛나는 강화결정'),(10,11,5,'찬란한 강화결정'),(12,12,6,'초월 강화핵')]],
            material_policy='목표 단계의 기본 성공률 구간이 바뀔 때 상위 재료로 교체. 손재주 보정은 재료 구간에 영향 없음',
            unresolved=['중간 등급 강화 상한','실패 시 재료·금화 처리','단계별 비용·성능 증가','기존 상한 초과 일반 장비 이관'],
            dexterity='초기 제안: 점당 +0.1%p, 합산 최대 +1.2%p; min(1,기본확률+보정). 사용자 제시 표 자체는 보존',
            validation='등급 상한 도달 시 시도 금지; 목표 단계=current+1; 호스트 1회 판정 및 중복 요청 결과 재사용'),
        migration=dict(player='구 5스탯 투자만 일회성 전액 환급; 생성 포인트와 레벨 예산 보존',
            gear={'strength':'power','magic':'power','endurance':'fortitude','agility':'swiftness','technique':'specialization'},
            stacking='구 힘·마력이 같은 장비에 있으면 높은 값 하나만 위력으로 이관; 원본 이관 기록 보존',
            version='독립 stat_schema_version=2 제안; 반복 로드에 환급 중복 금지'),
        equipment=dict(lines_by_rarity=[0,1,1,2,2],points_by_rarity=[[0,0],[1,1],[1,2],[1,2],[2,3]],
            duplicate_stat_per_item=False,activation='착용 및 기존 착용 조건 충족 시; 가방 보관 장비는 제외',
            upgrade_growth=False,per_stat_cap=12,randomness='권위 호스트가 생성 시 확정하고 저장; 장착·접속으로 재추첨 금지',
            exclusions='미구현 효과는 생성 풀에서 제외; 장비 세부 스탯을 기본 투자·스킬 노드·버프로 획득하지 않음'),
        great_success=dict(base_chance=0,craft='장비 수량은 1개 유지; 기본 bonus +1만, 등급·강화 단계·추가 옵션 수 증가 없음',
            alchemy='제작 1회분 물약 출력 +1개; 묶음은 횟수별 독립 판정',
            transaction='추가 산출물까지 용량 확보 후 판정·지급; 실패 시 비용·재료 미소모; 재전송 결과 재사용'),
        primary_contracts=dict(
            vitality='받는 회복은 자기/아군 기술의 HP 회복에 적용; 물약·부활 고정 HP·마을 전회복·최대 HP 보정 회복 제외. 발신 회복 배율과 수신 배율을 각 한 번 적용',
            fortitude='일반 피격 경직 지속시간 감소만; 넉백 거리·다운·잡기·보스 강제 연출·무적 제외. 완전 경직 면역 불가',
            swiftness='시전속도는 액티브의 준비 시간에만 적용; 차지 최대 시간·채널 지속·다단 타격 간격·후딜·궁극기 제외. 준비 시간 최소 0.1초, 원래 즉발은 즉발 유지',
            precision='치명 확률은 기존 합성 결과에 가산 후 최대 0.85; 치명 피해는 최종 배율에 가산해 최소1, 최대3.0. 정밀 자체가 기존 비치명 기술을 치명 가능으로 바꾸지 않음',
            specialization='직업당 한정된 대상 태그만 강화. 동일 공격이 복수 태그에 해당하면 가장 큰 보정 한 번만. 궁극기 제외. 미구현 효과는 설명에 예정 표시',
            support='회복·보호막은 기존 공격력 기반 계수로 위력을 반영하며 중복 배율 금지. 탐험가 CC 특화는 일반 적만, 보스 무력화/취소 규칙 보존'),
        caps=dict(chance='0~1로 제한; 확정 성공을 확률 실패로 변경하지 않음',
            drop='상대 증가: 기본10%에 탐색 최대3%면10.3%; 확정·레이드·퀘스트·상자 보상 제외',
            cooldown='기존 다른 쿨감과 곱 적용, 최종 일반 액티브 감소 상한40% 제안',
            duration='견고·평정 합산 후 일반 경직 감소 최종30% 상한',
            payout='금화 할인은 내림; 구매/제작 비용 최소1G; 취소는 실제 차감액만 환급',
            rounding='중간 계산은 실수 유지; 피해·회복의 최종 기존 정수 처리만 사용'))
    data=dict(metadata=metadata,primary_stats=primary,equipment_special_stats=secondary,class_specialization=specialization)
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    con=sqlite3.connect(OUT/'catalog.sqlite')
    for table,key,rows in [('primary_stats','id',primary),('equipment_special_stats','id',secondary),('class_specialization','class_id',specialization)]:
        con.execute(f'CREATE TABLE IF NOT EXISTS {table}(id TEXT PRIMARY KEY,data TEXT NOT NULL)');con.execute(f'DELETE FROM {table}')
        con.executemany(f'INSERT INTO {table} VALUES (?,?)',[(v[key],json.dumps(v,ensure_ascii=False)) for v in rows])
    con.execute('CREATE TABLE IF NOT EXISTS metadata(id TEXT PRIMARY KEY,data TEXT NOT NULL)');con.execute('DELETE FROM metadata');con.execute('INSERT INTO metadata VALUES (?,?)',('policy',json.dumps(metadata,ensure_ascii=False)));con.commit()
    assert con.execute('PRAGMA integrity_check').fetchone()[0]=='ok';con.close()
    assert len(primary)==6 and len(secondary)==18 and len(specialization)==20
    assert all(e['total_cap']==round(e['per_point']*s['max_total_points'],6) for s in secondary for e in s['effects'])
    assert all(before[str(p.relative_to(ROOT))]==hashlib.sha256(p.read_bytes()).hexdigest() for p in protected)
    (OUT/'validation.json').write_text(json.dumps(dict(status='passed',primary=6,equipment_special=18,classes=20,
        checks=['고유 ID','세부 스탯 합산 상한 계산','SQLite 무결성','정본 DB·캐시 미변경'],runtime_tested=False),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['# 기본 스탯 2안 및 장비 전용 세부 스탯', '', '사용자 선택: 기본 스탯 2안 확정. 아래 수치는 초기 조정안이며 런타임 미적용입니다.', '', '## 기본 스탯', '', '|이름|효과|초기 수식|','|---|---|---|']
    lines += [f"|{v['name']}|{v['effects']}|{v['formula']}|" for v in primary]
    lines += ['', '## 장비 전용 세부 스탯', '', '장비 한 줄 1~3점, 같은 세부 스탯 총 12점 상한. 일반/레어/유니크/에픽/레전드리의 줄 수는 0/1/1/2/2입니다. 스탯 포인트 투자와 강화로 증가하지 않습니다.', '', '|이름|분야|점당 효과 → 전체 상한|제한|','|---|---|---|---|']
    for s in secondary:
        effects=[]
        for e in s['effects']:
            factor=1 if e['unit']=='tiles' else 100;unit='칸' if e['unit']=='tiles' else '%p' if e['unit']=='chance_add' else '%'
            effects.append(f"{e['id']}: {e['per_point']*factor:g}{unit} → {e['total_cap']*factor:g}{unit}")
        lines.append(f"|{s['name']}|{s['group']}|{' / '.join(effects)}|{s['restrictions']}|")
    lines += ['', '## 이관과 실제 반영', '', '- 기본 스탯 투자 전액을 한 번 환급하고 6개 스탯으로 재투자합니다. 레벨·생성 포인트·아이템은 보존합니다.', '- 구 장비의 힘/마력→위력, 내구→견고, 민첩→신속, 기술→특화로 이관합니다.', '- 사용자 지정 확률형 강화로 개편합니다. 일반 상한 +3, 레전드리 +12와 단계별 확률은 확정이며 실패 시 1단계 하락하되 현재 +7은 유지하고, 실패 시에만 3%로 장비가 파괴됩니다. 성공률 구간마다 상위 재료를 사용합니다. 중간 등급 상한과 실패 비용은 미정입니다. metadata.enhancement를 참조하세요.', '- 제작/연금 대성공은 신규 기능이므로 해당 거래의 권위 처리·용량 검증·재전송 중복 방지와 함께 구현해야 합니다.', '- MP 분리·궁극기·미구현 직업 기믹은 이번 DB 작성만으로 적용됐다고 취급하지 않습니다.', '- 메인에서 런타임·저장 이관·UI·세부 효과를 구현한 뒤 정본 DB를 재생성해야 합니다. 이 폴더는 설계 DB입니다.', '- 탐사 제작 DB의 기존 5스탯 문구와 구 옵션은 이번 개편 정책을 후속 기준으로 따릅니다. 원본 장비 참조 스냅샷은 이관 전 근거로 보존합니다.']
    (OUT/'README.ko.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('기본 6종 / 장비 세부 18종 / 직업 특화 20종 작성 및 검증 완료; 런타임 미변경')


if __name__=='__main__':main()
