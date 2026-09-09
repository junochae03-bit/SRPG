# 스킬 이펙트

전투 스킬에 서로 구분되는 절차형 이펙트 18종을 적용한다. 기존 스킬의 피해량, 소모량, 쿨다운과 저장 데이터는 그대로 사용한다. 스킬 랭크 1~3에 따라 광선·입자·장식 밀도가 달라진다.

| 계열 | 이펙트 | 표현 |
| --- | --- | --- |
| `slash` | 섬광 검격 | 방향을 따라 휘어지는 검기 |
| `spin` | 회전 참격 | 회전하는 연속 칼날 |
| `fire` | 화염 폭발 | 불꽃과 팽창하는 폭발 |
| `frost` | 빙결 결정 | 얼음 고리와 솟는 결정 |
| `thunder` | 천둥 낙뢰 | 수직 번개와 지면 섬광 |
| `impact` | 대지 충격 | 충격파와 파편 |
| `rain` | 화살 폭우 | 넓은 범위에 쏟아지는 화살 |
| `shot` | 관통 사격 | 방향성 투사체와 잔광 |
| `poison` | 맹독 지대 | 독성 안개와 기포 |
| `heal` | 회복의 빛 | 상승하는 회복 빛 |
| `barrier` | 수호 장벽 | 보호막 외곽과 방어 문양 |
| `haste` | 가속의 바람 | 바람 궤적과 상승 표시 |
| `summon` | 소환 의식 | 소환진과 에너지 기둥 |
| `cards` | 마력 카드 | 회전하는 카드와 마력 |
| `chain` | 마력 사슬·연쇄 번개 | 사신의 사슬 고리, 마법사의 지그재그 전격 |
| `vortex` | 차원 소용돌이 | 중심으로 회전하는 에너지 |
| `blink` | 순간 이동 | 출발·도착 지점과 이동 잔광 |
| `rune` | 룬 마법진 | 문양과 원형 마법진 |

## 미리보기 실행

`publish/SRPG/Preview-Skill-Effects.cmd`를 실행하면 1440×900 이펙트 스튜디오가 열린다. 실행기는 `GODOT_EXE`, 프로젝트의 Godot, 저장소의 `RPG2/tools/godot`, PATH 순으로 엔진을 찾는다.

- **Space** 또는 일시정지 버튼: 애니메이션 재생·정지.
- **R** 또는 다시 재생 버튼: 처음부터 재생.
- **1 / 2 / 3** 또는 랭크 버튼: 효과 강도를 즉시 비교.

18종은 각각의 영역 안에서 반복 재생된다. 이 화면은 저장이나 전투 상태를 불러오지 않는 독립 장면이다.

자동 PNG 캡처 예시(PowerShell, `publish/SRPG`에서 실행):

```powershell
& '..\..\RPG2\tools\godot\Godot_v4.6-stable_win64_console.exe' --path game --log-file runtime/skill-effects-gallery.log res://vfx_gallery.tscn -- '--capture=D:/SSRPG/publish/SRPG/artifacts/skill-effects.png' --capture-at=0.4 --duration=2 --rank=2
```

`--capture-at`은 애니메이션 시각(초), `--duration`은 자동 종료 시간(초), `--rank`는 시작 랭크다. PNG 생성에는 실제 렌더러를 사용하므로 `--headless`를 붙이지 않는다. 저장 성공 시 `VFX_GALLERY_CAPTURE_OK`가 출력된다.

## 실제 전투 적용

`skill_effects.gd`가 `skill_vfx.gd`의 렌더러를 호출한다. 기본 직업·전직 스킬에서 전달한 스킬 식별자와 모드로 효과 계열을 결정하고, 이벤트의 위치·방향·랭크·남은 수명에 맞춰 그린다. `vfx` 필드를 지정하면 해당 계열을 직접 선택할 수 있다. 전직 원화는 미분류 효과의 호환 경로로 보존하고, 캐릭터 및 소환수 그림은 그대로 사용한다.

차지는 빛이 모이는 예비 동작으로 표시하며 취소하면 사라진다. 이동 기술은 실제 출발점과 도착점 사이에 잔광을 남기고, 근접 연타 범위는 시전자를 따라간다. 배운 스킬의 투사체에도 화염·얼음·독·카드·검기 등의 표현을 적용한다. 전직 랭크 4~5는 세 번째 시각 밀도를 사용해 화면을 과도하게 채우지 않는다.

갤러리와 전투가 같은 `SkillVfx.render(game, event)` 구현을 사용하므로 효과를 수정하면 두 화면에 함께 반영된다. 갤러리는 화면 좌표를 직접 사용하고, 전투는 `world_point`로 월드 좌표를 화면에 투영한다.

## 검증

`publish/SRPG`에서 실행한다.

```powershell
python tools/check_skill_effects.py --import-only
python tools/check_skill_effects.py
python tools/verify_v01.py
```

전용 검사는 엔진 가져오기와 효과 연결을 확인하고, 기존 전체 검사는 전투·진행·저장 동작의 회귀를 확인한다. 이미지 검토에서는 효과별 실루엣, 각 셀 안의 범위, 페이드와 18개 동시 재생을 확인한다.

검증 결과: 전체 회귀 24,486항목 PASS. 전용 검사 13,173항목 PASS(224개 액티브, 448회 발동, 18계열, 이동 56회). 실제 전투 8장/65항목 및 갤러리 3장 렌더 PASS, 오류·경고 없음. 결과는 `artifacts/skill-effects-verification.json`, 전투 이미지는 `artifacts/skill-effects-combat-*.png`, 갤러리는 `artifacts/skill-effects-gallery-1.png` ~ `-3.png`에 있다.
