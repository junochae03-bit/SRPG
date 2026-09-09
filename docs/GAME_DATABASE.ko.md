# 모험 도감과 게임 DB

V0.5는 싱글 플레이로 개발하며 온라인 멀티플레이는 이후 단계다. 이 DB는 게임의 실제 장비·몬스터·던전·드랍·스킬·별자리 카탈로그와 완료된 원화의 파일·영역·사용 관계를 조회하는 읽기 전용 자료다. 세이브나 운영 서버 DB가 아니다. 관리 DB 스키마 3과 게임 저장 형식 v7은 서로 독립적이다.

게임에서 **B**를 누르면 장비, 몬스터, 드랍, 스킬을 검색하고 필터링할 수 있다. 장비 상세에서 획득처를, 몬스터 상세에서 기본 드랍과 해당 레이드의 추가 드랍을 확인한다. 스킬 상세의 랭크 표는 포인트를 소비하지 않는다. 전투 수치를 수정할 때는 아래 원본을 수정한 뒤 DB를 재생성한다.

## 파일과 수록 범위

- [stelrpg.sqlite](database/stelrpg.sqlite): SQLite 관계형 DB. DB Browser for SQLite 같은 도구로 읽기 전용으로 열거나 아래 Python 예제를 사용한다.
- [stelrpg-database.json](database/stelrpg-database.json): 같은 모델의 JSON 스냅샷. 스킬의 중복 `node`/`ranks`는 관계형 `skill_ranks`로 정리했다.
- [schema.sql](database/schema.sql): FK·고유 키·확률 범위 제약과 조회용 뷰.
- [queries.sql](database/queries.sql): 장비 착용, 층별 몬스터, 획득처, 랭크 비교 예제.
- [manifest.json](database/manifest.json): 행 수, 파일 크기와 SHA-256. 원본 의존 파일의 SHA-256은 JSON의 `metadata.source_sha256`과 SQLite `metadata`에 있다.

| 자료 | 행 수 | 의미 |
|---|---:|---|
| 직업 | 20 | 기본 5계열 + 전직 15종 |
| 장비 | 2,500 | 직업 무기 20×10단계×5등급 + 5계열×6부위×10단계×5등급 |
| 몬스터 | 24 | 기본형 18종, 엘리트 3종, 보스 원형 3종 |
| 레이드 | 10 | B10부터 B100까지 이름과 성장 수치가 다른 보스전 |
| 던전 | 100 | 생태권, 입장 레벨, 수문장 |
| 층별 출현 | 620 | 몬스터와 역할별 출현·성장 값. 개체 수가 아니라 출현 조합 수 |
| 기본 드랍 | 132 | 몬스터별 독립 확률 항목 |
| 레이드 추가 등급 | 24 | 추가 장비 1개의 조건부 등급 분포 |
| 스킬 | 610 | 기본·전직 직업의 현재 노드 전체 |
| 선행 연결 | 651 | 노드 간 선행 랭크와 any/all 정보 |
| 스킬 랭크 | 2,030 | 각 노드의 1~최대 랭크 수치와 무력화량 |
| 전문화 별자리 | 900 | 20직업 × 45개. 원기술과 별도 집계 |
| 전체 빌드 노드 | 1,510 | 원기술 610 + 전문화 별자리 900 |
| 별자리 선행 연결 | 1,280 | 원기술에 붙는 입구와 전문화 경로 |
| 배타 그룹 | 40 | 직업마다 공통 전달 방식 1쌍 + 계열 핵심 1쌍 |
| 추가 배타 연결 | 4 | 궁수 계열 4직업의 단일 결의와 연쇄 충돌 |
| 지원 효과 정의 | 33 | 성장 10종, 조건부 연결 10종, 핵심 행동 13종 |
| 노드 효과 연결 | 900 | 노드 ID와 실제 전투 효과 ID·값 |

기존 원기술은 기본 검사·궁수·마법사 각각 50개, 기본 도적·격투가 각각 5개, 전직 15종 각각 30개다(150 + 10 + 450 = 610개). 여기에 직업마다 전문화 별자리 45개가 추가되어 트리의 총 선택지는 각각 95개·50개·75개다. 900개의 전문화 노드는 액티브 공격기 900개를 새로 만든다는 뜻이 아니다. 원기술의 전달 방식과 조건부 연결, 비용과 효율을 바꾸는 선택이다. 보스전 10개는 원형 kind 3종을 사용하며, 준비된 6개 생태계에는 새 보스 원화 6종을 연결한다. 생태권·이름·층별 능력치·공격 판정과 원화 변형은 별도로 기록한다.

## 별자리의 비용과 연결

`skills`, `skill_parents`, `skill_ranks`는 기존 원기술을 유지한다. `build_nodes`는 원기술과 별자리 전체의 ID·직업·종류·비용·해금 레벨을 제공하고, `constellations`에는 새 노드의 설명·시너지·대가·원화 참조가 있다. `constellation_edges`는 원기술 ID와 새 별자리 ID를 모두 참조한다. `build_edges` 뷰는 두 종류의 선행 연결을 합쳐 보여 준다.

직업마다 다섯 무리가 있고 각 무리는 작은 성장 6개, 조건부 연결 2개, 핵심 행동 1개로 구성된다. SP 비용은 작은 성장 1, 조건부 연결 3, 핵심 행동 6이다. 원기술 랭크와 새 별자리는 **같은 `레벨-1` 포인트 예산**을 사용한다. LV100에서 99SP이며 기존 전직 원기술 최대 투자 102SP와 새 별자리 전체 비용 90SP를 동시에 지불할 수 없다.

핵심 행동은 최대 2개다. 메아리와 단일 결의는 서로 배타적이고 계열별 핵심 행동 두 개도 서로 배타적이다. 공통 핵심과 계열 핵심은 함께 선택할 수 있으며 전투 해석기가 두 효과를 순서대로 적용한다. 예외로 궁수 계열의 단일 결의와 갈라지는 사냥길은 함께 선택할 수 없다. 한 대상만 맞히는 약속과 새 대상으로 연쇄하는 약속이 충돌하기 때문이다. 여러 추가 타격은 원시전의 피해·무력화 예산을 공유한다. `exclusive_groups`는 쌍별 선택 한도, `constellation_exclusions`는 추가 배타 연결, `metadata.build_policy`는 핵심 총한도를 기록한다.

핵심 노드는 두 조건부 연결을 **모두** 요구한다. 다른 노드는 선행 중 하나를 요구하며 이 차이가 `mode=all/any`에 기록된다. `skill_build.gd`가 UI 경로 미리보기, 실제 투자, 공유 비용, 배타 선택과 부분 해제 환급을 함께 판정한다. 선행을 해제하면 더 이상 성립하지 않는 자식 선택과 정확한 반환 SP를 미리 계산한다. 기존 스킬 ID와 랭크 규칙이 유지되므로 기존 세이브에 강제 초기화나 추가 SP를 지급하지 않는다.

원기술 랭크 표의 기준은 **별자리 미투자**다. 별자리 상세의 1랭크 표는 효과·조건·SP 비용을 설명하며, 직접 타격이 없는 패시브의 무력화 0은 다른 스킬에 주는 무력화 보너스가 없다는 뜻이 아니다. 실제 선택 후 값은 성장 화면과 전투 프로필에서 확인한다. 조건부 보너스는 실제 적중·회피·지원·대상 제어 상태에 따라 달라지므로 정적인 DB 값에 항상 적용된 것으로 합산하지 않는다.

## 확률을 읽는 방법

`drops.chance`는 처치 1회마다 **각 행을 따로 판정**하는 확률이다. 합계가 100%를 넘어도 오류가 아니며 여러 아이템이 동시에 나올 수 있다. 같은 몬스터의 무기 항목이 여러 개면 그 항목들이 각각 판정된 뒤 현재 직업의 전용 무기로 바뀐다. 원래 `weapon`/`weapons` 키는 원본 항목의 추적용으로 남아 있다. 드랍 장비의 단계는 `floor((층-1)/10)`이다. 튜토리얼의 예전 단계 추첨은 층별 장비 획득처 뷰에서 제외한다.

`raid_drops.chance`는 레이드에서 **추가 장비 1개가 확정으로 생성된 후 그 1개의 등급**을 정하는 확률이다. 기본 드랍과 독립이다. 등급 다음에 무기·머리·상의·장갑·하의·신발·장신구 7부위 중 하나를 균등 선택한다. 특정 부위까지 원하는 경우 `grade_chance × 1/7`을 사용한다. B100의 에픽 확률 26%와 에픽 무기 확률 약 3.71%는 서로 다른 사건이다. 획득처 화면과 SQL 뷰는 이를 분리한다. 무기는 처치자의 전직, 방어구·장신구는 처치자의 기본 계열에 맞춰진다.

도감의 기본 확률은 추가 보정이 없는 값이다. 사냥꾼은 소환수가 존재할 때 해당 패시브 랭크마다 기본 드랍 확률에 3%의 상대 보정이 붙고 최종 확률은 100%가 상한이다. 확정 추가 장비의 등급 분포에는 이 보정이 적용되지 않는다.

장비 행은 강화 +0의 부위·소유 직업/계열·단계·등급 조합이다. 희귀 옵션의 전체 조합을 각각 아이템으로 부풀리지 않는다. JSON의 `affix`·`resonance`는 대표 예시이고, 실제 전리품의 옵션을 보장하지 않는다. 레어 +2, 유니크 +3, 에픽 +4, 레전드리 +5에서 옵션이 열린다. 레어·유니크는 능력치 1종, 에픽·레전드리는 스킬 효과 계열 1종이다. 테두리 색과 명칭은 장비 카탈로그에서 가져온다.

## 스킬 기준과 무력화

랭크 비교는 **공격력 100 / 최대 HP 1000 / 기술 0 / 장비 없음 / 별자리 없음 / 다른 패시브 없음 / 직업 조건부 자원 보정 없음**으로 계산한다. 실전 피해, 회복, 쿨타임, 적 방어력, 치명타를 한 값으로 오해하지 않도록 기준을 명시한다. 강화 노드는 원기술 3랭크를 비교 기준으로 사용한다. 원기술과 별개의 공격이 아니므로 강화 노드 자체의 무력화는 0이다.

`skill_ranks.stagger_base`는 랭크 성장을 적용하고 기술 능력치를 적용하기 전 무력화량이다. `stagger_value`는 기술 보너스까지 적용한 값이다. 기준 기술 0에서는 둘이 같다. 실제 계산은 `BossStagger.skill_profile()`과 공유하며 기술 보너스는 `1 + 0.60 × T / (T + 60)`이다. T에는 장비 기술 옵션이 포함된다. 도감 수치는 한 번의 시전 예산이며 다단 공격이나 지속 피해가 매 타격마다 전체 예산을 다시 주는 뜻이 아니다. 실제 적중, 시전당 분할 예산, 보스 상태에 따라 무력화가 적용된다.

보스·레이드의 `stagger`(SQLite는 `stagger_json`)에는 런타임 초기화에서 읽은 일반 무력화 요구량, 체크 요구량, 넘어짐·유예·체크 시간, 넘어졌을 때 피해 배율이 있다. 전투 중의 누적값이 아니라 새 보스의 기준 설정이다.

## 원본과 재생성

실행 모델은 [game_database.gd](https://github.com/junochae03-bit/SRPG/blob/V0.5/game/scripts/game_database.gd)이다. 장비는 `equipment_catalog.gd`, 몬스터는 `world_catalog.gd`, 층별 성장과 레이드 확률은 `abyss_catalog.gd`, 드랍은 `data/drop_tables.json`, 원기술은 `skill_catalog.gd`와 `data/jobs/catalog.json`을 읽는다. 전문화는 `constellation_catalog.gd`·`skill_build.gd`에서 가져온다. 랭크 값은 실제 전투에 쓰이는 `job_balance.gd`·`skill_scaling.gd`, 별자리 행동은 `constellation_effects.gd`, 무력화는 `boss_stagger.gd`에서 해석한다.

프로젝트 루트에서 Godot 4.6과 Python 3 표준 라이브러리로 실행한다. 첫 체크아웃이면 에셋 import가 먼저 필요하다.

```powershell
$env:GODOT_EXE='D:\SSRPG\RPG2\tools\godot\Godot_v4.6-stable_win64_console.exe'
& $env:GODOT_EXE --headless --path game --editor --import
python tools/build_database.py
python tools/build_database.py --check
python tools/run_hidden_check.py database_v03
python tools/run_hidden_check.py skill_build_v04
python tools/run_hidden_check.py database_v04
python tools/run_hidden_check.py art_registry_v05
python tools/test_art_registry.py
```

`--check`는 현재 Godot 모델에서 다시 추출하고 임시 SQLite를 생성해 JSON·SQLite·스키마·매니페스트의 바이트를 비교한다. 고유 ID, FK, 직업 계열, 확률 범위, 레이드 등급 합계, 전체 랭크 및 에셋 경로도 검사한다. 원본이나 원화 매핑이 바뀐 뒤 재생성하지 않은 DB는 실패한다. 시각 없는 DB 생성은 원화 제작이나 이미지 편집을 수행하지 않는다. 저장 파일을 읽거나 변경하지 않는다.

읽기 전용 접속 예:

```python
import sqlite3
from pathlib import Path

path = Path('docs/database/stelrpg.sqlite').resolve()
db = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)
for row in db.execute('SELECT floor_id, name, health FROM raids ORDER BY floor_id'):
    print(row)
```

## 아트 담당자와의 연결

SQLite `assets` 또는 각 JSON 행의 `asset`에 실제 리소스 경로와 `[x,y,width,height]`가 있다. 몬스터는 `sheet_key`, `frame_index`, 발 기준점 `foot`도 포함한다. 장비 ID는 `eq:직업또는계열:부위:두자리단계:등급`, 몬스터 ID는 현재 전투 kind, 레이드 ID는 `raid:010`, 스킬 ID는 기존 카탈로그 ID를 유지한다.

새 원화 파일을 DB에서 직접 참조하도록 임의로 덮어쓰지 않는다. `Content.icon_texture`, `IconArt.skill`, `WorldArt.frame`의 실제 게임 매핑을 변경한 뒤 import·재생성·검사를 실행하면 도감과 DB에도 같은 결과가 반영된다. 배경이나 스킬 이펙트 제작은 별도 담당 작업이며 이 DB의 원화 참조는 현재 연결 상태를 설명한다.

## V0.5 원화 자산 관리

기존 게임 테이블과 `assets`를 유지하고 다음 관리 테이블을 추가했다. 같은 `stelrpg-database.json`과 `stelrpg.sqlite` 안에 있으므로 별도 원화 이미지나 원본 추출 폴더를 DB 패키지에 넣을 필요가 없다.

| 테이블 | 내용 |
|---|---|
| `art_sources` | 저장소 출처 문서·카탈로그 경로와 SHA256 |
| `art_files` | 실제 runtime PNG·절차형 VFX 소스 경로, SHA256, 크기·해상도, 원본 출처 근거 |
| `art_assets` | 분류·이름·상태·프레임 번호·동작·원본 영역·발/몸체 정보와 파일 참조 |
| `art_uses` | 장비·직업·스킬·층·몬스터 출현·드랍 또는 UI의 실제 소비 관계, 별도로 표시한 카탈로그 준비 관계 |

`art_catalog`는 파일·출처를 결합한 목록, `art_usage`는 사용처까지 결합한 조회 뷰다. `art_uses`의 장비·직업·스킬·별자리·몬스터·레이드·출현·층·드랍 참조는 SQLite 외래키로도 검사한다. 현재 행 수는 매니페스트의 `art_*` 값을 따른다.

완료된 아이콘 **168개**, 새 캐릭터 **33종 × 16 = 528프레임**, 새 장비 **115영역**, 배경 장식 **108개**, 새 몬스터·보스 **48키포즈**, 실제 바닥 **6재료**를 관리한다. 기존에 쓰는 캐릭터·건물·전리품·괴물, 타이틀, 18계열 절차형 VFX와 자동 효과·동료 원화도 함께 조회한다. 일부 추가 영역은 초상·동작별 소비를 따로 기록하므로 이 수량을 단순 합산한 값이 전체 행 수는 아니다.

`art_assets.status='applied'`는 실제 게임 매핑이 있다는 뜻이다. `available_catalog`는 완료된 runtime 카탈로그에는 있지만 현재 사용하는 기능이 없는 준비 영역이다. 새 캐릭터 528프레임 중 플레이어용 480프레임과 NPC 대기 3프레임은 사용되고, NPC의 나머지 45프레임은 준비 상태다. `art_uses.usage_kind`도 각각 `runtime_mapping`과 `catalog_available`로 구분한다. 카탈로그 준비 관계를 플레이 중 그려졌다는 증거로 해석하지 않는다. 미완성 테마 장비·벽 타일·원본 추출 전체는 포함하지 않는다.

관리 내보내기는 `GameDatabase.snapshot(true)`에서 수집한 메타데이터를 Python 표준 라이브러리로 검증하고 해시를 계산한다. 게임 도감은 기본 `snapshot()`을 계속 사용하므로 PCK의 `.gdc` 환경에서 개발 소스 스캔이나 전체 원화 관리 수집을 하지 않는다. 관리 수집도 코스튬 이미지를 추가로 RGBA 변환하지 않는다. 메모리에서 크로마를 제거하는 장비·코스튬은 원본 PNG 경로·원래 영역·원본 SHA256으로 기록한다.

예를 들어 새 장비와 게임 정의의 연결을 다음처럼 확인한다.

```sql
SELECT e.id,e.name,a.runtime_path,a.x,a.y,a.width,a.height,a.runtime_sha256
FROM equipment e JOIN art_uses u ON u.equipment_id=e.id
JOIN art_catalog a ON a.id=u.art_id
WHERE e.id='eq:reaper:weapon:09:3';

SELECT category,status,COUNT(*) regions
FROM art_catalog GROUP BY category,status ORDER BY category,status;

SELECT name,frame,action,status,runtime_path,x,y,width,height
FROM art_catalog WHERE id LIKE 'art:character:costume:pink-beret-gunner:%'
ORDER BY frame;
```

출처·영역·테마·소비 스크립트가 변경되면 `build_database.py --check`가 오래된 스냅샷을 거부한다. 범위 밖 좌표, 누락 파일, 출처 해시 불일치, 끊어진 소비 관계, 사용/준비 상태의 잘못된 표시도 검사한다. 상세 관리 절차는 [자산 DB 안내](ASSET_REGISTRY_V05.ko.md), 복사할 수 있는 SQL 예제는 [queries.sql](database/queries.sql)을 따른다. 이 관리 DB 검증은 전체 게임·EXE·릴리스 검증과 별도다.
