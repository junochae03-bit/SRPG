# V0.5.3 초반 성장 보상 구현

통합팀 후속 확인: `progression_rewards_v053` 1,197개, `town_services_v052` 266개, `loot_v04` 422개, `qa_save_v052` 33개가 실제 엔진에서 통과했다. 여관 UI에 5개/20개 보급을 연결했고 DB 재생성도 수행했다. 아래 담당자 작성 당시의 ‘엔진 대기’는 이후 이 결과로 보완되며, 장시간 진행·최종 배포 결과는 완성도 작업 보고에서 별도로 관리한다.

요청 범위: 첫 튜토리얼 마을 도착 시 LV.2까지 부족 XP 보충, 튜토리얼 일반 드랍 장비 tier 0, 여관 물약 5개 목표 소규모 보급. 전역 XP식·강화비·보스 체력·저장 스키마를 유지한다. UI 연결과 DB 생성물 갱신은 메인이 담당한다. 개인 저장과 V06를 수정하지 않는다.

`implementation-planning`과 `completion-verification` 절차에 따라 소스 작업과 엔진 검증 상태를 분리한다. 메인이 엔진을 직렬 실행하므로 이 작업에서는 엔진을 실행하지 않는다. 아래 검토는 담당 범위의 자체 검토이며 추가 사용자 승인을 요구하지 않는다.

## 편집 파일과 순서

1. **소스 작성·정적 검토 완료 / 엔진 대기 — 튜토리얼 XP**: `game/scripts/simulation.gd`의 기존 레벨업 루프를 `apply_level_ups(p)`로 추출하고 처치 시 같은 위치에서 호출했다. `game/scripts/local_session.gd`에서 미완료 튜토리얼·5처치 이상·LV.1일 때 도착 데이터의 XP를 최소 225로 보충한다. 후보 맵에서 기존 레벨업 처리를 수행한 뒤 저장하고, 성공한 후보만 세션에 반영한다. 검토: 후보 저장 전에 원본 플레이어를 변경하지 않고 레벨업 알림도 후보 시뮬레이션에 쌓이는 경로를 확인했다.
2. **소스 작성·정적 검토 완료 / 엔진 대기 — 일반 드랍 단계**: `simulation.gd`의 장비 생성에서 `floor_number==0`, `zone==forest`, 정예·보스가 아닌 경우 tier 0을 적용했다. 기존 RNG 호출 수·드랍 판정·심층 장비 단계·정예/보스 보상을 유지했다. 검토: 기존 장비를 재정규화하거나 변경하는 경로를 추가하지 않았다.
3. **소스 작성·정적 검토 완료 / 엔진 대기 — 소규모 보급 API**: `game/scripts/town_operations.gd`에 `inn:resupply_small`, `DEFAULT_INN_OPERATION`, `INN_RESUPPLY_TARGETS`를 추가했다. 현재 수량이 5개 이상이면 줄이지 않고 10 G 휴식만 처리한다. 기존 stage/quote 거래 경로를 사용한다. 검토: 잔액·수량 검증과 후보 가방 추가 실패가 거래 반영 이전에 처리되는 경로를 확인했다.
4. **회귀 작성·인계 준비 완료 / 실행 대기**: `game/tests/progression_rewards_v053.gd`를 작성했다. 아래 엔진 명령은 메인에 전달하며 실행 결과를 받기 전 통과로 표시하지 않는다. `docs/PROGRESSION_REVIEW_V053.ko.md`에는 이전 분석과 변경 후 설계/소스값을 구분했다. UTF-8 디코딩, diff 공백, 편집 범위·산술 확인을 수행했다.

## UI 연결 계약

- 기본 추천 행동: `TownOperations.DEFAULT_INN_OPERATION` → `resupply_small`.
- 보급 목표: `TownOperations.INN_RESUPPLY_TARGETS` → `resupply_small: 5`, `resupply: 20`.
- 견적: 기존 `service_quote.gd`의 `quote(p,"inn","resupply_small")`를 사용한다.
- 견적의 `target_potions`는 선택한 목표 수량 5 또는 20이며, `outputs.potion`은 부족한 경우에만 존재한다. `result`의 처리 후 수량은 기존 보유량보다 작아지지 않는다.
- 실행: 기존 시설 행동에 `{"facility":"inn","operation":"resupply_small"}`를 전달한다. 기존 위치 조건과 원자적 거래를 유지한다.
- 소규모 비용: `10 + 15×max(0,5−현재 물약)` G. 현재 0/2/5/8/20개일 때 각각 85/55/10/10/10 G. 처리 후 수량은 5/5/5/8/20개다.
- 기존 `resupply`는 물약 20개 목표이며 비용·행동 ID를 유지한다. UI가 연결되기 전 소규모 행동의 화면 노출은 완료로 간주하지 않는다.

## 메인에서 직렬 실행할 검증

프로젝트 루트 `D:\SSRPG\publish\SRPG-v04`에서 실행한다. 아래 명령은 엔진을 호출하므로 DB 담당은 실행하지 않는다.

```powershell
python tools/run_hidden_check.py progression_rewards_v053
python tools/run_hidden_check.py qa_save_v052
python tools/run_hidden_check.py dungeon_v02
python tools/run_hidden_check.py character_creation_v04
python tools/run_hidden_check.py progression_v02
python tools/run_hidden_check.py town_services_v052
python tools/run_hidden_check.py loot_v04
```

새 테스트는 별도 `runtime/progression-rewards-v053/<고유번호>` 저장 경로만 사용한다. 치트 기반 모델 회귀를 실제 플레이 측정으로 보고하지 않는다. 새 테스트의 전체 검증 등록은 메인이 담당하며 이 작업에서 `tools/verify_v01.py`는 편집하지 않는다.

## 진행·검증 결과

- 구현 및 정적 검토: 완료. 수정한 소스 3개와 새 회귀 1개·문서 2개가 UTF-8로 정상 디코딩되며 대체문자 U+FFFD가 없다. 소스 diff 공백 검사에서 문제가 없었다. Python 산술 검산으로 변경 후 층별 레벨·XP와 보급 비용을 확인했다. 이는 GDScript 구문 검사나 엔진 회귀 통과를 의미하지 않는다.
- 엔진 회귀: 미실행, 메인 직렬 실행 대기.
- UI 연결·실제 플레이·DB 재생성·배포: 이 작업 범위 밖이며 메인에서 확인한다.

회귀에는 세 기본 직업의 실제 처치 후 첫 도착·SP 사용·재접속, XP 0/224 경계, 이미 LV.2/8인 경우, 완료된 V6/V7 기록, 저장 경로 충돌 후 재시도, 처치의 다중 레벨업, 일반 신규 드랍과 기존 제한 장비 보존, 정예·보스·다른 지형·B1/10/11/21/100 단계, 소규모·전체 보급 비용, 금화 1 G 부족, 잘못된 수량, 시설 거리, 가방의 기존 물약 묶음 유무, 보급 결과 저장을 포함했다. 실제 드랍 확률의 대량 표본 검증은 기존 `loot_v04`가 담당한다.

인계 시 소스 SHA-256:

| 파일 | SHA-256 |
|---|---|
| `game/scripts/local_session.gd` | `8b53656c4c42e8dd268ab9146bb3772ed83c531746916ece986cb240af7795a9` |
| `game/scripts/simulation.gd` | `14cbe5f41896d375f37d75988bdb8178e7ecbf6ce9b8eea87f94628ba3ebf048` |
| `game/scripts/town_operations.gd` | `ba284121aae97f72041396651739a1b7c92cd0cd958804228977d88d8e069620` |
| `game/tests/progression_rewards_v053.gd` | `0f84984a6f68a8c09a9a37c9561e9f48c32d5b0cfd4ee05e2f2889c4bcd65552` |
