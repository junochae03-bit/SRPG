# 탐사 중 구조와 후유증 — 메인 개발 전달 명세

작성: 2026-09-13 · 담당: 시스템 관리 · 상태: 런타임 구현 및 모델·2프로세스 협동 검사 통과, 메인 UI·전체 게이트 통합 진행 중.
대상: `D:/SSRPG/publish/SRPG-v04`. 메인 개발이 병행 작업 중이므로 아래 코드 근거는 구현 직전 다시 확인한다.

## 사용자 확정 규칙

- 탐사 중 기절한 팀원은 다른 팀원이 상호작용 키를 계속 눌러 일으킨다. 여기서 기절은 HP 0의 쓰러짐이며 일반 전투 상태이상 stun과 다르다.
- 구조로 일어난 팀원에게 공격력 감소, 방어력 감소, 최대 체력 감소가 생긴다.
- 탐사 중에는 이 후유증을 제거할 수 없다.
- 귀환 후 성당에서 공격력·방어력 감소를 제거한다.
- 귀환 후 여관에서 회복하면 최대 체력 감소를 제거한다.
- 귀환 자체는 치료가 아니다. 두 시설의 치료 효과는 독립적이다.

## 시스템 관리 보완안과 초기 수치

아래 수치는 사용자 지정값이 아닌 구현용 초기 조정안이다. 별도 승인 대기 없이 적용 가능한 기본값으로 전달하며 이후 플레이 결과로 조정한다.

|항목|초기 기준|
|---|---|
|구조 시간·거리|기존 3초, 1.8칸, 벽에 가리지 않는 거리 유지|
|구조 완료 HP|후유증 적용 후 최대 HP의 35%, 최소 1|
|구조 직후 보호|기존 무적 1초 유지|
|쇠약|물리·마법 공격력 및 물리·마법 방어력 각각 15% 감소|
|부상|최대 HP 20% 감소|
|반복 구조|동일 후유증은 중첩하지 않는다. 이미 치료된 종류는 다음 구조 때 다시 부여|
|성당 치료|쇠약 전체 제거, 초기 비용 10 G, 부상·현재 HP에는 영향 없음|
|여관 회복|현재 HP를 회복하는 여관 서비스가 부상을 제거한 뒤 정상 최대 HP까지 회복. 기존 서비스 비용 유지|

여관의 `rest`, `resupply_small`, `resupply`는 현재 모두 HP 회복을 포함하므로 같은 부상 제거 규칙을 적용한다. 추후 회복 없는 물품 구매가 생기면 치료를 붙이지 않는다. 성당은 쇠약이 없으면 치료 비활성화·무과금으로 처리한다. 자금이 부족하면 치료 상태를 바꾸지 않으며 기존 무료 회복 경로로 후유증을 없앨 수는 없다.

## 구조 입력과 예외

1. 살아 있고 행동 가능한 동료가 구조 가능 대상 근처에서 상호작용 키를 누르면 구조를 시작한다. 재지정한 키도 작동하고 안내에 실제 키를 표시한다.
2. 구조 중에는 키 유지, 구조자·대상의 상태, 거리, 시야를 호스트가 계속 확인한다. 클라이언트가 완료나 경과 시간을 확정하지 않는다.
3. 키 해제, 이동·공격·회피·스킬 입력, 피해를 받음, 거리 이탈, 시야 차단, 구조자 쓰러짐, 메뉴 진입·창 포커스 상실, 연결 종료 시 진행도를 0으로 취소한다. 입력 갱신이 끊겼을 때도 구조가 자동 완료되지 않도록 입력 만료 처리를 둔다.
4. 후보가 여러 명이면 가장 가까운 한 명을 선택하고 동률은 안정적인 ID 순서를 사용한다. 시작 후 대상을 고정한다. 여러 구조자의 진행도는 합산하지 않으며 최초 완료 한 번만 적용한다.
5. 구조 후보가 있으면 해당 키다운은 구조가 소비한다. 취소나 완료 후 키를 놓고 다시 누르기 전까지 바닥 아이템·오브젝트가 연속 작동하지 않게 한다. 구조 대상이 없으면 기존 상호작용을 유지한다.
6. 구조에 성공한 순간에만 두 후유증을 부여하고 스탯을 다시 계산한 후 HP를 설정한다. 취소된 구조에는 후유증을 추가하지 않는다.
7. 기존 20초 구조 제한, 전멸·솔로 패배 경로는 이번 요청만으로 변경하지 않는다. 이미 얻은 후유증은 패배 후 재생성·안전지대 회복에도 유지한다. 솔로 자기 구조는 추가하지 않는다.

## 스탯·저장 규칙

- 후유증은 타이머가 있는 일반 디버프와 분리한 영속 상태 두 개(예: `revival_weakness`, `revival_injury`)로 저장한다. 수치는 공통 규칙 한 곳에서 관리한다.
- 정상 스탯을 장비·성장·스킬로 계산하고 해당 공격력·방어력·최대 HP에 후유증 배율을 한 번 적용한다. 기본 스탯 투자값이나 장비 원본값을 변경하지 않는다. 공격력 감소를 최종 피해에 다시 곱하지 않는다.
- 적용·해제·재계산이 반복되어도 누적 감소나 복구 초과가 생기지 않아야 한다. 최대 HP는 최소 1, 방어력은 최소 0을 보장한다.
- 물리·마법 공격, 일반 공격·스킬·직업별 공격력 경로가 같은 후유증 반영 스탯을 쓰는지 확인한다. 고정 피해의 성격은 기존 규칙을 유지한다.
- 레벨업, 장비 교체, 물약·회복·정화 스킬, 던전 휴식, 층 이동, 귀환, 저장 후 재실행, 협동 종료가 후유증을 없애지 않아야 한다. 회복은 감소한 최대 HP까지만 가능하다.
- 저장·불러오기 및 협동 체크포인트에 두 상태를 포함한다. 구 저장은 둘 다 false로 이관한다. 잘못된 타입 검증은 기존 저장 검증 정책을 따른다.
- 저장 버전은 병행 중인 스탯 개편 등과 합쳐 한 번에 정한다. 이 문서가 임의 버전 번호를 선점하지 않는다.
- 시설 비용과 치료는 기존 staged 거래 흐름에서 함께 처리하고 중복 요청으로 중복 차감하지 않는다. 실패 시 비용·상태 변경과 저장 실패 재시도는 기존 거래 정책을 유지한다.

## UI 기준

- 구조 대상 근처: `[현재 상호작용 키] 길게 눌러 구조 · 3초`와 진행 막대.
- 파티 HUD·캐릭터 정보: `쇠약: 공격력·방어력 -15% / 성당에서 치료`, `부상: 최대 체력 -20% / 여관에서 회복`을 각각 표시한다. 시간 제한 아이콘으로 표시하지 않는다.
- 체력바와 상세 정보에 현재 유효 최대 HP와 부상으로 줄어든 양을 식별할 수 있게 표시한다.
- 귀환·재출발 안내에서 남아 있는 후유증과 해당 시설을 알려주되 출발을 강제로 막지 않는다.
- 성당의 마을 위치·NPC·상호작용·시설 화면을 실제 접근 가능하게 추가한다. 전용 그래픽이 아직 없으면 기존 적합한 임시 아트를 쓰고 미완성 아트 범위를 결과에 명시한다.

## 확인한 코드와 구현 순서

|순서|컴포넌트·현재 근거|필요 작업|
|---|---|---|
|1|`game/scripts/party_rules.gd`: 구조 3초·거리 1.8·HP 35%·무적 1초|후유증 공통 규칙 추가, 상태 모델과 재계산 진입점 확정|
|2|`simulation.gd`: `add_player`, `persistent`, `player_defeated`, `respawn_player`; `local_session.gd`: `validate_save`; `coop_session.gd`: 체크포인트|영속 상태·구 저장 이관·층 이동과 귀환 보존부터 구현|
|3|`main.gd`: `_unhandled_input`; `key_bindings.gd`: 눌림 이벤트만 반환; `simulation.gd`: 구조 시작과 자동 진행|키 유지·취소·입력 만료 및 호스트 판정 구현. `monster_attacks.gd` 기존 구조 취소와 통합|
|4|`simulation.gd`·`player_combat.gd`·`job_combat.gd`; `player_stats.gd`·`combat_stats.gd`|실제 공격·방어·HP 계산 경로 추적 후 배율 단일 적용과 표시 일치|
|5|`world_catalog.gd`: 성당 없음; `town_services.gd`, `town_operations.gd`, `service_quote.gd`, `town_panel.gd`, `npc_dialogue.gd`|성당 등록·치료 거래, 여관 회복 순서 수정, 시설별 효과 분리|
|6|`main.gd`, `party_hud.gd`, `status_strip.gd` 등|진행도·후유증·치료 안내 추가, 시설 아트와 길찾기 확인|
|7|`game_database.gd`, `tools/verify_v01.py`, `docs/PLAY_CURRENT.ko.md`|DB 규칙·조작 안내·회귀 검사 반영 후 결과 보고|

## 완료 기준과 검증

- 탭 입력과 3초 미만 유지로 구조되지 않으며 3초 연속 유지 시 1회 구조된다. 키 재지정과 취소 조건들을 실제 입력으로 확인한다.
- 정상 공격력 100, 방어력 100, 최대 HP 1000인 대상은 구조 후 85/85/800, HP 280이 된다. 반복 구조·스탯 재계산으로 추가 감소하지 않는다.
- 부상 상태에서 정상 최대 HP가 장비 교체로 1200이 되면 유효 최대 HP는 960이며 현재 HP가 이를 넘지 않는다.
- 탐사 회복·정화·휴식, 패배·층 이동·귀환·재실행·협동 종료 후에도 두 상태가 유지된다.
- 성당만 이용하면 100/100/800, 여관만 이용하면 85/85/1000, 두 시설을 어떤 순서로 이용해도 100/100/1000이 된다. 한 종류 치료 뒤 재차 구조되면 두 종류 모두 다시 존재한다.
- 여관 회복은 부상을 먼저 제거하고 정상 최대 HP까지 채운다. 성당은 부상을 제거하거나 HP를 채우지 않는다.
- 호스트·게스트 구조, 동시 구조, 구조자/대상 연결 종료, 입력 끊김·중복 요청을 검증한다. 타인의 비용·치료 상태를 변경할 수 없어야 한다.
- 구 저장 불러오기, 후유증 저장 후 복원, 시설 거래 실패·자금 부족을 검사한다. 새 회귀 검사는 기존 완료 증거 검사와 전체 게이트에 등록한다.
- 실제 화면에서 구조 막대·HP 감소·후유증 두 종류와 두 시설의 치료 결과를 확인한다.
- 확인된 전체 게이트: 대상 저장소에서 `python tools/verify_v01.py`. `tools/engine_path.py`가 요구하는 Godot 4.6 경로는 기존 메인 개발 환경의 `GODOT_EXE`를 사용한다. 새 검사 이름·번호는 구현자가 등록한 후 실행하며 이 문서에서는 미실행이다.

## 전달 및 진행 기록

- 시스템 관리: 현재 입력·구조·저장·시설 코드 확인, 사용자 규칙과 초기 조정안 분리, 위 검증 기준 작성 완료.
- 메인 개발: 2026-09-13 기존 `메인 개발` 작업에 명세 경로·구현 요청·검증 기준 전달 완료. 구현·플레이 검증·전체 게이트 결과는 아직 확인되지 않았다.
- 롤백: 코드 되돌림으로 기존 저장의 후유증을 조용히 삭제하지 않는다. 저장 형식 변경 전 개발용 복사본을 보관하고 버전 호환 정책을 확인한다.

## 메인 요청에 따른 현행 함수 점검 — 2026-09-13

메인의 아트·DB 통합 중 읽기 전용으로 재확인했던 기록이다. 아래는 구현 전 스냅샷이며 후속 구현 결과는 문서 마지막 기록을 따른다. 이 점검 단계에서는 이 문서만 수정했고 런타임 코드 수정·엔진 실행은 하지 않았다. 3차 전직은 보류 범위다. 줄 번호는 병행 편집으로 바뀔 수 있어 함수명을 기준으로 찾는다.

### 입력과 구조: 반드시 함께 고칠 경로

|현행 함수|확인한 동작과 적용 지점|
|---|---|
|`key_bindings.gd::action_for_event`, `is_pressed`|이벤트 함수는 pressed만 반환하고 release·echo는 버린다. `is_pressed("interact")`로 유지 상태를 읽되 시작 이벤트와 구분한다. 기존 키 재지정을 그대로 따른다.|
|`main.gd::_physics_process`|0.05초마다 `session.send_input(direction, aim, sprint)`를 호출한다. 여기에 상호작용 유지 상태를 전달할 수 있다. `can_act`는 현재 paused·텍스트 포커스만 보므로 창 활성 상태와 메뉴 차단도 포함한다. bot/playtest 별도 입력 경로도 확인한다.|
|`main.gd::_unhandled_input`, `_notification`|interact는 단발 `session.act`로 전송된다. 창 포커스 상실은 현재 `cancel_charge()`만 호출한다. 구조 전용 취소를 추가해야 하며 release를 UI가 소비해도 취소되어야 한다.|
|`local_session.gd::send_input`, `coop_session.gd::send_input`, `receive_input`, `simulation.gd::set_input`|현재 direction/aim/sprint만 전달한다. 전체 체인에 hold를 추가한다면 기존 호출 호환 기본값은 false로 두되 실제 구조 호출자는 명시적으로 갱신한다. RPC 송신·수신 시그니처를 함께 변경하고 현행 `PROTOCOL=15`와 메인의 다른 프로토콜 변경을 통합한다.|
|`local_session.gd::act`, `coop_session.gd::host_action`|출구 2.8칸 이내 interact를 `Simulation.action`보다 먼저 층 이동으로 처리한다. 구조 후보 우선 판정을 이 상위 계층에도 반영해야 한다. 게스트는 출구 근처에서 구조 대신 방장 전용 이동 안내를 받는 경우가 생길 수 있다.|
|`simulation.gd::action`|downed 후보 배열 첫 원소를 선택하고 즉시 진행도 0을 설정한다. 최근접·동률 ID 정렬, 현재 구조 중 재시작 방지, 시작 입력 소비가 필요하다. 현재 `cancel_charge`는 구조 취소 분기에서 제외된다.|
|`simulation.gd::set_input`, `tick`|입력마다 `input_age=0`, 움직이면 구조를 취소한다. `tick`은 구조를 먼저 진행한 뒤 input_age를 증가시키며 0.35초 초과 시 이동·달리기만 정지한다. 입력 나이 증가·만료·hold 검사를 구조 누적보다 먼저 해야 마지막 프레임 자동 완료를 막는다. 기존 0.35초 만료를 우선 재사용한다.|
|`simulation.gd::tick`, `monster_attacks.gd::damage`|구형 적 공격 경로와 패턴 공격 경로가 각각 revive 필드를 지운다. 공통 취소 함수를 도입하면 두 경로를 함께 연결한다. 패턴은 피해량 0 이하일 때 취소하지 않지만 구형 경로는 무조건 취소하므로 ‘실제 피해를 받음’ 기준도 일치시킨다.|
|`simulation.gd::player_defeated`, `reset_after_defeat`, `respawn_player`; `coop_session.gd::start_departure`, `peer_left`|다운·재생성·연결 종료 시 구조 런타임만 정리하고 영속 후유증은 보존한다. `start_departure`가 켠 network_leaving 대상을 구조 후보·계속 유효성 판정에서 제외한다.|

hold 입력은 unreliable_ordered 채널 1이고 action은 reliable 채널 2이므로 서로 도착 순서가 보장되지 않는다. 시작 요청이 hold보다 먼저 도착한 경우 즉시 영구 취소하거나 오래된 hold=true로 구조하지 않도록 입력 세대/시퀀스와 유효한 시작 시점을 정한다. 사용자가 이미 키를 놓은 뒤 지연된 시작 요청이 들어와도 완료되지 않아야 한다. 여러 틱에 걸쳐 입력을 받는 검사를 실제 RPC 경로로 수행한다.

### 영속 필드·재계산·시설 거래

|현행 함수|확인한 동작과 적용 지점|
|---|---|
|`simulation.gd::add_player`, `persistent`|현행 저장 버전 7이며 저장·복원 모두 명시 필드 목록이다. 두 bool을 양쪽에 넣고 최초 `recalculate` 전에 복원한다. `add_player`는 계산 후 HP를 max_hp로 채우므로 감소된 최대 HP가 먼저 확정되어야 한다. revive_target/progress/hold는 저장하지 않는다.|
|`local_session.gd::validate_save`, `enter_saved`, `save_game`, `change_map`|검증은 현재 버전 1~7만 허용한다. 구 저장 필드 누락은 false, 존재하는 잘못된 타입은 거부한다. change_map은 persistent→add_player 후 이전 HP를 새 최대 HP로 제한하므로 후유증 누락 시 층 이동으로 사라진다. 개인 저장 원본을 직접 검사 데이터로 변경하지 않는다.|
|`coop_session.gd::register_player`, `change_map`, `publish_checkpoints`, `receive_checkpoint`, `start_departure`, `exit_checkpoint`|입장 검증, 게스트 지도 재구성, 주기 체크포인트, 퇴장 최종 저장 모두 같은 두 필드를 보존해야 한다. 클라이언트 저장은 자기 Simulation이 아니라 검증된 latest_checkpoint를 사용한다. 구조·치료 후 dirty를 기록해 체크포인트가 나가게 한다.|
|`simulation.gd::snapshot`, `coop_session.gd::receive_snapshot`|플레이어를 복제한 뒤 타인의 비공개 필드를 제거하는 구조라 후유증은 공개 상태로 복제 가능하다. 파티원 HUD에 필요한 후유증·유효 최대 HP는 남기고 입력 세대 같은 내부 제어 필드는 공개 여부를 별도 판단한다.|
|`simulation.gd::damage_for`|현재 레벨·성장·스킬·장비 공격력을 합산해 반환하는 공통 지점. 여기서 쇠약 배율을 한 번 반영한다. `player_combat.gd` 일반/강공격, `active_skills.gd::_cast`, `job_combat.gd::direct_manifestation_hit`, `act`, `_execute`, `constellation_effects.gd`의 damage_for 호출도 동일하게 영향받는다.|
|`job_combat.gd::attack_power`, `outgoing`; `player_combat.gd::hit`|attack_power는 공격 버프·공격 물약 배율을, outgoing은 추가 피해 보정을 적용한다. 이곳에 쇠약을 다시 곱하지 않는다. 반사 등 damage_for를 통과하지 않는 고정 피해를 임의로 낮추지 않는다. 표시용 `combat_stats.gd::rows`도 damage_for→attack_power를 사용한다.|
|`simulation.gd::recalculate`, `gear_changed`, `apply_level_ups`|max_hp와 defense를 원본 구성에서 다시 계산한 뒤 magic_defense=defense를 대입한다. 양 방어가 완성된 후 각각 쇠약을 한 번 반영하고 max_hp에 부상을 반영한다. 스탯 개편에서 양방어가 분리되면 동일 대입 방식으로 덮어쓰지 않는다.|
|`simulation.gd::recalculate`의 HP 보정|현재 `clampi(hp + new_max - old_max, 1, new_max)`이다. 다운 중 재계산이 HP 1을 만들지 않도록 hp=0 보존이 필요하다. 구조 완료는 상태 부여→재계산→down 해제와 35% HP 설정 순서로 명시 처리한다. 여관은 부상 해제→재계산→최대 HP 회복, 성당은 HP 보존이다. 일반 장비 교체의 기존 HP 보정은 유지하되 재계산만 반복해 추가 회복되지 않아야 한다.|
|`progression.gd::mitigation`, `received`|magic_defense 또는 defense를 이용해 방어율을 계산한다. 두 적 피해 경로가 received를 사용하므로 감소된 방어 스탯을 넣으면 된다. 받는 피해에 15% 추가 배율을 붙이는 방식은 요구와 다르다.|
|`town_services.gd::transact`|town인지와 `World.nearest(p.pos)==facility`를 검증한다. TownOperations 분기와 일반 staged 분기에 각각 필드 복사 목록이 있으므로 두 목록 모두 후유증 필드를 포함해야 한다. 현재 마지막 `sim.gear_changed(p)` 재계산과 여관 치유 순서가 충돌하지 않게 한다.|
|`town_operations.gd::handles`, `describe`, `stage`, `quote`; `service_quote.gd::quote`|rest는 TownServices 직접 분기, resupply 두 종류는 TownOperations stage 분기다. 세 서비스 모두 부상 해제·정상 최대 HP 회복을 구현한다. 견적은 실제 플레이어를 변경하지 않고 치료 후 최대 HP를 표시해야 한다. stage는 sim 인자가 없으므로 공통 순수 스탯 계산 또는 거래 계층의 일관된 재계산 경로를 정한다.|
|`coop_session.gd::receipt_values`; `town_panel.gd::receipt_changes`|현행 거래 영수증은 gold/hp 등을 포함하지만 후유증·max_hp는 없다. 두 상태·최대 HP의 before/after를 전달해 ‘금화 차감만 표시된 치료’가 되지 않게 한다. receive_action의 serial 중복 거부와 패널 pending_receipt를 재사용한다.|

### 성당 연결과 접근성

- `world_catalog.gd::FACILITIES`, `RESIDENTS`, `resident_pos`, `nearest`에 `church`와 주민을 추가하는 방식을 권장한다. 현행 시설은 smith/shop/alchemy/guild/inn/portal/costume/training이고 성당은 없다. 최종 좌표는 아트 통합 결과에 맞춰 메인이 정하며 이 문서는 점유하지 않는다.
- `dungeon.gd::generate_town`은 FACILITIES를 순회해 건물 footprint와 마을 길을 생성한다. 기존 시설·스폰·동쪽 수련장과 겹치지 않고 성당 주민 위치까지 걸어갈 수 있어야 한다. `main.gd::draw_building`, `draw_resident`, `draw_town_guidance` 및 FACILITIES 순회 렌더링도 확인한다.
- `town_panel.gd::open`은 시설별 기본 operation 사전을 `[key]`로 직접 접근한다. `church`를 월드에만 넣으면 오류가 나므로 기본 operation과 `refresh` 분기를 함께 추가한다. `npc_dialogue.gd::open`, `open_service`로 진입되는 치료 화면과 서비스 버튼 문구도 연결한다.
- `ui_art.gd::facility`는 6개 고정 키 배열에서 인덱스를 찾으며 새 키는 -1이다. 성당 등록 시 명시적인 유효 아틀라스/임시 아이콘 매핑이 필요하다. 시설 추가만으로 올바른 아트가 자동 생성되지 않는다.

### 권장 적용 단계와 추가 필수 회귀

1. **영속 상태·스탯부터 통합:** 사용자 규칙을 공통 함수/규칙으로 만들고 저장 복원·snapshot·checkpoint에 연결한다. 정상/쇠약/부상/둘 다의 4상태, 재계산 멱등성, 다운 HP 0 보존, 구 저장 및 잘못된 타입 거부를 검사한다. 병행 중인 스탯 DB 이관과 같은 저장 버전으로 정리한다.
2. **구조 hold 체인 통합:** 입력→세션→RPC→Simulation을 한 번에 연결한다. 만료 0.35초 검사 선행, 3초 경계, 2.9초 후 끊김, 시작/release 순서 역전, 창 포커스·개인 메뉴·채팅, 타깃 이탈·network_leaving, 최근접 타깃 선택, 두 구조자 동시 완료를 검사한다. 출구와 바닥 드롭이 겹치는 위치에서도 구조가 우선이어야 한다.
3. **두 시설 연결:** 두 staged 커밋 목록, rest/resupply 두 경로, 견적/실제 결과/영수증 일치, 쇠약 없는 성당 무과금, 부족한 금화·가방 부족 거래 실패 시 완전 보존을 검사한다. 성당→여관과 여관→성당 순서, 부상 해제 뒤 HP 정상 최대치 회복을 검사한다.
4. **기존 검사 갱신:** `game/tests/coop_rules.gd`, `combat_lifecycle.gd`는 현재 interact 한 번 후 31×0.1초 tick만으로 구조를 기대한다. 성공 사례는 매 틱 유효 hold 입력을 주도록 바꾸고 옛 탭 사례는 실패를 기대하는 회귀로 남긴다. `combat_lifecycle_network.gd`도 현재 `session.act("interact")` 한 번만 보내므로 실제 게스트 hold 갱신으로 변경한다. 기존 쿨다운·버프 정리·사망 페널티 검증은 보존한다.
5. **주변 회귀와 실제 협동:** `town_services_v052`, `qa_save_v052`, `legacy_save`, `keyboard_ui_v051`, `town_clarity_ui_v052`, `town_renewal_visual_v052` 등 관련 기존 검사를 실행한다. 시설 수/키 고정 가정도 함께 점검한다. 새 검사 파일을 만들면 `tools/godot_test_completion.py` 완료 마커와 `tools/verify_v01.py` 실행 등록을 같이 추가한다.
6. **메인 단독 엔진 검증·보고:** 전체 게이트 후 실제 프로세스 협동 검사를 포함한다. 확인된 도구는 `python tools/run_coop_check.py --lifecycle`, `python tools/run_coop_check.py --closing-race`이며 이 명세 작성 중에는 실행하지 않았다. 필요하면 기존 네트워크 검사에 치료·재입장 후 보존 사례를 확장한다. 실패 로그 수정까지 완료하고 명세 상태를 구현 완료로 바꿀 때 검증 기록 경로를 남긴다.

추가 경계: 일반 구조 취소는 후유증을 만들지 않는다. 구조 실패로 기절 제한 시간이 끝나는 것은 기존 패배 동작이며 신규 후유증 부여와 혼동하지 않는다. 성당은 회복량을 바꾸지 않고, 감소한 최대 HP가 가득 찬 상태여도 여관 치료는 부상 제거와 실제 최대 HP 회복을 수행해야 한다. 검사 통과 주장과 읽기 전용 코드 확인을 구분한다.

## 후속 실제 구현·검증 기록

메인의 실제 구현 위임 이후 `feature/v071-crafting`에서 소유 파일에 구현했다. 제작 큐, 스탯 개편, 저장 세대 8을 보존했다. 메인이 추가 위임한 신규 재료별 저장 상한, 장비 제작 라우트, `reward_kill`의 신규 재료 드롭 호출도 연결했다. 3차 전직·커밋·운영 DB 생성은 수행하지 않았다.

- `revival_aftereffects.gd`: 비중첩 영속 bool 두 개, 공격/방어/최대 HP 계산, 구조 후보·hold·취소·만료, 여관 치료·UI 설명과 초기 조정안 metadata를 제공한다.
- 구조 시작은 서버에서 **같은 unreliable_ordered 입력 스트림의 hold 상승 에지**에만 반응한다. 기존 단발 interact는 후보가 있으면 소비하며 구조를 시작하지 않는다. 이에 따라 입력/action 채널 간 순서 역전으로 지연된 단발 요청이 구조를 시작할 수 없다. 입력 만료 0.35초를 진행도 계산 전에 검사하고, 취소 후 계속 누르고 있어도 재시작하지 않는다.
- 층 출구에서도 구조를 먼저 소비한다. 구조 완료 시 상태 부여→스탯 계산(다운 HP 0 유지)→다운 해제·감소한 최대 HP의35% 회복을 처리한다. 저장·지도 재생성·스냅샷·체크포인트·퇴장 저장에 후유증을 유지한다.
- 성당 `church:treat`는 (31,9)의 별빛 성당과 사제 엘린을 통해 쇠약만10G에 치료한다. 기존 건물 art3·치유사 아바타를 재사용한다. 생성된 마을 길과 주민 접근 가능성을 검사했다.
- 여관 `rest`도 공통 TownOperations 견적/거래 경로로 통합했고 resupply_small/resupply와 함께 부상만 제거한다. 두 staged 커밋 목록에 상태를 복사하고 정상 최대 HP까지 회복한다. 견적은 원본 플레이어를 바꾸지 않는다.
- 메인이 승격 권한을 추가 위임해 협동 프로토콜을18로 변경하고 `coop_old_version.gd`는17로 접속하도록 바꿨다. 기존 `coop_rules`, `combat_lifecycle`, `combat_lifecycle_network`의 구조 성공 사례에 실제 hold 갱신을 추가했다.
- 필수 UI 연결은 `docs/design/REVIVAL_UI_HANDOFF.ko.md`로 전달했다. 메인에서 main 입력·포커스·구조 막대, 성당 버튼·시설 아이콘·NPC·거래 영수증·DB 연결을 적용했다고 회신했다. 파티/캐릭터 후유증 표시, 귀환/출발 안내, 실제 화면 확인과 전체 게이트 등록·실행은 메인 최종 통합에서 확인해야 한다.

검사 결과:

|검사|결과|근거|
|---|---|---|
|후유증 모델·저장·후보/취소·거래·마을 접근|62개, 실패0|`runtime/revival-models-1789295355248855300/revival_aftereffects.log`|
|기존 파티 규칙|20개, 실패0|같은 디렉터리 coop_rules.log|
|기존 전투 생명주기|330개, 실패0|같은 디렉터리 combat_lifecycle.log|
|기존 마을 거래|266개, 실패0|같은 디렉터리 town_services_v052.log|
|실제2프로세스 협동: 양방향 구조·분리치료·귀환·최종 퇴장 저장|호스트31개+게스트36개, 실패0|`runtime/revival-network-1789295275237979700/host/run.log`, guest/run.log|
|기존6인 협동 생명주기 + 구프로토콜17 거절|PASS|`runtime/coop-check-1789295447913455400` · `python tools/run_coop_check.py --lifecycle --old-client`|

재현 명령은 `GODOT_EXE`를 기존 Godot4.6 경로로 설정한 뒤 `python tools/check_revival_models.py`, `python tools/check_revival_network.py`이다. 샌드박스 내 첫 Godot 실행은 시작 직후 signal11로 충돌했고 해당 프로세스를 종료한 뒤 승인된 외부 실행으로 통과했다. 최초 네트워크 테스트 데이터의 불일치한 층 해금값은 수정했으며 게임 저장 검증을 약화하지 않았다. 위 검사는 전체 출시 게이트·최종 UI 시각 검증을 대신하지 않는다.
