# V0.5.2 DB 생성 코드 인계

진입점은 기존 `python tools/build_database.py`와 `python tools/build_database.py --check` 하나로 유지한다. `tools/game_db_rules.py`는 이 빌더가 사용하는 확장 모듈이며 별도 생성 명령이 아니다. SQLite와 portable metadata의 schema_version은4다. 런타임 snapshot의 기존 도감/아트 버전은 유지한다.

추가 테이블: facilities, item_definitions, service_operations, service_samples, service_inputs, service_outputs, service_effects, dungeon_layouts, training_rules, inventory_rules.

- 시설·NPC, 가방 규격과 물약 상한, 던전 앵커/연결/선택 순서, 훈련 영역·위치·HP·빈 통계는 실제 Godot 상수를 읽는다.
- 신규 town_operations 경로의 거래는 describe를 실행한 기준 상태 평가다. 수량1~10 중 실제 허용되는 값만 수록한다. 분해는 등급별 +0~+5, 보충은 소지물약0~상한을 평가한다. 입력/출력은 반드시 sample_id와 함께 조회한다. 가방 적합성은 이 수치 표에서 검사하지 않으며 storage_checked=false로 명시한다.
- 기존 강화·재련·판매·구매·길드·휴식은 실행 dispatcher에서 작업 ID를 발견하고 quote/실행 함수 원문과 source 심볼·해시를 보존한다. 이들은 평가된 레시피 행이 아니라 source_rule이다. 분해의 장비 소비와 회복/의뢰 초기화 등 상태 변화도 service_effects의 실제 stage/transact 규칙을 읽는다. 새 경로가 기존 분기보다 우선하며 같은 ID는 하나만 존재한다.
- 던전 생성·배치·위치 보정과 수련장 측정·회복·리셋·보상 차단은 관련 함수 원문을 보존한다. 규칙 코드는 설명·추적용이며 DB 소비자가 문자열을 실행하지 않는다. 수련장 보상 차단 구문이 바뀌면 검토 없이 계속 생성하지 않고 실패한다.
- 원본 함수와 확장 모듈이 빌더 의존성 해시에 포함되므로 원본만 바뀌어도 --check가 stale을 검출한다. 준비/외부 아트48+18종을 새 사용중 자산으로 등록하지 않았다. 허수아비 아트 registry 연결은 메인 개발의 provenance 인계와 별도로 확인한다.

DB 전용 검증:

```text
python -B tools/test_game_db.py
python tools/run_hidden_check.py database_world_rules_v052
python tools/build_database.py
python tools/build_database.py --check
```

`verify_v01.py`에도 database_world_rules_v052를 등록했다. 첫 명령은 엔진 없이 SQLite 메모리 DB로 관계·제약·잘못된 참조·단절 그래프·범위·단일 빌더 등록과 현재 원본 심볼을 검사한다. 나머지는 source freeze 이후 메인 개발이 직렬 실행한다.

작성 시 엔진 없는 Python 검사4개 통과. Godot 파싱/실행·최종 JSON/SQLite 생성·전체 회귀·커밋은 실행하지 않았으며 메인 개발 검증 대기다. legacy 작업의 정규화된 옵션 풀·수치 평가 및 동적 효과의 의미별 구조화는 이 source_rule 표현을 기반으로 후속 확장할 수 있다.
