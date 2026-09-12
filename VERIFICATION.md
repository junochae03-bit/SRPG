현재 배포 검증: [V0.6 전체 소스·Windows EXE·DB 검사](docs/VERIFICATION_V06.ko.md).

아래는 V0.1 당시의 보존 기록입니다.

# 스텔알피지 V0.1 검증

2026-09-09 · Windows · Godot 4.6 stable · OpenGL Compatibility.

`python tools/verify_v01.py`: **PASS, 3,767개 검사, 실패 0**. 엔진 오류·스크립트 오류·경고가 없었다. 전체 모델/UI 회귀, 수풀 안정성, 구형 저장 이행, PNG 프레임 경계, 실제 그래픽 캡처 29장을 검사했다. 원본 사용자 저장은 복사본만 검사하고 원본 SHA256이 유지됨을 확인했다.

| 검사 | 수 | 결과 |
|---|---:|---|
| rules | 90 | PASS |
| inventory_grid | 83 | PASS |
| inventory_ui | 17 | PASS |
| combat | 45 | PASS |
| skills_v04 | 204 | PASS |
| loot_v04 | 302 | PASS |
| single_player | 30 | PASS |
| expansion_ui | 43 | PASS |
| appearance_v041 | 138 | PASS |
| expansion_v05 | 877 | PASS |
| polish_v05 | 271 | PASS |
| monsters_v05 | 410 | PASS |
| skills_v01 | 1026 | PASS |
| ui_v01 | 231 | PASS |

새 `skills_v01` 검사는 150노드의 랭크 1/2/3 기여와 36개 액티브의 실제 시전·피해·회복·방벽·가속, 비용·대기시간·투사체 폭·FX 랭크를 확인한다. 기준 공격력 18의 초승달 검기는 32 → 49 → 71 피해이며 UI와 시전은 같은 계산을 사용한다.

새 `ui_v01` 검사는 3직업의 50노드 이름/아이콘, 검색/필터/투자/슬롯 배치, 큰 장비 초상과 착용 비교, NPC 5명의 작업 화면, 실제 구매·판매·강화·재련·조제·의뢰·숙박을 검사한다. 사전 표시한 금화/재료와 실제 소모가 일치하고 거래 실패 시 상태가 변하지 않는다. 세 원정지의 선택→확인→실제 이동도 확인했다.

기존 검사는 전투·무기·회피·충전, 24종 적·공격 패턴·독립 드롭표, 장비·가방·스택·저장·수풀·외형·아이콘을 포함한다. 24개 드롭표에 대해 총 1,200,000회 표본을 판정한다.

`python tools/test_single_run.py`: **PASS**. 실제 프로세스에서 40초 자동 플레이로 6회 처치, 48.64타일 이동, 씨앗 2개를 획득했다. 일반 전투 구간의 확률 장비는 0개였으며 별도 통제된 엘리트의 실제 공격→처치→보장 장비→줍기→저장→새 프로세스 복원을 확인했다. 엘리트 체력을 낮춘 검사는 전체 전투 난이도 평가가 아닌 전리품·저장 경로의 검사다.

`python tools/build_v01.py`, `python tools/test_export_v01.py`: **PASS**. Windows EXE에서 40초 이동·전투, 실행 파일 옆 휴대형 저장, 새 프로세스의 모든 영속 필드 일치, 가방·성장 실제 그래픽 렌더를 확인했다. 개발용 테스트 폴더와 개인 저장은 실행 패키지에 포함하지 않는다.

[검증 데이터](docs/VERIFICATION_V01.json) · [가방](docs/screenshots/inventory-v01.png) · [성장](docs/screenshots/skill-web.png) · [상점](docs/screenshots/shop-v01.png) · [대장간](docs/screenshots/smith-v01.png)

UI 입력 검사는 SubViewport 합성 입력, 화면은 실제 Godot 렌더다. 장시간 수동 플레이의 재미·전체 난이도·음량 취향까지 보장하지 않는다. 일반 몬스터는 정지 원화와 이동/공격 변형, 추가 전투 원화는 기본 직업 외형 3종에 적용되어 있다.
