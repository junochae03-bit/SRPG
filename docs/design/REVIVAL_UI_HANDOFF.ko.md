# 후유증 구현 UI 연결 패치 — 메인 적용용

시스템 담당은 아래 공통 UI 파일을 수정하지 않았다. 현재 제작 패널·투사체 변경에 다음 호출을 통합한다. 런타임 저장 버전8을 보존했다. 후속 메인 위임으로 시스템 담당이 프로토콜18 전환과 구17거절 검사, 기존3개hold회귀 갱신까지 완료했다. 아래 UI는 메인 소유이며 입력·성당 연결은 메인 적용 회신을 받았다. 파티/캐릭터/귀환·출발 후유증 표시와 최종 시각 검증은 메인이 확인한다.

## main.gd

`_physics_process`에서 기존 can_act에 창 활성 조건을 추가하고 입력 전송을 변경한다.

```gdscript
var can_act=not session.paused and not text_input_focused() and get_window().has_focus()
# 기존 direction/aim 계산 유지
session.send_input(direction, aim, can_act and keybindings.is_pressed("sprint"), can_act and keybindings.is_pressed("interact"))
```

`_notification`의 기존 focus-out `session.cancel_charge()`는 런타임에서 구조도 취소하도록 연결했다. 단발 `session.act("interact")`는 유지해도 된다. 구조 대상 근처에서는 소비만 하고, 실제 구조 시작은 hold 스트림의 상승 에지에만 일어난다. 해제/취소 뒤에는 키를 놓고 다시 눌러야 한다.

`draw_actor` 등 현재 down_time/revive_progress를 그리는 위치의 하드코딩 E를 아래와 같이 실제 키로 대체한다. 진행도 텍스트 아래 막대는 기존 draw_rect를 사용한다.

```gdscript
if p.get("down_time",0)>0:
    text_at(point+Vector2(0,-35),"%s 길게 눌러 구조 · %d초"%[keybindings.label("interact"),ceili(p.down_time)],18,Color("ffd780"),true)
elif p.has("revive_target"):
    var ratio=clampf(float(p.get("revive_progress",0))/3.,0.,1.)
    text_at(point+Vector2(0,-35),"구조 중 %.1f / 3초"%float(p.get("revive_progress",0)),18,Color("9ce3cf"),true)
    draw_rect(Rect2(point+Vector2(-48,-20),Vector2(96,5)),Color("334b4b"))
    draw_rect(Rect2(point+Vector2(-48,-20),Vector2(96*ratio,5)),Color("9ce3cf"))
```

파티/캐릭터 HUD에는 `preload("res://scripts/revival_aftereffects.gd").summary(p)`를 표시한다. 두 줄 최대이며 빈 문자열이면 숨긴다. 상세 체력 표시에는 `normal_max_hp(p)`와 `p.max_hp` 차이를 ‘부상으로 감소’라고 표시한다. 귀환·재출발 화면에도 summary를 재사용하되 출발을 막지 않는다.

## town_panel.gd

- `open` 기본 operation 사전에 `"church":"treat"` 추가.
- `refresh` 시설 match에 `"church":church(p)` 추가.
- `inn`의 rest 서비스 카드 설명은 `Quote.quote(p,"inn","rest").result` 사용. 기존 감소된 `p.max_hp`만 표시하지 않는다. rest/resupply_small/resupply 세 종류 모두 서버에서 부상 해제 후 정상 최대 HP까지 회복한다.
- 신규 화면은 기존 서비스 카드/선택·검토 흐름을 재사용한다.

```gdscript
func church(p:Dictionary):
    var q=Quote.quote(p,"church","treat")
    service_card(body,"treat","쇠약 치료 · %d G"%q.cost,q.result,"guild",Vector2(0,70),func():choose("treat"),operation=="treat",158)
```

`Quote`는 TownOperations를 경유하므로 service_quote.gd 추가 분기는 필요 없다. 쇠약 없는 경우 q.reason이 있어 치료가 비활성화되어야 하며 런타임도 무과금 거부한다. `receipt_changes`에는 다음 차이를 추가한다. 협동 영수증은 두 bool과 max_hp를 포함하도록 구현했다.

```gdscript
if before.get("revival_weakness",false) and not after.get("revival_weakness",false):rows.append("쇠약 치료")
if before.get("revival_injury",false) and not after.get("revival_injury",false):rows.append("부상 치료 · 최대 생명력 회복")
```

## 시설 아트·NPC·DB

- world_catalog에 `church`=(31,9), 건물 기존 art=3, 높이440, 사제 아바타 gat_role_healer_2를 등록했다. 현재는 기존 건물·치유사 아트 재사용이다. 생성된 길과 주민 접근성은 신규 모델 검사에서 확인한다.
- `ui_art.gd::facility`에서 `key=="church"`를 기존 `guild` 아트로 명시 매핑한다. 가장 간단한 적용은 함수 첫 줄 `if key=="church":return facility("guild")`이다. 고정 6키 배열의 index=-1로 보내면 안 된다.
- `npc_dialogue.gd::STORIES`에 쇠약은 성당, 부상은 여관 설명을 추가하고 서비스 버튼 문구 매핑에 `"church":"쇠약을 치료한다"`를 추가한다. World.RESIDENTS 등록은 이미 되어 있다.
- `game_database.gd`의 metadata에 `db.metadata["revival_aftereffects"]=preload("res://scripts/revival_aftereffects.gd").configuration()` 추가. configuration은 수치가 초기 조정안임을 `balance_status=initial_proposal`로 표시한다.

## 기존 검사 수정·신규 검사 등록

- `coop_rules.gd`, `combat_lifecycle.gd`의 구조 성공 tick 반복에서 매 틱 `sim.set_input(2,Vector2.ZERO,Vector2.RIGHT,false,true)`를 먼저 보낸다. interact 후 자동진행하던 옛 성공 사례는 신규 검사에서 실패 조건으로 남겼다. 이동 취소 검사도 먼저 hold=true로 실제 구조를 시작하도록 바꾼다.
- `combat_lifecycle_network.gd`의 게스트 구조는 기다리는 동안 0.05초마다 `session.send_input(Vector2.ZERO,Vector2.RIGHT,false,true)`를 전송하고 완료 후 false 전송한다.
- 신규 `game/tests/revival_aftereffects.gd` 출력은 `REVIVAL_AFTEREFFECTS_TESTS checks=N failures=N`. `tools/godot_test_completion.py`의 `_STANDARD`와 `verify_v01.py` 실행 목록에 `revival_aftereffects`를 등록한다.
- 신규 실제 2프로세스 검사 `python tools/check_revival_network.py`는 자체 로그·독립 저장·엄격한 종료 판정을 제공한다. 슬롯 확보 후 시스템 담당이 실행한다.
- 런타임 함수 변경으로 기존 UI 입력만 연결하지 않으면 구조는 의도대로 완료되지 않는다. 이 패치는 선택적 미관 작업이 아니라 기능 완성에 필수다.
