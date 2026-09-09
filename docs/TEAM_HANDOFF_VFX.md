# VFX 작업 인계

작업 위치: `D:/SSRPG/publish/SRPG`. 도감·DB·무력화 작업 위치는 공유받은 `D:/SSRPG/publish/SRPG-v03`, 브랜치 `feature/codex-stagger-v03`이다. 별도 릴리스나 다른 작업본 덮어쓰기는 수행하지 않는다.

공유받은 V0.2 기준은 `6e6e6bb` / `V0.2`다. 이 작업 폴더의 확인된 HEAD는 `d627a6e`이고 기존 V0.2 수정이 작업 트리에 함께 있으므로 **이 폴더 전체 diff나 active_skills.gd 전체 파일을 그대로 병합하지 않는다.** 아래 VFX 변경만 선택한다.

## 변경 파일

새 런타임 파일:

- `game/scripts/skill_vfx_catalog.gd` (+ `.uid`): 18종 효과 계열·팔레트와 기본/전직 스킬 매핑.
- `game/scripts/skill_vfx.gd` (+ `.uid`): 수명 기반 절차형 애니메이션, 차지·이동·범위 추적, 스킬 투사체 그림. 피해를 발생시키지 않는다.
- `game/scripts/vfx_gallery.gd` (+ `.uid`), `game/vfx_gallery.tscn`: 18종 반복 재생 갤러리.
- `Preview-Skill-Effects.cmd`: 갤러리 실행기.

기존 파일의 좁은 통합 변경:

1. `game/scripts/skill_effects.gd`: `render()`와 `projectile()` 맨 앞에 새 렌더러 호출 각 한 줄. 처리하지 않는 효과는 기존 원화/도형 경로로 계속 진행한다.
2. `game/scripts/active_skills.gd`: cast 동안 `casting_vfx` 메타데이터를 생성하고 종료 시 제거한다. 생성된 투사체에 시각 메타데이터를 붙인다. `fx(..., visual:Dictionary={})`는 생성한 이벤트를 반환하며 `add_zone(..., visual:Dictionary={})`는 펄스 시간을 전달한다. 부채꼴 발사 그림의 위치를 실제 발사점으로 보정했다. **기존 bonuses()의 gear/cooldown_factor 변경은 이번 VFX 작업에 속하지 않는다.**
3. `game/scripts/job_combat.gd`: `fx()` 선택 인자/반환값, `cast_visual()` helper, windup/release 정보, 실제 스킬 위치·이동 끝점·범위 추적·투사체 정보만 추가했다. zone의 중복 짧은 FX를 제거하고 실제 zone FX 하나를 사용한다. 원소술사 chain은 기존 근접 판정 루프에서 수용한 적까지 그린다. 판정 반경·피해·자원·쿨다운은 변경하지 않았다.

검증/문서:

- `game/tests/skill_vfx.gd`, `game/tests/visual_skill_vfx.gd` (+ `.uid`).
- `tools/check_skill_effects.py`.
- `docs/SKILL_EFFECTS.ko.md`, `docs/SKILL_EFFECTS_PLAN.md`, 이 문서.

## 이벤트 계약

`skill_fx`의 기존 `fx`, `pos`, `dir`, `owner`, `duration`, `radius`, `end`, `sound`를 유지한다. `main.on_event()`가 시각 수명 `life`, `max_life`를 추가한다.

| 필드 | 의미 |
| --- | --- |
| `skill_id` | 발동한 카탈로그 노드 ID. 자동 회피/지원 발동에는 없을 수 있다. |
| `skill_mode` | 카탈로그/Scaling의 실제 모드. |
| `class_id` | 시전자 직업. |
| `rank` | 실제 스킬 랭크. 렌더 밀도는 1~3으로 제한한다. |
| `owner` | 시전자 플레이어 ID. |
| `origin`, `end`, `pos`, `dir` | 논리 월드 Vector2. `world_point()`로 투영한다. |
| `count` | 타격/발사 횟수의 시각 참고값. |
| `skill_phase` | 전직 `windup` 또는 `release`. 기본 스킬에는 없어도 된다. |
| `pulse_times` | zone의 실제 상대 타격 시각 복사본. |
| `follow_owner`, `follow_offset` | 이동하는 근접 연타 범위의 시전자 추적 여부와 조준 방향 오프셋. |
| `vfx` | 갤러리 등에서 사용하는 선택적 효과 계열 직접 지정. |

**현재 `cast_id`와 `source` 필드는 새로 만들지 않았다.** 무력화 작업에서 전투 발동 ID/피해 출처를 추가할 경우 시각 렌더러는 이를 읽거나 수정하지 않는다. 피해·무력화 계산은 시뮬레이션의 실제 적중 경로에 연결하고, FX 이벤트 수·재생 횟수·펄스 그림에서 계산하지 않는다. `owner`는 플레이어 ID이며 `skill_id`는 발동마다 고유한 ID가 아니다.

자동 회피·지원 효과처럼 스킬 메타데이터가 없는 직업 시트 키는 기존 JobArt로 넘겨 의미가 바뀌지 않게 했다. 캐릭터·소환수 원화는 유지했다.

## 검증과 미리보기

전체 회귀 최종 재실행: `python tools/verify_v01.py` → `V01_GATE PASS checks=24486`. 로그: `runtime/v01-checks/20260909-184910`, 결과 `artifacts/v01_verification.json`.

전용 검사 최종 PASS: `python tools/check_skill_effects.py`. 224개 액티브 × 첫/최대 랭크 = 448회 발동, 18계열, 이동 56회, 529개 FX 이벤트, 13,173개 항목 실패 0. 실제 전투 캡처 8장/65개 검사 실패 0/렌더 오류 0 및 갤러리 3장 생성 통과. 로그: `runtime/skill-effects-checks/20260909-184837-45916`. 최초 검사 종료의 오디오 객체 경고는 테스트의 `stop_audio()` 후 비동기 정리 대기로 해결했고 최종 실행은 경고가 없다.

실행: `Preview-Skill-Effects.cmd`. Space 재생/정지, R 다시 재생, 1~3 시각 강도. 갤러리는 개인 저장을 열지 않는다.

생성 완료·육안 검토한 경로:

- `artifacts/skill-effects-gallery-1.png` ~ `-3.png` (0.22 / 0.55 / 0.90초).
- `artifacts/skill-effects-combat-*.png` (실제 session.act 기반 전투 장면 8종).
- `artifacts/skill-effects-verification.json` (전용 검사 기록).

새 그림 파일을 다운로드하거나 외부 에셋을 추가하지 않았다. 모든 신규 VFX는 Godot CanvasItem 도형으로 그린다.
