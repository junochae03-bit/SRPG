# 모험 도감과 게임 DB

V0.3은 개인용 싱글 플레이로 개발한다. 온라인 멀티플레이는 이후 단계다. 이 DB는 게임의 실제 장비·몬스터·던전·드랍·스킬 카탈로그를 조회하고 아트 담당자와 데이터 담당자가 같은 ID를 쓰도록 만든 읽기 전용 자료다. 세이브나 운영 서버 DB가 아니다.

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

기본 검사·궁수·마법사는 각각 50개, 기본 도적·격투가는 각각 5개, 전직 15종은 각각 30개 노드를 보유한 현재 게임 자료를 모두 수록했다(150 + 10 + 450 = 610개). 이 도감 작업에서 미구현 스킬을 추가했다고 표시하지 않는다. 보스 10개는 원형 스프라이트 3종을 공유하며, 생태권·이름·층별 능력치·공격 판정은 별도로 기록한다.

## 확률을 읽는 방법

`drops.chance`는 처치 1회마다 **각 행을 따로 판정**하는 확률이다. 합계가 100%를 넘어도 오류가 아니며 여러 아이템이 동시에 나올 수 있다. 같은 몬스터의 무기 항목이 여러 개면 그 항목들이 각각 판정된 뒤 현재 직업의 전용 무기로 바뀐다. 원래 `weapon`/`weapons` 키는 원본 항목의 추적용으로 남아 있다. 드랍 장비의 단계는 `floor((층-1)/10)`이다. 튜토리얼의 예전 단계 추첨은 층별 장비 획득처 뷰에서 제외한다.

`raid_drops.chance`는 레이드에서 **추가 장비 1개가 확정으로 생성된 후 그 1개의 등급**을 정하는 확률이다. 기본 드랍과 독립이다. 등급 다음에 무기·머리·상의·장갑·하의·신발·장신구 7부위 중 하나를 균등 선택한다. 특정 부위까지 원하는 경우 `grade_chance × 1/7`을 사용한다. B100의 에픽 확률 26%와 에픽 무기 확률 약 3.71%는 서로 다른 사건이다. 획득처 화면과 SQL 뷰는 이를 분리한다. 무기는 처치자의 전직, 방어구·장신구는 처치자의 기본 계열에 맞춰진다.

도감의 기본 확률은 추가 보정이 없는 값이다. 사냥꾼은 소환수가 존재할 때 해당 패시브 랭크마다 기본 드랍 확률에 3%의 상대 보정이 붙고 최종 확률은 100%가 상한이다. 확정 추가 장비의 등급 분포에는 이 보정이 적용되지 않는다.

장비 행은 강화 +0의 부위·소유 직업/계열·단계·등급 조합이다. 희귀 옵션의 전체 조합을 각각 아이템으로 부풀리지 않는다. JSON의 `affix`·`resonance`는 대표 예시이고, 실제 전리품의 옵션을 보장하지 않는다. 레어 +2, 유니크 +3, 에픽 +4, 레전드리 +5에서 옵션이 열린다. 레어·유니크는 능력치 1종, 에픽·레전드리는 스킬 효과 계열 1종이다. 테두리 색과 명칭은 장비 카탈로그에서 가져온다.

## 스킬 기준과 무력화

랭크 비교는 **공격력 100 / 최대 HP 1000 / 기술 0 / 장비 없음 / 다른 패시브 없음 / 직업 조건부 자원 보정 없음**으로 계산한다. 실전 피해, 회복, 쿨타임, 적 방어력, 치명타를 한 값으로 오해하지 않도록 기준을 명시한다. 강화 노드는 원기술 3랭크를 비교 기준으로 사용한다. 원기술과 별개의 공격이 아니므로 강화 노드 자체의 무력화는 0이다.

`skill_ranks.stagger_base`는 랭크 성장을 적용하고 기술 능력치를 적용하기 전 무력화량이다. `stagger_value`는 기술 보너스까지 적용한 값이다. 기준 기술 0에서는 둘이 같다. 실제 계산은 `BossStagger.skill_profile()`과 공유하며 기술 보너스는 `1 + 0.60 × T / (T + 60)`이다. T에는 장비 기술 옵션이 포함된다. 도감 수치는 한 번의 시전 예산이며 다단 공격이나 지속 피해가 매 타격마다 전체 예산을 다시 주는 뜻이 아니다. 실제 적중, 시전당 분할 예산, 보스 상태에 따라 무력화가 적용된다.

보스·레이드의 `stagger`(SQLite는 `stagger_json`)에는 런타임 초기화에서 읽은 일반 무력화 요구량, 체크 요구량, 넘어짐·유예·체크 시간, 넘어졌을 때 피해 배율이 있다. 전투 중의 누적값이 아니라 새 보스의 기준 설정이다.

## 원본과 재생성

실행 모델은 [game_database.gd](../game/scripts/game_database.gd)이다. 장비는 `equipment_catalog.gd`, 몬스터는 `world_catalog.gd`, 층별 성장과 레이드 확률은 `abyss_catalog.gd`, 드랍은 `data/drop_tables.json`, 스킬은 `skill_catalog.gd`와 `data/jobs/catalog.json`을 읽는다. 랭크 값은 실제 전투에 쓰이는 `job_balance.gd`·`skill_scaling.gd`, 무력화는 `boss_stagger.gd`에서 계산한다.

프로젝트 루트에서 Godot 4.6과 Python 3 표준 라이브러리로 실행한다. 첫 체크아웃이면 에셋 import가 먼저 필요하다.

```powershell
$env:GODOT_EXE='D:\SSRPG\RPG2\tools\godot\Godot_v4.6-stable_win64_console.exe'
& $env:GODOT_EXE --headless --path game --editor --import
python tools/build_database.py
python tools/build_database.py --check
python tools/run_hidden_check.py database_v03
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
