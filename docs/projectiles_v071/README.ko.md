# V0.7.1 투사체 시각 연출

화살, 볼트, 단검, 비전, 화염, 냉기, 번개, 암흑 8계열 × 4프레임 = 32 비행 프레임. 작은 숲 배경 캐릭터에 맞춘 윤곽과 색을 사용한다. PNG 원본은 수정하지 않는다. physical.png는 런타임 마젠타 제거, elements.png는 원본 알파를 사용한다. 생성 원본 위치와 프롬프트는 generation.json, 해시는 catalog.json에 있다.

## 전투 연결 계약

- 전용 Node2D `projectile_visual_v071.gd`를 생성하고 매 화면 프레임 `begin_frame(game)`을 호출한다. 투사체가 없는 프레임에도 호출해 이전 명령을 지운다. 세션 종료 시 기존 시각 레이어와 함께 정리한다.
- 기존 투사체 그림 전에 `render_shot(game, shot)`을 호출한다. true이면 기존 그림을 생략하고 false이면 기존 fallback을 유지한다. wave/card 및 지원하지 않는 계열은 fallback 대상이다.
- 실제 발사 시 `projectile_launch` 이벤트를 추가한다. 필드: projectile_type, class_id, skill_id/skill_mode(있을 때), dir, pos, visual_origin, duration=0.1. 스킬별 필드는 launch 직후 부여되는 경우가 있으므로 최종 shot 메타데이터와 일치시킨다.
- 실제 `hit(...)` 승인 직후에만 `projectile_impact` 이벤트를 추가한다. 필드: projectile_type, class_id, skill_id/skill_mode, dir, pos=승인된 충돌 위치, visual_offset, duration=0.24. visual_offset은 shot 복사본의 pos를 해당 충돌 위치로 바꿔 Presentation.projectile_offset으로 산출한다. visual_family가 있으면 두 이벤트에 복사한다.
- 이벤트 그리기에서 `render_event(game,event,t,duration)`을 호출하고 true이면 중복 fallback을 생략한다. 명중 실패·벽 소멸·사거리 종료에 명중 장식을 만들지 않는다.
- 기본 발사 데이터에 class_id를 보존하면 hunter bow는 bolt로 구분한다. 단검은 명시적인 dagger/visual_family=dagger 투사체에만 사용한다. 기존 근접 공격을 투사체로 바꾸지 않는다.

## 표현 규칙

탄체는 실제 shot.dir의 등각 투영 방향으로 회전하며 발사 지점의 visual_origin에서 기존 비행 높이 -70으로 수렴한다. 비행 프레임은 12 fps로 반복하며 수명이 끝나기 전에 흐려지지 않는다. 잔상은 실제 이동 거리와 속도로 제한하고 최대 76 px이다. 탄체 기준 폭은 42~60 px, 발사 장식은 30 px, 명중 장식은 물리 68 px / 마법 96 px이다. 이는 일반 투사체용이며 큰 범위 스킬의 기존 크기 규칙과 별개다.

기존 공격 아틀라스의 장식을 재사용한다: arrow/bolt→heavy_impact, dagger→cross_slash, arcane→holy_judgment, fire→fire_burst, frost→ice_shatter, thunder→chain_lightning, shadow→void_rend. 별도 shader에서 검정 배경을 알파로 변환하고 시야 마스크를 적용한다. 속도·사거리·피해량·관통·재사용 대기시간은 변경하지 않는다.

## 검증 구분

- 원본/카탈로그 정적 검사: 8계열, 32프레임 및 경계 분리 확인 완료.
- `game/tests/projectile_visual_v071.gd`: 반복 프레임, 6방향 회전, 발사 위치, 높이 수렴, 잔상 제한, 입력 불변 검사. Godot 4.6 headless 292 checks / 0 failures (skill_mode/vfx 단독 입력 및 gambler fallback 포함).
- `game/tests/visual_projectile_v071.gd`: 실제 게임 배경 위 8계열 × 발사/비행/명중의 독립 렌더 캡처. Godot 4.6 OpenGL GPU 24 checks / 0 failures. 실전 충돌 검증과 구분한다. 캡처는 artifacts/projectile-v071-계열-단계.png이다.
- 실제 전투 연결: projectile_combat_v071 76/0, 기존 combat 51/0, qa_combat_v052 143/0.
- 실제 main/Simulation/GPU: projectile_live_visual_v071 65/0, 25캡처. 명중·몸 앞 표시·빈 프레임·연결 종료·벽 충돌·시야 밖 contact 숨김 확인.
- 협동 전송: snapshot 직렬화 왕복 메타데이터 검사 통과. 다중 클라이언트 ENet 재실행은 메인의 전체 통합 검사에 남긴다.

메인이 main.gd, player_combat.gd, skill_effects.gd의 투사체 구간 소유권을 추가로 넘겨 실제 연결을 구현했다. simulation.gd는 변경하지 않았으며 기존 스냅샷의 메타데이터 복사를 사용한다. 최초 투사체 tick에서 최종 스킬 정보를 담아 발사 이벤트를 한 번 생성하고 hit 승인 직후 명중 이벤트를 생성한다. 기존 기본 발사 flash는 새 reader 지원 계열에서 중복되지 않는다. gambler/card/wave는 기존 fallback을 유지한다.

추가 회귀 검사: projectile_combat_v071.gd(실제 명중·빗나감·벽·거절·관통·스냅샷), projectile_live_visual_v071.gd(실제 main/Simulation 충돌에서 GPU로 이어지는 8계열 캡처). 실행 완료 결과는 verification.json에 기록했다. 비행/잔상은 z=-2를 유지하고, 명중 contact만 절대 z=0 자식층으로 몬스터 몸 위에 표시한다. 두 층 모두 같은 시야 마스크를 사용한다. 검증 화면은 artifacts/projectile-live-v071-*.png이다. 메인의 커밋 및 릴리스 빌드 전 작업 파일 기준이다.
