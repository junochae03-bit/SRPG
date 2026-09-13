# 확정 18종 atlas reader 인계

메인 요청에 따라 새 reader/카탈로그/PNG/셰이더/테스트만 추가했다. 기존 skill_effects.gd, skill_vfx.gd와 공유 DB는 수정하지 않았다. Godot 동시 실행 금지 요청에 따라 엔진을 실행하지 않았으며 파싱·GPU 렌더·인게임 검증은 메인 실행 대기다.

## API와 호출 위치

`game/scripts/skill_atlas_v06.gd`는 전용 additive Node2D 레이어다. 기존 draw CanvasItem과 같은 화면 좌표계의 자식으로 한 번 생성한다. 원래 CanvasItem의 material을 바꾸지 않는다. 시야 마스킹/레이어 순서는 메인이 기존 VFX와 맞춰 연결해야 한다. 적 위험 외곽 위에 불투명 효과를 겹치지 않는다.

- 매 렌더 프레임 시작에 `layer.begin_frame()`을 정확히 한 번 호출한다. 이벤트가 없어도 호출하고 세션 종료 때 레이어를 숨기거나 제거한다.
- 기존 `SkillVfx.render_ground(game,event)`를 먼저 유지한다.
- `layer.render(game,event,elapsed_seconds,duration_seconds,"event")`를 호출한다. life/max_life 이벤트는 elapsed=max_life-life, duration=max_life다. 반환 true는 atlas 소유 이벤트라는 뜻이며, 펄스 사이 빈 구간도 true라 기존 장식이 튀어나오지 않는다. false면 기존 fallback을 쓴다.
- `binding(event).keep_procedural_link`가 true인 연쇄는 기존 연결선 렌더를 유지해야 한다. atlas는 end의 적중 장식만 그린다. 현재 procedural 전체를 무조건 early return으로 지우지 않는다. 연결선만 분리할 때 공통 수정은 메인이 한다.
- 투사체 경로는 channel="projectile". 실제 투사체의 age/lifetime을 전달해야 한다. 해당 시계가 없는 호출부에서 남은 사거리로 가짜 시간을 만들지 말고 기존 procedural을 유지한다. visual_origin/visual_start를 그대로 전달하며 reader가 CharacterPresentation.projectile_offset을 한 번만 적용한다.
- `sample(event,t,duration,channel)`는 게임 상태를 수정하지 않는 순수 샘플 함수. t는 정규화값이 아닌 경과 초다. pulse_times의 가장 최근 실제 펄스에서만 짧게 재생하고 새 펄스를 생성하지 않는다.

동일 이벤트의 반복 enqueue는 호출부가 피한다. begin_frame 이전 명령은 다음 프레임에 남지 않는다. 시전 취소·사망·새 인스턴스 전환으로 원본 이벤트가 제거되면 다시 enqueue하지 않는다. reader는 일반 이벤트의 취소 상태를 추측하지 않으며 cancelled=true는 거부한다. follow_owner는 현재 생존 시전자와 실제 타격 계산에 쓰는 owner.aim으로 위치를 구한다. windup은 기존 표현으로 fallback한다.

## 확정 범위

카탈로그에는 18효과/108프레임과 canonical active ID·class_id·skill_mode가 모두 일치하는 37바인딩만 있다. 옛38개 추천 중 runesword_a02(enchant)는 지원모드이므로 배제했다. 원본 atlas6장은 그대로 복사했으므로 이미지 안에는 미배정6행도 남아 있으나 카탈로그/바인딩에서는 접근할 수 없다. 미배정 효과·궁극기·3차·추출 원작 이미지는 연결하지 않는다.

최대 보이는 폭/높이는 224px 이하로, 방향성 효과는 회전까지 고려한 보수적 대각선 상한을 쓴다. rank/visual_scale을 다시 곱하지 않는다. 장식 크기는 실제 범위가 아니다. 원본6장의 SHA256을 확인했고 원본 픽셀은 수정하지 않았다. 출처는 SRPG-equipment의 자체 ImageGen 산출물이며 카탈로그 source_sha256과 이전 ATTACK_SPRITES_PROMPTS.json을 참고한다.

## 메인 검증 명령

Godot --headless --path game --script res://tests/skill_atlas_v06.gd

테스트는 37바인딩/108프레임, 모드불일치 거부, windup/예비효과 거부, actual pulse gap, 종료, 중복 visual_scale 방지를 검사한다. 현재 Python 정적 검증으로 18효과/37실존 active ID/원본해시/모든 프레임224상한을 확인했다. 메인은 import 후 파싱·실제 draw 레이어·좌우/잠긴 aim·발사 위치·연쇄선·취소·시야/6인 위험 경계를 확인해야 한다. reader API를 준비한 상태이며 런타임 연결 완료라고 보고하지 않는다.

## 시야 마스크 후속 수정

메인 로그 line17 실패는 ResourceLoader.exists 검사이며 신규 PNG6장에 import 메타파일이 없는 상태를 확인했다. 검사 삭제 없이 메인이 import 후 재실행한다. 테스트는 실제 checks/failures를 집계하고 실패 시 exit1이다.

shader는 visible_ground와 같은 inverse iso/12.5 원점/green channel/경계 밖0 처리를 한다. render 호출마다 game.vision 및 현재 camera/screen_anchor uniform을 갱신한다. 회전·스케일을 CPU polygon 꼭짓점에 적용해 VERTEX가 화면좌표가 되게 한다. 투사체의 visual elevation은 꼭짓점 색채널에 전달하고 셰이더에서 빼서 지면 시야에 투영한다. 색 modulation은 vertex 단계에서 흰색으로 복원한다. 지면 효과는 offset0이다. 레이어 z=-2 배치는 메인이 연결한다. GPU mask/회전/고도 검증은 메인의 엔진 실행 대기이며 이번에는 엔진 실행하지 않았다.
