# V0.5 원화 자산 DB

원화 담당자는 파일과 프레임을, 게임 담당자는 장비·스킬·층의 소비 관계를 같은 DB에서 찾는다. [JSON](database/stelrpg-database.json)과 [SQLite](database/stelrpg.sqlite)에 기존 게임 테이블과 `art_sources`, `art_files`, `art_assets`, `art_uses`를 함께 저장한다. 이미지 파일을 DB 안에 복제하지 않는다.

## 적용과 준비의 구분

- **applied**: 게임 카탈로그나 실제 기능의 소비 경로에 연결됨. `runtime_mapping` 관계가 있다.
- **available_catalog**: 완료된 runtime 카탈로그의 준비 영역. `catalog_available` 관계만 있으며 현재 플레이에서 사용된다는 뜻이 아니다.

전체 아이콘 168개와 새 캐릭터 33종·528프레임을 조회할 수 있다. 새 캐릭터 중 플레이어용 30종은 16프레임씩 사용하며 NPC 전용 3종은 대기 1프레임씩 사용한다. NPC의 나머지 45프레임은 준비 영역으로 기록한다. 등록 상태는 선택 가능한 직업과도 별개다. 플레이어 원화의 `art_uses.class_id`와 `mapping_json`에 실제 허용 직업·avatar/costume 선택을 기록한다. NPC 전용 권총 외형에 플레이어 직업 관계를 만들지 않는다.

새 장비 115영역은 실제 장비 정의 2,500개와 연결한다. 108개 장식은 마을·튜토리얼·100개 층, 새 몬스터 18종과 보스 6종의 48키포즈는 층별 출현에 연결한다. 새 바닥은 사용 중인 6재료의 `sample_rect`를 등록하고 `metadata_json.authored_rect`에 원래 512×512 패널을 남긴다. 18계열 VFX는 PNG가 아니라 절차형 코드이므로 프레임 영역은 없고 `.gd` 파일 해시를 저장한다. 절차형 효과가 대체한 예전 직업 효과 행은 등록하지 않고, 실제 자동 효과와 동료 스프라이트는 등록한다.

미완성 테마 장비, 원본 추출 전체, 별도 팩의 미사용 벽·TileSet·미리보기는 등록하지 않는다. 기존 게임에서 계속 쓰는 캐릭터·장비·전리품·건물·몬스터·타이틀은 함께 관리한다. 프레임 재생 완료나 GPU 제출 횟수는 이 DB의 범위가 아니다. 실제 화면의 `art_usage` 계측과 구분한다.

## 읽기와 수정

SQLite는 읽기 전용으로 열어 `art_catalog` 또는 `art_usage` 뷰를 사용한다. `art_catalog`의 `runtime_sha256`은 보존된 원본 PNG/스크립트 바이트이며 `provenance_sha256`은 출처 문서의 바이트다. 장비·코스튬의 메모리 RGBA 캐시와 투명 패딩을 새로운 원화 파일로 세지 않는다. `frame=-1`은 초상, 단일 영역 또는 절차형 효과처럼 프레임 번호가 없는 경우다.

```sql
-- 현재 사용 영역과 준비 영역을 나눠 집계한다.
SELECT category,status,COUNT(*) FROM art_catalog
GROUP BY category,status ORDER BY category,status;

-- B100에서 실제 샘플링하는 바닥 재료와 레이어/테마 설정.
SELECT a.name,a.runtime_path,a.x,a.y,a.width,a.height,u.mapping_json
FROM art_catalog a JOIN art_uses u ON u.art_id=a.id
WHERE a.category='floor_tile' AND u.floor_id=100;

-- 특정 원화의 모든 직업/층/아이템 소비 위치.
SELECT target_table,target_id,consumer,usage_kind,mapping_json
FROM art_usage WHERE art_id='art:equipment:weapon_reaper_relic';

-- 준비되어 있지만 아직 게임에서 사용하지 않는 원화.
SELECT id,name,category,frame,runtime_path,provenance_path
FROM art_catalog WHERE status='available_catalog';
```

DB를 직접 수정해 게임 원화를 바꾸지 않는다. 해당 runtime 카탈로그/reader 매핑을 수정하고 에셋 import 후 프로젝트 루트에서 실행한다.

```text
python tools/build_database.py
python tools/build_database.py --check
python tools/run_hidden_check.py art_registry_v05
python tools/test_art_registry.py
```

`GODOT_EXE`는 Godot 4.6 경로를 사용한다. 해시와 관리 목록은 내보낼 때만 생성한다. 게임의 `GameDatabase.snapshot()`은 관리 확장을 실행하지 않으며, 개발 내보내기만 `snapshot(true)`를 호출한다. 파일/영역/소비 경로/출처가 바뀌면 최신 DB를 다시 만든다. `--check`는 임시 위치에서 재생성한 JSON·SQLite·스키마·매니페스트와 비교한다. 반복 중간 산출물은 `runtime`에만 두고 최종 소스 동결 후 배포용 DB를 생성한다.

검사는 카탈로그 수록 범위, 실제 장비·스킬·층 대응, 준비/사용 상태, 원본 해시·좌표, SQLite 외래키·고유 ID·무결성을 다룬다. 잘못된 파일·대상 ID·범위 밖 좌표·허위 적용 상태가 거부되는지도 확인한다. 정확한 현재 수량은 [manifest.json](database/manifest.json)에 기록한다. DB 스키마 3, 게임 저장 v7, 출시 버전 V0.5는 각각 다른 기준이다.
